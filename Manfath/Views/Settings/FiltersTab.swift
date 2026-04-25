import SwiftUI

struct FiltersTab: View {
    @Bindable var settings: SettingsStore

    @State private var newBlockItem: String = ""
    @State private var addingCustomGroup: Bool = false
    @State private var newGroupName: String = ""
    @State private var newGroupPorts: String = ""

    // Inline edit state — only one group editable at a time.
    @State private var editingGroupId: UUID? = nil
    @State private var editName: String = ""
    @State private var editPorts: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                visibleRangeCard
                pinnedGroupsCard
                suggestedGroupsCard
                blocklistCard
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.automatic)
    }

    // MARK: - Visible range

    private var visibleRangeCard: some View {
        Card(title: "filters.visibleRange.title") {
            HStack(spacing: 12) {
                rangeField(value: $settings.minPort, placeholder: "1024")
                Text(verbatim: "—")
                    .foregroundStyle(.tertiary)
                rangeField(value: $settings.maxPort, placeholder: "65535")
                Spacer()
            }

            Text("filters.visibleRange.help")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            Divider().padding(.vertical, 4)

            Toggle(isOn: $settings.showOnlyRealServers) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("filters.showOnlyRealServers")
                    Text("filters.showOnlyRealServersHelp")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func rangeField(value: Binding<UInt16>, placeholder: String) -> some View {
        TextField(
            placeholder,
            value: value,
            format: .number.grouping(.never)
        )
        .textFieldStyle(.roundedBorder)
        .multilineTextAlignment(.center)
        .font(.system(.body, design: .monospaced))
        .frame(width: 88)
    }

    // MARK: - Pinned groups (current state)

    private var pinnedGroupsCard: some View {
        Card(title: "filters.pinnedGroups") {
            if settings.portGroups.isEmpty && !addingCustomGroup {
                Text("filters.noGroups")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(settings.portGroups.enumerated()), id: \.element.id) { idx, group in
                        groupRow(group)
                        if idx < settings.portGroups.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            Divider().padding(.vertical, 4)

            if addingCustomGroup {
                customGroupInlineEditor
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        addingCustomGroup = true
                    }
                } label: {
                    Label("filters.addCustomGroup", systemImage: "plus.circle")
                        .font(.callout)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.tint)
            }
        }
    }

    @ViewBuilder
    private func groupRow(_ group: PortGroup) -> some View {
        if editingGroupId == group.id {
            editingRow(for: group)
        } else {
            displayRow(for: group)
        }
    }

    private func displayRow(for group: PortGroup) -> some View {
        let idx = settings.portGroups.firstIndex(where: { $0.id == group.id })
        return HStack(spacing: 10) {
            if let presetId = group.presetId {
                BrandIconView(descriptor: BrandIcons.forPreset(presetId), size: 16)
                    .frame(width: 18)
            } else {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 18)
            }

            Text(group.name)
                .font(.body)
                .lineLimit(1)

            Text(verbatim: formatGroupPorts(group))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            // Reorder — up / down arrows. Disabled at the boundaries.
            Button {
                if let i = idx { moveGroup(from: i, to: i - 1) }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .disabled((idx ?? 0) <= 0)
            .help("filters.moveUp")

            Button {
                if let i = idx { moveGroup(from: i, to: i + 1) }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .disabled((idx ?? 0) >= settings.portGroups.count - 1)
            .help("filters.moveDown")

            Button {
                startEdit(group)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("filters.editGroup")

            Button {
                removeGroup(group)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("filters.removeGroup")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    private func editingRow(for group: PortGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let presetId = group.presetId {
                    BrandIconView(descriptor: BrandIcons.forPreset(presetId), size: 16)
                        .frame(width: 18)
                } else {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 18)
                }

                TextField("filters.groupNamePlaceholder", text: $editName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                TextField("filters.groupPortsPlaceholder", text: $editPorts)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { commitEdit(group) }
            }
            HStack {
                Text("filters.groupPortsHint")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Cancel") { cancelEdit() }
                    .buttonStyle(.borderless)
                Button("filters.save") { commitEdit(group) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }

    private var customGroupInlineEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("filters.groupNamePlaceholder", text: $newGroupName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 180)
                TextField("filters.groupPortsPlaceholder", text: $newGroupPorts)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { commitNewGroup() }
                Spacer(minLength: 0)
            }

            HStack {
                Text("filters.groupPortsHint")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        addingCustomGroup = false
                        newGroupName = ""
                        newGroupPorts = ""
                    }
                }
                .buttonStyle(.borderless)
                Button("filters.addGroup") { commitNewGroup() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Suggested groups (presets)

    private var suggestedGroupsCard: some View {
        Card(
            title: "filters.suggested.title",
            subtitle: "filters.suggested.subtitle"
        ) {
            VStack(spacing: 0) {
                ForEach(Array(PresetGroups.all.enumerated()), id: \.element.id) { idx, preset in
                    presetRow(preset)
                    if idx < PresetGroups.all.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private func presetRow(_ preset: PresetGroups.Preset) -> some View {
        let on = isPresetEnabled(preset.id)
        return HStack(spacing: 10) {
            Toggle(isOn: Binding(
                get: { on },
                set: { _ in togglePreset(preset) }
            )) {
                EmptyView()
            }
            .labelsHidden()
            .toggleStyle(.checkbox)

            Text(preset.name)
                .font(.body)
                .frame(width: 170, alignment: .leading)

            Text(verbatim: formatPresetPorts(preset))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture { togglePreset(preset) }
    }

    // MARK: - Blocklist

    private var blocklistCard: some View {
        Card(title: "filters.blocklist.title", subtitle: "filters.blocklist.subtitle") {
            if settings.processBlocklist.isEmpty {
                Text("No processes hidden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(settings.processBlocklist.enumerated()), id: \.element) { idx, name in
                        HStack {
                            Text(name)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button {
                                removeBlock(name)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 6)
                        if idx < settings.processBlocklist.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            Divider().padding(.vertical, 4)

            HStack {
                TextField("e.g. rapportd", text: $newBlockItem)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { addBlock() }
                Button("filters.addProcess") { addBlock() }
                    .disabled(newBlockItem.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - Helpers

    private func formatGroupPorts(_ group: PortGroup) -> String {
        var parts: [String] = group.ports.map { String($0) }
        for r in group.ranges { parts.append("\(r.min)–\(r.max)") }
        return parts.isEmpty ? "—" : parts.joined(separator: ", ")
    }

    private func formatPresetPorts(_ preset: PresetGroups.Preset) -> String {
        var parts: [String] = preset.ports.map { String($0) }
        for r in preset.ranges { parts.append("\(r.min)–\(r.max)") }
        return parts.joined(separator: ", ")
    }

    private func isPresetEnabled(_ id: String) -> Bool {
        settings.portGroups.contains { $0.presetId == id }
    }

    private func togglePreset(_ preset: PresetGroups.Preset) {
        if let idx = settings.portGroups.firstIndex(where: { $0.presetId == preset.id }) {
            settings.portGroups.remove(at: idx)
        } else {
            settings.portGroups.append(PresetGroups.makeGroup(from: preset))
        }
    }

    private func removeGroup(_ group: PortGroup) {
        if editingGroupId == group.id { cancelEdit() }
        settings.portGroups.removeAll { $0.id == group.id }
    }

    private func moveGroup(from src: Int, to dst: Int) {
        guard dst >= 0, dst < settings.portGroups.count, src != dst else { return }
        let item = settings.portGroups.remove(at: src)
        settings.portGroups.insert(item, at: dst)
    }

    private func startEdit(_ group: PortGroup) {
        editingGroupId = group.id
        editName = group.name
        editPorts = formatGroupPorts(group)
    }

    private func cancelEdit() {
        editingGroupId = nil
        editName = ""
        editPorts = ""
    }

    private func commitEdit(_ group: PortGroup) {
        let trimmed = editName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let idx = settings.portGroups.firstIndex(where: { $0.id == group.id })
        else { return }

        let parsed = Self.parsePortsAndRanges(editPorts)
        var updated = settings.portGroups[idx]
        updated.name = trimmed
        updated.ports = parsed.ports
        updated.ranges = parsed.ranges
        // Preserve id and presetId — editing a preset-derived group
        // doesn't sever its preset link.
        settings.portGroups[idx] = updated
        cancelEdit()
    }

    private func commitNewGroup() {
        let name = newGroupName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let parsed = Self.parsePortsAndRanges(newGroupPorts)
        let group = PortGroup(name: name, ports: parsed.ports, ranges: parsed.ranges)
        settings.portGroups.append(group)
        newGroupName = ""
        newGroupPorts = ""
        withAnimation(.easeInOut(duration: 0.12)) {
            addingCustomGroup = false
        }
    }

    private func addBlock() {
        let trimmed = newBlockItem.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if !settings.processBlocklist.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            settings.processBlocklist.append(trimmed)
        }
        newBlockItem = ""
    }

    private func removeBlock(_ name: String) {
        settings.processBlocklist.removeAll { $0 == name }
    }

    // MARK: - Pure parsing (testable)

    /// Parse "3000, 5173, 8000-8999" into discrete ports + ranges.
    /// Skips garbage tokens silently.
    static func parsePortsAndRanges(_ s: String) -> (ports: [UInt16], ranges: [PortRange]) {
        var ports: [UInt16] = []
        var ranges: [PortRange] = []
        let tokens = s.split(whereSeparator: { ",; \n\t".contains($0) })
        for raw in tokens {
            let token = raw.trimmingCharacters(in: .whitespaces)
            guard !token.isEmpty else { continue }
            if let dash = token.firstIndex(where: { $0 == "-" || $0 == "–" }) {
                let lo = String(token[..<dash])
                let hi = String(token[token.index(after: dash)...])
                if let l = UInt16(lo), let h = UInt16(hi) {
                    ranges.append(PortRange(min: l, max: h))
                }
            } else if let v = UInt16(token) {
                ports.append(v)
            }
        }
        return (ports, ranges)
    }
}

// MARK: - Card chrome

/// Lightweight grouped-content card. Replaces SwiftUI's `Form { Section }`
/// which on macOS forces a heavy inset look. Used by FiltersTab to give
/// each block a clear visual boundary without nesting everything in
/// `.formStyle(.grouped)`.
private struct Card<Content: View>: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }
}
