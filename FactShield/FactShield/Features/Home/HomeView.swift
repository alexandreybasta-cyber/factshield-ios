import SwiftUI

struct HomeView: View {
    @State private var showSession = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Hero section
                    HeroCard {
                        showSession = true
                    }
                    
                    // How it works
                    HowItWorksSection()
                    
                    // Recent history
                    RecentHistorySection()
                }
                .padding()
            }
            .navigationTitle("FactShield")
            .sheet(isPresented: $showSession) {
                Text("Fact-Check Session")
                    .font(.title)
            }
        }
    }
}

struct HeroCard: View {
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue.gradient)
            
            Text("Live Fact-Checking")
                .font(.title2.bold())
            
            Text("Press your Action Button while watching or listening to any content. FactShield analyzes claims in real-time and shows verdicts in your Dynamic Island.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onStart) {
                Label("Start Fact-Checking", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

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
