import AppKit
import OptimusClipCore
import SwiftUI

/// Dedicated tab for browsing transformation history.
///
/// Provides a full-featured history browser with:
/// - Search and filter by transformation name or content
/// - Entries grouped by date (Today, Yesterday, This Week, Older)
/// - Expandable entries showing full input/output
/// - Copy to clipboard actions
/// - Clear history functionality
struct HistoryTabView: View {
    @Environment(\.historyStore) private var historyStore

    @State private var searchText = ""
    @State private var entries: [HistoryRecord] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var expandedEntryId: UUID?
    @State private var showClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search history...", text: self.$searchText)
                    .textFieldStyle(.plain)
                if !self.searchText.isEmpty {
                    Button {
                        self.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding()

            Divider()

            // Content
            if self.isLoading {
                Spacer()
                ProgressView("Loading history...")
                Spacer()
            } else if let loadError {
                Spacer()
                ContentUnavailableView {
                    Label("Error Loading History", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(loadError)
                }
                Spacer()
            } else if self.filteredEntries.isEmpty {
                Spacer()
                if self.entries.isEmpty {
                    ContentUnavailableView {
                        Label("No History Yet", systemImage: "clock")
                    } description: {
                        Text("Trigger a transformation to see it appear here.")
                    }
                } else {
                    ContentUnavailableView {
                        Label("No Matches", systemImage: "magnifyingglass")
                    } description: {
                        Text("No history entries match \"\(self.searchText)\"")
                    }
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(self.groupedEntries, id: \.0) { group, groupEntries in
                            HistoryGroupHeader(title: group)
                            ForEach(groupEntries) { entry in
                                HistoryEntryView(
                                    entry: entry,
                                    isExpanded: self.expandedEntryId == entry.id,
                                    onToggle: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if self.expandedEntryId == entry.id {
                                                self.expandedEntryId = nil
                                            } else {
                                                self.expandedEntryId = entry.id
                                            }
                                        }
                                    }
                                )
                                Divider()
                                    .padding(.leading)
                            }
                        }
                    }
                    .padding(.bottom)
                }
            }

            Divider()

            // Footer
            HStack {
                Text("\(self.filteredEntries.count) of \(self.entries.count) entries")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Refresh") {
                    Task { await self.refreshHistory() }
                }
                .disabled(self.isLoading)
                Button("Clear History...") {
                    self.showClearConfirmation = true
                }
                .disabled(self.entries.isEmpty || self.isLoading)
            }
            .padding()
        }
        .task {
            await self.refreshHistory()
        }
        .confirmationDialog(
            "Clear History?",
            isPresented: self.$showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All History", role: .destructive) {
                Task { await self.clearHistory() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all \(self.entries.count) history entries.")
        }
    }

    // MARK: - Computed Properties

    private var filteredEntries: [HistoryRecord] {
        guard !self.searchText.isEmpty else { return self.entries }
        let query = self.searchText.lowercased()
        return self.entries.filter { entry in
            entry.transformationName.lowercased().contains(query) ||
                entry.inputText.lowercased().contains(query) ||
                entry.outputText.lowercased().contains(query) ||
                (entry.providerName?.lowercased().contains(query) ?? false)
        }
    }

    private var groupedEntries: [(String, [HistoryRecord])] {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        var groups: [String: [HistoryRecord]] = [:]
        let groupOrder = ["Today", "Yesterday", "This Week", "Older"]

        for entry in self.filteredEntries {
            let group = if calendar.isDateInToday(entry.timestamp) {
                "Today"
            } else if calendar.isDateInYesterday(entry.timestamp) {
                "Yesterday"
            } else if entry.timestamp > weekAgo {
                "This Week"
            } else {
                "Older"
            }
            groups[group, default: []].append(entry)
        }

        return groupOrder.compactMap { key in
            guard let entries = groups[key], !entries.isEmpty else { return nil }
            return (key, entries)
        }
    }

    // MARK: - Actions

    private func refreshHistory() async {
        await MainActor.run {
            self.isLoading = true
            self.loadError = nil
        }

        do {
            let records = try await self.historyStore.fetchRecent(limit: nil)
            await MainActor.run {
                self.entries = records
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.loadError = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func clearHistory() async {
        do {
            try await self.historyStore.removeAll()
            await MainActor.run {
                self.entries = []
                self.expandedEntryId = nil
            }
        } catch {
            await MainActor.run {
                self.loadError = "Failed to clear history: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - History Group Header

private struct HistoryGroupHeader: View {
    let title: String

    var body: some View {
        Text(self.title)
            .font(.headline)
            .foregroundColor(.secondary)
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }
}

// MARK: - History Entry View

private struct HistoryEntryView: View {
    let entry: HistoryRecord
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row (always visible)
            Button(action: self.onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(self.entry.transformationName)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            if !self.entry.wasSuccessful {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }

                        HStack(spacing: 8) {
                            if let provider = entry.providerName {
                                Text(provider.capitalized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Text("\(self.entry.inputCharCount) chars")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("\(self.entry.processingTimeMs)ms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Text(self.entry.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(self.isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content
            if self.isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // Input section
                    TextSection(
                        title: "Input",
                        text: self.entry.inputText,
                        onCopy: { self.copyToClipboard(self.entry.inputText) }
                    )

                    // Output section
                    TextSection(
                        title: "Output",
                        text: self.entry.outputText,
                        onCopy: { self.copyToClipboard(self.entry.outputText) }
                    )

                    // Error message if present
                    if let errorMessage = entry.errorMessage {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Error")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Text Section

private struct TextSection: View {
    let title: String
    let text: String
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(self.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: self.onCopy) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            Text(self.text)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(10)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

// MARK: - Preview

#Preview {
    HistoryTabView()
        .frame(width: 650, height: 550)
}
