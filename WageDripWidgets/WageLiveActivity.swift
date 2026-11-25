#if os(iOS)
import ActivityKit
import SwiftUI
import WidgetKit
import WageDripCore

/// Lock Screen card and Dynamic Island. The current amount is the biggest, first thing on it;
/// the "as of" time and the countdown are secondary. No progress bar.
struct WageLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WageActivityAttributes.self) { context in
            LiveCard(state: context.state, isStale: context.isStale)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .activityBackgroundTint(ReceiptTheme.paper)
                .activitySystemActionForegroundColor(ReceiptTheme.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    LiveCard(state: context.state, isStale: context.isStale, onDark: true)
                        .padding(.horizontal, 6)
                }
            } compactLeading: {
                Image(systemName: "drop.fill")
            } compactTrailing: {
                Text(verbatim: context.state.compactText)
                    .font(.system(.footnote, design: .monospaced, weight: .medium))
                    .minimumScaleFactor(0.7)
            } minimal: {
                Image(systemName: "drop.fill")
            }
        }
    }
}

private struct LiveCard: View {
    let state: LiveState
    let isStale: Bool
    /// The Dynamic Island is always black, so it cannot use the paper palette.
    var onDark = false

    private var ink: Color { onDark ? .white : ReceiptTheme.ink }
    private var secondary: Color { onDark ? .white.opacity(0.65) : ReceiptTheme.inkSecondary }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let first = state.lines.first {
                HStack(alignment: .firstTextBaseline) {
                    Text(state.isFinal && first.period == .today ? LocalizedStringKey("今日已结清") : first.period.headlineLabel)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("截至")
                        Text(state.asOf, style: .time)
                    }
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(secondary)

                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: first.text)
                        .font(.system(size: 34, weight: .medium, design: .monospaced))
                        .foregroundStyle(isStale ? secondary : ink)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if let end = state.countdownEnd, end > state.asOf {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("距下班")
                            Text(timerInterval: state.asOf...end, countsDown: true)
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 80, alignment: .trailing)
                        }
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(secondary)
                    }
                }
            }
            if state.lines.count > 1 {
                HStack(spacing: 14) {
                    ForEach(state.lines.dropFirst(), id: \.period) { line in
                        HStack(spacing: 4) {
                            Text(line.period.label).foregroundStyle(secondary)
                            Text(verbatim: line.text).foregroundStyle(ink)
                        }
                        .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .font(.system(.caption, design: .monospaced))
                .minimumScaleFactor(0.7)
            }
        }
    }
}
#endif
