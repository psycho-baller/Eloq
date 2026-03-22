import Foundation
import SwiftData

enum WordRoleKind: String, Codable, CaseIterable, Identifiable {
    case overused
    case underused

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overused:
            return "Overused"
        case .underused:
            return "Underused"
        }
    }

    var opposite: WordRoleKind {
        switch self {
        case .overused:
            return .underused
        case .underused:
            return .overused
        }
    }
}

enum ConnectionOrigin: String, Codable, CaseIterable {
    case user
    case ai
    case imported
}

enum SuggestionStatus: String, Codable, CaseIterable, Identifiable {
    case suggested
    case accepted
    case dismissed

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

enum HealthLevel: String, Codable, CaseIterable {
    case healthy
    case partial
    case error
}

enum WorkspaceError: LocalizedError {
    case invalidWord
    case duplicateRole(String, WordRoleKind)
    case missingOppositeRole
    case missingAPIKey
    case malformedAIResponse
    case unavailableSnapshot

    var errorDescription: String? {
        switch self {
        case .invalidWord:
            return "Add a word or short phrase first."
        case let .duplicateRole(term, kind):
            return "\"\(term)\" already exists as an \(kind.title.lowercased()) word."
        case .missingOppositeRole:
            return "A connection needs both an overused word and an underused word."
        case .missingAPIKey:
            return "OpenAI key not found in Keychain."
        case .malformedAIResponse:
            return "OpenAI returned a malformed suggestion payload."
        case .unavailableSnapshot:
            return "Eloq has not exported a snapshot yet."
        }
    }
}

@Model
final class Word {
    @Attribute(.unique) var normalizedTerm: String
    var id: UUID
    var displayTerm: String
    var notes: String
    var sourceExcerpt: String = ""
    var exampleUsage: String = ""
    var contextsBlob: String
    var provenance: String
    var createdAt: Date
    var updatedAt: Date

    init(
        displayTerm: String,
        normalizedTerm: String,
        notes: String = "",
        sourceExcerpt: String = "",
        exampleUsage: String = "",
        contexts: [String] = [],
        provenance: String = "user",
        createdAt: Date = .now
    ) {
        id = UUID()
        self.displayTerm = displayTerm
        self.normalizedTerm = normalizedTerm
        self.notes = notes
        self.sourceExcerpt = sourceExcerpt
        self.exampleUsage = exampleUsage
        contextsBlob = Word.encodeContexts(contexts)
        self.provenance = provenance
        self.createdAt = createdAt
        updatedAt = createdAt
    }

    var contexts: [String] {
        get {
            contextsBlob
                .split(separator: "\n")
                .map { String($0) }
                .filter { !$0.isEmpty }
        }
        set {
            contextsBlob = Word.encodeContexts(newValue)
            updatedAt = .now
        }
    }

