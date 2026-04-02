import SwiftData
import SwiftUI

struct EloqSettingsView: View {
    @ObservedObject var workspace: EloqWorkspace

    var body: some View {
        TabView {
            AISettingsTab(workspace: workspace)
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }

            CaptureSettingsTab(workspace: workspace)
                .tabItem {
                    Label("Capture", systemImage: "text.cursor")
                }

            StorageSettingsTab(workspace: workspace)
                .tabItem {
                    Label("Storage", systemImage: "externaldrive")
                }
        }
        .frame(minWidth: 620, minHeight: 460)
        .background(EloqTheme.canvas.ignoresSafeArea())
        .groupBoxStyle(EloqPanelGroupBoxStyle())
    }
}

private struct AISettingsTab: View {
    @ObservedObject var workspace: EloqWorkspace

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("OpenAI")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Eloq uses your API key for opposite-side suggestion generation. Word storage stays local whether a key is present or not.")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                EloqChip(
                    text: workspace.hasOpenAIKey ? "Stored" : "Missing",
                    tone: workspace.hasOpenAIKey ? .accent : .warning
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.headline)

                TextField("OpenAI API key", text: $workspace.apiKeyDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                Text(workspace.openAIKeyStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Save Key") {
                    workspace.saveOpenAIKey()
                }
                .buttonStyle(.borderedProminent)
                .disabled(workspace.apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Clear Key") {
                    workspace.clearOpenAIKey()
                }
                .buttonStyle(.bordered)
                .disabled(!workspace.hasOpenAIKey)
            }

            Spacer()
        }
        .padding(24)
        .background(EloqTheme.canvas)
    }
}

private struct CaptureSettingsTab: View {
    @ObservedObject var workspace: EloqWorkspace

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Capture")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Selection capture is the fastest way to add a word while you write. Eloq uses the global shortcut Control + Option + Command + L.")
                .foregroundStyle(.secondary)

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text(workspace.captureStatusText)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("Request Accessibility Access") {
                            workspace.requestAccessibilityAccess()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Open Accessibility Settings") {
                            workspace.openAccessibilitySettings()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label("Global Capture", systemImage: "keyboard")
            }

            Spacer()
        }
        .padding(24)
        .background(EloqTheme.canvas)
    }
}

private struct StorageSettingsTab: View {
    @ObservedObject var workspace: EloqWorkspace

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Storage & Export")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Eloq is local-first. These paths control snapshot export and the Audora migration bridge.")
                .foregroundStyle(.secondary)

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    PathRow(label: "Eloq Storage", path: workspace.storageDirectoryPathText)
                    PathRow(label: "Snapshot Export", path: workspace.snapshotPathText)
                    PathRow(label: "Browser Bridge", path: workspace.browserBridgeURLText)
                    PathRow(label: "Audora Import Folder", path: workspace.audoraImportDirectoryPathText)

                    HStack {
                        Button("Reveal Eloq Storage") {
                            workspace.revealStorageDirectoryInFinder()
                        }
                        .buttonStyle(.bordered)

                        Button("Reveal Snapshot") {
                            workspace.revealSnapshotInFinder()
                        }
                        .buttonStyle(.bordered)

                        Button("Reveal Audora Import") {
                            workspace.revealAudoraImportDirectoryInFinder()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label("Paths", systemImage: "folder")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Label(workspace.health.title, systemImage: healthSymbolName(workspace.health.level))
                        .foregroundStyle(healthTintColor(workspace.health.level))

                    Text(workspace.health.detail)
                        .foregroundStyle(.secondary)

                    if let lastExportAt = workspace.health.lastExportAt {
                        Text("Last export: \(lastExportAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button("Export Snapshot Now") {
                            workspace.exportNow()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Import Audora Vocabulary") {
                            workspace.importAudoraVocabulary()
                        }
                        .buttonStyle(.bordered)
                        .disabled(workspace.isImporting)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label("Current Status", systemImage: "heart.text.square")
            }

            Spacer()
        }
        .padding(24)
        .background(EloqTheme.canvas)
    }

    private func healthSymbolName(_ level: HealthLevel) -> String {
        switch level {
        case .healthy:
            return "checkmark.circle.fill"
        case .partial:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    private func healthTintColor(_ level: HealthLevel) -> Color {
        switch level {
        case .healthy:
            return EloqTheme.accent
        case .partial:
            return EloqTheme.warning
        case .error:
            return EloqTheme.danger
        }
    }
}

private struct PathRow: View {
    let label: String
    let path: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.headline)
            Text(path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}

#Preview {
    let schema = Schema([
        Word.self,
        WordRole.self,
        WordConnection.self,
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])

    EloqSettingsView(workspace: EloqWorkspace(modelContext: container.mainContext, registerHotKey: false))
}
