import SwiftUI
import SwiftData

struct ContentView: View {
    @ObservedObject var workspace: EloqWorkspace

    var body: some View {
        ZStack {
            EloqPalette.canvas.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    header

                    if let banner = workspace.lastBanner {
                        bannerView(banner)
                    }

                    screenContent
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 1180, minHeight: 760)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Eloq")
                    .font(.eloqDisplay(size: 34))
                    .foregroundStyle(EloqPalette.ink)

                Text("A calm lexical companion for the words you want to outgrow and the words you want to reach for.")
                    .font(.eloqBody(size: 14, weight: .medium))
                    .foregroundStyle(EloqPalette.mutedInk)
                    .frame(maxWidth: 560, alignment: .leading)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                ForEach(WorkspaceScreen.allCases) { screen in
                    Button {
                        workspace.currentScreen = screen
                    } label: {
                        Text(screen.title)
                            .font(.eloqBody(size: 13, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(workspace.currentScreen == screen ? EloqPalette.panelStrong : EloqPalette.panel)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(workspace.currentScreen == screen ? EloqPalette.accent.opacity(0.35) : EloqPalette.stroke, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(workspace.currentScreen == screen ? EloqPalette.ink : EloqPalette.mutedInk)
                }
            }

            healthPill
        }
    }

    private var healthPill: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(workspace.health.title)
                .font(.eloqBody(size: 12, weight: .bold))
                .foregroundStyle(EloqPalette.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(workspace.health.level.color.opacity(0.22))
                )
                .overlay(
                    Capsule()
                        .stroke(workspace.health.level.color.opacity(0.38), lineWidth: 1)
                )

            Text(workspace.health.detail)
                .font(.eloqBody(size: 11, weight: .medium))
                .foregroundStyle(EloqPalette.mutedInk)
                .frame(maxWidth: 280, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var screenContent: some View {
        switch workspace.currentScreen {
        case .home:
            HomeScreen(workspace: workspace)
        case .inbox:
            InboxScreen(workspace: workspace)
        case .library:
            LibraryScreen(workspace: workspace)
        }
    }

    private func bannerView(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack")
                .foregroundStyle(EloqPalette.accent)
            Text(message)
                .font(.eloqBody(size: 13, weight: .medium))
                .foregroundStyle(EloqPalette.ink)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(EloqPalette.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(EloqPalette.stroke, lineWidth: 1)
        )
    }
}

private struct HomeScreen: View {
    @ObservedObject var workspace: EloqWorkspace

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(spacing: 18) {
                quickAddCard
                onboardingCard
            }
            .frame(maxWidth: .infinity, alignment: .top)

            VStack(spacing: 18) {
                inboxSummaryCard
                importCard
                openAIKeyCard
                recentWordsCard
            }
            .frame(width: 360)
        }
    }

    private var quickAddCard: some View {
        EloqPanel {
            VStack(alignment: .leading, spacing: 18) {
                sectionEyebrow("Quick Add")

                Text("Add a word in seconds. Save first, let AI map the opposite side immediately after.")
                    .font(.eloqBody(size: 15, weight: .medium))
                    .foregroundStyle(EloqPalette.mutedInk)

                VStack(alignment: .leading, spacing: 12) {
                    TextField("constraint", text: $workspace.quickAddText)
                        .textFieldStyle(.plain)
                        .font(.eloqDisplay(size: 26))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(EloqPalette.panelStrong)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(EloqPalette.stroke, lineWidth: 1)
                        )

                    Picker("Mode", selection: $workspace.quickAddMode) {
                        ForEach(WordRoleKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                HStack(spacing: 12) {
                    Button {
                        workspace.submitQuickAdd()
                    } label: {
                        Label("Save Word", systemImage: "arrow.up.circle.fill")
                    }
                    .buttonStyle(EloqPrimaryButtonStyle())

                    Button {
                        workspace.captureSelectionIntoDraft()
                    } label: {
                        Label("Capture Selection", systemImage: "text.cursor")
                    }
                    .buttonStyle(EloqSecondaryButtonStyle())
                }

                Text(workspace.captureStatusText)
                    .font(.eloqBody(size: 12, weight: .medium))
                    .foregroundStyle(EloqPalette.mutedInk)
            }
        }
    }

    private var onboardingCard: some View {
        EloqPanel {
            VStack(alignment: .leading, spacing: 14) {
                sectionEyebrow("First Run")

                if workspace.totalWordCount == 0 {
                    Text("Start with one overused word and one underused word.")
                        .font(.eloqDisplay(size: 24))
                        .foregroundStyle(EloqPalette.ink)

                    Text("Example: save “thing” as overused, then save “constraint” as underused. Eloq will suggest the connection so the vocabulary graph starts feeling alive right away.")
                        .font(.eloqBody(size: 14, weight: .medium))
                        .foregroundStyle(EloqPalette.mutedInk)
                } else {
                    Text("\(workspace.totalWordCount) words in your graph")
                        .font(.eloqDisplay(size: 24))
                        .foregroundStyle(EloqPalette.ink)

                    Text("The main write surface is this Mac app. Obsidian and the browser extension now read the exported Eloq snapshot.")
                        .font(.eloqBody(size: 14, weight: .medium))
                        .foregroundStyle(EloqPalette.mutedInk)
                }
            }
        }
    }

    private var inboxSummaryCard: some View {
        EloqPanel {
            VStack(alignment: .leading, spacing: 14) {
                sectionEyebrow("Inbox")

                Text("\(workspace.pendingSuggestions.count)")
                    .font(.eloqDisplay(size: 42))
                    .foregroundStyle(EloqPalette.ink)

                Text("pending AI suggestions")
                    .font(.eloqBody(size: 14, weight: .semibold))
                    .foregroundStyle(EloqPalette.mutedInk)

                if workspace.pendingSuggestions.isEmpty {
                    Text("No suggestions to review yet. Add a word or import Audora vocabulary.")
                        .font(.eloqBody(size: 13, weight: .medium))
                        .foregroundStyle(EloqPalette.mutedInk)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(workspace.pendingSuggestions.prefix(3)), id: \.id) { connection in
                            Text(summaryLine(for: connection))
                                .font(.eloqBody(size: 13, weight: .medium))
                                .foregroundStyle(EloqPalette.ink)
                                .lineLimit(1)
                        }
                    }
                }

                Button("Review Inbox") {
                    workspace.currentScreen = .inbox
                }
                .buttonStyle(EloqSecondaryButtonStyle())
            }
        }
    }

    private var importCard: some View {
        EloqPanel {
            VStack(alignment: .leading, spacing: 14) {
                sectionEyebrow("Audora Import")

                Text(workspace.importReport.sourceSummary)
                    .font(.eloqBody(size: 13, weight: .medium))
                    .foregroundStyle(EloqPalette.mutedInk)

                HStack(spacing: 16) {
                    metric("Words", value: workspace.importReport.importedWords)
                    metric("Links", value: workspace.importReport.importedConnections)
                    metric("Skipped", value: workspace.importReport.skippedRules)
                }

                HStack(spacing: 12) {
                    Button {
                        workspace.importAudoraVocabulary()
                    } label: {
                        Label(workspace.isImporting ? "Importing…" : "Import Audora Vocabulary", systemImage: "tray.and.arrow.down.fill")
                    }
                    .buttonStyle(EloqPrimaryButtonStyle())
                    .disabled(workspace.isImporting)

                    Button {
                        workspace.exportNow()
                    } label: {
                        Label("Export Snapshot", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(EloqSecondaryButtonStyle())
                }
            }
        }
    }

    private var recentWordsCard: some View {
        EloqPanel {
            VStack(alignment: .leading, spacing: 14) {
                sectionEyebrow("Recent Words")

                if workspace.filteredWords().isEmpty {
                    Text("Nothing saved yet.")
                        .font(.eloqBody(size: 13, weight: .medium))
                        .foregroundStyle(EloqPalette.mutedInk)
                } else {
                    ForEach(Array(workspace.filteredWords().prefix(5)), id: \.id) { word in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(word.displayTerm)
                                    .font(.eloqBody(size: 14, weight: .semibold))
                                    .foregroundStyle(EloqPalette.ink)
                                Text(workspace.roles(for: word).map { $0.kind.title }.joined(separator: " · "))
                                    .font(.eloqBody(size: 12, weight: .medium))
                                    .foregroundStyle(EloqPalette.mutedInk)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private var openAIKeyCard: some View {
        EloqPanel {
            VStack(alignment: .leading, spacing: 14) {
                sectionEyebrow("OpenAI")

                HStack(alignment: .center) {
                    Text(workspace.hasOpenAIKey ? "AI ready" : "API key required")
                        .font(.eloqBody(size: 14, weight: .semibold))
                        .foregroundStyle(EloqPalette.ink)

                    Spacer()

                    Text(workspace.hasOpenAIKey ? "Stored" : "Missing")
                        .font(.eloqBody(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill((workspace.hasOpenAIKey ? EloqPalette.accent : EloqPalette.warn).opacity(0.18))
                        )
                }

                Text(workspace.openAIKeyStatus)
                    .font(.eloqBody(size: 13, weight: .medium))
                    .foregroundStyle(EloqPalette.mutedInk)

                SecureField(workspace.hasOpenAIKey ? "Replace OpenAI API key" : "Paste OpenAI API key", text: $workspace.apiKeyDraft)
                    .textFieldStyle(.plain)
                    .font(.eloqBody(size: 13, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(EloqPalette.panelStrong)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(EloqPalette.stroke, lineWidth: 1)
                    )

                HStack(spacing: 12) {
                    Button {
                        workspace.saveOpenAIKey()
                    } label: {
                        Label(workspace.hasOpenAIKey ? "Replace Key" : "Save Key", systemImage: "key.fill")
                    }
                    .buttonStyle(EloqPrimaryButtonStyle())

                    if workspace.hasOpenAIKey {
                        Button {
                            workspace.clearOpenAIKey()
                        } label: {
                            Label("Clear Key", systemImage: "trash")
                        }
                        .buttonStyle(EloqSecondaryButtonStyle())
                    }
                }

                Text("Eloq stores this key in your macOS Keychain. Local word storage continues to work even when no key is present.")
                    .font(.eloqBody(size: 11, weight: .medium))
                    .foregroundStyle(EloqPalette.subtleInk)
            }
        }
    }

    private func metric(_ label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.eloqBody(size: 10, weight: .bold))
                .foregroundStyle(EloqPalette.subtleInk)
            Text(String(value))
                .font(.eloqDisplay(size: 24))
                .foregroundStyle(EloqPalette.ink)
        }
    }

    private func sectionEyebrow(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.eloqBody(size: 11, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(EloqPalette.subtleInk)
    }

    private func summaryLine(for connection: WordConnection) -> String {
        workspace.connectionTitle(connection).replacingOccurrences(of: "->", with: " -> ")
    }
}

private struct InboxScreen: View {
    @ObservedObject var workspace: EloqWorkspace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                EloqPanel {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Suggestion Inbox")
                            .font(.eloqDisplay(size: 28))
                            .foregroundStyle(EloqPalette.ink)

                        Text(workspace.isGeneratingSuggestions
                             ? "Generating suggestion rows for your latest addition…"
                             : "Review AI-linked overused and underused pairs. Accept to publish them into the exported Eloq snapshot.")
                            .font(.eloqBody(size: 14, weight: .medium))
                            .foregroundStyle(EloqPalette.mutedInk)
                    }
                }

                if workspace.pendingSuggestions.isEmpty {
                    EloqPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("No suggestions to review")
                                .font(.eloqDisplay(size: 24))
                                .foregroundStyle(EloqPalette.ink)
                            Text("Add a word or import Audora vocabulary and Eloq will queue AI-discovered connections here.")
                                .font(.eloqBody(size: 14, weight: .medium))
                                .foregroundStyle(EloqPalette.mutedInk)
                        }
                    }
                } else {
                    ForEach(workspace.pendingSuggestions, id: \.id) { connection in
                        SuggestionCard(
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

                if !workspace.reviewedSuggestions.isEmpty {
                    EloqPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Reviewed")
                                .font(.eloqDisplay(size: 22))
                                .foregroundStyle(EloqPalette.ink)

                            ForEach(Array(workspace.reviewedSuggestions.prefix(8)), id: \.id) { connection in
                                SuggestionCard(
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
            }
        }
    }
}

private struct LibraryScreen: View {
    @ObservedObject var workspace: EloqWorkspace

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            EloqPanel {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        TextField("Search words", text: $workspace.searchText)
                            .textFieldStyle(.plain)
                            .font(.eloqBody(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(EloqPalette.panelStrong)
                            )

                        Picker("Filter", selection: $workspace.libraryFilter) {
                            ForEach(LibraryFilter.allCases) { filter in
                                Text(filter.title).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 280)
                    }

                    List(selection: Binding(
                        get: { workspace.selectedWordID },
                        set: { newValue in workspace.selectedWordID = newValue }
                    )) {
                        ForEach(workspace.filteredWords(), id: \.id) { word in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(word.displayTerm)
                                    .font(.eloqBody(size: 14, weight: .semibold))
                                Text(workspace.roles(for: word).map { $0.kind.title }.joined(separator: " · "))
                                    .font(.eloqBody(size: 12, weight: .medium))
                                    .foregroundStyle(EloqPalette.mutedInk)
                            }
                            .padding(.vertical, 4)
                            .tag(word.id)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
            }
            .frame(width: 360)

            if let selectedWord = workspace.selectedWord() {
                EloqPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(selectedWord.displayTerm)
                            .font(.eloqDisplay(size: 34))
                            .foregroundStyle(EloqPalette.ink)

                        HStack(spacing: 8) {
                            ForEach(workspace.roles(for: selectedWord), id: \.id) { role in
                                Text(role.kind.title)
                                    .font(.eloqBody(size: 11, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(role.kind == .underused ? EloqPalette.accent.opacity(0.2) : EloqPalette.warn.opacity(0.18)))
                            }
                        }

                        if !selectedWord.notes.isEmpty {
                            Text(selectedWord.notes)
                                .font(.eloqBody(size: 14, weight: .medium))
                                .foregroundStyle(EloqPalette.mutedInk)
                        }

                        ForEach(workspace.roles(for: selectedWord), id: \.id) { role in
                            RoleConnectionBuilderSection(
                                workspace: workspace,
                                word: selectedWord,
                                focusKind: role.kind
                            )
                        }

                        Text("Connections")
                            .font(.eloqDisplay(size: 22))
                            .foregroundStyle(EloqPalette.ink)

                        if workspace.connections(for: selectedWord).isEmpty {
                            Text("No accepted or suggested links yet.")
                                .font(.eloqBody(size: 14, weight: .medium))
                                .foregroundStyle(EloqPalette.mutedInk)
                        } else {
                            ForEach(workspace.connections(for: selectedWord), id: \.id) { connection in
                                SuggestionCard(
                                    title: workspace.connectionTitle(connection).replacingOccurrences(of: "->", with: " -> "),
                                    status: connection.status,
                                    rationale: connection.rationale,
                                    useWhen: connection.useWhen,
                                    caution: connection.caution,
                                    confidence: connection.confidence,
                                    onAccept: connection.status == .suggested || connection.status == .dismissed ? { workspace.accept(connection) } : nil,
                                    onDismiss: connection.status != .dismissed ? { workspace.dismiss(connection) } : nil,
                                    onRestore: connection.status != .suggested ? { workspace.restore(connection) } : nil
                                )
                            }
                        }
                    }
                }
            } else {
                EloqPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select a word")
                            .font(.eloqDisplay(size: 28))
                            .foregroundStyle(EloqPalette.ink)
                        Text("The library stays intentionally spare: choose a word to inspect both sides of its graph and the AI suggestions attached to it.")
                            .font(.eloqBody(size: 14, weight: .medium))
                            .foregroundStyle(EloqPalette.mutedInk)
                    }
                }
            }
        }
    }
}

private struct RoleConnectionBuilderSection: View {
    @ObservedObject var workspace: EloqWorkspace
    let word: Word
    let focusKind: WordRoleKind

    @State private var manualCounterpart = ""

    private var acceptedConnections: [WordConnection] {
        workspace.scopedConnections(for: word, focusKind: focusKind)
            .filter { $0.status == .accepted }
    }

    private var suggestedConnections: [WordConnection] {
        workspace.scopedConnections(for: word, focusKind: focusKind)
            .filter { $0.status == .suggested }
    }

    private var availableWords: [Word] {
        workspace.availableOppositeWords(for: word, focusKind: focusKind)
    }

    private var sectionTitle: String {
        focusKind == .overused ? "Underused Matches" : "Overused Counterweights"
    }

    private var sectionCopy: String {
        focusKind == .overused
            ? "Generate or select sharper underused replacements for this overused word."
            : "Generate or select overused defaults that this stronger word should replace."
    }

    private var addButtonTitle: String {
        focusKind == .overused ? "Add Underused Link" : "Add Overused Link"
    }

    private var textFieldPlaceholder: String {
        focusKind == .overused ? "specific alternative" : "default wording"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(sectionTitle)
                        .font(.eloqDisplay(size: 22))
                        .foregroundStyle(EloqPalette.ink)

                    Text(sectionCopy)
                        .font(.eloqBody(size: 13, weight: .medium))
                        .foregroundStyle(EloqPalette.mutedInk)
                }

                Spacer()

                Button {
                    workspace.requestSuggestions(for: word, focusKind: focusKind)
                } label: {
                    Label(workspace.isGeneratingSuggestions ? "Generating…" : "Generate AI Ideas", systemImage: "sparkles")
                }
                .buttonStyle(EloqSecondaryButtonStyle())
                .disabled(workspace.isGeneratingSuggestions || !workspace.hasOpenAIKey)
            }

            if !acceptedConnections.isEmpty {
                connectionTagRow(
                    title: "Linked",
                    connections: acceptedConnections,
                    fill: EloqPalette.accent.opacity(0.18),
                    stroke: EloqPalette.accent.opacity(0.32),
                    selectOnTap: true,
                    acceptOnTap: false
                )
            }

            if !suggestedConnections.isEmpty {
                connectionTagRow(
                    title: "AI Ideas",
                    connections: suggestedConnections,
                    fill: Color.orange.opacity(0.16),
                    stroke: Color.orange.opacity(0.3),
                    selectOnTap: false,
                    acceptOnTap: true
                )
            } else {
                Text(workspace.hasOpenAIKey
                     ? "No AI ideas yet. Generate suggestions here without leaving the library."
                     : "Save an OpenAI key on Home to generate AI suggestions from the library.")
                    .font(.eloqBody(size: 12, weight: .medium))
                    .foregroundStyle(EloqPalette.subtleInk)
            }

            if !availableWords.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    tagSectionLabel("Connect From Library")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(availableWords, id: \.id) { counterpart in
                                Button {
                                    _ = workspace.connectCounterpart(
                                        focusWord: word,
                                        focusKind: focusKind,
                                        counterpartWord: counterpart
                                    )
                                } label: {
                                    LibraryTag(
                                        text: counterpart.displayTerm,
                                        detail: focusKind.opposite.title,
                                        fill: EloqPalette.panelStrong,
                                        stroke: EloqPalette.stroke
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                tagSectionLabel("Add Custom")

                HStack(spacing: 10) {
                    TextField(textFieldPlaceholder, text: $manualCounterpart)
                        .textFieldStyle(.plain)
                        .font(.eloqBody(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(EloqPalette.panelStrong)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(EloqPalette.stroke, lineWidth: 1)
                        )

                    Button(addButtonTitle) {
                        if workspace.createLibraryConnection(
                            focusWord: word,
                            focusKind: focusKind,
                            counterpartText: manualCounterpart
                        ) {
                            manualCounterpart = ""
                        }
                    }
                    .buttonStyle(EloqPrimaryButtonStyle())
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(EloqPalette.panelStrong.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(EloqPalette.stroke, lineWidth: 1)
        )
    }

    private func connectionTagRow(
        title: String,
        connections: [WordConnection],
        fill: Color,
        stroke: Color,
        selectOnTap: Bool,
        acceptOnTap: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            tagSectionLabel(title)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(connections, id: \.id) { connection in
                        if let counterpart = workspace.counterpartWord(for: connection, focusKind: focusKind) {
                            Button {
                                if acceptOnTap {
                                    workspace.accept(connection)
                                } else if selectOnTap {
                                    workspace.selectWord(counterpart)
                                }
                            } label: {
                                LibraryTag(
                                    text: counterpart.displayTerm,
                                    detail: acceptOnTap ? "\(Int(connection.confidence * 100))% · Accept" : "Connected",
                                    fill: fill,
                                    stroke: stroke
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func tagSectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.eloqBody(size: 10, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(EloqPalette.subtleInk)
    }
}

private struct LibraryTag: View {
    let text: String
    let detail: String
    let fill: Color
    let stroke: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(text)
                .font(.eloqBody(size: 12, weight: .semibold))
                .foregroundStyle(EloqPalette.ink)
                .lineLimit(1)

            Text(detail)
                .font(.eloqBody(size: 10, weight: .medium))
                .foregroundStyle(EloqPalette.mutedInk)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(stroke, lineWidth: 1)
        )
    }
}

private struct SuggestionCard: View {
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.eloqBody(size: 15, weight: .semibold))
                        .foregroundStyle(EloqPalette.ink)
                    Text(rationale)
                        .font(.eloqBody(size: 13, weight: .medium))
                        .foregroundStyle(EloqPalette.mutedInk)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(status.title)
                        .font(.eloqBody(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(status.color.opacity(0.18)))
                    Text("\(Int(confidence * 100))%")
                        .font(.eloqBody(size: 11, weight: .bold))
                        .foregroundStyle(EloqPalette.subtleInk)
                        .monospacedDigit()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                detailLine("Use when", useWhen)
                detailLine("Caution", caution)
            }

            HStack(spacing: 10) {
                if let onAccept {
                    Button("Accept", action: onAccept)
                        .buttonStyle(EloqPrimaryButtonStyle())
                }
                if let onDismiss {
                    Button("Dismiss", action: onDismiss)
                        .buttonStyle(EloqSecondaryButtonStyle())
                }
                if let onRestore {
                    Button("Restore", action: onRestore)
                        .buttonStyle(EloqSecondaryButtonStyle())
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(EloqPalette.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(EloqPalette.stroke, lineWidth: 1)
        )
    }

    private func detailLine(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.eloqBody(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(EloqPalette.subtleInk)
            Text(text)
                .font(.eloqBody(size: 13, weight: .medium))
                .foregroundStyle(EloqPalette.ink)
        }
    }
}

private struct EloqPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(EloqPalette.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(EloqPalette.stroke, lineWidth: 1)
            )
    }
}

private struct EloqPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.eloqBody(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(Color.white)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(EloqPalette.accent.opacity(configuration.isPressed ? 0.8 : 1))
            )
    }
}

private struct EloqSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.eloqBody(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(EloqPalette.ink)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(EloqPalette.panelStrong.opacity(configuration.isPressed ? 0.75 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(EloqPalette.stroke, lineWidth: 1)
            )
    }
}

private enum EloqPalette {
    static let canvas = Color(hex: 0x101316)
    static let panel = Color(hex: 0x171B20)
    static let panelStrong = Color(hex: 0x1D232A)
    static let ink = Color(hex: 0xF5F0E8)
    static let mutedInk = Color(hex: 0xB8B2A8)
    static let subtleInk = Color(hex: 0x857E72)
    static let stroke = Color.white.opacity(0.08)
    static let accent = Color(hex: 0x7FAE8B)
    static let warn = Color(hex: 0xB26A56)
}

private extension HealthLevel {
    var color: Color {
        switch self {
        case .healthy:
            return EloqPalette.accent
        case .partial:
            return Color.orange
        case .error:
            return Color.red.opacity(0.8)
        }
    }
}

private extension SuggestionStatus {
    var color: Color {
        switch self {
        case .suggested:
            return Color.orange
        case .accepted:
            return EloqPalette.accent
        case .dismissed:
            return EloqPalette.warn
        }
    }
}

private extension Font {
    static func eloqDisplay(size: CGFloat) -> Font {
        .custom("New York", size: size, relativeTo: .title)
    }

    static func eloqBody(size: CGFloat, weight: Font.Weight) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

private extension Color {
    init(hex: UInt64) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
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
    ContentView(workspace: EloqWorkspace(modelContext: container.mainContext))
}