    private static func encodeContexts(_ values: [String]) -> String {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

@Model
final class WordRole {
    @Attribute(.unique) var key: String
    var id: UUID
    var wordID: UUID
    var wordNormalizedTerm: String
    var kindRaw: String
    var primaryMode: Bool
    var createdAt: Date
    var updatedAt: Date

    init(word: Word, kind: WordRoleKind, primaryMode: Bool = false, createdAt: Date = .now) {
        id = UUID()
        wordID = word.id
        wordNormalizedTerm = word.normalizedTerm
        key = Self.makeKey(normalizedTerm: word.normalizedTerm, kind: kind)
        kindRaw = kind.rawValue
        self.primaryMode = primaryMode
        self.createdAt = createdAt
        updatedAt = createdAt
    }

    var kind: WordRoleKind {
        get { WordRoleKind(rawValue: kindRaw) ?? .underused }
        set {
            kindRaw = newValue.rawValue
            key = Self.makeKey(normalizedTerm: wordNormalizedTerm, kind: newValue)
            updatedAt = .now
        }
    }

    static func makeKey(normalizedTerm: String, kind: WordRoleKind) -> String {
        "\(kind.rawValue):\(normalizedTerm)"
    }
}

@Model
final class WordConnection {
    @Attribute(.unique) var key: String
    var id: UUID
    var fromRoleKey: String
    var toRoleKey: String
    var originRaw: String
    var statusRaw: String
    var rationale: String
    var useWhen: String
    var caution: String
    var sourceExcerpt: String = ""
    var exampleUsage: String = ""
    var confidence: Double
    var createdAt: Date
    var updatedAt: Date

    init(
        fromRole: WordRole,
        toRole: WordRole,
        origin: ConnectionOrigin,
        status: SuggestionStatus,
        rationale: String,
        useWhen: String,
        caution: String,
        sourceExcerpt: String = "",
        exampleUsage: String = "",
        confidence: Double,
        createdAt: Date = .now
    ) {
        id = UUID()
        fromRoleKey = fromRole.key
        toRoleKey = toRole.key
        key = Self.makeKey(fromRole: fromRole, toRole: toRole)
        originRaw = origin.rawValue
        statusRaw = status.rawValue
        self.rationale = rationale
        self.useWhen = useWhen
        self.caution = caution
        self.sourceExcerpt = sourceExcerpt
        self.exampleUsage = exampleUsage
        self.confidence = confidence
        self.createdAt = createdAt
        updatedAt = createdAt
    }

    var origin: ConnectionOrigin {
        get { ConnectionOrigin(rawValue: originRaw) ?? .ai }
        set {
            originRaw = newValue.rawValue
            updatedAt = .now
        }
    }

    var status: SuggestionStatus {
        get { SuggestionStatus(rawValue: statusRaw) ?? .suggested }
        set {
            statusRaw = newValue.rawValue
            updatedAt = .now
        }
    }

    static func makeKey(fromRole: WordRole, toRole: WordRole) -> String {
        "\(fromRole.key)->\(toRole.key)"
    }
}

struct SnapshotReadModel: Codable, Equatable {
    var version: Int
    var generatedAt: Date
    var summary: SnapshotSummary
    var words: [SnapshotWord]
    var connections: [SnapshotConnection]
}

struct SnapshotSummary: Codable, Equatable {
    var totalWords: Int
    var overusedWords: Int
    var underusedWords: Int
    var acceptedConnections: Int
    var suggestedConnections: Int
    var dismissedConnections: Int
}

struct SnapshotWord: Codable, Equatable, Identifiable {
    var id: String
    var displayTerm: String
    var normalizedTerm: String
    var roles: [String]
    var notes: String
    var sourceExcerpt: String
    var exampleUsage: String
    var contexts: [String]
    var provenance: String
}

struct SnapshotConnection: Codable, Equatable, Identifiable {
    var id: String
    var overusedWordID: String
    var overusedTerm: String
    var underusedWordID: String
    var underusedTerm: String
    var origin: String
    var status: String
    var rationale: String
    var useWhen: String
    var caution: String
    var sourceExcerpt: String
    var exampleUsage: String
    var confidence: Double
}

struct LegacyVocabularyRule: Decodable {
    var id: String
    var type: String
    var term: String
    var replacementOptions: [LegacyReplacementOption]
    var contexts: [String]?
    var source: String?
    var active: Bool?
    var priority: Int?
    var notes: String?
    var family: String?
    var pinned: Bool?
}

struct LegacyReplacementOption: Decodable {
    var word: String
    var useWhen: String?
    var caution: String?
}

struct LegacyWritingAwarenessSeed: Decodable {
    var sourceRunId: String?
    var rules: [LegacyVocabularyRule]
}

struct LegacyWritingAwarenessState: Decodable {
    var manualRules: [LegacyVocabularyRule]

    init(manualRules: [LegacyVocabularyRule] = []) {
        self.manualRules = manualRules
    }
}

enum SuggestedCounterpartSource: String, Codable, Equatable {
    case library
    case generated

    var title: String {
        switch self {
        case .library:
            return "In Library"
        case .generated:
            return "New AI"
        }
    }
}

struct SuggestionCandidate: Codable, Equatable, Hashable, Identifiable {
    var id: String { counterpartTerm }
    var counterpartTerm: String
    var rationale: String
    var useWhen: String
    var caution: String
    var exampleUsage: String
    var confidence: Double
}

struct ConnectionSuggestion: Equatable, Identifiable {
    var id: UUID
    var focusWordID: UUID
    var focusWordTerm: String
    var focusNormalizedTerm: String
    var focusKind: WordRoleKind
    var counterpartTerm: String
    var counterpartNormalizedTerm: String
    var counterpartSource: SuggestedCounterpartSource
    var rationale: String
    var useWhen: String
    var caution: String
    var sourceExcerpt: String
    var exampleUsage: String
    var confidence: Double
    var status: SuggestionStatus
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        focusWordID: UUID,
        focusWordTerm: String,
        focusNormalizedTerm: String,
        focusKind: WordRoleKind,
        counterpartTerm: String,
        counterpartNormalizedTerm: String,
        counterpartSource: SuggestedCounterpartSource = .generated,
        rationale: String,
        useWhen: String,
        caution: String,
        sourceExcerpt: String = "",
        exampleUsage: String = "",
        confidence: Double,
        status: SuggestionStatus = .suggested,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.focusWordID = focusWordID
        self.focusWordTerm = focusWordTerm
        self.focusNormalizedTerm = focusNormalizedTerm
        self.focusKind = focusKind
        self.counterpartTerm = counterpartTerm
        self.counterpartNormalizedTerm = counterpartNormalizedTerm
        self.counterpartSource = counterpartSource
        self.rationale = rationale
        self.useWhen = useWhen
        self.caution = caution
        self.sourceExcerpt = sourceExcerpt
        self.exampleUsage = exampleUsage
        self.confidence = confidence
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var overusedTerm: String {
        focusKind == .overused ? focusWordTerm : counterpartTerm
    }

    var underusedTerm: String {
        focusKind == .underused ? focusWordTerm : counterpartTerm
    }

    var title: String {
        "\(overusedTerm)->\(underusedTerm)"
    }

    var pairKey: String {
        let overusedNormalized = focusKind == .overused ? focusNormalizedTerm : counterpartNormalizedTerm
        let underusedNormalized = focusKind == .underused ? focusNormalizedTerm : counterpartNormalizedTerm
        return "\(WordRole.makeKey(normalizedTerm: overusedNormalized, kind: .overused))->\(WordRole.makeKey(normalizedTerm: underusedNormalized, kind: .underused))"
    }
}

struct AIGraphSuggestionPayload: Codable, Equatable {
    var suggestions: [SuggestionCandidate]
}

struct RoleSummary: Codable, Hashable {
    var term: String
    var normalizedTerm: String
    var kind: String
}

struct ExistingConnectionSummary: Codable, Hashable {
    var overused: String
    var underused: String
    var status: String
}

struct ImportReport: Equatable {
    var importedWords: Int
    var importedConnections: Int
    var skippedRules: Int
    var conflicts: Int
    var sourceSummary: String

    static let empty = ImportReport(
        importedWords: 0,
        importedConnections: 0,
        skippedRules: 0,
        conflicts: 0,
        sourceSummary: "No import has run yet."
    )
}

struct HealthStatus: Equatable {
    var level: HealthLevel
    var title: String
    var detail: String
    var lastExportAt: Date?
    var lastAIError: String?

    static let idle = HealthStatus(
        level: .partial,
        title: "Local-first",
        detail: "Words save locally. Snapshot export will start after your first change.",
        lastExportAt: nil,
        lastAIError: nil
    )
}

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all
    case overused
    case underused

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .overused:
            return "Overused"
        case .underused:
            return "Underused"
        }
    }
}

enum WorkspaceScreen: String, CaseIterable, Identifiable {
    case home
    case inbox
    case library
    case atlas

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .inbox:
            return "Inbox"
        case .library:
            return "Library"
        case .atlas:
            return "Atlas"
        }
    }
}

struct SelectionCaptureResult: Equatable {
    var text: String
    var sourceApp: String
    var contextLabel: String
    var usedClipboardFallback: Bool
}

enum Normalization {
    static func term(_ rawValue: String) -> String {
        rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    static func normalizedTerm(_ rawValue: String) -> String {
        term(rawValue).lowercased()
    }

    static func candidateTerm(_ rawValue: String) -> String? {
        let cleaned = term(rawValue)
        guard !cleaned.isEmpty else {
            return nil
        }
        return cleaned
    }
}
