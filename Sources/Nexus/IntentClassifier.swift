// NEXUS Intent Classifier — rules that decide what an input is.
// Client-side, no round trip: the chip shows the result, the user can cycle it.
// No model provider needed — pure text rules.

import Foundation

enum IntentAction {
    case send        // route as mission / steer / brainstorm / direct by mode
    case explain     // open Explain panel, don't send
    case pause       // control message to the mission runtime
    case stop        // control message: halt the mission runtime
}

struct Classification {
    let action: IntentAction
    let mode: AppState.EntryMode
}

enum IntentClassifier {

    static func classify(_ raw: String, missionRunning: Bool) -> Classification {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if text.isEmpty {
            return Classification(action: .send, mode: missionRunning ? .steer : .brainstorm)
        }

        if stopPhrases.contains(text) {
            return Classification(action: .stop, mode: .pause)
        }
        if pausePhrases.contains(text) {
            return Classification(action: .pause, mode: .pause)
        }
        if isSystemQuestion(text) {
            return Classification(action: .explain, mode: .explain)
        }
        if isCalendar(text) {
            return Classification(action: .send, mode: .calendar)
        }
        if isDirect(text) {
            return Classification(action: .send, mode: .direct)
        }
        if isBrainstorm(text) {
            return Classification(action: .send, mode: .brainstorm)
        }
        if isMission(text) {
            return Classification(action: .send, mode: missionRunning ? .steer : .mission)
        }
        // Safe default: casual text never starts work — it starts a discussion.
        return Classification(action: .send, mode: missionRunning ? .steer : .brainstorm)
    }

    /// Cycle order for the chip (click overrides the classification).
    static func cycleOrder(missionRunning: Bool) -> [AppState.EntryMode] {
        missionRunning
            ? [.steer, .mission, .brainstorm, .direct, .calendar]
            : [.mission, .brainstorm, .direct, .calendar]
    }

    static func nextMode(_ current: AppState.EntryMode,
                         missionRunning: Bool) -> AppState.EntryMode {
        let order = cycleOrder(missionRunning: missionRunning)
        guard let idx = order.firstIndex(of: current) else { return order[0] }
        return order[(idx + 1) % order.count]
    }

    // MARK: - Phrase tables

    private static let stopPhrases: Set<String> = [
        "stop", "stop.", "halt", "cancel", "abort", "enough",
        "stop it", "that's enough", "that's it",
    ]

    private static let pausePhrases: Set<String> = [
        "pause", "wait", "hold on", "hold it", "freeze",
    ]

    private static let systemQuestionPrefixes = [
        "explain", "tell me why", "walk me through",
        "what are you", "what did you", "what are we", "what's the plan",
        "what is the plan", "why are you", "how are you", "where are we",
        "status", "what can you do",
    ]

    private static let directVerbs = [
        "open ", "play ", "reveal ", "tail ", "take a screenshot",
        "screenshot", "show the project", "stop watching", "stop observing",
        "pause music", "resume music",
    ]

    private static let brainstormMarkers = [
        "what if", "what about", "i'm thinking", "im thinking",
        "thinking about", "wondering", "brainstorm", "ideas",
        "how far", "could we", "should we", "let's explore",
        "explore", "alternatives", "options", "which approach",
        "what do you think", "do you think", "makes sense",
        "curious", "i wonder", "not sure", "tradeoff", "trade-off",
        "pros and cons", "let's discuss", "discuss", "talk about",
    ]

    private static let missionFirstWords: Set<String> = [
        "build", "add", "fix", "create", "implement", "research",
        "investigate", "analyze", "deploy", "refactor", "debug",
        "write", "generate", "integrate", "migrate", "optimize",
        "install", "configure", "execute", "ship", "prepare", "verify",
        "check", "ensure", "run", "test", "update", "review", "clean",
        "rename", "move", "plan",
    ]

