import SwiftUI

struct FactCheckSessionView: View {
    @State private var coordinator = FactCheckCoordinator.shared
    @State private var selectedClaim: Claim?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Status indicator
                    StatusCard()
                    
                    // Current claim
                    if let claim = coordinator.currentClaim {
                        ClaimCard(claim: claim)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Current verdict
                    if let verdict = coordinator.currentVerdict {
                        VerdictCard(verdict: verdict)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // All claims list
                    if !coordinator.allClaims.isEmpty {
                        ClaimsListSection(
                            claims: coordinator.allClaims,
                            verdicts: coordinator.allVerdicts,
                            selectedClaim: $selectedClaim
                        )
                    }
                    
                    // Transcript
                    TranscriptCard(transcript: coordinator.sessionTranscript)
                }
                .padding()
                .animation(.easeInOut(duration: 0.3), value: coordinator.currentClaim?.id)
                .animation(.easeInOut(duration: 0.3), value: coordinator.currentVerdict?.id)
            }
            .navigationTitle("Fact-Check Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if coordinator.isRunning {
                        Button("Stop") {
                            Task {
                                await coordinator.stopSession()
                            }
                        }
                        .foregroundStyle(.red)
                    } else {
                        Button("Start") {
                            Task {
                                await coordinator.startSession()
                            }
                        }
                    }
                }
            }
            .sheet(item: $selectedClaim) { claim in
                ClaimDetailView(
                    claim: claim,
                    verdict: coordinator.allVerdicts.first(where: { $0.claimId == claim.id })
                )
            }
        }
    }
}

// MARK: - Status Card

struct StatusCard: View {
    @State private var coordinator = FactCheckCoordinator.shared
    
