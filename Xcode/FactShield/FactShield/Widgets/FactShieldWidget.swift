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
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "waveform.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .symbolEffect(.pulse, isActive: context.state.status != .complete)
            
            Text(context.state.claimText ?? context.state.status.rawValue)
                .font(.caption)
                .lineLimit(2)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Expanded Trailing View

private struct ExpandedTrailingView: View {
    let context: ActivityViewContext<FactCheckAttributes>
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("\(context.state.elapsedSeconds)s")
                .font(.caption.bold())
                .monospacedDigit()
                .foregroundStyle(.secondary)
            
            if context.state.confidenceScore > 0 {
                Text("\(Int(context.state.confidenceScore * 100))%")
                    .font(.caption2.bold())
                    .foregroundStyle(.blue)
            }
        }
    }
}

// MARK: - Expanded Bottom View

private struct ExpandedBottomView: View {
    let context: ActivityViewContext<FactCheckAttributes>
    
    var body: some View {
        HStack(spacing: 12) {
            // Verdict display with colored icon
            if let verdict = context.state.verdict {
                HStack(spacing: 4) {
                    Image(systemName: verdict.icon)
                        .foregroundStyle(verdict.color)
                    Text(verdict.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(verdict.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(verdict.color.opacity(0.15), in: Capsule())
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(context.state.status.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Stop button triggers StopFactCheckIntent
            Button(intent: StopFactCheckIntent()) {
                HStack(spacing: 4) {
                    Image(systemName: "stop.fill")
                        .font(.caption2)
                    Text("Stop")
                        .font(.caption.bold())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.red, in: Capsule())
            }
            .buttonStyle(.plain)
        }
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
import WidgetKit
import SwiftUI
import ActivityKit

struct FactShieldLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FactCheckAttributes.self) { context in
            // Lock screen / banner presentation
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded layout (when user long-presses the island)
                DynamicIslandExpandedRegion(.leading) {
                    expandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    expandedCenter(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(context: context)
                }
            } compactLeading: {
                compactLeading(context: context)
            } compactTrailing: {
                compactTrailing(context: context)
            } minimal: {
                minimalView(context: context)
            }
        }
    }
    
    // MARK: - Lock Screen View
    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<FactCheckAttributes>) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.blue)
                Text("FactShield")
                    .font(.headline)
                Spacer()
                Text(context.state.status.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let claim = context.state.claimText {
                Text(claim)
                    .font(.subheadline)
                    .lineLimit(2)
            }
            
            if let verdict = context.state.verdict {
                HStack {
                    VerdictBadge(verdict: verdict, confidence: context.state.confidenceScore)
                    Spacer()
                    Text("\(context.state.sourceCount) sources")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.black.opacity(0.8))
    }
    
    // MARK: - Dynamic Island: Compact Leading
    @ViewBuilder
    private func compactLeading(context: ActivityViewContext<FactCheckAttributes>) -> some View {
        Image(systemName: "checkmark.shield.fill")
            .foregroundStyle(statusColor(context.state.status))
            .symbolEffect(.pulse, isActive: context.state.status != .complete)
    }
    
    // MARK: - Dynamic Island: Compact Trailing
    @ViewBuilder
    private func compactTrailing(context: ActivityViewContext<FactCheckAttributes>) -> some View {
        if let verdict = context.state.verdict {
            Text(verdict.rawValue)
                .font(.caption2.bold())
                .foregroundStyle(verdictColor(verdict))
        } else {
            Text(context.state.status.rawValue)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Dynamic Island: Minimal
    @ViewBuilder
    private func minimalView(context: ActivityViewContext<FactCheckAttributes>) -> some View {
        Image(systemName: "checkmark.shield.fill")
            .foregroundStyle(statusColor(context.state.status))
            .symbolEffect(.pulse, isActive: context.state.status != .complete)
    }
    
    // MARK: - Dynamic Island: Expanded Regions
    @ViewBuilder
    private func expandedLeading(context: ActivityViewContext<FactCheckAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("FactShield")
                .font(.caption2.bold())
            Text(context.state.status.rawValue)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    @ViewBuilder
    private func expandedTrailing(context: ActivityViewContext<FactCheckAttributes>) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let verdict = context.state.verdict {
                Text(verdict.rawValue)
                    .font(.caption2.bold())
                    .foregroundStyle(verdictColor(verdict))
                Text("\(Int(context.state.confidenceScore * 100))% confident")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(context.state.elapsedSeconds)s")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func expandedCenter(context: ActivityViewContext<FactCheckAttributes>) -> some View {
        VStack(spacing: 4) {
            if let claim = context.state.claimText {
                Text(claim)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    @ViewBuilder
    private func expandedBottom(context: ActivityViewContext<FactCheckAttributes>) -> some View {
        HStack {
            if let verdict = context.state.verdict {
                VerdictBadge(verdict: verdict, confidence: context.state.confidenceScore)
                
                Spacer()
                
                if let reasoning = context.state.reasoningSummary {
                    Text(reasoning)
                        .font(.caption2)
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Analyzing...")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Helper Views
    private func statusColor(_ status: FactCheckAttributes.VerificationStatus) -> Color {
        switch status {
        case .listening: return .blue
        case .transcribing: return .cyan
        case .extracting: return .orange
        case .searching: return .purple
        case .verifying: return .yellow
        case .complete: return .green
        }
    }
    
    private func verdictColor(_ verdict: FactCheckAttributes.VerdictType) -> Color {
        switch verdict {
        case .true: return .green
        case .substantiallyTrue: return .yellow
        case .misleading: return .orange
        case .false: return .red
        case .unverifiable: return .gray
        }
    }
}

struct VerdictBadge: View {
    let verdict: FactCheckAttributes.VerdictType
    let confidence: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(verdictColor(verdict))
                .frame(width: 8, height: 8)
            Text(verdict.rawValue)
                .font(.caption2.bold())
            Text("\(Int(confidence * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(verdictColor(verdict).opacity(0.15))
        .clipShape(Capsule())
    }
    
    private func verdictColor(_ verdict: FactCheckAttributes.VerdictType) -> Color {
        switch verdict {
        case .true: return .green
        case .substantiallyTrue: return .yellow
        case .misleading: return .orange
        case .false: return .red
        case .unverifiable: return .gray
        }
    }
}
