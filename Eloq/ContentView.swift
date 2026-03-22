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

                AtlasTab(workspace: workspace)
                    .tabItem {
                        Label("Atlas", systemImage: "point.3.connected.trianglepath.dotted")
                    }
                    .tag(WorkspaceScreen.atlas)
            }
        }
        .frame(minWidth: 1024, minHeight: 700)
        .background(EloqTheme.canvas.ignoresSafeArea())
        .groupBoxStyle(EloqPanelGroupBoxStyle())
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
        .background(EloqTheme.canvas.ignoresSafeArea())
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
                                ForEach(workspace.pendingSuggestions, id: \.id) { suggestion in
                                    SuggestionRow(
                                        title: workspace.connectionTitle(suggestion).replacingOccurrences(of: "->", with: " -> "),
                                        counterpartSource: suggestion.counterpartSource,
                                        status: suggestion.status,
                                        rationale: suggestion.rationale,
                                        useWhen: suggestion.useWhen,
                                        caution: suggestion.caution,
                                        sourceExcerpt: suggestion.sourceExcerpt,
                                        exampleUsage: suggestion.exampleUsage,
                                        confidence: suggestion.confidence,
                                        onAccept: { workspace.accept(suggestion) },
                                        onDismiss: { workspace.dismiss(suggestion) },
                                        onRestore: nil
                                    )
                                }
                            }
                        }

                        if !workspace.reviewedSuggestions.isEmpty {
                            Section("Reviewed") {
                                ForEach(Array(workspace.reviewedSuggestions.prefix(18)), id: \.id) { suggestion in
                                    SuggestionRow(
                                        title: workspace.connectionTitle(suggestion).replacingOccurrences(of: "->", with: " -> "),
                                        counterpartSource: suggestion.counterpartSource,
                                        status: suggestion.status,
                                        rationale: suggestion.rationale,
                                        useWhen: suggestion.useWhen,
                                        caution: suggestion.caution,
                                        sourceExcerpt: suggestion.sourceExcerpt,
                                        exampleUsage: suggestion.exampleUsage,
                                        confidence: suggestion.confidence,
                                        onAccept: suggestion.status == .dismissed ? { workspace.accept(suggestion) } : nil,
                                        onDismiss: suggestion.status == .accepted ? { workspace.dismiss(suggestion) } : nil,
                                        onRestore: { workspace.restore(suggestion) }
                                    )
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)
                    .background(EloqTheme.canvas)
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
                .scrollContentBackground(.hidden)
                .background(EloqTheme.canvas)
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
        .background(EloqTheme.canvas.ignoresSafeArea())
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

private struct AtlasTab: View {
    @ObservedObject var workspace: EloqWorkspace

    private var snapshot: SnapshotReadModel {
        workspace.atlasSnapshot
    }

    private var atlasNodes: [AtlasNodeModel] {
        workspace.words
            .flatMap { word in
                workspace.roles(for: word).map { role in
                    AtlasNodeModel(
                        id: "\(role.kind.rawValue):\(word.id.uuidString)",
                        wordID: word.id,
                        term: word.displayTerm,
                        kind: role.kind,
                        connectionCount: atlasEdges.filter { edge in
                            edge.overusedWordID == word.id || edge.underusedWordID == word.id
                        }.count
                    )
                }
            }
            .sorted { lhs, rhs in
                if lhs.kind == rhs.kind {
                    return lhs.term.localizedCaseInsensitiveCompare(rhs.term) == .orderedAscending
                }
                return lhs.kind.rawValue < rhs.kind.rawValue
            }
    }

    private var atlasEdges: [AtlasEdgeModel] {
        snapshot.connections
            .filter { $0.status == SuggestionStatus.accepted.rawValue }
            .compactMap { connection in
                guard let overusedWordID = UUID(uuidString: connection.overusedWordID),
                      let underusedWordID = UUID(uuidString: connection.underusedWordID) else {
                    return nil
                }

                return AtlasEdgeModel(
                    id: connection.id,
                    overusedWordID: overusedWordID,
                    underusedWordID: underusedWordID,
                    confidence: connection.confidence
                )
            }
    }

    private var overusedNodes: [AtlasNodeModel] {
        atlasNodes.filter { $0.kind == .overused }
    }

    private var underusedNodes: [AtlasNodeModel] {
        atlasNodes.filter { $0.kind == .underused }
    }

    private var orderedOverusedNodes: [AtlasNodeModel] {
        overusedNodes.sorted(by: atlasSort)
    }

    private var orderedUnderusedNodes: [AtlasNodeModel] {
        underusedNodes.sorted(by: atlasSort)
    }

    private var isolatedWordCount: Int {
        let connectedWordIDs = Set(atlasEdges.flatMap { [$0.overusedWordID, $0.underusedWordID] })
        return Set(workspace.words.map(\.id)).subtracting(connectedWordIDs).count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if atlasNodes.isEmpty {
                        UnavailableStateView(
                            systemImage: "point.3.connected.trianglepath.dotted",
                            title: "No Graph Yet",
                            message: "Add words and accept a few links to turn Eloq into a visible atlas."
                        )
                    } else {
                        atlasHeader
                        AtlasBoard(
                            overusedNodes: orderedOverusedNodes,
                            underusedNodes: orderedUnderusedNodes,
                            edges: atlasEdges,
                            selectedWordID: workspace.selectedWordID,
                            onSelect: { wordID in
                                workspace.selectedWordID = wordID
                            }
                        )

                        if let selectedWord = workspace.selectedWord() {
                            AtlasInspector(
                                workspace: workspace,
                                word: selectedWord,
                                snapshot: snapshot,
                                edges: atlasEdges
                            )
                        } else {
                            InlineStatRow(
                                primary: "Select a node",
                                secondary: "Choose any word in the atlas to inspect its role memberships and accepted opposite-side links."
                            )
                            .padding(16)
                            .background(EloqTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(EloqTheme.border, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .navigationTitle("Word Atlas")
            .background(EloqTheme.canvas.ignoresSafeArea())
        }
    }

    private var atlasHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            MetricPanel(
                title: "Accepted Links",
                value: "\(atlasEdges.count)",
                detail: "Only accepted graph edges render here",
                systemImage: "checkmark.circle"
            )

            MetricPanel(
                title: "Overused Nodes",
                value: "\(overusedNodes.count)",
                detail: "Words that currently anchor the left side",
                systemImage: "arrow.turn.down.right"
            )

            MetricPanel(
                title: "Underused Nodes",
                value: "\(underusedNodes.count)",
                detail: "Sharper words available on the right side",
                systemImage: "arrow.turn.up.left"
            )

            MetricPanel(
                title: "Isolated",
                value: "\(isolatedWordCount)",
                detail: "Saved words that still need accepted links",
                systemImage: "circle.dashed"
            )
        }
    }

    private func atlasSort(lhs: AtlasNodeModel, rhs: AtlasNodeModel) -> Bool {
        if lhs.connectionCount != rhs.connectionCount {
            return lhs.connectionCount > rhs.connectionCount
        }

        return lhs.term.localizedCaseInsensitiveCompare(rhs.term) == .orderedAscending
    }
}

private struct AtlasBoard: View {
    let overusedNodes: [AtlasNodeModel]
    let underusedNodes: [AtlasNodeModel]
    let edges: [AtlasEdgeModel]
    let selectedWordID: UUID?
    let onSelect: (UUID) -> Void

    private let rowHeaderWidth: CGFloat = 248
    private let columnWidth: CGFloat = 164
    private let columnHeaderHeight: CGFloat = 88
    private let rowHeight: CGFloat = 72
    private let interItemSpacing: CGFloat = 12
    private let outerPadding: CGFloat = 24

    private var edgeLookup: [String: AtlasEdgeModel] {
        Dictionary(uniqueKeysWithValues: edges.map { (edgeKey($0.overusedWordID, $0.underusedWordID), $0) })
    }

    private var relatedWordIDs: Set<UUID> {
        guard let selectedWordID else {
            return []
        }

        var related = Set([selectedWordID])
        for edge in edges {
            if edge.overusedWordID == selectedWordID {
                related.insert(edge.underusedWordID)
            }
            if edge.underusedWordID == selectedWordID {
                related.insert(edge.overusedWordID)
            }
        }
        return related
    }

    private var boardHeight: CGFloat {
        let rowCount = max(overusedNodes.count, 1)
        return max(
            420,
            (outerPadding * 2) + columnHeaderHeight + (CGFloat(rowCount) * rowHeight) + (CGFloat(rowCount) * interItemSpacing)
        )
    }

    private var boardWidth: CGFloat {
        rowHeaderWidth + (CGFloat(max(underusedNodes.count, 1)) * (columnWidth + interItemSpacing))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(EloqTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(EloqTheme.border, lineWidth: 1)
                )

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: interItemSpacing) {
                    HStack(alignment: .top, spacing: interItemSpacing) {
                        AtlasMatrixLegendCard(width: rowHeaderWidth, height: columnHeaderHeight)

                        ForEach(underusedNodes) { node in
                            AtlasMatrixColumnHeader(
                                node: node,
                                width: columnWidth,
                                height: columnHeaderHeight,
                                isSelected: selectedWordID == node.wordID,
                                isRelated: selectedWordID == nil || relatedWordIDs.contains(node.wordID),
                                onTap: { onSelect(node.wordID) }
                            )
                        }
                    }

                    ForEach(overusedNodes) { overused in
                        HStack(alignment: .center, spacing: interItemSpacing) {
                            AtlasMatrixRowHeader(
                                node: overused,
                                width: rowHeaderWidth,
                                height: rowHeight,
                                isSelected: selectedWordID == overused.wordID,
                                isRelated: selectedWordID == nil || relatedWordIDs.contains(overused.wordID),
                                onTap: { onSelect(overused.wordID) }
                            )

                            ForEach(underusedNodes) { underused in
                                AtlasMatrixCell(
                                    edge: edgeLookup[edgeKey(overused.wordID, underused.wordID)],
                                    width: columnWidth,
                                    height: rowHeight,
                                    isSelectedRow: selectedWordID == overused.wordID,
                                    isSelectedColumn: selectedWordID == underused.wordID,
                                    isRelatedRow: selectedWordID == nil || relatedWordIDs.contains(overused.wordID),
                                    isRelatedColumn: selectedWordID == nil || relatedWordIDs.contains(underused.wordID),
                                    onTap: {
                                        if selectedWordID == overused.wordID {
                                            onSelect(underused.wordID)
                                        } else {
                                            onSelect(overused.wordID)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(outerPadding)
                .frame(minWidth: boardWidth, alignment: .leading)
            }
        }
        .frame(height: boardHeight)
    }

    private func edgeKey(_ overusedWordID: UUID, _ underusedWordID: UUID) -> String {
        "\(overusedWordID.uuidString)|\(underusedWordID.uuidString)"
    }
}

private struct AtlasInspector: View {
    @ObservedObject var workspace: EloqWorkspace
    let word: Word
    let snapshot: SnapshotReadModel
    let edges: [AtlasEdgeModel]

    private var wordsByID: [String: SnapshotWord] {
        Dictionary(uniqueKeysWithValues: snapshot.words.map { ($0.id, $0) })
    }

    private var outgoingTerms: [String] {
        edges
            .filter { $0.overusedWordID == word.id }
            .compactMap { wordsByID[$0.underusedWordID.uuidString]?.displayTerm }
            .sorted()
    }

    private var incomingTerms: [String] {
        edges
            .filter { $0.underusedWordID == word.id }
            .compactMap { wordsByID[$0.overusedWordID.uuidString]?.displayTerm }
            .sorted()
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(word.displayTerm)
                            .font(.title2)
                            .fontWeight(.semibold)

                        FlowRoleBadges(kinds: workspace.roles(for: word).map(\.kind))
                    }

                    Spacer()

                    Button("Open in Library") {
                        workspace.selectedWordID = word.id
                        workspace.currentScreen = .library
                    }
                    .buttonStyle(.borderedProminent)
                }

                if outgoingTerms.isEmpty && incomingTerms.isEmpty {
                    Text("This word exists in Eloq, but it does not have any accepted atlas links yet.")
                        .foregroundStyle(.secondary)
                } else {
                    if !outgoingTerms.isEmpty {
                        AtlasTermSection(
                            title: "Sharper alternatives",
                            subtitle: "Accepted underused words linked from this overused node",
                            terms: outgoingTerms,
                            tone: .accent
                        )
                    }

                    if !incomingTerms.isEmpty {
                        AtlasTermSection(
                            title: "Words this can replace",
                            subtitle: "Accepted overused words that route into this underused node",
                            terms: incomingTerms,
                            tone: .warning
                        )
                    }
                }
            }
        } label: {
            Label("Selection", systemImage: "scope")
        }
    }
}

private struct AtlasMatrixLegendCard: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accepted Atlas")
                .font(.headline)
                .foregroundStyle(EloqTheme.textPrimary)

            Text("Rows are overused defaults. Columns are sharper underused words.")
                .font(.caption)
                .foregroundStyle(EloqTheme.textSecondary)

            HStack(spacing: 8) {
                Circle()
                    .fill(EloqTheme.accent)
                    .frame(width: 8, height: 8)
                Text("accepted connection")
                    .font(.caption2)
                    .foregroundStyle(EloqTheme.textSecondary)
            }
        }
        .padding(16)
        .background(EloqTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(EloqTheme.border, lineWidth: 1)
        )
        .frame(width: width, height: height, alignment: .leading)
    }
}