    var body: some View {
        HStack {
            Image(systemName: coordinator.isRunning ? "waveform.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(coordinator.isRunning ? .green : .gray)
                .symbolEffect(.pulse, isActive: coordinator.isRunning)
            
            VStack(alignment: .leading) {
                Text(coordinator.isRunning ? "Active" : "Inactive")
                    .font(.headline)
                Text("Elapsed: \(formattedTime(coordinator.elapsedSeconds))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if coordinator.isRunning {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(coordinator.allClaims.count)")
                        .font(.title3.bold())
                        .foregroundStyle(.blue)
                    Text("claims")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func formattedTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        }
        return "\(secs)s"
    }
}

// MARK: - Claim Card

struct ClaimCard: View {
    let claim: Claim
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Claim Detected")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                CheckWorthinessBadge(worthiness: claim.checkWorthiness)
            }
            
            Text(claim.text)
                .font(.body)
            
            HStack {
                Label(claim.status.rawValue.capitalized, systemImage: statusIcon(claim.status))
                    .font(.caption2)
                    .foregroundStyle(statusColor(claim.status))
                
                Spacer()
                
                Text(claim.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func statusIcon(_ status: Claim.ClaimStatus) -> String {
        switch status {
        case .pending: return "clock"
        case .extracting: return "text.magnifyingglass"
        case .searching: return "magnifyingglass"
        case .verifying: return "checkmark.circle"
        case .complete: return "checkmark.seal.fill"
        case .failed: return "exclamationmark.triangle"
        }
    }
    
    private func statusColor(_ status: Claim.ClaimStatus) -> Color {
        switch status {
        case .pending: return .gray
        case .extracting: return .orange
        case .searching: return .purple
        case .verifying: return .yellow
        case .complete: return .green
        case .failed: return .red
        }
    }
}

// MARK: - Check Worthiness Badge

struct CheckWorthinessBadge: View {
    let worthiness: Claim.CheckWorthiness
    
    var body: some View {
        Text(worthiness.rawValue.capitalized)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
    
    private var color: Color {
        switch worthiness {
        case .high: return .red
        case .medium: return .orange
        case .low: return .gray
        }
    }
}

// MARK: - Verdict Card

struct VerdictCard: View {
    let verdict: Verdict
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(verdictColor(verdict.verdictType))
                        .frame(width: 10, height: 10)
                    Text(verdict.verdictType.rawValue)
                        .font(.title3.bold())
                        .foregroundStyle(verdictColor(verdict.verdictType))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(verdict.confidenceScore * 100))%")
                        .font(.headline)
                        .foregroundStyle(verdictColor(verdict.verdictType))
                    Text("confidence")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(verdict.reasoning)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if !verdict.sources.isEmpty {
                Divider()
                
                Text("Sources (\(verdict.sources.count))")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                
                ForEach(verdict.sources) { source in
                    SourceRow(source: source)
                }
            }
            
            HStack {
                Spacer()
                Text("Verified in \(verdict.elapsedSeconds)s")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(verdictColor(verdict.verdictType).opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(verdictColor(verdict.verdictType).opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func verdictColor(_ type: Verdict.VerdictType) -> Color {
        switch type {
        case .true: return .green
        case .substantiallyTrue: return .yellow
        case .misleading: return .orange
        case .false: return .red
        case .unverifiable: return .gray
        }
    }
}

// MARK: - Source Row

struct SourceRow: View {
    let source: Source
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(credibilityColor(source.credibilityScore))
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(source.name)
                        .font(.caption.bold())
                    if let bias = source.biasRating {
                        Text("(\(bias))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(source.snippet)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
    
    private func credibilityColor(_ score: Double) -> Color {
        if score >= 0.8 { return .green }
        if score >= 0.5 { return .yellow }
        return .red
    }
}

// MARK: - Claims List Section

struct ClaimsListSection: View {
    let claims: [Claim]
    let verdicts: [Verdict]
    @Binding var selectedClaim: Claim?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Claims (\(claims.count))")
                .font(.headline)
            
            ForEach(claims) { claim in
                Button {
                    selectedClaim = claim
                } label: {
                    ClaimListRow(
                        claim: claim,
                        verdict: verdicts.first(where: { $0.claimId == claim.id })
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Claim List Row

struct ClaimListRow: View {
    let claim: Claim
    let verdict: Verdict?
    
    var body: some View {
        HStack(spacing: 12) {
            if let verdict {
                Circle()
                    .fill(verdictColor(verdict.verdictType))
                    .frame(width: 10, height: 10)
            } else {
                Circle()
                    .fill(.gray.opacity(0.3))
                    .frame(width: 10, height: 10)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(claim.text)
                    .font(.subheadline)
                    .lineLimit(2)
                
                HStack {
                    if let verdict {
                        Text(verdict.verdictType.rawValue)
                            .font(.caption2.bold())
                            .foregroundStyle(verdictColor(verdict.verdictType))
                    }
                    Text(claim.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }
    
    private func verdictColor(_ type: Verdict.VerdictType) -> Color {
        switch type {
        case .true: return .green
        case .substantiallyTrue: return .yellow
        case .misleading: return .orange
        case .false: return .red
        case .unverifiable: return .gray
        }
    }
}

// MARK: - Transcript Card

struct TranscriptCard: View {
    let transcript: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Live Transcript")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if !transcript.isEmpty {
                    Button {
                        withAnimation { isExpanded.toggle() }
                    } label: {
                        Text(isExpanded ? "Collapse" : "Expand")
                            .font(.caption2)
                    }
                }
            }
            
            Text(transcript.isEmpty ? "Waiting for audio..." : transcript)
                .font(.caption)
                .foregroundStyle(transcript.isEmpty ? .secondary : .primary)
                .lineLimit(isExpanded ? nil : 10)
                .animation(.easeInOut, value: isExpanded)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Claim Detail View

struct ClaimDetailView: View {
    let claim: Claim
    let verdict: Verdict?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Claim info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Claim")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(claim.text)
                            .font(.body)
                        
                        HStack {
                            CheckWorthinessBadge(worthiness: claim.checkWorthiness)
                            Spacer()
                            Text(claim.timestamp, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(claim.timestamp, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Verdict
                    if let verdict {
                        VerdictCard(verdict: verdict)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "hourglass")
                                .font(.title)
                                .foregroundStyle(.secondary)
                            Text("Verification in progress...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(32)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("Claim Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
