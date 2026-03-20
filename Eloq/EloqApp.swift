import SwiftData
import SwiftUI

@main
struct EloqApp: App {
    private let sharedModelContainer: ModelContainer
    @StateObject private var workspace: EloqWorkspace

    init() {
        let schema = Schema([
            Word.self,
            WordRole.self,
            WordConnection.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            sharedModelContainer = container
            _workspace = StateObject(wrappedValue: EloqWorkspace(modelContext: container.mainContext))
        } catch {
            fatalError("Could not create Eloq ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(workspace: workspace)
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandMenu("Capture") {
                Button("Capture Selection") {
                    workspace.captureSelectionIntoDraft()
                }
                .keyboardShortcut("L", modifiers: [.command, .option, .control])

                Button("Request Accessibility Access") {
                    workspace.requestAccessibilityAccess()
                }
            }
        }
    }
}
