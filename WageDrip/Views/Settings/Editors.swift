import SwiftUI
import WageDripCore

struct DayOverridesEditor: View {
    @Binding var overrides: [DayKey: DayOverride]
    @State private var date = Date()

    var body: some View {
        Form {
            Section {
                DatePicker("日期", selection: $date, displayedComponents: .date)
                Button("标记为上班") { overrides[DayKey(date, calendar: .current)] = .work }
                Button("标记为休息") { overrides[DayKey(date, calendar: .current)] = .rest }
            } footer: {
                Text("手动标记优先于节假日日历和周末。比如公司额外放假，或周末要上班。")
            }
            Section("已标记") {
                if overrides.isEmpty {
                    Text("还没有手动标记").foregroundStyle(.secondary)
                }
                ForEach(overrides.keys.sorted(), id: \.self) { day in
                    HStack {
                        Text(verbatim: day.string)
                        Spacer()
                        Text(overrides[day] == .work ? LocalizedStringKey("上班") : LocalizedStringKey("休息")).foregroundStyle(.secondary)
                        Button(role: .destructive) { overrides[day] = nil } label: {
                            Label("删除", systemImage: "trash").labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("手动标记")
    }
}

struct EquivalentsEditor: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Picker("小票上显示", selection: $store.settings.selectedEquivalentID) {
                    Text("不显示").tag(UUID?.none)
                    ForEach(store.settings.equivalents) { item in
                        Text(verbatim: item.displayName).tag(UUID?.some(item.id))
                    }
                }
            }
            Section {
                ForEach($store.settings.equivalents) { $item in
                    ItemRow(name: nameBinding($item.customName, key: item.nameKey), amount: $item.price, currency: $item.currency)
                }
                .onDelete { store.settings.equivalents.remove(atOffsets: $0) }
                Button("添加一项") {
                    store.settings.equivalents.append(Equivalent(customName: String(localized: "新项目"), price: 10,
                                                                 currency: store.settings.displayCurrency))
                }
            } header: {
                Text("物品与单价")
            } footer: {
                Text("默认价格只是粗略参考，按你身边的物价改。左滑可删除。")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("等价换算")
    }
}

struct MilestonesEditor: View {
    @Environment(SettingsStore.self) private var store
    @State private var permissionDenied = false

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Toggle("里程碑提醒", isOn: Binding(
                    get: { store.settings.milestoneAlertsEnabled },
                    set: { on in
                        guard on else {
                            store.settings.milestoneAlertsEnabled = false
                            return
                        }
                        Task {
                            let granted = await MilestoneNotifier.requestPermission()
                            store.settings.milestoneAlertsEnabled = granted
                            permissionDenied = !granted
                        }
                    }
                ))
                if permissionDenied {
                    Text("通知权限未开启，请到系统设置里允许窝囊费发送通知。")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            } footer: {
                Text("赚到某个里程碑的那一刻发一条通知。时刻是提前算好的，不需要窝囊费在后台运行。")
            }
            ForEach(Period.allCases, id: \.self) { period in
                Section {
                    ForEach($store.settings.milestones) { $item in
                        if item.period == period {
                            ItemRow(name: nameBinding($item.customName, key: item.nameKey), amount: $item.amount, currency: $item.currency)
                        }
                    }
                    .onDelete { store.settings.milestones.remove(atOffsets: $0) }
                    Button("添加一项") {
                        store.settings.milestones.append(Milestone(customName: String(localized: "新项目"), amount: 100,
                                                                   currency: store.settings.displayCurrency, period: period))
                    }
                } header: {
                    Text(period.label)
                }
            }
            Section {
                EmptyView()
            } footer: {
                Text("里程碑按小票上显示的金额判定：开了税后显示就按税后算。")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("里程碑")
    }
}

/// Editing a built-in item's name turns it into a custom name.
private func nameBinding(_ custom: Binding<String?>, key: String?) -> Binding<String> {
    Binding(
        get: { localizedName(key: key, custom: custom.wrappedValue) },
        set: { custom.wrappedValue = $0 }
    )
}

private struct ItemRow: View {
    @Binding var name: String
    @Binding var amount: Decimal
    @Binding var currency: String

    var body: some View {
        HStack {
            TextField("名称", text: $name)
            AmountField(label: "金额", value: $amount, showsLabel: false)
                .frame(maxWidth: 110)
            Picker("货币", selection: $currency) {
                ForEach(supportedCurrencies, id: \.self) { Text(verbatim: $0).tag($0) }
            }
            .labelsHidden()
            .fixedSize()
        }
    }
}

/// Hidden page (tap the version row five times) showing how often widgets and the Live Activity
/// actually refresh on this device.
struct DiagnosticsView: View {
    @State private var entries: [Diagnostics.Entry] = []

    var body: some View {
        List {
            Section("概况") {
                LabeledContent("共享容器") { Text(AppGroup.isSharedContainerAvailable ? LocalizedStringKey("可用") : LocalizedStringKey("不可用")) }
                LabeledContent("小组件重载间隔（中位数）") { Text(verbatim: interval("widget")) }
                LabeledContent("实时活动更新间隔（中位数）") { Text(verbatim: interval("live")) }
            }
            Section {
                Button("清空记录", role: .destructive) {
                    Diagnostics.clear()
                    entries = []
                }
            }
            Section("记录") {
                ForEach(entries.reversed()) { entry in
                    HStack {
                        Text(entry.date, format: .dateTime.month().day().hour().minute().second())
                        Spacer()
                        Text(verbatim: entry.event)
                    }
                    .font(.system(.caption, design: .monospaced))
                }
            }
        }
        .navigationTitle("诊断")
        .onAppear { entries = Diagnostics.entries() }
    }

    private func interval(_ prefix: String) -> String {
        guard let seconds = Diagnostics.medianInterval(prefix: prefix) else { return "-" }
        return seconds < 120 ? "\(Int(seconds)) s" : "\(Int(seconds / 60)) min"
    }
}
