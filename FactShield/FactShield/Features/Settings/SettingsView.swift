import SwiftUI

struct SettingsView: View {
    @AppStorage("qwen_api_key") private var qwenAPIKey: String = ""
    @AppStorage("tavily_api_key") private var tavilyAPIKey: String = ""
    @AppStorage("google_factcheck_api_key") private var googleFactCheckAPIKey: String = ""
    @AppStorage("preferred_capture_mode") private var preferredCaptureMode: String = "microphone"
    @AppStorage("extraction_interval") private var extractionInterval: Double = 15.0
    @AppStorage("auto_start_live_activity") private var autoStartLiveActivity: Bool = true
    @AppStorage("on_device_recognition") private var preferOnDeviceRecognition: Bool = true
    
    @State private var showingAPIKeyInfo = false
    
    var body: some View {
        Form {
            // MARK: - API Configuration
            Section {
                SecureInputField(title: "Qwen API Key", text: $qwenAPIKey, placeholder: "sk-...")
                SecureInputField(title: "Tavily API Key", text: $tavilyAPIKey, placeholder: "tvly-...")
                SecureInputField(title: "Google Fact Check Key", text: $googleFactCheckAPIKey, placeholder: "AIza...")
            } header: {
                Text("API Keys")
            } footer: {
                Button {
                    showingAPIKeyInfo = true
                } label: {
                    Label("How to get API keys", systemImage: "questionmark.circle")
                        .font(.caption)
                }
            }
            
            // MARK: - Audio Settings
            Section {
                Picker("Capture Mode", selection: $preferredCaptureMode) {
                    Text("Microphone (AEC)").tag("microphone")
                    Text("System Audio (ReplayKit)").tag("replaykit")
                }
                
                Toggle("Prefer On-Device Recognition", isOn: $preferOnDeviceRecognition)
            } header: {
                Text("Audio & Speech")
            } footer: {
                Text("Microphone mode uses Acoustic Echo Cancellation to isolate audio from other apps. System Audio mode captures directly via screen recording.")
            }
            
            // MARK: - Pipeline Settings
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Extraction Interval")
                        Spacer()
                        Text("\(Int(extractionInterval))s")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $extractionInterval, in: 5...60, step: 5)
                }
                
                Toggle("Auto-Start Live Activity", isOn: $autoStartLiveActivity)
            } header: {
                Text("Fact-Check Pipeline")
            } footer: {
                Text("How often to extract claims from the transcript. Lower = more responsive but higher API usage.")
            }
            
            // MARK: - Status
            Section {
                StatusRow(title: "API Key", isConfigured: !qwenAPIKey.isEmpty)
                StatusRow(title: "Microphone", isConfigured: true)
                StatusRow(title: "Speech Recognition", isConfigured: true)
                StatusRow(title: "Live Activities", isConfigured: true)
            } header: {
                Text("Status")
            }
            
            // MARK: - About
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text("Phase 1")
                        .foregroundStyle(.secondary)
                }
                
                Link(destination: URL(string: "https://github.com/factshield")!) {
                    HStack {
                        Text("GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("About")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("API Key Setup", isPresented: $showingAPIKeyInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Qwen API: Get from dashscope.aliyuncs.com\n\nTavily API: Get from tavily.com\n\nGoogle Fact Check: Get from Google Cloud Console")
        }
    }
}

// MARK: - Secure Input Field

struct SecureInputField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    @State private var isRevealed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                if isRevealed {
                    TextField(placeholder, text: $text)
                        .font(.system(.body, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField(placeholder, text: $text)
                        .font(.system(.body, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Status Row

struct StatusRow: View {
    let title: String
    let isConfigured: Bool
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: isConfigured ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isConfigured ? .green : .red)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
