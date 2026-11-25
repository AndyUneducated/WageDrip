import SwiftUI
import WageDripCore

/// Three quick steps to a running receipt: region, pay, hours.
struct OnboardingView: View {
    @Environment(SettingsStore.self) private var store
    @State private var draft = Settings.defaults(for: Settings.inferredRegion(from: .current))
    @State private var step = 0

    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case 0:
                    Section {
                        Picker("地区", selection: region) {
                            ForEach(Region.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    } header: {
                        Text("你在哪里上班")
                    } footer: {
                        Text("地区决定默认的节假日日历、货币和参考物价，之后都可以改。")
                    }
                case 1:
                    Section {
                        PayInputs(settings: $draft)
                    } header: {
                        Text("你的窝囊费")
                    } footer: {
                        Text("金额只保存在这台设备上。")
                    }
                default:
                    Section {
                        WorkHoursInputs(settings: $draft)
                    } header: {
                        Text("几点上班 几点下班")
                    } footer: {
                        Text("午休算带薪时间。弹性工时可以稍后在设置里打开。")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("窝囊费")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step > 0 {
                        Button("上一步") { step -= 1 }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(step < 2 ? "下一步" : "开始计费") {
                        if step < 2 {
                            step += 1
                        } else {
                            draft.onboardingDone = true
                            store.settings = draft
                        }
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 420)
        #endif
    }

    private var region: Binding<Region> {
        Binding(get: { draft.region }, set: { draft = draft.switchingRegion(to: $0) })
    }
}
