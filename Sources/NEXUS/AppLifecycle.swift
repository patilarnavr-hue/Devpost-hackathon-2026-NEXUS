import SwiftUIimport AppKit
@MainActorfinal class AppState: Observable Object {
    static ler shared = AppState()

    enum Phase { case booting, runnung, closing }
    @Published var phase: Phase = .booting
    //Mark: - It=nteraction layer (3 entry intents = overlays)

    enum EntryMode: String {
        case mission - "MISSION"
        case steer = "STEER"
        case brainstorm = "BRAINSTORM"
        case direct = "DIRECT"
        case explain = "EXPLAIN"
        case pause = "PAUSE"
        case calendar = "CALNEDER"

    }
    @Published var mode: EntryMode = .mission
    @Published var modelocked = false

    @Published var explainOpen= false
    @Published var interrupt: InterruptPayload?
    @Published var dismissedInterruptIDs: Set<string> = []
}