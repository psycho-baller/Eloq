import Foundation
import SwiftData
import Testing
@testable import Eloq

@Suite(.serialized)
struct EloqTests {

    @Test
    @MainActor
    func importsLegacyAudoraVocabularyIntoTheEloqGraph() throws {
        let harness = try TestHarness.make()
        defer { harness.cleanup() }

        try harness.writeAudoraSeed(
            """
            {
              "sourceRunId": "legacy-seed",
              "rules": [
                {
                  "id": "avoid-thing",
                  "type": "avoid",
                  "term": "thing",
                  "replacementOptions": [
                    {
                      "word": "constraint",
                      "useWhen": "Use it when the sentence refers to a real limiting factor.",
                      "caution": "Do not force it when you mean a literal object."
                    }
                  ],
                  "notes": "Sharpen vague nouns."
                }
              ]
            }
            """
        )

        let workspace = EloqWorkspace(
            modelContext: harness.container.mainContext,
            storagePaths: harness.storagePaths,
            registerHotKey: false
        )

        workspace.importAudoraVocabulary()

        #expect(workspace.importReport.importedWords == 2)
        #expect(workspace.importReport.importedConnections == 1)
        #expect(workspace.words.map(\.displayTerm).sorted() == ["constraint", "thing"])

        let importedConnection = try #require(workspace.connections.first)
        #expect(importedConnection.status == .accepted)
        #expect(workspace.connectionTitle(importedConnection) == "thing->constraint")
    }

