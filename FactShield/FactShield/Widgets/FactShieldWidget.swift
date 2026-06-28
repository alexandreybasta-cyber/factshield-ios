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
