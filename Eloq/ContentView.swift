import SwiftData
import SwiftUI

struct ContentView: View {
    @ObservedObject var workspace: EloqWorkspace

    var body: some View {
        VStack(spacing: 0) {
            if let banner = workspace.lastBanner {
                BannerStrip(message: banner) {
                    workspace.dismissBanner()
                }
            }

            TabView(selection: $workspace.currentScreen) {
                HomeTab(workspace: workspace)
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                    .tag(WorkspaceScreen.home)

                InboxTab(workspace: workspace)
                    .tabItem {
                        Label("Inbox", systemImage: "sparkles")
                    }
                    .tag(WorkspaceScreen.inbox)

                LibraryTab(workspace: workspace)
                    .tabItem {
                        Label("Library", systemImage: "books.vertical")
                    }
                    .tag(WorkspaceScreen.library)
            }
        }
        .frame(minWidth: 1024, minHeight: 700)
    }
}

private struct HomeTab: View {
    @ObservedObject var workspace: EloqWorkspace

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    quickAddPanel

                    HStack(alignment: .top, spacing: 16) {
                        MetricPanel(
                            title: "Library",
                            value: "\(workspace.totalWordCount)",
                            detail: "\(workspace.overusedWordCount) overused • \(workspace.underusedWordCount) underused",
                            systemImage: "text.book.closed"
                        )

                        MetricPanel(
                            title: "Inbox",
                            value: "\(workspace.pendingSuggestions.count)",
                            detail: workspace.pendingSuggestions.isEmpty ? "Nothing waiting for review" : "Suggestions ready to accept or dismiss",
                            systemImage: "sparkles"
                        )

                        MetricPanel(
                            title: "Connections",
                            value: "\(workspace.acceptedConnectionCount)",
                            detail: "Accepted links in the active vocabulary graph",
                            systemImage: "point.3.connected.trianglepath.dotted"
                        )
                    }

