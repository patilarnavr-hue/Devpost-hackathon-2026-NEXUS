// NEXUS SwiftUI Models — data structures for UI

import Foundation

enum MachineState: String, CaseIterable {
    case idle = "IDLE"
    case perceiving = "PERCEIVING"
    case analyzing = "ANALYZING"
    case planning = "PLANNING"
    case waitingForPermission = "WAITING_FOR_PERMISSION"
    case executing = "EXECUTING"
    case verifying = "VERIFYING"
    case replanning = "REPLANNING"
    case success = "SUCCESS"
    case error = "ERROR"
}

enum VerificationStatus: String {
    case notRun = "not_run"
    case running = "running"
    case passed = "passed"
    case failed = "failed"
}

struct ActivityEvent: Identifiable {
    let id: String
    let timestamp: Date
    let type: String
    let source: String
    let workflow: String
    let severity: String
    let message: String

    init(type: String, message: String, timestamp: Date = Date(), severity: String = "info") {
        self.id = UUID().uuidString
        self.timestamp = timestamp
        self.type = type
        self.source = "local"
        self.workflow = ""
        self.severity = severity
        self.message = message
    }

    init?(from dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let timestamp = dict["timestamp"] as? Double,
              let type = dict["type"] as? String,
              let message = dict["message"] as? String else { return nil }

        self.id = id
        self.timestamp = Date(timeIntervalSince1970: timestamp)
        self.type = type
        self.source = dict["source"] as? String ?? ""
        self.workflow = dict["workflow"] as? String ?? ""
        self.severity = dict["severity"] as? String ?? "normal"
        self.message = message
    }
}

struct PlanStepData: Identifiable {
    let id: String
    let objective: String
    let tool: String
    let risk: String
    let status: String
    let expectedResult: String
    let postcondition: String

    init(from dict: [String: Any]) {
        self.id = dict["id"] as? String ?? ""
        self.objective = dict["objective"] as? String ?? ""
        self.tool = dict["tool"] as? String ?? ""
        self.risk = dict["risk"] as? String ?? "low"
        self.status = dict["status"] as? String ?? "pending"
        self.expectedResult = dict["expected_result"] as? String ?? ""
        self.postcondition = dict["postcondition"] as? String ?? ""
    }
}

struct PlanData: Identifiable {
    let id: String
    let objective: String
    let status: String
    let steps: [PlanStepData]

    init(from dict: [String: Any]) {
        self.id = dict["id"] as? String ?? ""
        self.objective = dict["objective"] as? String ?? ""
        self.status = dict["status"] as? String ?? "pending"
        if let stepsArray = dict["steps"] as? [[String: Any]] {
            self.steps = stepsArray.map { PlanStepData(from: $0) }
        } else {
            self.steps = []
        }
    }
}

struct MemoryItem: Identifiable {
    let id: String
    let type: String
    let content: String
    let source: String
    let timestamp: Date
    let confidence: Double
    let relevance: Double

    init?(from dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let type = dict["type"] as? String,
              let content = dict["content"] as? String else { return nil }

        self.id = id
        self.type = type
        self.content = content
        self.source = dict["source"] as? String ?? ""
        self.timestamp = Date(timeIntervalSince1970: dict["timestamp"] as? Double ?? 0)
        self.confidence = dict["confidence"] as? Double ?? 0.5
        self.relevance = dict["relevance"] as? Double ?? 0.5
    }
}

// MARK: - Sessions (persistent worlds)

struct SessionSummary: Identifiable {
    let id: String
    let name: String
    let objective: String
    let state: String
    let workflow: String
    let timelineCount: Int
    let active: Bool
    let updatedAt: Date

    init(from dict: [String: Any]) {
        self.id = dict["id"] as? String ?? ""
        self.name = dict["name"] as? String ?? "SESSION"
        self.objective = dict["objective"] as? String ?? ""
        self.state = dict["state"] as? String ?? "IDLE"
        self.workflow = dict["workflow"] as? String ?? ""
        self.timelineCount = dict["timeline_count"] as? Int ?? 0
        self.active = dict["active"] as? Bool ?? false
        self.updatedAt = Date(timeIntervalSince1970: dict["updated_at"] as? Double ?? 0)
    }
}

struct SessionEntry: Identifiable {
    let id: String
    let t: Date
    let kind: String   // goal | event | decision | chat
    let label: String
    let severity: String
    let role: String   // user | nexus (chat turns)