private struct AtlasMatrixColumnHeader: View {
    let node: AtlasNodeModel
    let width: CGFloat
    let height: CGFloat
    let isSelected: Bool
    let isRelated: Bool
    let onTap: () -> Void

    private var tone: EloqChipTone {
        .accent
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Text(node.term)
                    .font(.headline)
                    .foregroundStyle(isRelated ? EloqTheme.textPrimary : EloqTheme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    Text(node.kind.title)
                        .font(.caption)
                        .foregroundStyle(tone.foregroundColor)

                    Text("\(node.connectionCount)")
                        .font(.caption)
                        .foregroundStyle(EloqTheme.textSecondary)
                        .monospacedDigit()
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? EloqTheme.surface : EloqTheme.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? tone.foregroundColor.opacity(0.55) : EloqTheme.border, lineWidth: isSelected ? 1.5 : 1)
            )
            .overlay(alignment: .top) {
                Capsule()
                    .fill(isSelected ? tone.foregroundColor : Color.clear)
                    .frame(width: width - 28, height: 3)
                    .padding(.top, 10)
            }
            .frame(width: width, height: height, alignment: .topLeading)
        }
        .buttonStyle(.plain)
    }
}

private struct AtlasMatrixRowHeader: View {
    let node: AtlasNodeModel
    let width: CGFloat
    let height: CGFloat
    let isSelected: Bool
    let isRelated: Bool
    let onTap: () -> Void