    @Test
    @MainActor
    func exportsVersionedSnapshotFromTheGraph() throws {
        let harness = try TestHarness.make()
        defer { harness.cleanup() }

        let context = harness.container.mainContext
        let overusedWord = Word(
            displayTerm: "thing",
            normalizedTerm: "thing",
            notes: "Vague placeholder",
            sourceExcerpt: "This thing keeps blocking the project.",
            exampleUsage: "That thing became the central blocker."
        )
        let underusedWord = Word(
            displayTerm: "constraint",
            normalizedTerm: "constraint",
            notes: "Sharper alternative",
            exampleUsage: "The budget constraint shaped the roadmap."
        )
        context.insert(overusedWord)
        context.insert(underusedWord)

        let overusedRole = WordRole(word: overusedWord, kind: .overused, primaryMode: true)
        let underusedRole = WordRole(word: underusedWord, kind: .underused, primaryMode: true)
        context.insert(overusedRole)
        context.insert(underusedRole)

        let acceptedConnection = WordConnection(
            fromRole: overusedRole,
            toRole: underusedRole,
            origin: .user,
            status: .accepted,
            rationale: "Use the sharper term when you mean a real limiting condition.",
            useWhen: "Use it when the blocker is concrete.",
            caution: "Skip it if you literally mean an object.",
            sourceExcerpt: "This thing keeps blocking the project.",
            exampleUsage: "The regulatory constraint slowed the rollout.",
            confidence: 0.94
        )
        context.insert(acceptedConnection)
        try context.save()

        let workspace = EloqWorkspace(
            modelContext: context,
            storagePaths: harness.storagePaths,
            registerHotKey: false
        )

        workspace.exportNow()

        let snapshotData = try Data(contentsOf: harness.storagePaths.snapshotURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(SnapshotReadModel.self, from: snapshotData)

        #expect(snapshot.version == 1)
        #expect(snapshot.summary.totalWords == 2)
        #expect(snapshot.summary.acceptedConnections == 1)
        #expect(snapshot.summary.suggestedConnections == 0)
        #expect(snapshot.words.map(\.displayTerm).sorted() == ["constraint", "thing"])

        let exportedConnection = try #require(snapshot.connections.first)
        #expect(exportedConnection.overusedTerm == "thing")
        #expect(exportedConnection.underusedTerm == "constraint")
        #expect(exportedConnection.status == SuggestionStatus.accepted.rawValue)
        #expect(snapshot.words.first(where: { $0.displayTerm == "thing" })?.sourceExcerpt == "This thing keeps blocking the project.")
        #expect(snapshot.words.first(where: { $0.displayTerm == "constraint" })?.exampleUsage == "The budget constraint shaped the roadmap.")
        #expect(exportedConnection.sourceExcerpt == "This thing keeps blocking the project.")
        #expect(exportedConnection.exampleUsage == "The regulatory constraint slowed the rollout.")
    }

    @Test
    @MainActor
    func updatesWordReferenceDetailsAndPersistsThem() throws {
        let harness = try TestHarness.make()
        defer { harness.cleanup() }

        let context = harness.container.mainContext
        let word = Word(displayTerm: "interesting", normalizedTerm: "interesting")
        context.insert(word)
        try context.save()

        let workspace = EloqWorkspace(
            modelContext: context,
            storagePaths: harness.storagePaths,
            registerHotKey: false
        )

        workspace.updateWordReferenceDetails(
            word,
            sourceExcerpt: "The argument felt interesting but vague.",
            exampleUsage: "The result was interesting enough to revisit later."
        )

        let updatedWord = try #require(workspace.words.first(where: { $0.displayTerm == "interesting" }))
        #expect(updatedWord.sourceExcerpt == "The argument felt interesting but vague.")
        #expect(updatedWord.exampleUsage == "The result was interesting enough to revisit later.")
    }

    @Test
    @MainActor
    func createsManualLibraryConnectionsAndOppositeRoles() throws {
        let harness = try TestHarness.make()
        defer { harness.cleanup() }

        let context = harness.container.mainContext
        let focusWord = Word(displayTerm: "thing", normalizedTerm: "thing")
        context.insert(focusWord)
        context.insert(WordRole(word: focusWord, kind: .overused, primaryMode: true))
        try context.save()

        let workspace = EloqWorkspace(
            modelContext: context,
            storagePaths: harness.storagePaths,
            registerHotKey: false
        )

        let created = workspace.createLibraryConnection(
            focusWord: focusWord,
            focusKind: .overused,
            counterpartText: "constraint"
        )

        #expect(created)
        #expect(workspace.words.map(\.displayTerm).sorted() == ["constraint", "thing"])

        let connection = try #require(workspace.connections.first)
        #expect(connection.status == .accepted)
        #expect(workspace.connectionTitle(connection) == "thing->constraint")
    }

    @Test
    @MainActor
    func excludesAlreadyLinkedOppositeWordsFromLibraryCandidates() throws {
        let harness = try TestHarness.make()
        defer { harness.cleanup() }

        let context = harness.container.mainContext
        let overused = Word(displayTerm: "thing", normalizedTerm: "thing")
        let linkedUnderused = Word(displayTerm: "constraint", normalizedTerm: "constraint")
        let availableUnderused = Word(displayTerm: "specificity", normalizedTerm: "specificity")
        context.insert(overused)
        context.insert(linkedUnderused)
        context.insert(availableUnderused)

        let overusedRole = WordRole(word: overused, kind: .overused, primaryMode: true)
        let linkedRole = WordRole(word: linkedUnderused, kind: .underused, primaryMode: true)
        let availableRole = WordRole(word: availableUnderused, kind: .underused, primaryMode: true)
        context.insert(overusedRole)
        context.insert(linkedRole)
        context.insert(availableRole)

        context.insert(
            WordConnection(
                fromRole: overusedRole,
                toRole: linkedRole,
                origin: .user,
                status: .accepted,
                rationale: "Existing link.",
                useWhen: "Use the more precise option.",
                caution: "Avoid forcing it.",
                confidence: 1
            )
        )
        try context.save()

        let workspace = EloqWorkspace(
            modelContext: context,
            storagePaths: harness.storagePaths,
            registerHotKey: false
        )

        let candidates = workspace.availableOppositeWords(for: overused, focusKind: .overused)

        #expect(candidates.map(\.displayTerm) == ["specificity"])
    }

    @Test
    @MainActor
    func prioritizesNewAISuggestionsAheadOfLibraryReuses() throws {
        let harness = try TestHarness.make()
        defer { harness.cleanup() }

        let context = harness.container.mainContext
        let overused = Word(displayTerm: "thing", normalizedTerm: "thing")
        let libraryUnderused = Word(displayTerm: "constraint", normalizedTerm: "constraint")
        context.insert(overused)
        context.insert(libraryUnderused)
        context.insert(WordRole(word: overused, kind: .overused, primaryMode: true))
        context.insert(WordRole(word: libraryUnderused, kind: .underused, primaryMode: true))
        try context.save()

        let workspace = EloqWorkspace(
            modelContext: context,
            storagePaths: harness.storagePaths,
            registerHotKey: false
        )

        let staged = workspace.stageAISuggestions(
            [
                SuggestionCandidate(
                    counterpartTerm: "constraint",
                    rationale: "Matches the current library well.",
                    useWhen: "Use it when the sentence names a concrete limit.",
                    caution: "Skip it if you mean a literal object.",
                    exampleUsage: "The compliance constraint delayed the launch.",
                    confidence: 0.97
                ),
                SuggestionCandidate(
                    counterpartTerm: "specificity",
                    rationale: "Introduces a sharper new angle.",
                    useWhen: "Use it when the sentence needs more precision than a placeholder noun.",
                    caution: "Avoid it when the sentence is not really about precision.",
                    exampleUsage: "Specificity made the feedback more useful.",
                    confidence: 0.74
                ),
            ],
            for: overused,
            focusKind: .overused
        )

        #expect(staged == 2)

        let scopedSuggestions = workspace.pendingSuggestions(for: overused, focusKind: .overused)
        #expect(scopedSuggestions.map(\.counterpartTerm) == ["specificity", "constraint"])
        #expect(scopedSuggestions.map(\.counterpartSource) == [.generated, .library])
        #expect(workspace.pendingSuggestions.map(\.counterpartSource) == [.generated, .library])
    }

    @Test
    func buildsExplicitDirectionGuidanceForBothGenerationModes() {
        let underusedFocus = RoleSummary(
            term: "lucid",
            normalizedTerm: "lucid",
            kind: WordRoleKind.underused.rawValue
        )
        #expect(OpenAISuggestionService.oppositeKind(for: underusedFocus.kind) == WordRoleKind.overused.rawValue)
        #expect(
            OpenAISuggestionService.directionGuidance(for: underusedFocus)
                .contains("Suggest overused/default words or phrases")
        )

        let overusedFocus = RoleSummary(
            term: "nice",
            normalizedTerm: "nice",
            kind: WordRoleKind.overused.rawValue
        )
        #expect(OpenAISuggestionService.oppositeKind(for: overusedFocus.kind) == WordRoleKind.underused.rawValue)
        #expect(
            OpenAISuggestionService.directionGuidance(for: overusedFocus)
                .contains("Suggest sharper underused words or phrases")
        )
    }

    @Test
    @MainActor
    func requestingSuggestionsForUnderusedWordsStagesOverusedIdeasAndAnnouncesResult() async throws {
        let harness = try TestHarness.make()
        defer { harness.cleanup() }

        MockOpenAIURLProtocol.lastRequest = nil
        MockOpenAIURLProtocol.requestHandler = { request in
            if MockOpenAIURLProtocol.lastRequest == nil || request.httpBody != nil {
                MockOpenAIURLProtocol.lastRequest = request
            }

            let outputText = """
            {"suggestions":[{"counterpartTerm":"generic wording","rationale":"Maps the sharper target back to a common fallback.","useWhen":"Use it when the sentence can stay plain and less precise.","caution":"Skip it when the sharper word matters.","exampleUsage":"The summary used generic wording throughout.","confidence":0.78}]}
            """
            let responseObject: [String: Any] = [
                "output": [
                    [
                        "type": "message",
                        "content": [
                            [
                                "type": "output_text",
                                "text": outputText,
                            ],
                        ],
                    ],
                ],
            ]
            let responseData = try JSONSerialization.data(withJSONObject: responseObject)
            let url = request.url ?? URL(string: "https://api.openai.com/v1/responses")!
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, responseData)
        }
        defer {
            MockOpenAIURLProtocol.requestHandler = nil
            MockOpenAIURLProtocol.lastRequest = nil
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockOpenAIURLProtocol.self]
        let aiService = OpenAISuggestionService(
            session: URLSession(configuration: configuration),
            apiKeyProvider: { "test-key" }
        )

        let context = harness.container.mainContext
        let underusedWord = Word(displayTerm: "lucid", normalizedTerm: "lucid")
        context.insert(underusedWord)
        context.insert(WordRole(word: underusedWord, kind: .underused, primaryMode: true))
        try context.save()

        let workspace = EloqWorkspace(
            modelContext: context,
            aiService: aiService,
            storagePaths: harness.storagePaths,
            registerHotKey: false
        )
        let focusWord = try #require(workspace.words.first(where: { $0.displayTerm == "lucid" }))

        workspace.requestSuggestions(for: focusWord, focusKind: .underused)

        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if MockOpenAIURLProtocol.lastRequest != nil && !workspace.isGeneratingSuggestions {
                break
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        let request = try #require(MockOpenAIURLProtocol.lastRequest)
        #expect(!workspace.isGeneratingSuggestions)
        #expect(request.url?.absoluteString == "https://api.openai.com/v1/responses")

        let suggestion = try #require(workspace.pendingSuggestions(for: focusWord, focusKind: .underused).first)
        #expect(suggestion.counterpartTerm == "generic wording")
        #expect(suggestion.counterpartSource == .generated)
        #expect(suggestion.overusedTerm == "generic wording")
        #expect(suggestion.underusedTerm == "lucid")
        #expect(workspace.lastBanner == "Queued 1 suggestion(s) for review on \"lucid\".")
    }

    @Test
    @MainActor
    func stagesAISuggestionsWithoutPersistingUntilAccepted() throws {
        let harness = try TestHarness.make()
        defer { harness.cleanup() }

        let context = harness.container.mainContext
        let focusWord = Word(displayTerm: "thing", normalizedTerm: "thing")
        context.insert(focusWord)
        context.insert(WordRole(word: focusWord, kind: .overused, primaryMode: true))
        try context.save()

        let workspace = EloqWorkspace(
            modelContext: context,
            storagePaths: harness.storagePaths,
            registerHotKey: false
        )

        let staged = workspace.stageAISuggestions(
            [
                SuggestionCandidate(
                    counterpartTerm: "constraint",
                    rationale: "Sharper than a placeholder noun.",
                    useWhen: "Use it when the sentence points to a real limiting factor.",
                    caution: "Avoid it if you mean a literal object.",
                    exampleUsage: "The staffing constraint slowed the launch.",
                    confidence: 0.92
                )
            ],
            for: focusWord,
            focusKind: .overused
        )

        #expect(staged == 1)
        #expect(workspace.pendingSuggestions.count == 1)
        #expect(workspace.words.map(\.displayTerm).sorted() == ["thing"])
        #expect(workspace.connections.isEmpty)

        let suggestion = try #require(workspace.pendingSuggestions.first)
        workspace.accept(suggestion)

        #expect(workspace.words.map(\.displayTerm).sorted() == ["constraint", "thing"])
        #expect(workspace.connections.count == 1)
        #expect(workspace.pendingSuggestions.isEmpty)
        #expect(workspace.reviewedSuggestions.first?.status == .accepted)
        #expect(workspace.connections.first?.exampleUsage == "The staffing constraint slowed the launch.")
        #expect(workspace.words.first(where: { $0.displayTerm == "constraint" })?.exampleUsage == "The staffing constraint slowed the launch.")
    }

    @Test
    @MainActor
    func deletingWordRemovesRolesConnectionsAndStagedSuggestions() throws {
        let harness = try TestHarness.make()
        defer { harness.cleanup() }

        let context = harness.container.mainContext
        let overused = Word(displayTerm: "thing", normalizedTerm: "thing")
        let underused = Word(displayTerm: "constraint", normalizedTerm: "constraint")
        context.insert(overused)
        context.insert(underused)

        let overusedRole = WordRole(word: overused, kind: .overused, primaryMode: true)
        let underusedRole = WordRole(word: underused, kind: .underused, primaryMode: true)
        context.insert(overusedRole)
        context.insert(underusedRole)
        context.insert(
            WordConnection(
                fromRole: overusedRole,
                toRole: underusedRole,
                origin: .user,
                status: .accepted,
                rationale: "Existing accepted link.",
                useWhen: "Use the sharper word when it is more precise.",
                caution: "Avoid forcing it.",
                confidence: 1
            )
        )
        try context.save()

        let workspace = EloqWorkspace(
            modelContext: context,
            storagePaths: harness.storagePaths,
            registerHotKey: false
        )

        _ = workspace.stageAISuggestions(
            [
                SuggestionCandidate(
                    counterpartTerm: "specificity",
                    rationale: "Another sharper noun.",
                    useWhen: "Use it when precision matters.",
                    caution: "Skip it if it sounds forced.",
                    exampleUsage: "Specificity improved the design review.",
                    confidence: 0.71
                )
            ],
            for: overused,
            focusKind: .overused
        )

        #expect(workspace.words.count == 2)
        #expect(workspace.connections.count == 1)
        #expect(workspace.pendingSuggestions.count == 1)

        workspace.deleteWord(overused)

        #expect(workspace.words.map(\.displayTerm) == ["constraint"])
        #expect(workspace.roles.count == 1)
        #expect(workspace.connections.isEmpty)
        #expect(workspace.pendingSuggestions.isEmpty)
        #expect(workspace.reviewedSuggestions.isEmpty)
    }
}