    init(from dict: [String: Any], index: Int) {
        let time = dict["t"] as? Double ?? 0
        self.id = "\(time)-\(index)"
        self.t = Date(timeIntervalSince1970: time)
        self.kind = dict["kind"] as? String ?? "event"
        self.label = dict["label"] as? String ?? ""
        self.severity = dict["severity"] as? String ?? "info"
        self.role = dict["role"] as? String ?? ""
    }
}

struct SessionInfo: Identifiable {
    var id: String
    var name: String
    var objective: String
    var state: String
    var workflow: String
    var decisions: [String]
    var timeline: [SessionEntry]

    init(id: String = UUID().uuidString, name: String, objective: String = "", state: String = "IDLE",
         workflow: String = "", decisions: [String] = [], timeline: [SessionEntry] = []) {
        self.id = id
        self.name = name
        self.objective = objective
        self.state = state
        self.workflow = workflow
        self.decisions = decisions
        self.timeline = timeline
    }

    init(from dict: [String: Any]) {
        self.id = dict["id"] as? String ?? ""
        self.name = dict["name"] as? String ?? ""
        self.objective = dict["objective"] as? String ?? ""
        self.state = dict["state"] as? String ?? "IDLE"
        self.workflow = dict["workflow"] as? String ?? ""
        if let d = dict["decisions"] as? [[String: Any]] {
            self.decisions = d.compactMap { $0["label"] as? String }
        } else {
            self.decisions = []
        }
        if let tl = dict["timeline"] as? [[String: Any]] {
            self.timeline = tl.enumerated().map { SessionEntry(from: $0.element, index: $0.offset) }
        } else {
            self.timeline = []
        }
    }
}

struct SessionBriefing {
    let objective: String
    let sessionName: String
    let relevantMemory: [String]
    let tools: [String]
    let workflow: String
    let stepsDone: Int
    let stepsTotal: Int

    init(from dict: [String: Any]) {
        self.objective = dict["objective"] as? String ?? ""
        self.sessionName = dict["session_name"] as? String ?? ""
        if let mem = dict["relevant_memory"] as? [[String: Any]] {
            self.relevantMemory = mem.map {
                let type = $0["type"] as? String ?? "memory"
                let content = $0["content"] as? String ?? ""
                return "\(type.uppercased()): \(content)"
            }
        } else {
            self.relevantMemory = []
        }
        self.tools = dict["tools"] as? [String] ?? []
        self.workflow = dict["workflow"] as? String ?? ""
        self.stepsDone = dict["steps_done"] as? Int ?? 0
        self.stepsTotal = dict["steps_total"] as? Int ?? 0
    }
}

// MARK: - Mission (phase ladder + live step)

struct MissionData {
    let objective: String
    let phase: String?        // understanding | context | research | build | verify
    let step: String
    let stepsDone: Int
    let stepsTotal: Int
    let rationale: String
    let etaMs: Int

    init(from dict: [String: Any]) {
        self.objective = dict["objective"] as? String ?? ""
        self.phase = dict["phase"] as? String
        self.step = dict["step"] as? String ?? ""
        self.stepsDone = dict["steps_done"] as? Int ?? 0
        self.stepsTotal = dict["steps_total"] as? Int ?? 0
        self.rationale = dict["rationale"] as? String ?? ""
        self.etaMs = dict["eta_ms"] as? Int ?? 0
    }
}

// MARK: - Mission Dashboard

struct ScheduledMissionData: Identifiable {
    let id: String
    let name: String
    let triggerType: String      // cron | webhook | event | manual
    let schedule: String
    let goalText: String
    let intent: String
    let enabled: Bool
    let nextRun: Date?
    let lastRun: Date?
    let runCount: Int

    init(from dict: [String: Any]) {
        self.id = dict["id"] as? String ?? ""
        self.name = dict["name"] as? String ?? ""
        self.triggerType = dict["trigger_type"] as? String ?? "cron"
        self.schedule = dict["schedule"] as? String ?? ""
        self.goalText = dict["goal_text"] as? String ?? ""
        self.intent = dict["intent"] as? String ?? "mission"
        self.enabled = dict["enabled"] as? Bool ?? true
        self.nextRun = (dict["next_run"] as? Double).map { Date(timeIntervalSince1970: $0) }
        self.lastRun = (dict["last_run"] as? Double).map { Date(timeIntervalSince1970: $0) }
        self.runCount = dict["run_count"] as? Int ?? 0
    }
}