    private static let missionPhrases = [
        "take this", "take the", "set up", "setup", "make sure",
        "start the", "start a", "plan my", "write me",
    ]

    private static func isSystemQuestion(_ text: String) -> Bool {
        systemQuestionPrefixes.contains { text.hasPrefix($0) }
    }

    private static func isDirect(_ text: String) -> Bool {
        directVerbs.contains { text.hasPrefix($0) }
    }

    private static func isBrainstorm(_ text: String) -> Bool {
        if text.hasSuffix("?") { return true }
        return brainstormMarkers.contains { text.contains($0) }
    }

    private static func isMission(_ text: String) -> Bool {
        if missionPhrases.contains(where: { text.hasPrefix($0) }) { return true }
        let first = text.split(separator: " ").first.map(String.init) ?? ""
        return missionFirstWords.contains(first)
    }

    // MARK: - Calendar detection (mirrors core/discussion.py)

    private static let calNouns = [
        "meeting", "meetings", "event", "events", "appointment", "appointments",
        "call", "sync", "lunch", "dinner", "coffee", "demo", "standup", "interview",
        "session", "deadline", "booking", "review", "retro", "planning", "1:1"
    ]

    private static let calReadMarkers = [
        "my calendar", "the calendar", "our calendar", "on the calendar",
        "in my calendar", "calendar today", "calendar tomorrow",
        "calendar this", "calendar for", "agenda", "my schedule",
        "on my schedule", "schedule today", "schedule tomorrow",
        "schedule this", "schedule for", "am i free", "i'm free",
        "im free", "free today", "free tomorrow", "free on", "free at",
        "free this", "any free", "free time", "busy today", "busy tomorrow",
        "busy on", "availability", "what's on", "whats on", "how busy"
    ]

    private static let calResearchExclusions = [
        "should we", "what if", "brainstorm", "ideas", "api", "sdk",
        "library", "framework", " vs ", "versus", "compare", "pros and cons",
        "how to build", "how to implement", "app for", "an app"
    ]

    private static func isCalendar(_ text: String) -> Bool {
        let t = text.lowercased()
        if calResearchExclusions.contains(where: { t.contains($0) }) {
            return false
        }
        // create/delete verbs + noun + time signal
        let createVerbs = ["add ", "create ", "schedule ", "book ", "set up ", "block ", "new "]
        let deleteVerbs = ["delete ", "remove ", "cancel "]
        let hasNoun = calNouns.contains { t.contains($0) } || t.contains("calendar")
        let hasTime = t.contains("today") || t.contains("tomorrow") || t.contains("tonight") ||
                      t.contains("monday") || t.contains("tuesday") || t.contains("wednesday") ||
                      t.contains("thursday") || t.contains("friday") || t.contains("saturday") ||
                      t.contains("sunday") || t.contains("week") || t.contains("weekend") ||
                      t.contains("at ") || t.contains("am") || t.contains("pm") ||
                      t.range(of: #"\d{1,2}[-–—]\d{1,2}"#, options: .regularExpression) != nil

        // create
        for verb in createVerbs where t.hasPrefix(verb) {
            if (hasNoun || t.contains("calendar")) && (hasTime || verb.hasPrefix("block")) {
                return true
            }
        }
        // delete
        for verb in deleteVerbs where t.hasPrefix(verb) {
            if hasNoun || t.contains("calendar") {
                return true
            }
        }
        // free/busy
        if (t.contains("free") || t.contains("busy") || t.contains("availability")) && hasTime {
            if !t.contains("feel free") && !t.contains("free to ") { return true }
        }
        // read markers
        if calReadMarkers.contains(where: { t.contains($0) }) { return true }
        if t.contains("check") && (t.contains("calendar") || t.contains("schedule")) { return true }
        if t.contains("do i have") && hasTime { return true }
        if t.hasSuffix("?") && hasTime && (t.contains("meeting") || t.contains("event") || t.contains("appointment")) { return true }
        return false
    }
}