private struct TestHarness {
    let rootDirectory: URL
    let container: ModelContainer
    let storagePaths: EloqStoragePaths

    static func make() throws -> TestHarness {
        let fileManager = FileManager.default
        let rootDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("eloq-tests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)

        let schema = Schema([
            Word.self,
            WordRole.self,
            WordConnection.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])

        return TestHarness(
            rootDirectory: rootDirectory,
            container: container,
            storagePaths: EloqStoragePaths(
                rootDirectory: rootDirectory.appendingPathComponent("Eloq", isDirectory: true),
                snapshotURL: rootDirectory.appendingPathComponent("Eloq", isDirectory: true).appendingPathComponent("snapshot.json"),
                audoraStateURL: rootDirectory
                    .appendingPathComponent("Audora", isDirectory: true)
                    .appendingPathComponent("WritingAwareness", isDirectory: true)
                    .appendingPathComponent("state.json"),
                audoraSeedURL: rootDirectory
                    .appendingPathComponent("Audora", isDirectory: true)
                    .appendingPathComponent("WritingAwareness", isDirectory: true)
                    .appendingPathComponent("seed.json")
            )
        )
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: rootDirectory)
    }

    func writeAudoraSeed(_ json: String) throws {
        let audoraDirectory = storagePaths.audoraSeedURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: audoraDirectory, withIntermediateDirectories: true)
        try json.data(using: .utf8)?.write(to: storagePaths.audoraSeedURL)
    }
}

private final class MockOpenAIURLProtocol: URLProtocol, @unchecked Sendable {
    static var lastRequest: URLRequest?
    static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
