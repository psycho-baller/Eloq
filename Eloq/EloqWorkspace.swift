import AppKit
import Combine
import Foundation
import SwiftData

struct EloqStoragePaths {
    let rootDirectory: URL
    let snapshotURL: URL
    let audoraStateURL: URL
    let audoraSeedURL: URL

    static func `default`(fileManager: FileManager = .default) -> EloqStoragePaths {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let eloqRoot = applicationSupport.appendingPathComponent("Eloq", isDirectory: true)
        let audoraRoot = applicationSupport
            .appendingPathComponent("Audora", isDirectory: true)
            .appendingPathComponent("WritingAwareness", isDirectory: true)

        return EloqStoragePaths(
            rootDirectory: eloqRoot,
            snapshotURL: eloqRoot.appendingPathComponent("snapshot.json"),
            audoraStateURL: audoraRoot.appendingPathComponent("state.json"),
            audoraSeedURL: audoraRoot.appendingPathComponent("seed.json")
        )
    }
}

@MainActor
final class EloqWorkspace: ObservableObject {
    @Published private(set) var words: [Word] = []
    @Published private(set) var roles: [WordRole] = []
    @Published private(set) var connections: [WordConnection] = []
    @Published var currentScreen: WorkspaceScreen = .home
    @Published var selectedWordID: UUID?
    @Published var quickAddText = ""
    @Published var quickAddMode: WordRoleKind = .underused
    @Published var libraryFilter: LibraryFilter = .all
    @Published var searchText = ""
    @Published var importReport: ImportReport = .empty
    @Published var health: HealthStatus = .idle
    @Published var lastBanner: String?
    @Published var isImporting = false
    @Published var isGeneratingSuggestions = false
    @Published var apiKeyDraft = ""
    @Published private(set) var hasOpenAIKey = false
    @Published private(set) var openAIKeyStatus = "No OpenAI key stored."

    private let modelContext: ModelContext
    private let fileManager: FileManager
    private let aiService: OpenAISuggestionService
    private let selectionCaptureManager: EloqSelectionCaptureManager
    private let storagePaths: EloqStoragePaths
    private var hotKeyManager: EloqGlobalHotKeyManager?
    private var exportTask: Task<Void, Never>?

    init(
        modelContext: ModelContext,
        fileManager: FileManager = .default,
        aiService: OpenAISuggestionService? = nil,
        selectionCaptureManager: EloqSelectionCaptureManager? = nil,
        storagePaths: EloqStoragePaths? = nil,
        registerHotKey: Bool = true
    ) {
        self.modelContext = modelContext
        self.fileManager = fileManager
        self.aiService = aiService ?? OpenAISuggestionService()
        self.selectionCaptureManager = selectionCaptureManager ?? .shared
        self.storagePaths = storagePaths ?? .default(fileManager: fileManager)
        if registerHotKey {
            hotKeyManager = EloqGlobalHotKeyManager { [weak self] in
                self?.handleGlobalCapture()
            }
        }
        refreshOpenAIKeyStatus()
        refresh()
    }

    var pendingSuggestions: [WordConnection] {
        connections
            .filter { $0.status == .suggested }
            .sorted { lhs, rhs in
                if lhs.confidence == rhs.confidence {
                    return connectionTitle(lhs) < connectionTitle(rhs)
                }
                return lhs.confidence > rhs.confidence
            }
    }

