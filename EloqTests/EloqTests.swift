import Foundation
import SwiftData
import Testing
@testable import Eloq

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
        let overusedWord = Word(displayTerm: "thing", normalizedTerm: "thing", notes: "Vague placeholder")
        let underusedWord = Word(displayTerm: "constraint", normalizedTerm: "constraint", notes: "Sharper alternative")
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
