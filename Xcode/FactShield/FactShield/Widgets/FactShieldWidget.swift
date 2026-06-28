import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents

// MARK: - StopFactCheckIntent (LiveActivityIntent for widget extension)

struct StopFactCheckIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Fact-Check"
    static var description: IntentDescription = "Stop the current fact-checking session"
    
    func perform() async throws -> some IntentResult {
        // The main app handles the actual stopping via App Intent dispatch
        return .result()
    }
}

// MARK: - Verdict Helpers

extension FactCheckAttributes.VerdictType {
    var color: Color {
        switch self {
        case .true: return .green
        case .substantiallyTrue: return .blue
        case .misleading: return .orange
        case .false: return .red
        case .unverifiable: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .true: return "checkmark.circle.fill"
        case .substantiallyTrue: return "checkmark.circle"
        case .misleading: return "exclamationmark.triangle.fill"
        case .false: return "xmark.circle.fill"
        case .unverifiable: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Live Activity Widget

struct FactShieldLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FactCheckAttributes.self) { context in
            // Lock screen / banner presentation
            LockScreenBannerView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded layout (when user long-presses the island)
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                // Compact Leading - Animated waveform (Shazam-like)
                CompactLeadingView(context: context)
            } compactTrailing: {
                // Compact Trailing - Elapsed time
                CompactTrailingView(context: context)
            } minimal: {
                // Minimal - Shield icon (when multiple Live Activities)
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.blue)
            }
            .widgetURL(URL(string: "factshield://live-activity"))
            .keylineTint(.blue)
        }
    }
}

// MARK: - Compact Leading View (pill left side)

private struct CompactLeadingView: View {
    let context: ActivityViewContext<FactCheckAttributes>
    
    var body: some View {
        Image(systemName: "waveform.circle.fill")
            .foregroundStyle(.blue)
            .symbolEffect(.pulse, isActive: context.state.status != .complete)
    }
}

// MARK: - Compact Trailing View (pill right side)

private struct CompactTrailingView: View {
    let context: ActivityViewContext<FactCheckAttributes>
    
    var body: some View {
        Text("\(context.state.elapsedSeconds)s")
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }
}

// MARK: - Expanded Leading View

private struct ExpandedLeadingView: View {
    let context: ActivityViewContext<FactCheckAttributes>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "waveform.circle.fill")
                .font(.title3)
                .foregroundStyle(.orange)
                .symbolEffect(.pulse, isActive: context.state.status != .complete)
            
            Text(context.state.claimText ?? context.state.status.rawValue)
                .font(.caption2)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.primary)
        }
        .padding(.leading, 4)
        .padding(.vertical, 4)
    }
}

// MARK: - Expanded Trailing View

private struct ExpandedTrailingView: View {
    let context: ActivityViewContext<FactCheckAttributes>
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("\(context.state.elapsedSeconds)s")
                .font(.caption2.bold())
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            if context.state.confidenceScore > 0 {
                Text("\(Int(context.state.confidenceScore * 100))%")
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }
        }
        .padding(.trailing, 4)
        .padding(.vertical, 4)
    }
}

// MARK: - Expanded Bottom View

private struct ExpandedBottomView: View {
    let context: ActivityViewContext<FactCheckAttributes>
    
    var body: some View {
        HStack(spacing: 8) {
            // Verdict badge (compact)
            if let verdict = context.state.verdict {
                HStack(spacing: 3) {
                    Image(systemName: verdict.icon)
                        .font(.caption2)
                        .foregroundStyle(verdict.color)
                    Text(verdict.rawValue)
                        .font(.caption2.bold())
                        .foregroundStyle(verdict.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(verdict.color.opacity(0.15), in: Capsule())
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "waveform")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(context.state.status.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            
            Spacer()
            
            // Stop button triggers StopFactCheckIntent
            Button(intent: StopFactCheckIntent()) {
                HStack(spacing: 3) {
                    Image(systemName: "stop.fill")
                        .font(.caption2)
                    Text("Stop")
                        .font(.caption2.bold())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.red, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}

// MARK: - Lock Screen Banner View

private struct LockScreenBannerView: View {
    let context: ActivityViewContext<FactCheckAttributes>
    
    var body: some View {
        HStack(spacing: 12) {
            // Animated waveform icon
            Image(systemName: "waveform.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .symbolEffect(.pulse, isActive: context.state.status != .complete)
            
            // Status text
            VStack(alignment: .leading, spacing: 2) {
                Text("FactShield")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                
                Text(context.state.claimText ?? context.state.status.rawValue)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            
            // Verdict badge or elapsed time
            if let verdict = context.state.verdict {
                VStack(spacing: 2) {
                    Image(systemName: verdict.icon)
                        .font(.title3)
                        .foregroundStyle(verdict.color)
                    Text(verdict.rawValue)
                        .font(.caption2.bold())
                        .foregroundStyle(verdict.color)
                }
            } else {
                VStack(spacing: 2) {
                    Text("\(context.state.elapsedSeconds)s")
                        .font(.title3.bold())
                        .monospacedDigit()
                        .foregroundStyle(.blue)
                    Text(context.attributes.captureMode.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