    private var tone: EloqChipTone {
        .warning
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Text(node.term)
                    .font(.headline)
                    .foregroundStyle(isRelated ? EloqTheme.textPrimary : EloqTheme.textSecondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(node.kind.title)
                        .font(.caption)
                        .foregroundStyle(tone.foregroundColor)

                    Text("\(node.connectionCount) link\(node.connectionCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(EloqTheme.textSecondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? EloqTheme.surface : EloqTheme.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? tone.foregroundColor.opacity(0.55) : EloqTheme.border, lineWidth: isSelected ? 1.5 : 1)
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isSelected ? tone.foregroundColor : tone.foregroundColor.opacity(isRelated ? 0.35 : 0.18))
                    .frame(width: 3, height: 40)
                    .padding(.leading, 10)
            }
            .frame(width: width, height: height, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

private struct AtlasMatrixCell: View {
    let edge: AtlasEdgeModel?
    let width: CGFloat
    let height: CGFloat
    let isSelectedRow: Bool
    let isSelectedColumn: Bool
    let isRelatedRow: Bool
    let isRelatedColumn: Bool
    let onTap: () -> Void

    private var isConnected: Bool {
        edge != nil
    }

    private var isActiveSelection: Bool {
        isSelectedRow || isSelectedColumn
    }

    private var isContextActive: Bool {
        isRelatedRow && isRelatedColumn
    }

    private var backgroundColor: Color {
        if isConnected && isActiveSelection {
            return EloqTheme.accent.opacity(0.18)
        }
        if isConnected && isContextActive {
            return EloqTheme.accent.opacity(0.1)
        }
        if isSelectedRow || isSelectedColumn {
            return EloqTheme.surfaceRaised
        }
        return EloqTheme.canvas.opacity(0.32)
    }

    private var borderColor: Color {
        if isConnected && isActiveSelection {
            return EloqTheme.accent.opacity(0.65)
        }
        if isConnected {
            return EloqTheme.accent.opacity(isContextActive ? 0.3 : 0.16)
        }
        if isSelectedRow || isSelectedColumn {
            return EloqTheme.border.opacity(0.9)
        }
        return EloqTheme.border.opacity(0.5)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )

                if let edge {
                    VStack(spacing: 6) {
                        Circle()
                            .fill(EloqTheme.accent)
                            .frame(width: isActiveSelection ? 12 : 10, height: isActiveSelection ? 12 : 10)

                        Text("\(Int((edge.confidence * 100).rounded()))%")
                            .font(.caption2)
                            .foregroundStyle(isContextActive ? EloqTheme.textPrimary : EloqTheme.textSecondary)
                            .monospacedDigit()
                    }
                } else {
                    Circle()
                        .fill(EloqTheme.border.opacity(0.45))
                        .frame(width: 5, height: 5)
                }
            }
            .frame(width: width, height: height)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    private var tooltip: String {
        if let edge {
            return "Accepted connection • \(Int((edge.confidence * 100).rounded()))% confidence"
        }
        return "No accepted connection"
    }
}

private struct AtlasTermSection: View {
    let title: String
    let subtitle: String
    let terms: [String]
    let tone: EloqChipTone

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(terms, id: \.self) { term in
                        EloqChip(text: term, tone: tone)
                    }
                }
            }
        }
    }
}