    var reviewedSuggestions: [WordConnection] {
        connections
            .filter { $0.status != .suggested }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var totalWordCount: Int {
        words.count
    }

    var overusedWordCount: Int {
        roles.filter { $0.kind == .overused }.count
    }

    var underusedWordCount: Int {
        roles.filter { $0.kind == .underused }.count
    }

    var acceptedConnectionCount: Int {
        connections.filter { $0.status == .accepted }.count
    }

    var recentWords: [Word] {
        words.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.displayTerm.localizedCaseInsensitiveCompare(rhs.displayTerm) == .orderedAscending
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    var captureStatusText: String {
        selectionCaptureManager.isTrusted
            ? "Global capture is ready on Control + Option + Command + L."
            : "Enable Accessibility access for true global capture. Clipboard fallback still works."
    }

    var snapshotPathText: String {
        storagePaths.snapshotURL.path
    }

    var storageDirectoryPathText: String {
        storagePaths.rootDirectory.path
    }

    var audoraImportDirectoryPathText: String {
        storagePaths.audoraSeedURL.deletingLastPathComponent().path
    }

    func filteredWords() -> [Word] {
        words
            .filter { word in
                switch libraryFilter {
                case .all:
                    return true
                case .overused:
                    return role(for: word, kind: .overused) != nil
                case .underused:
                    return role(for: word, kind: .underused) != nil
                }
            }
            .filter { word in
                guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return true
                }
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return word.displayTerm.lowercased().contains(query) || word.notes.lowercased().contains(query)
            }
            .sorted { $0.displayTerm.localizedCaseInsensitiveCompare($1.displayTerm) == .orderedAscending }
    }

    func selectWord(_ word: Word?) {
        selectedWordID = word?.id
    }

    func selectedWord() -> Word? {
        guard let selectedWordID else {
            return nil
        }
        return words.first(where: { $0.id == selectedWordID })
    }

    func connections(for word: Word) -> [WordConnection] {
        connections
            .filter { connection in
                role(forKey: connection.fromRoleKey)?.wordID == word.id || role(forKey: connection.toRoleKey)?.wordID == word.id
            }
            .sorted { lhs, rhs in
                if lhs.status == rhs.status {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.status.rawValue < rhs.status.rawValue
            }
    }

    func requestAccessibilityAccess() {
        selectionCaptureManager.requestAccess()
    }

    func openAccessibilitySettings() {
        selectionCaptureManager.openAccessibilitySettings()
    }

    func dismissBanner() {
        lastBanner = nil
    }

    func saveOpenAIKey() {
        let trimmed = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastBanner = "Paste your OpenAI API key first."
            return
        }

        guard EloqKeychain.shared.saveOpenAIKey(trimmed) else {
            lastBanner = "Failed to save the OpenAI key to Keychain."
            return
        }

        refreshOpenAIKeyStatus()
        lastBanner = "Saved your OpenAI key to the macOS Keychain."
    }

    func clearOpenAIKey() {
        guard EloqKeychain.shared.clearOpenAIKey() else {
            lastBanner = "Failed to clear the OpenAI key from Keychain."
            return
        }

        apiKeyDraft = ""
        refreshOpenAIKeyStatus()
        lastBanner = "Removed the OpenAI key from Keychain."
    }

    func captureSelectionIntoDraft() {
        if !selectionCaptureManager.isTrusted {
            selectionCaptureManager.requestAccess()
        }

        guard let capture = selectionCaptureManager.captureSelection() else {
            lastBanner = "Nothing captured. Select a word first or copy it to the clipboard."
            return
        }

        quickAddText = capture.text
        currentScreen = .home
        NSApp.activate(ignoringOtherApps: true)
        lastBanner = capture.usedClipboardFallback
            ? "Captured from the clipboard. Choose a mode, then save."
            : "Captured \"\(capture.text)\" from \(capture.sourceApp)."
    }

    func submitQuickAdd() {
        let text = quickAddText
        let mode = quickAddMode
        quickAddText = ""

        Task {
            await addWord(text: text, kind: mode, provenance: "user", context: "Quick Add")
        }
    }

    func addWord(
        text: String,
        kind: WordRoleKind,
        provenance: String,
        context: String
    ) async {
        guard let candidate = Normalization.candidateTerm(text) else {
            lastBanner = WorkspaceError.invalidWord.localizedDescription
            return
        }

        let normalized = Normalization.normalizedTerm(candidate)
        let word = upsertWord(displayTerm: candidate, normalizedTerm: normalized, provenance: provenance, context: context)
        if role(for: word, kind: kind) != nil {
            selectedWordID = word.id
            lastBanner = WorkspaceError.duplicateRole(word.displayTerm, kind).localizedDescription
            return
        }

        let role = WordRole(word: word, kind: kind, primaryMode: true)
        modelContext.insert(role)
        word.updatedAt = .now

        do {
            try saveAndRefresh()
            selectedWordID = word.id
            currentScreen = .inbox
            lastBanner = "Saved \"\(word.displayTerm)\" to \(kind.title.lowercased()) words."
            scheduleExport()
            await enrichConnections(for: role)
        } catch {
            lastBanner = error.localizedDescription
        }
    }

    func updateStatus(for connection: WordConnection, to status: SuggestionStatus) {
        connection.status = status
        do {
            try saveAndRefresh()
            scheduleExport()
        } catch {
            lastBanner = error.localizedDescription
        }
    }

    func accept(_ connection: WordConnection) {
        updateStatus(for: connection, to: .accepted)
    }

    func dismiss(_ connection: WordConnection) {
        updateStatus(for: connection, to: .dismissed)
    }

    func restore(_ connection: WordConnection) {
        updateStatus(for: connection, to: .suggested)
    }

    func importAudoraVocabulary() {
        isImporting = true
        defer { isImporting = false }

        do {
            try ensureExportDirectory()

            let legacySeed = try decodeLegacySeedIfPresent()
            let legacyState = try decodeLegacyStateIfPresent()

            let allRules = (legacySeed?.rules ?? []) + (legacyState?.manualRules ?? [])
            guard !allRules.isEmpty else {
                importReport = ImportReport(
                    importedWords: 0,
                    importedConnections: 0,
                    skippedRules: 0,
                    conflicts: 0,
                    sourceSummary: "No Audora vocabulary data was found."
                )
                health = HealthStatus(
                    level: .partial,
                    title: "Nothing to import",
                    detail: "Audora seed/state files were not found under Application Support.",
                    lastExportAt: health.lastExportAt,
                    lastAIError: health.lastAIError
                )
                return
            }

            var newWordCount = 0
            var newConnectionCount = 0
            var skippedRules = 0

            for rule in allRules {
                guard let sourceKind = roleKind(from: rule.type),
                      let term = Normalization.candidateTerm(rule.term) else {
                    skippedRules += 1
                    continue
                }

                let normalized = Normalization.normalizedTerm(term)
                let wordResult = upsertWordResult(
                    displayTerm: term,
                    normalizedTerm: normalized,
                    provenance: rule.source ?? "imported",
                    context: (rule.contexts ?? []).joined(separator: ", ")
                )
                if wordResult.isNew {
                    newWordCount += 1
                }
                let word = wordResult.word
                let role = ensureRole(for: word, kind: sourceKind, primaryMode: sourceKind == .underused)

                if sourceKind == .overused {
                    for option in rule.replacementOptions {
                        guard let replacementTerm = Normalization.candidateTerm(option.word) else {
                            continue
                        }
                        let underusedWordResult = upsertWordResult(
                            displayTerm: replacementTerm,
                            normalizedTerm: Normalization.normalizedTerm(replacementTerm),
                            provenance: "imported",
                            context: (rule.contexts ?? []).joined(separator: ", ")
                        )
                        if underusedWordResult.isNew {
                            newWordCount += 1
                        }
                        let underusedWord = underusedWordResult.word
                        let underusedRole = ensureRole(for: underusedWord, kind: .underused, primaryMode: false)
                        let created = upsertConnection(
                            overusedRole: role,
                            underusedRole: underusedRole,
                            origin: .imported,
                            status: .accepted,
                            rationale: rule.notes ?? "Imported from Audora.",
                            useWhen: option.useWhen ?? "Use the underused word when it is more precise than the default wording.",
                            caution: option.caution ?? "Skip it if the sentence becomes forced.",
                            confidence: 0.9
                        )
                        if created {
                            newConnectionCount += 1
                        }
                    }
                }
            }

            try saveAndRefresh()
            scheduleExport()
            importReport = ImportReport(
                importedWords: newWordCount,
                importedConnections: newConnectionCount,
                skippedRules: skippedRules,
                conflicts: 0,
                sourceSummary: "Imported Audora vocabulary from seed.json and state.json."
            )
            lastBanner = "Imported \(newWordCount) words and \(newConnectionCount) connections from Audora."
        } catch {
            lastBanner = error.localizedDescription
            health = HealthStatus(
                level: .error,
                title: "Import failed",
                detail: error.localizedDescription,
                lastExportAt: health.lastExportAt,
                lastAIError: health.lastAIError
            )
        }
    }

    func exportNow() {
        do {
            try exportSnapshot()
        } catch {
            health = HealthStatus(
                level: .error,
                title: "Export failed",
                detail: error.localizedDescription,
                lastExportAt: health.lastExportAt,
                lastAIError: health.lastAIError
            )
        }
    }

    func revealSnapshotInFinder() {
        if fileManager.fileExists(atPath: storagePaths.snapshotURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([storagePaths.snapshotURL])
        } else {
            NSWorkspace.shared.open(storagePaths.rootDirectory)
        }
    }

    func revealStorageDirectoryInFinder() {
        NSWorkspace.shared.open(storagePaths.rootDirectory)
    }

    func revealAudoraImportDirectoryInFinder() {
        NSWorkspace.shared.open(storagePaths.audoraSeedURL.deletingLastPathComponent())
    }

    func requestSuggestions(for word: Word, focusKind: WordRoleKind) {
        guard let focusRole = role(for: word, kind: focusKind) else {
            lastBanner = "Save \"\(word.displayTerm)\" as \(focusKind.title.lowercased()) before asking AI for links."
            return
        }

        Task {
            await enrichConnections(for: focusRole)
        }
    }

    func scopedConnections(for word: Word, focusKind: WordRoleKind) -> [WordConnection] {
        guard let focusRole = role(for: word, kind: focusKind) else {
            return []
        }

        return connections
            .filter { connection in
                switch focusKind {
                case .overused:
                    return connection.fromRoleKey == focusRole.key
                case .underused:
                    return connection.toRoleKey == focusRole.key
                }
            }
            .sorted { lhs, rhs in
                if lhs.status == rhs.status {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.status.rawValue < rhs.status.rawValue
            }
    }

    func counterpartWord(for connection: WordConnection, focusKind: WordRoleKind) -> Word? {
        switch focusKind {
        case .overused:
            return role(forKey: connection.toRoleKey).flatMap(word(for:))
        case .underused:
            return role(forKey: connection.fromRoleKey).flatMap(word(for:))
        }
    }

    func availableOppositeWords(for word: Word, focusKind: WordRoleKind) -> [Word] {
        let existingCounterpartIDs = Set(
            scopedConnections(for: word, focusKind: focusKind)
                .compactMap { counterpartWord(for: $0, focusKind: focusKind)?.id }
        )

        return words
            .filter { candidate in
                candidate.id != word.id &&
                role(for: candidate, kind: focusKind.opposite) != nil &&
                !existingCounterpartIDs.contains(candidate.id)
            }
            .sorted { $0.displayTerm.localizedCaseInsensitiveCompare($1.displayTerm) == .orderedAscending }
    }

    @discardableResult
    func createLibraryConnection(
        focusWord: Word,
        focusKind: WordRoleKind,
        counterpartText: String
    ) -> Bool {
        guard let counterpartTerm = Normalization.candidateTerm(counterpartText) else {
            lastBanner = WorkspaceError.invalidWord.localizedDescription
            return false
        }

        let normalized = Normalization.normalizedTerm(counterpartTerm)
        guard normalized != focusWord.normalizedTerm else {
            lastBanner = "A word cannot connect to itself."
            return false
        }

        let counterpartWord = upsertWord(
            displayTerm: counterpartTerm,
            normalizedTerm: normalized,
            provenance: "user",
            context: "Library"
        )

        return connectCounterpart(
            focusWord: focusWord,
            focusKind: focusKind,
            counterpartWord: counterpartWord
        )
    }

    @discardableResult
    func connectCounterpart(
        focusWord: Word,
        focusKind: WordRoleKind,
        counterpartWord: Word
    ) -> Bool {
        let focusRole = ensureRole(for: focusWord, kind: focusKind, primaryMode: false)
        let counterpartRole = ensureRole(
            for: counterpartWord,
            kind: focusKind.opposite,
            primaryMode: false
        )

        let overusedRole = focusKind == .overused ? focusRole : counterpartRole
        let underusedRole = focusKind == .underused ? focusRole : counterpartRole
        let copy = manualConnectionCopy(
            focusWord: focusWord,
            focusKind: focusKind,
            counterpartWord: counterpartWord
        )

        _ = upsertConnection(
            overusedRole: overusedRole,
            underusedRole: underusedRole,
            origin: .user,
            status: .accepted,
            rationale: copy.rationale,
            useWhen: copy.useWhen,
            caution: copy.caution,
            confidence: 1,
            allowStatusOverride: true
        )

        do {
            try saveAndRefresh()
            scheduleExport()
            lastBanner = "Linked \"\(focusWord.displayTerm)\" with \"\(counterpartWord.displayTerm)\"."
            return true
        } catch {
            lastBanner = error.localizedDescription
            return false
        }
    }

    private func refresh() {
        do {
            words = try modelContext.fetch(FetchDescriptor<Word>())
                .sorted { $0.displayTerm.localizedCaseInsensitiveCompare($1.displayTerm) == .orderedAscending }
            roles = try modelContext.fetch(FetchDescriptor<WordRole>())
                .sorted { lhs, rhs in
                    if lhs.wordNormalizedTerm == rhs.wordNormalizedTerm {
                        return lhs.kind.rawValue < rhs.kind.rawValue
                    }
                    return lhs.wordNormalizedTerm < rhs.wordNormalizedTerm
                }
            connections = try modelContext.fetch(FetchDescriptor<WordConnection>())
                .sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            lastBanner = error.localizedDescription
        }
    }

    private func refreshOpenAIKeyStatus() {
        let storedKey = EloqKeychain.shared.openAIKey()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        apiKeyDraft = storedKey
        hasOpenAIKey = !storedKey.isEmpty
        openAIKeyStatus = hasOpenAIKey
            ? "Stored in macOS Keychain. AI suggestions are enabled."
            : "No OpenAI key stored. Manual vocabulary management still works."
    }

    private func saveAndRefresh() throws {
        try modelContext.save()
        refresh()
    }

    private func handleGlobalCapture() {
        captureSelectionIntoDraft()
    }

    private func scheduleExport() {
        exportTask?.cancel()
        exportTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else {
                return
            }
            self?.performExportAfterDebounce()
        }
    }

    private func performExportAfterDebounce() {
        do {
            try exportSnapshot()
        } catch {
            health = HealthStatus(
                level: .error,
                title: "Snapshot degraded",
                detail: error.localizedDescription,
                lastExportAt: health.lastExportAt,
                lastAIError: health.lastAIError
            )
        }
    }

    private func exportSnapshot() throws {
        try ensureExportDirectory()
        let snapshot = buildSnapshot()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        try data.write(to: storagePaths.snapshotURL, options: .atomic)

        health = HealthStatus(
            level: health.lastAIError == nil ? .healthy : .partial,
            title: "Snapshot healthy",
            detail: "Exported \(snapshot.summary.acceptedConnections) accepted connections to \(storagePaths.snapshotURL.path).",
            lastExportAt: .now,
            lastAIError: health.lastAIError
        )
    }

    private func buildSnapshot() -> SnapshotReadModel {
        let snapshotWords = words.map { word in
            SnapshotWord(
                id: word.id.uuidString,
                displayTerm: word.displayTerm,
                normalizedTerm: word.normalizedTerm,
                roles: roles(for: word).map { $0.kind.rawValue },
                notes: word.notes,
                contexts: word.contexts,
                provenance: word.provenance
            )
        }

        let snapshotConnections = connections.compactMap { connection -> SnapshotConnection? in
            guard let overusedRole = role(forKey: connection.fromRoleKey),
                  let underusedRole = role(forKey: connection.toRoleKey),
                  overusedRole.kind == .overused,
                  underusedRole.kind == .underused,
                  let overusedWord = word(for: overusedRole),
                  let underusedWord = word(for: underusedRole) else {
                return nil
            }

            return SnapshotConnection(
                id: connection.id.uuidString,
                overusedWordID: overusedWord.id.uuidString,
                overusedTerm: overusedWord.displayTerm,
                underusedWordID: underusedWord.id.uuidString,
                underusedTerm: underusedWord.displayTerm,
                origin: connection.origin.rawValue,
                status: connection.status.rawValue,
                rationale: connection.rationale,
                useWhen: connection.useWhen,
                caution: connection.caution,
                confidence: connection.confidence
            )
        }

        let summary = SnapshotSummary(
            totalWords: snapshotWords.count,
            overusedWords: snapshotWords.filter { $0.roles.contains(WordRoleKind.overused.rawValue) }.count,
            underusedWords: snapshotWords.filter { $0.roles.contains(WordRoleKind.underused.rawValue) }.count,
            acceptedConnections: snapshotConnections.filter { $0.status == SuggestionStatus.accepted.rawValue }.count,
            suggestedConnections: snapshotConnections.filter { $0.status == SuggestionStatus.suggested.rawValue }.count,
            dismissedConnections: snapshotConnections.filter { $0.status == SuggestionStatus.dismissed.rawValue }.count
        )

        return SnapshotReadModel(
            version: 1,
            generatedAt: .now,
            summary: summary,
            words: snapshotWords,
            connections: snapshotConnections
        )
    }

    private func enrichConnections(for role: WordRole) async {
        guard let focusWord = word(for: role) else {
            return
        }

        isGeneratingSuggestions = true
        defer { isGeneratingSuggestions = false }

        do {
            let roleSummaries = roles.compactMap { currentRole -> RoleSummary? in
                guard let currentWord = self.word(for: currentRole) else {
                    return nil
                }
                return RoleSummary(
                    term: currentWord.displayTerm,
                    normalizedTerm: currentWord.normalizedTerm,
                    kind: currentRole.kind.rawValue
                )
            }

            let existingConnections = connections.compactMap { connection -> ExistingConnectionSummary? in
                guard let overusedRole = self.role(forKey: connection.fromRoleKey),
                      let underusedRole = self.role(forKey: connection.toRoleKey),
                      let overused = self.word(for: overusedRole)?.displayTerm,
                      let underused = self.word(for: underusedRole)?.displayTerm else {
                    return nil
                }

                return ExistingConnectionSummary(
                    overused: overused,
                    underused: underused,
                    status: connection.status.rawValue
                )
            }

            let suggestions = try await aiService.suggestConnections(
                for: RoleSummary(
                    term: focusWord.displayTerm,
                    normalizedTerm: focusWord.normalizedTerm,
                    kind: role.kind.rawValue
                ),
                existingRoles: roleSummaries,
                existingConnections: existingConnections
            )

            try applySuggestions(suggestions, focusRole: role)
            health = HealthStatus(
                level: health.lastExportAt == nil ? .partial : .healthy,
                title: "AI suggestions ready",
                detail: suggestions.isEmpty
                    ? "No new opposite-side suggestions were generated for \"\(focusWord.displayTerm)\"."
                    : "Generated \(suggestions.count) suggestion(s) for \"\(focusWord.displayTerm)\".",
                lastExportAt: health.lastExportAt,
                lastAIError: nil
            )
        } catch {
            let detail = error.localizedDescription
            health = HealthStatus(
                level: .partial,
                title: "AI unavailable",
                detail: detail,
                lastExportAt: health.lastExportAt,
                lastAIError: detail
            )
            lastBanner = detail
        }
    }

    private func applySuggestions(_ suggestions: [SuggestionCandidate], focusRole: WordRole) throws {
        guard let focusWord = word(for: focusRole) else {
            return
        }

        let deduplicated = Dictionary(
            suggestions.compactMap { suggestion -> (String, SuggestionCandidate)? in
                guard let term = Normalization.candidateTerm(suggestion.counterpartTerm) else {
                    return nil
                }
                let normalized = Normalization.normalizedTerm(term)
                guard normalized != focusWord.normalizedTerm else {
                    return nil
                }
                return (normalized, SuggestionCandidate(
                    counterpartTerm: term,
                    rationale: suggestion.rationale,
                    useWhen: suggestion.useWhen,
                    caution: suggestion.caution,
                    confidence: suggestion.confidence
                ))
            },
            uniquingKeysWith: { first, _ in first }
        )

        for (_, suggestion) in deduplicated.sorted(by: { $0.key < $1.key }) {
            let counterpartWord = upsertWord(
                displayTerm: suggestion.counterpartTerm,
                normalizedTerm: Normalization.normalizedTerm(suggestion.counterpartTerm),
                provenance: "ai",
                context: ""
            )
            let counterpartRole = ensureRole(
                for: counterpartWord,
                kind: focusRole.kind.opposite,
                primaryMode: false
            )

            let overusedRole = focusRole.kind == .overused ? focusRole : counterpartRole
            let underusedRole = focusRole.kind == .underused ? focusRole : counterpartRole

            _ = upsertConnection(
                overusedRole: overusedRole,
                underusedRole: underusedRole,
                origin: .ai,
                status: .suggested,
                rationale: suggestion.rationale,
                useWhen: suggestion.useWhen,
                caution: suggestion.caution,
                confidence: min(max(suggestion.confidence, 0), 1)
            )
        }

        try saveAndRefresh()
        scheduleExport()
    }

    private func upsertWord(
        displayTerm: String,
        normalizedTerm: String,
        provenance: String,
        context: String
    ) -> Word {
        upsertWordResult(
            displayTerm: displayTerm,
            normalizedTerm: normalizedTerm,
            provenance: provenance,
            context: context
        ).word
    }

    private func upsertWordResult(
        displayTerm: String,
        normalizedTerm: String,
        provenance: String,
        context: String
    ) -> (word: Word, isNew: Bool) {
        if let existing = words.first(where: { $0.normalizedTerm == normalizedTerm }) {
            if !context.isEmpty, !existing.contexts.contains(context) {
                existing.contexts = existing.contexts + [context]
            }
            if existing.displayTerm != displayTerm {
                existing.displayTerm = displayTerm
            }
            existing.updatedAt = .now
            return (existing, false)
        }

        let word = Word(
            displayTerm: displayTerm,
            normalizedTerm: normalizedTerm,
            contexts: context.isEmpty ? [] : [context],
            provenance: provenance
        )
        modelContext.insert(word)
        words.append(word)
        return (word, true)
    }

    private func ensureRole(for word: Word, kind: WordRoleKind, primaryMode: Bool) -> WordRole {
        if let existing = role(for: word, kind: kind) {
            if primaryMode {
                existing.primaryMode = true
            }
            existing.updatedAt = .now
            return existing
        }

        let role = WordRole(word: word, kind: kind, primaryMode: primaryMode)
        modelContext.insert(role)
        word.updatedAt = .now
        roles.append(role)
        return role
    }

    @discardableResult
    private func upsertConnection(
        overusedRole: WordRole,
        underusedRole: WordRole,
        origin: ConnectionOrigin,
        status: SuggestionStatus,
        rationale: String,
        useWhen: String,
        caution: String,
        confidence: Double,
        allowStatusOverride: Bool = false
    ) -> Bool {
        let key = WordConnection.makeKey(fromRole: overusedRole, toRole: underusedRole)
        if let existing = connections.first(where: { $0.key == key }) {
            if !allowStatusOverride && (existing.status == .accepted || existing.status == .dismissed) {
                return false
            }
            existing.origin = origin
            existing.status = status
            existing.rationale = rationale
            existing.useWhen = useWhen
            existing.caution = caution
            existing.confidence = confidence
            existing.updatedAt = .now
            return false
        }

        let connection = WordConnection(
            fromRole: overusedRole,
            toRole: underusedRole,
            origin: origin,
            status: status,
            rationale: rationale,
            useWhen: useWhen,
            caution: caution,
            confidence: confidence
        )
        modelContext.insert(connection)
        connections.append(connection)
        return true
    }

    func roles(for word: Word) -> [WordRole] {
        roles
            .filter { $0.wordID == word.id }
            .sorted { $0.kind.rawValue < $1.kind.rawValue }
    }

    private func role(for word: Word, kind: WordRoleKind) -> WordRole? {
        roles.first { $0.wordID == word.id && $0.kind == kind }
    }

    private func role(forKey key: String) -> WordRole? {
        roles.first { $0.key == key }
    }

    private func word(for role: WordRole) -> Word? {
        words.first { $0.id == role.wordID }
    }

    func connectionTitle(_ connection: WordConnection) -> String {
        let overused = role(forKey: connection.fromRoleKey).flatMap(word(for:))?.displayTerm ?? "Overused"
        let underused = role(forKey: connection.toRoleKey).flatMap(word(for:))?.displayTerm ?? "Underused"
        return "\(overused)->\(underused)"
    }

    private func manualConnectionCopy(
        focusWord: Word,
        focusKind: WordRoleKind,
        counterpartWord: Word
    ) -> (rationale: String, useWhen: String, caution: String) {
        switch focusKind {
        case .overused:
            return (
                rationale: "Linked manually from the library.",
                useWhen: "Reach for \"\(counterpartWord.displayTerm)\" when it says the idea more precisely than \"\(focusWord.displayTerm)\".",
                caution: "Skip it if the sharper word changes the meaning or tone too much."
            )
        case .underused:
            return (
                rationale: "Linked manually from the library.",
                useWhen: "Notice when \"\(focusWord.displayTerm)\" is a sharper alternative to defaulting to \"\(counterpartWord.displayTerm)\".",
                caution: "Do not force the stronger word when the simpler wording is actually better."
            )
        }
    }

    private func roleKind(from rawValue: String) -> WordRoleKind? {
        switch rawValue {
        case "avoid":
            return .overused
        case "target":
            return .underused
        default:
            return nil
        }
    }

    private func ensureExportDirectory() throws {
        try fileManager.createDirectory(
            at: storagePaths.rootDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private func decodeLegacySeedIfPresent() throws -> LegacyWritingAwarenessSeed? {
        guard fileManager.fileExists(atPath: storagePaths.audoraSeedURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: storagePaths.audoraSeedURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LegacyWritingAwarenessSeed.self, from: data)
    }

    private func decodeLegacyStateIfPresent() throws -> LegacyWritingAwarenessState? {
        guard fileManager.fileExists(atPath: storagePaths.audoraStateURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: storagePaths.audoraStateURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LegacyWritingAwarenessState.self, from: data)
    }
}
