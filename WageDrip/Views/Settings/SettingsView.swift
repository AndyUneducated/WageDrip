import SwiftUI
import WageDripCore

struct SettingsView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var versionTaps = 0

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section("薪酬") {
                    PayInputs(settings: $store.settings)
                }

                Section {
                    Toggle("显示税后金额", isOn: $store.settings.showAfterTax)
                    LabeledContent("扣除比例") {
                        Text(verbatim: percentText(store.settings.deductionRate))
                    }
                    Slider(value: $store.settings.deductionRate.asDouble, in: 0...0.6, step: 0.01)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(TaxPreset.allCases, id: \.self) { preset in
                                Button(preset.label) { store.settings.deductionRate = preset.rate }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                        }
                    }
                } header: {
                    Text("税费扣除")
                } footer: {
                    Text("参考值只是中高收入的粗略综合扣除率（税加社保），实际请按自己的工资条调整。")
                }

                Section {
                    WorkHoursInputs(settings: $store.settings)
                    Toggle("非固定工时", isOn: $store.settings.flexEnabled)
                        .disabled(store.settings.payMode == .hourly)
                    if store.settings.payMode == .hourly {
                        Text("时薪按排班时长计算，不适用非固定工时。")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else if store.settings.flexEnabled {
                        LabeledContent("工作时段权重") {
                            Text(verbatim: percentText(store.settings.flexWorkWeight))
                        }
                        Slider(value: $store.settings.flexWorkWeight.asDouble, in: 0...1, step: 0.05)
                        LabeledContent("下班后至午夜权重") {
                            Text(verbatim: percentText(1 - store.settings.flexWorkWeight))
                        }
                    }
                } header: {
                    Text("工时")
                } footer: {
                    Text("非固定工时适合没有固定上下班时间的项目制：上下班之间拿到大部分日薪，剩下的在下班后到午夜之间匀速计入。")
                }

                Section("日历") {
                    Picker("地区", selection: Binding(get: { store.settings.region },
                                                     set: { store.settings = store.settings.switchingRegion(to: $0) })) {
                        ForEach(Region.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    Picker("节假日日历", selection: $store.settings.holidayCalendar) {
                        ForEach(HolidayCalendarKind.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    StartDateRow(startDate: $store.settings.startDate)
                    NavigationLink("手动标记上班或休息") {
                        DayOverridesEditor(overrides: $store.settings.dayOverrides)
                    }
                }

                Section("显示") {
                    ForEach(Period.allCases, id: \.self) { period in
                        Toggle(period.label, isOn: periodBinding(period))
                    }
                    Stepper(value: $store.settings.fractionDigits, in: 0...8) {
                        LabeledContent("小数位数") { Text(verbatim: "\(store.settings.fractionDigits)") }
                    }
                }

                CurrencySection()

                Section("换算与里程碑") {
                    NavigationLink("等价换算") { EquivalentsEditor() }
                    NavigationLink("里程碑") { MilestonesEditor() }
                }

                #if os(iOS)
                Section {
                    Toggle("上班时自动显示", isOn: $store.settings.autoStartLiveActivity)
                } header: {
                    Text("实时活动")
                } footer: {
                    Text("实时活动上的金额只在窝囊费有机会运行时刷新，大约几分钟一次，旁边的“截至”时间表示数字的新旧。要每分钟准确的金额，请用锁屏或桌面小组件。自动显示需要你偶尔打开一次窝囊费来预约之后几个工作日。非固定工时模式下，系统会在 8 小时后结束实时活动。")
                }
                #endif

                Section {
                    LabeledContent("版本") {
                        Text(verbatim: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { versionTaps += 1 }
                    if versionTaps >= 5 {
                        NavigationLink("诊断") { DiagnosticsView() }
                    }
                } footer: {
                    Text("数据只保存在这台设备上。节假日数据来自 holiday-cn，汇率来自欧洲央行（Frankfurter）。")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("设置")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 600)
        #endif
    }

    /// Refuses to switch off the last remaining period.
    private func periodBinding(_ period: Period) -> Binding<Bool> {
        Binding(
            get: { store.settings.periods.contains(period) },
            set: { on in
                var periods = store.settings.periods
                if on { periods.insert(period) } else { periods.remove(period) }
                if !periods.isEmpty { store.settings.periods = periods }
            }
        )
    }
}

private struct StartDateRow: View {
    @Binding var startDate: DayKey?

    var body: some View {
        Toggle("设置入职日期", isOn: Binding(
            get: { startDate != nil },
            set: { startDate = $0 ? DayKey(Date(), calendar: .current) : nil }
        ))
        if let day = startDate {
            DatePicker("入职日期", selection: Binding(
                get: { day.date(in: .current) },
                set: { startDate = DayKey($0, calendar: .current) }
            ), displayedComponents: .date)
        }
    }
}

private struct CurrencySection: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Section {
            CurrencyPicker(label: "显示货币", selection: $store.settings.displayCurrency)
            if store.settings.displayCurrency != store.settings.payCurrency {
                Picker("汇率", selection: $store.settings.rateMode) {
                    Text("每日自动").tag(RateMode.auto)
                    Text("手动指定").tag(RateMode.manual)
                }
                if store.settings.rateMode == .manual {
                    AmountField(label: "手动汇率", value: $store.settings.manualRate)
                }
                LabeledContent("当前汇率") {
                    Text(verbatim: "1 \(store.settings.payCurrency) = \(store.rate.rate) \(store.settings.displayCurrency)")
                }
                if store.rate.source == .fallbackOneToOne {
                    Label("暂无汇率，按 1:1 显示。联网后会自动更新。", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                } else if let asOf = store.rate.asOf {
                    LabeledContent("汇率日期") { Text(verbatim: asOf.string) }
                }
            }
        } header: {
            Text("货币")
        }
        .task(id: store.settings.displayCurrency + store.settings.payCurrency + store.settings.rateMode.rawValue) {
            await store.refreshRate()
        }
    }
}