private struct AtlasNodeModel: Identifiable {
    let id: String
    let wordID: UUID
    let term: String
    let kind: WordRoleKind
    let connectionCount: Int
}

private struct AtlasEdgeModel: Identifiable {
    let id: String
    let overusedWordID: UUID
    let underusedWordID: UUID
    let confidence: Double
}

private struct WordDetailView: View {
    @ObservedObject var workspace: EloqWorkspace
    let word: Word
    @State private var isShowingDeleteConfirmation = false
    @State private var sourceExcerptDraft = ""
    @State private var exampleUsageDraft = ""

    private var roles: [WordRole] {
        workspace.roles(for: word)
    }

    private var hasReferenceChanges: Bool {
        sourceExcerptDraft.trimmingCharacters(in: .whitespacesAndNewlines) != word.sourceExcerpt ||
            exampleUsageDraft.trimmingCharacters(in: .whitespacesAndNewlines) != word.exampleUsage
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

                            if !word.sourceExcerpt.isEmpty {
                                DetailLine(label: "Source Excerpt", text: word.sourceExcerpt)
                            }

                            if !word.exampleUsage.isEmpty {
                                DetailLine(label: "Example", text: word.exampleUsage)
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

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        ReferenceEditor(
                            title: "Source excerpt",
                            placeholder: "Paste the real sentence or excerpt where this word showed up.",
                            text: $sourceExcerptDraft,
                            minHeight: 96
                        )

                        ReferenceEditor(
                            title: "Example usage",
                            placeholder: "Store one clean example sentence you want to remember.",
                            text: $exampleUsageDraft,
                            minHeight: 84
                        )

                        HStack {
                            Spacer()

                            Button("Save reference details") {
                                workspace.updateWordReferenceDetails(
                                    word,
                                    sourceExcerpt: sourceExcerptDraft,
                                    exampleUsage: exampleUsageDraft
                                )
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!hasReferenceChanges)
                        }
                    }
                } label: {
                    Label("Source & Example", systemImage: "quote.opening")
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
        .toolbar {
            ToolbarItem {
                Button(role: .destructive) {
                    isShowingDeleteConfirmation = true
                } label: {
                    Label("Delete Word", systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            "Delete \"\(word.displayTerm)\"?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Word", role: .destructive) {
                workspace.deleteWord(word)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the word, its roles, linked connections, and any staged AI suggestions that mention it.")
        }
        .task(id: word.id) {
            sourceExcerptDraft = word.sourceExcerpt
            exampleUsageDraft = word.exampleUsage
        }
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

    private var canonicalConnections: [WordConnection] {
        scopedConnections.filter { $0.status != .suggested }
    }

    private var suggestedConnections: [ConnectionSuggestion] {
        workspace.pendingSuggestions(for: focusWord, focusKind: focusKind)
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
                        ForEach(suggestedConnections, id: \.id) { suggestion in
                            Button(suggestion.counterpartTerm) {
                                workspace.accept(suggestion)
                            }
                            .buttonStyle(.borderedProminent)
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

                if suggestedConnections.isEmpty && canonicalConnections.isEmpty {
                    Text("No links for this side yet.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(suggestedConnections, id: \.id) { suggestion in
                            SuggestionRow(
                                title: suggestion.counterpartTerm,
                                counterpartSource: suggestion.counterpartSource,
                                status: suggestion.status,
                                rationale: suggestion.rationale,
                                useWhen: suggestion.useWhen,
                                caution: suggestion.caution,
                                sourceExcerpt: suggestion.sourceExcerpt,
                                exampleUsage: suggestion.exampleUsage,
                                confidence: suggestion.confidence,
                                onAccept: { workspace.accept(suggestion) },
                                onDismiss: { workspace.dismiss(suggestion) },
                                onRestore: nil
                            )

                            if suggestion.id != suggestedConnections.last?.id || !canonicalConnections.isEmpty {
                                Divider()
                            }
                        }

                        ForEach(canonicalConnections, id: \.id) { connection in
                            SuggestionRow(
                                title: workspace.counterpartWord(for: connection, focusKind: focusKind)?.displayTerm ?? "Linked word",
                                counterpartSource: nil,
                                status: connection.status,
                                rationale: connection.rationale,
                                useWhen: connection.useWhen,
                                caution: connection.caution,
                                sourceExcerpt: connection.sourceExcerpt,
                                exampleUsage: connection.exampleUsage,
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

                            if connection.id != canonicalConnections.last?.id {
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
    let counterpartSource: SuggestedCounterpartSource?
    let status: SuggestionStatus
    let rationale: String
    let useWhen: String
    let caution: String
    let sourceExcerpt: String
    let exampleUsage: String
    let confidence: Double
    let onAccept: (() -> Void)?
    let onDismiss: (() -> Void)?
    let onRestore: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline)

                    if let counterpartSource {
                        EloqChip(text: counterpartSource.title, tone: counterpartSource.chipTone)
                    }
                }

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

            if !sourceExcerpt.isEmpty {
                DetailLine(label: "Source Excerpt", text: sourceExcerpt)
            }

            DetailLine(label: "Use When", text: useWhen)

            if !exampleUsage.isEmpty {
                DetailLine(label: "Example", text: exampleUsage)
            }

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
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(EloqTheme.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(EloqTheme.border, lineWidth: 1)
        )
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
        .background(EloqTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(EloqTheme.border, lineWidth: 1)
        )
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
                EloqChip(text: "\(connectionCount)", tone: .neutral)
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
                    EloqChip(
                        text: kind.title,
                        tone: kind == .underused ? .accent : .warning
                    )
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
                .foregroundStyle(EloqTheme.accent)

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
        .background(EloqTheme.surfaceRaised)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(EloqTheme.border), alignment: .bottom)
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

private struct ReferenceEditor: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let minHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(EloqTheme.surfaceRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(EloqTheme.border, lineWidth: 1)
                    )

                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .font(.body)
                    .foregroundStyle(EloqTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: minHeight)

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .foregroundStyle(EloqTheme.textSecondary)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: minHeight)
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
            return EloqTheme.warning
        case .accepted:
            return EloqTheme.accent
        case .dismissed:
            return .secondary
        }
    }
}

private extension SuggestedCounterpartSource {
    var chipTone: EloqChipTone {
        switch self {
        case .library:
            return .neutral
        case .generated:
            return .accent
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
            return EloqTheme.accent
        case .partial:
            return EloqTheme.warning
        case .error:
            return EloqTheme.danger
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
