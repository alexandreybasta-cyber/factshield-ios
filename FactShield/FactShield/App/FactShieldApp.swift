import SwiftUI
import AVFAudio

@main
struct FactShieldApp: App {
    @State private var appState = AppState.shared
    @State private var coordinator = FactCheckCoordinator.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    requestPermissions()
                }
        }
    }
    
    private func requestPermissions() {
        // Request microphone permission
        AVAudioApplication.requestRecordPermission { granted in
            Task { @MainActor in
                appState.hasMicrophonePermission = granted
            }
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "checkmark.shield.fill")
                }
                .tag(AppTab.home)
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(AppTab.history)
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(AppTab.settings)
        }
    }
}

// MARK: - History View (placeholder for SwiftData integration)

struct HistoryView: View {
    @State private var coordinator = FactCheckCoordinator.shared
    
    var body: some View {
        NavigationStack {
            if coordinator.allVerdicts.isEmpty {
                ContentUnavailableView(
                    "No Fact-Checks Yet",
                    systemImage: "clock",
                    description: Text("Your fact-check history will appear here after your first session.")
                )
                .navigationTitle("History")
            } else {
                List {
                    ForEach(coordinator.allVerdicts) { verdict in
                        VerdictHistoryRow(verdict: verdict, claim: coordinator.allClaims.first(where: { $0.id == verdict.claimId }))
                    }
                }
                .navigationTitle("History")
            }
        }
    }
}

// MARK: - Verdict History Row

struct VerdictHistoryRow: View {
    let verdict: Verdict
    let claim: Claim?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(verdictColor(verdict.verdictType))
                    .frame(width: 10, height: 10)
                Text(verdict.verdictType.rawValue)
                    .font(.caption.bold())
                    .foregroundStyle(verdictColor(verdict.verdictType))
                Spacer()
                Text(verdict.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            if let claim {
                Text(claim.text)
                    .font(.subheadline)
                    .lineLimit(2)
            }
            
            Text(verdict.reasoning)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
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
