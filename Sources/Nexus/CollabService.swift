// NEXUS Collab — LAN rooms over Bonjour.
// No server, no accounts: every Mac advertises itself as _nexuscollab._tcp
// with the room code in the TXT record. Join a code, discover everyone in
// that room on the local network, mesh-connect, chat + share a task board.
// Share the code (or the nexus://room/CODE link) with anyone on the same Wi-Fi.

import SwiftUI
import Network

struct CollabMessage: Identifiable, Codable, Equatable {
    var id: String
    var from: String
    var text: String
    var ts: Date
}

struct CollabTask: Identifiable, Codable, Equatable {
    var id: String
    var text: String
    var done: Bool
    var by: String
}

struct CollabMember: Identifiable, Equatable {
    var id: String
    var handle: String
}

final class CollabService: ObservableObject, @unchecked Sendable {
    static let shared = CollabService()

    @Published var handle: String
    @Published var roomCode: String? = nil
    @Published var members: [CollabMember] = []
    @Published var messages: [CollabMessage] = []
    @Published var tasks: [CollabTask] = []
    @Published var lastError: String = ""

    let myID = UUID().uuidString

    private var listener: NWListener?
    private var browser: NWBrowser?
    private var conns: [String: NWConnection] = [:]   // peer uid → connection
    private var seen = Set<String>()                   // message dedup
    private var connectLock = Set<String>()            // avoid parallel dials

    private init() {
        let saved = UserDefaults.standard.string(forKey: "nexus.handle")
        handle = saved ?? Self.generateHandle()
        UserDefaults.standard.set(handle, forKey: "nexus.handle")
    }

    private static func generateHandle() -> String {
        let a = ["RED", "AXIOM", "CIPHER", "EMBER", "ONYX", "PULSE", "VANTA", "RELAY", "NOVA", "HALO"]
        let b = ["FOX", "HAWK", "WOLF", "VIPER", "RAVEN", "TITAN", "ORBIT", "FLUX", "ECHO", "BOLT"]
        return "\(a.randomElement()!)-\(b.randomElement()!)-\(Int.random(in: 10...99))"
    }

    // MARK: - Room lifecycle

    func createRoom() {
        let chars = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        let code = String((0..<4).map { _ in chars.randomElement()! })
        join(code)
    }

    func join(_ rawCode: String) {
        leave(silent: true)
        let code = rawCode.uppercased().trimmingCharacters(in: .whitespaces)
        guard code.count == 4 else { lastError = "Room codes are 4 characters"; return }
        roomCode = code
        loadHistory()
        seen = Set(messages.map(\.id))
        startListener()
        startBrowser()
        members = [CollabMember(id: myID, handle: handle)]
    }

    func leave(silent: Bool = false) {
        broadcast(["t": "bye", "fid": myID, "from": handle])
        listener?.cancel(); listener = nil
        browser?.cancel(); browser = nil
        for (_, c) in conns { c.cancel() }
        conns = [:]
        connectLock.removeAll()
        members = []
        if !silent {
            roomCode = nil
            messages = []
            tasks = []
        }
    }

    var inviteLink: String { "nexus://room/\(roomCode ?? "")" }

    func copyInvite() {
        let paste = NSPasteboard.general
        paste.clearContents()
        paste.setString(inviteLink, forType: .string)
    }

    // MARK: - Networking

    private func startListener() {
        guard let code = roomCode else { return }
        do {
            let params = NWParameters.tcp
            params.includePeerToPeer = true
            let lst = try NWListener(using: params)
            let txt = NWTXTRecord(["room": code, "uid": myID, "h": handle])
            lst.service = NWListener.Service(name: "\(handle)-\(myID.prefix(4))",
                                             type: "_nexuscollab._tcp",
                                             txtRecord: txt)
            lst.newConnectionHandler = { [weak self] conn in
                self?.accept(conn)
            }
            lst.stateUpdateHandler = { [weak self] st in
                if case .failed = st {
                    DispatchQueue.main.async { self?.lastError = "listener failed — try rejoining" }
                }
            }
            lst.start(queue: .main)
            listener = lst
        } catch {
            lastError = "Cannot listen: \(error.localizedDescription)"
        }
    }

