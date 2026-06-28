import SwiftUI

struct HomeView: View {
    @State private var coordinator = FactCheckCoordinator.shared
    @State private var showSession = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Hero section
                    HeroCard(isRunning: coordinator.isRunning) {
                        if coordinator.isRunning {
                            showSession = true
                        } else {
                            Task {
                                await coordinator.startSession()
                                showSession = true
                            }
                        }
                    }
                    
                    // Active session banner
                    if coordinator.isRunning {
                        ActiveSessionBanner(
                            elapsedSeconds: coordinator.elapsedSeconds,
                            currentClaim: coordinator.currentClaim?.text
                        ) {
                            showSession = true
                        }
                    }
                    
                    // How it works
                    HowItWorksSection()
                    
                    // Recent history
                    RecentHistorySection()
                }
                .padding()
            }
            .navigationTitle("FactShield")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showSession) {
                FactCheckSessionView()
            }
        }
    }
}

// MARK: - Active Session Banner

struct ActiveSessionBanner: View {
    let elapsedSeconds: Int
    let currentClaim: String?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(.green)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .fill(.green.opacity(0.3))
                            .frame(width: 20, height: 20)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Session Active")
                        .font(.subheadline.bold())
                    if let claim = currentClaim {
                        Text(claim)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Listening for claims...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Text("\(elapsedSeconds)s")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.green.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hero Card

struct HeroCard: View {
    let isRunning: Bool
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue.gradient)
                .symbolEffect(.pulse, isActive: isRunning)
            
            Text("Live Fact-Checking")
                .font(.title2.bold())
            
            Text("Press your Action Button while watching or listening to any content. FactShield analyzes claims in real-time and shows verdicts in your Dynamic Island.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            if !isRunning {
                Button(action: onStart) {
                    Label("Start Fact-Checking", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button(action: onStart) {
                    Label("Session Active", systemImage: "waveform")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.green)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - How It Works

struct HowItWorksSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How It Works")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
                StepRow(icon: "hand.tap.fill", title: "Press Action Button", description: "While watching any video or listening to audio")
                StepRow(icon: "waveform", title: "Audio Captured", description: "Microphone + Acoustic Echo Cancellation isolates the audio")
                StepRow(icon: "text.bubble.fill", title: "Claims Extracted", description: "AI identifies verifiable factual statements")
                StepRow(icon: "magnifyingglass", title: "Evidence Searched", description: "Multiple sources cross-checked simultaneously")
                StepRow(icon: "checkmark.seal.fill", title: "Verdict Delivered", description: "Result shown in your Dynamic Island with sources")
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct StepRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Recent History

struct RecentHistorySection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Checks")
                .font(.headline)
            
            // TODO: Load from SwiftData
            Text("No fact-checks yet. Start your first session!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(24)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    HomeView()
}