struct MissionHistoryEntry: Identifiable {
    let id: String
    let t: Date
    let label: String
    let intent: String
    let sessionName: String

    init(from dict: [String: Any]) {
        self.id = dict["id"] as? String ?? UUID().uuidString
        self.t = Date(timeIntervalSince1970: dict["t"] as? Double ?? 0)
        self.label = dict["label"] as? String ?? ""
        self.intent = dict["intent"] as? String ?? ""
        self.sessionName = dict["session_name"] as? String ?? ""
    }
}

struct ArtifactInfo: Identifiable {
    let id: String
    let name: String
    let size: Int64
    let modified: Date
    let path: String

    init(from dict: [String: Any]) {
        self.name = dict["name"] as? String ?? ""
        self.id = self.name
        self.size = Int64(dict["size"] as? Int ?? 0)
        self.modified = Date(timeIntervalSince1970: dict["mtime"] as? Double ?? 0)
        self.path = dict["path"] as? String ?? ""
    }
}

struct DashboardData {
    var scheduled: [ScheduledMissionData] = []
    var history: [MissionHistoryEntry] = []
    var artifacts: [ArtifactInfo] = []

    init() {}

    init(from dict: [String: Any]) {
        if let s = dict["scheduled"] as? [[String: Any]] {
            scheduled = s.map { ScheduledMissionData(from: $0) }
        }
        if let h = dict["history"] as? [[String: Any]] {
            history = h.map { MissionHistoryEntry(from: $0) }
        }
        if let a = dict["artifacts"] as? [[String: Any]] {
            artifacts = a.map { ArtifactInfo(from: $0) }
        }
    }
}

// MARK: - World transition (collapse → scan → resolve)

struct WorldTransition: Equatable {
    let start: Date
    let from: String
    let to: String

    static func == (lhs: WorldTransition, rhs: WorldTransition) -> Bool {
        lhs.start == rhs.start
    }
}

// MARK: - Dynamic source arbitration

struct ArbitrationSource: Identifiable {
    let id: String
    let tool: String
    let gap: String
    let confidence: Double
    let success: Bool
    let mode: String
    let summary: String

    init(from dict: [String: Any], index: Int) {
        self.tool = dict["tool"] as? String ?? "?"
        self.gap = dict["gap"] as? String ?? ""
        self.confidence = dict["confidence"] as? Double ?? 0
        self.success = dict["success"] as? Bool ?? false
        self.mode = dict["mode"] as? String ?? ""
        self.summary = dict["summary"] as? String ?? ""
        self.id = "\(index)-\(tool)-\(gap)"
    }
}

struct ArbitrationData {
    let id: String
    let status: String        // running | resolved | incomplete | conflict | budget_exhausted
    let confidence: Double
    let mode: String          // parallel | sequential | single | ""
    let activeSource: String
    let gapsTotal: Int
    let gapsKnown: Int
    let gapsUnknown: Int
    let gapsRequired: Int
    let gapsResolved: Int
    let callsSpent: Int
    let callsMax: Int
    let conflictCount: Int
    let sources: [ArbitrationSource]

    init(from dict: [String: Any]) {
        self.id = dict["id"] as? String ?? ""
        self.status = dict["status"] as? String ?? ""
        self.confidence = dict["confidence"] as? Double ?? 0
        self.mode = dict["mode"] as? String ?? ""
        self.activeSource = dict["active_source"] as? String ?? ""
        self.gapsTotal = dict["gaps_total"] as? Int ?? 0
        self.gapsKnown = dict["gaps_known"] as? Int ?? 0
        self.gapsUnknown = dict["gaps_unknown"] as? Int ?? 0
        self.gapsRequired = dict["gaps_required"] as? Int ?? 0
        self.gapsResolved = dict["gaps_resolved"] as? Int ?? 0
        self.conflictCount = dict["conflict_count"] as? Int ?? 0
        if let budget = dict["budget"] as? [String: Any] {
            self.callsSpent = budget["calls_spent"] as? Int ?? 0
            self.callsMax = budget["max_calls"] as? Int ?? 0
        } else {
            self.callsSpent = 0
            self.callsMax = 0
        }
        if let srcs = dict["sources"] as? [[String: Any]] {
            self.sources = srcs.enumerated().map {
                ArbitrationSource(from: $0.element, index: $0.offset)
            }
        } else {
            self.sources = []
        }
    }
}