    private func startBrowser() {
        let br = NWBrowser(for: .bonjour(type: "_nexuscollab._tcp", domain: "local."), using: .tcp)
        br.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self = self, let room = self.roomCode else { return }
            for r in results {
                guard case .bonjour(let txt) = r.metadata,
                      let rRoom = txt["room"], rRoom == room,
                      let uid = txt["uid"], uid != self.myID else { continue }
                if self.conns[uid] == nil, !self.connectLock.contains(uid) {
                    self.connectLock.insert(uid)
                    self.dial(r.endpoint, uid: uid, peerHandle: txt["h"] ?? String(uid.prefix(6)))
                }
            }
        }
        br.start(queue: .main)
        browser = br
    }

    private func dial(_ endpoint: NWEndpoint, uid: String, peerHandle: String) {
        let conn = NWConnection(to: endpoint, using: .tcp)
        conn.stateUpdateHandler = { [weak self] st in
            switch st {
            case .ready:
                DispatchQueue.main.async {
                    self?.conns[uid] = conn
                    self?.upsertMember(id: uid, handle: peerHandle)
                    self?.receiveLoop(conn, uid: uid)
                    self?.sendRaw(["t": "hello", "fid": self?.myID ?? "", "from": self?.handle ?? ""])
                    self?.sendRaw(["t": "sync", "fid": self?.myID ?? "",
                                   "msgs": (self?.messages.suffix(50).map { m in
                                       ["id": m.id, "from": m.from, "text": m.text, "ts": m.ts.timeIntervalSince1970]
                                   }) ?? [],
                                   "tasks": (self?.tasks ?? []).map { t in
                                       ["id": t.id, "text": t.text, "done": t.done, "by": t.by]
                                   }])
                }
            case .failed, .cancelled:
                DispatchQueue.main.async {
                    self?.conns[uid]?.cancel()
                    self?.conns[uid] = nil
                    self?.connectLock.remove(uid)
                    self?.members.removeAll { $0.id == uid }
                }
            default: break
            }
        }
        conn.start(queue: .main)
    }

    private func accept(_ conn: NWConnection) {
        conn.stateUpdateHandler = { [weak self] st in
            if case .ready = st {
                self?.receiveLoop(conn, uid: "incoming-\(UUID().uuidString.prefix(6))")
            }
        }
        conn.start(queue: .main)
    }

    private func receiveLoop(_ conn: NWConnection, uid: String) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if let data = data, !data.isEmpty {
                self.handlePayload(data, from: conn)
            }
            if isComplete || error != nil {
                DispatchQueue.main.async {
                    self.conns[uid]?.cancel()
                    self.conns[uid] = nil
                    self.connectLock.remove(uid)
                }
                return
            }
            self.receiveLoop(conn, uid: uid)
        }
    }

    /// Messages are newline-delimited JSON; may arrive batched or split.
    private var rxBuffer = Data()

    private func handlePayload(_ data: Data, from conn: NWConnection) {
        rxBuffer.append(data)
        while let nl = rxBuffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = rxBuffer[rxBuffer.startIndex...nl]
            rxBuffer.removeSubrange(rxBuffer.startIndex...nl)
            let chunk = Data(line.dropLast())
            guard (try? JSONSerialization.jsonObject(with: chunk)) != nil else { continue }
            DispatchQueue.main.async { self.applyLine(chunk, from: conn) }
        }
    }

    private func applyLine(_ chunk: Data, from conn: NWConnection) {
        guard let obj = (try? JSONSerialization.jsonObject(with: chunk)) as? [String: Any] else { return }
        apply(obj, from: conn)
    }

    private func apply(_ obj: [String: Any], from conn: NWConnection) {
        let type = obj["t"] as? String ?? ""
        let fid = obj["fid"] as? String ?? ""
        let from = obj["from"] as? String ?? "??"
        switch type {
        case "hello":
            if fid != myID {
                upsertMember(id: fid, handle: from)
                conns[fid] = conn
                connectLock.insert(fid)
            }
        case "msg":
            let mid = obj["id"] as? String ?? UUID().uuidString
            guard !seen.contains(mid), fid != myID else { return }
            seen.insert(mid)
            let ts = (obj["ts"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
            messages.append(CollabMessage(id: mid, from: from, text: obj["text"] as? String ?? "", ts: ts))
            saveHistory()
            flood(obj, except: conn)
        case "sync":
            guard messages.isEmpty else { return }
            if let msgs = obj["msgs"] as? [[String: Any]] {
                for m in msgs {
                    let mid = m["id"] as? String ?? UUID().uuidString
                    guard !seen.contains(mid) else { continue }
                    seen.insert(mid)
                    messages.append(CollabMessage(id: mid,
                                                  from: m["from"] as? String ?? "??",
                                                  text: m["text"] as? String ?? "",
                                                  ts: (m["ts"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()))
                }
                messages.sort { $0.ts < $1.ts }
            }
            if let ts = obj["tasks"] as? [[String: Any]] {
                tasks = ts.map { t in
                    CollabTask(id: t["id"] as? String ?? UUID().uuidString,
                               text: t["text"] as? String ?? "",
                               done: t["done"] as? Bool ?? false,
                               by: t["by"] as? String ?? "??")
                }
            }
            saveHistory()
        case "task":
            guard let t = obj["task"] as? [String: Any] else { return }
            let tid = t["id"] as? String ?? ""
            if let i = tasks.firstIndex(where: { $0.id == tid }) {
                tasks[i].done = t["done"] as? Bool ?? tasks[i].done
            } else {
                tasks.append(CollabTask(id: tid, text: t["text"] as? String ?? "",
                                        done: t["done"] as? Bool ?? false,
                                        by: t["by"] as? String ?? from))
            }
            saveHistory()
            flood(obj, except: conn)
        case "bye":
            members.removeAll { $0.id == fid }
            conns[fid]?.cancel()
            conns[fid] = nil
            connectLock.remove(fid)
        default: break
        }
    }

    // MARK: - Send

    func send(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let mid = UUID().uuidString
        seen.insert(mid)
        let msg = CollabMessage(id: mid, from: handle, text: t, ts: Date())
        messages.append(msg)
        saveHistory()
        broadcast(["t": "msg", "id": mid, "fid": myID, "from": handle, "text": t, "ts": msg.ts.timeIntervalSince1970])
    }

    func addTask(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let task = CollabTask(id: UUID().uuidString, text: t, done: false, by: handle)
        tasks.append(task)
        saveHistory()
        broadcast(["t": "task", "fid": myID, "from": handle,
                   "task": ["id": task.id, "text": task.text, "done": task.done, "by": task.by]])
    }

    func toggleTask(_ id: String) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].done.toggle()
        let t = tasks[i]
        saveHistory()
        broadcast(["t": "task", "fid": myID, "from": handle,
                   "task": ["id": t.id, "text": t.text, "done": t.done, "by": t.by]])
    }

    private func broadcast(_ obj: [String: Any]) { flood(obj, except: nil) }

    private func flood(_ obj: [String: Any], except keep: NWConnection?) {
        guard var data = try? JSONSerialization.data(withJSONObject: obj) else { return }
        data.append(0x0A)
        for (_, c) in conns where c !== keep && (c.state == .ready) {
            c.send(content: data, completion: .contentProcessed { _ in })
        }
    }

    private func sendRaw(_ obj: [String: Any]) {
        guard var data = try? JSONSerialization.data(withJSONObject: obj) else { return }
        data.append(0x0A)
        for (_, c) in conns where c.state == .ready {
            c.send(content: data, completion: .contentProcessed { _ in })
        }
    }

    private func upsertMember(id: String, handle h: String) {
        if let i = members.firstIndex(where: { $0.id == id }) {
            members[i].handle = h
        } else {
            members.append(CollabMember(id: id, handle: h))
        }
    }

    // MARK: - Local history

    private var historyFile: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Nexus/rooms", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(roomCode ?? "none").json")
    }

    private func saveHistory() {
        struct Snap: Codable { var messages: [CollabMessage]; var tasks: [CollabTask] }
        let snap = Snap(messages: messages, tasks: tasks)
        try? JSONEncoder().encode(snap).write(to: historyFile)
    }

    private func loadHistory() {
        struct Snap: Codable { var messages: [CollabMessage]; var tasks: [CollabTask] }
        guard let d = try? Data(contentsOf: historyFile),
              let snap = try? JSONDecoder().decode(Snap.self, from: d) else { return }
        messages = snap.messages
        tasks = snap.tasks
    }
}