                    HStack(alignment: .top, spacing: 16) {
                        recentWordsPanel
                        operationsPanel
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .navigationTitle("Eloq")
        }
    }

    private var quickAddPanel: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Build your vocabulary graph")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Save a word, decide whether it belongs on the overused or underused side, and let Eloq suggest the opposite-side links immediately.")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        Text("\(workspace.pendingSuggestions.count) pending")
                            .font(.headline)
                            .monospacedDigit()

                        Button("Review Inbox") {
                            workspace.currentScreen = .inbox
                        }
                        .buttonStyle(.bordered)
                    }
                }

                TextField("Add a word or short phrase", text: $workspace.quickAddText)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .onSubmit {
                        workspace.submitQuickAdd()
                    }

                Picker("Mode", selection: $workspace.quickAddMode) {
                    ForEach(WordRoleKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Button("Save Word") {
                        workspace.submitQuickAdd()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(workspace.quickAddText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Capture Selection") {
                        workspace.captureSelectionIntoDraft()
                    }
                    .buttonStyle(.bordered)

                    Button("Open Library") {
                        workspace.currentScreen = .library
                    }
                    .buttonStyle(.bordered)
                }
            }
        } label: {
            Label("Quick Add", systemImage: "plus.circle")
        }
    }

    private var recentWordsPanel: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                if workspace.recentWords.isEmpty {
                    Text("Start by saving an overused word and an underused word. Eloq will use those as the first shape of the graph.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(workspace.recentWords.prefix(6)), id: \.id) { word in
                        Button {
                            workspace.selectWord(word)
                            workspace.currentScreen = .library
                        } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(word.displayTerm)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    Text(workspace.roles(for: word).map { $0.kind.title }.joined(separator: " • "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(word.updatedAt.formatted(date: .omitted, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)

                        if word.id != workspace.recentWords.prefix(6).last?.id {
                            Divider()
                        }
                    }
                }
            }
        } label: {
            Label("Recent Words", systemImage: "clock")
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var operationsPanel: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Capture")
                        .font(.headline)

                    Text(workspace.captureStatusText)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("Request Access") {
                            workspace.requestAccessibilityAccess()
                        }
                        .buttonStyle(.bordered)

                        Button("Accessibility Settings") {
                            workspace.openAccessibilitySettings()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Import & Export")
                        .font(.headline)

                    Text(workspace.importReport.sourceSummary)
                        .foregroundStyle(.secondary)

                    Text("\(workspace.importReport.importedWords) words • \(workspace.importReport.importedConnections) connections • \(workspace.importReport.skippedRules) skipped")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    HStack {
                        Button(workspace.isImporting ? "Importing…" : "Import Audora") {
                            workspace.importAudoraVocabulary()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(workspace.isImporting)

                        Button("Export Snapshot") {
                            workspace.exportNow()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Divider()

                HealthSummaryView(health: workspace.health)

                Text("OpenAI and storage configuration live in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } label: {
            Label("Operations", systemImage: "gearshape.2")
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct InboxTab: View {
    @ObservedObject var workspace: EloqWorkspace

    var body: some View {
        NavigationStack {
            Group {
                if workspace.pendingSuggestions.isEmpty && workspace.reviewedSuggestions.isEmpty {
                    UnavailableStateView(
                        systemImage: "sparkles",
                        title: "No Suggestions Yet",
                        message: "Add a word or import Audora vocabulary and Eloq will queue AI-discovered links here."
                    )
                } else {
                    List {
                        if !workspace.pendingSuggestions.isEmpty {
                            Section {
                                InlineStatRow(
                                    primary: "\(workspace.pendingSuggestions.count) pending",
                                    secondary: "Accept useful links to make them part of the exported vocabulary graph."
                                )
                            }

                            Section("Pending") {
                                ForEach(workspace.pendingSuggestions, id: \.id) { connection in
                                    SuggestionRow(
                                        title: workspace.connectionTitle(connection).replacingOccurrences(of: "->", with: " -> "),
                                        status: connection.status,
                                        rationale: connection.rationale,
                                        useWhen: connection.useWhen,
                                        caution: connection.caution,
                                        confidence: connection.confidence,
                                        onAccept: { workspace.accept(connection) },
                                        onDismiss: { workspace.dismiss(connection) },
                                        onRestore: nil
                                    )
                                }
                            }
                        }

                        if !workspace.reviewedSuggestions.isEmpty {
                            Section("Reviewed") {
                                ForEach(Array(workspace.reviewedSuggestions.prefix(18)), id: \.id) { connection in
                                    SuggestionRow(
                                        title: workspace.connectionTitle(connection).replacingOccurrences(of: "->", with: " -> "),
                                        status: connection.status,
                                        rationale: connection.rationale,
                                        useWhen: connection.useWhen,
                                        caution: connection.caution,
                                        confidence: connection.confidence,
                                        onAccept: connection.status == .dismissed ? { workspace.accept(connection) } : nil,
                                        onDismiss: connection.status == .accepted ? { workspace.dismiss(connection) } : nil,
                                        onRestore: { workspace.restore(connection) }
                                    )
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .navigationTitle("Suggestion Inbox")
            .toolbar {
                if workspace.isGeneratingSuggestions {
                    ToolbarItem {
                        ProgressView()
                    }
                }
            }
        }
    }
}

private struct LibraryTab: View {
    @ObservedObject var workspace: EloqWorkspace

    private var selectionBinding: Binding<UUID?> {
        Binding(
            get: { workspace.selectedWordID },
            set: { workspace.selectedWordID = $0 }
        )
    }

    var body: some View {
        NavigationSplitView {
            if workspace.filteredWords().isEmpty {
                UnavailableStateView(
                    systemImage: "text.book.closed",
                    title: "No Words Found",
                    message: workspace.words.isEmpty
                        ? "Save your first word on Home to start the library."
                        : "Try a different search or library filter."
                )
            } else {
                List(selection: selectionBinding) {
                    ForEach(workspace.filteredWords(), id: \.id) { word in
                        LibraryWordRow(
                            word: word,
                            roleSummary: workspace.roles(for: word).map { $0.kind.title }.joined(separator: " • "),
                            connectionCount: workspace.connections(for: word).count
                        )
                        .tag(word.id)
                    }
                }
                .listStyle(.sidebar)
            }
        } detail: {
            if let selectedWord = workspace.selectedWord() {
                WordDetailView(workspace: workspace, word: selectedWord)
            } else {
                UnavailableStateView(
                    systemImage: "character.book.closed",
                    title: "Select a Word",
                    message: "Choose a word from the library to review connections, accept AI ideas, or link an opposite-side term manually."
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $workspace.searchText, prompt: "Search words")
        .toolbar {
            ToolbarItem {
                Picker("Filter", selection: $workspace.libraryFilter) {
                    ForEach(LibraryFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
            }
        }
    }
}

private struct WordDetailView: View {
    @ObservedObject var workspace: EloqWorkspace
    let word: Word

    private var roles: [WordRole] {
        workspace.roles(for: word)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(word.displayTerm)
                                .font(.largeTitle)
                                .fontWeight(.semibold)

                            if !roles.isEmpty {
                                FlowRoleBadges(kinds: roles.map { $0.kind })
                            }

                            if !word.notes.isEmpty {
                                DetailLine(label: "Notes", text: word.notes)
                            }

                            if !word.contexts.isEmpty {
                                DetailLine(label: "Contexts", text: word.contexts.joined(separator: ", "))
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 8) {
                            MetricCallout(title: "Total Links", value: "\(workspace.connections(for: word).count)")
                            MetricCallout(
                                title: "Accepted",
                                value: "\(workspace.connections(for: word).filter { $0.status == .accepted }.count)"
                            )
                        }
                    }
                } label: {
                    Label("Word Overview", systemImage: "character.book.closed")
                }

                if let overusedRole = roles.first(where: { $0.kind == .overused }),
                   let underusedRole = roles.first(where: { $0.kind == .underused }) {
                    HStack(alignment: .top, spacing: 16) {
                        RoleConnectionPanel(workspace: workspace, focusWord: word, focusKind: overusedRole.kind)
                        RoleConnectionPanel(workspace: workspace, focusWord: word, focusKind: underusedRole.kind)
                    }
                } else if let onlyRole = roles.first {
                    RoleConnectionPanel(workspace: workspace, focusWord: word, focusKind: onlyRole.kind)
                } else {
                    UnavailableStateView(
                        systemImage: "link.badge.plus",
                        title: "No Roles Yet",
                        message: "This word exists in storage but is not currently assigned to an overused or underused side."
                    )
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle(word.displayTerm)
    }
}

private struct RoleConnectionPanel: View {
    @ObservedObject var workspace: EloqWorkspace
    let focusWord: Word
    let focusKind: WordRoleKind
    @State private var manualCounterpart = ""

    private var scopedConnections: [WordConnection] {
        workspace.scopedConnections(for: focusWord, focusKind: focusKind)
    }

    private var suggestedConnections: [WordConnection] {
        scopedConnections.filter { $0.status == .suggested }
    }

    private var availableWords: [Word] {
        workspace.availableOppositeWords(for: focusWord, focusKind: focusKind)
    }

    private var title: String {
        switch focusKind {
        case .overused:
            return "Sharper alternatives"
        case .underused:
            return "Words this can replace"
        }
    }

    private var helperText: String {
        switch focusKind {
        case .overused:
            return "Generate underused words that help you stop leaning on “\(focusWord.displayTerm)”."
        case .underused:
            return "Generate overused words that “\(focusWord.displayTerm)” should be connected against."
        }
    }

    private var chipTitle: String {
        switch focusKind {
        case .overused:
            return "Tap to accept AI alternatives"
        case .underused:
            return "Tap to accept AI source words"
        }
    }

    private var manualPlaceholder: String {
        switch focusKind {
        case .overused:
            return "Add a new underused word"
        case .underused:
            return "Add a new overused word"
        }
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text(helperText)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Generate AI Ideas") {
                        workspace.requestSuggestions(for: focusWord, focusKind: focusKind)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if workspace.isGeneratingSuggestions {
                    ProgressView()
                }

                if !suggestedConnections.isEmpty {
                    ConnectionChipRow(title: chipTitle) {
                        ForEach(suggestedConnections, id: \.id) { connection in
                            if let counterpart = workspace.counterpartWord(for: connection, focusKind: focusKind) {
                                Button(counterpart.displayTerm) {
                                    workspace.accept(connection)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }

                if !availableWords.isEmpty {
                    ConnectionChipRow(title: "Connect a word already in your library") {
                        ForEach(Array(availableWords.prefix(18)), id: \.id) { candidate in
                            Button(candidate.displayTerm) {
                                _ = workspace.connectCounterpart(
                                    focusWord: focusWord,
                                    focusKind: focusKind,
                                    counterpartWord: candidate
                                )
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                HStack {
                    TextField(manualPlaceholder, text: $manualCounterpart)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            createManualConnection()
                        }

                    Button("Connect") {
                        createManualConnection()
                    }
                    .buttonStyle(.bordered)
                    .disabled(manualCounterpart.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Divider()

                if scopedConnections.isEmpty {
                    Text("No links for this side yet.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(scopedConnections, id: \.id) { connection in
                            SuggestionRow(
                                title: workspace.counterpartWord(for: connection, focusKind: focusKind)?.displayTerm ?? "Linked word",
                                status: connection.status,
                                rationale: connection.rationale,
                                useWhen: connection.useWhen,
                                caution: connection.caution,
                                confidence: connection.confidence,
                                onAccept: connection.status == .suggested || connection.status == .dismissed
                                    ? { workspace.accept(connection) }
                                    : nil,
                                onDismiss: connection.status != .dismissed
                                    ? { workspace.dismiss(connection) }
                                    : nil,
                                onRestore: connection.status != .suggested
                                    ? { workspace.restore(connection) }
                                    : nil
                            )

                            if connection.id != scopedConnections.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(focusKind.title, systemImage: focusKind == .overused ? "arrow.turn.down.right" : "arrow.turn.up.left")
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func createManualConnection() {
        if workspace.createLibraryConnection(
            focusWord: focusWord,
            focusKind: focusKind,
            counterpartText: manualCounterpart
        ) {
            manualCounterpart = ""
        }
    }
}

private struct SuggestionRow: View {
    let title: String
    let status: SuggestionStatus
    let rationale: String
    let useWhen: String
    let caution: String
    let confidence: Double
    let onAccept: (() -> Void)?
    let onDismiss: (() -> Void)?
    let onRestore: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.headline)

                Spacer()

                HStack(spacing: 10) {
                    Label(status.title, systemImage: status.symbolName)
                        .font(.caption)
                        .foregroundStyle(status.tintColor)

                    Text("\(Int(confidence * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            if !rationale.isEmpty {
                Text(rationale)
                    .foregroundStyle(.secondary)
            }

            DetailLine(label: "Use When", text: useWhen)
            DetailLine(label: "Caution", text: caution)

            HStack {
                if let onAccept {
                    Button("Accept", action: onAccept)
                        .buttonStyle(.borderedProminent)
                }

                if let onDismiss {
                    Button("Dismiss", action: onDismiss)
                        .buttonStyle(.bordered)
                }

                if let onRestore {
                    Button("Restore", action: onRestore)
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 10)
    }
}

private struct HealthSummaryView: View {
    let health: HealthStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(health.title, systemImage: health.level.symbolName)
                .foregroundStyle(health.level.tintColor)

            Text(health.detail)
                .foregroundStyle(.secondary)

            if let lastExportAt = health.lastExportAt {
                Text("Last export: \(lastExportAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let lastAIError = health.lastAIError, !lastAIError.isEmpty {
                DetailLine(label: "AI", text: lastAIError)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MetricPanel: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            Text(value)
                .font(.system(size: 30, weight: .semibold))
                .monospacedDigit()

            Text(detail)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct MetricCallout: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }
}

private struct LibraryWordRow: View {
    let word: Word
    let roleSummary: String
    let connectionCount: Int

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(word.displayTerm)
                    .font(.headline)

                if !roleSummary.isEmpty {
                    Text(roleSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if connectionCount > 0 {
                Text("\(connectionCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }
}

private struct FlowRoleBadges: View {
    let kinds: [WordRoleKind]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(kinds) { kind in
                    Text(kind.title)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.quaternary, in: Capsule())
                }
            }
        }
    }
}

private struct ConnectionChipRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    content
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct InlineStatRow: View {
    let primary: String
    let secondary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(primary)
                .font(.headline)
                .monospacedDigit()
            Text(secondary)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private struct BannerStrip: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)

            Text(message)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.quaternary.opacity(0.55))
    }
}

private struct UnavailableStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

private struct DetailLine: View {
    let label: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
        }
    }
}

private extension SuggestionStatus {
    var symbolName: String {
        switch self {
        case .suggested:
            return "sparkles"
        case .accepted:
            return "checkmark.circle.fill"
        case .dismissed:
            return "minus.circle.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .suggested:
            return .orange
        case .accepted:
            return .green
        case .dismissed:
            return .secondary
        }
    }
}

private extension HealthLevel {
    var symbolName: String {
        switch self {
        case .healthy:
            return "checkmark.circle.fill"
        case .partial:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .healthy:
            return .green
        case .partial:
            return .orange
        case .error:
            return .red
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

    ContentView(workspace: EloqWorkspace(modelContext: container.mainContext, registerHotKey: false))
}
