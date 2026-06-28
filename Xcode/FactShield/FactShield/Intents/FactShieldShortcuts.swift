import AppIntents

struct FactShieldShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFactCheckIntent(),
            phrases: [
                "Start fact-checking with \(.applicationName)",
                "Fact-check this with \(.applicationName)",
                "Quick fact-check with \(.applicationName)"
            ],
            shortTitle: "Fact-Check",
            systemImageName: "checkmark.shield"
        )
        
        AppShortcut(
            intent: StopFactCheckIntent(),
            phrases: [
                "Stop fact-checking with \(.applicationName)",
                "End fact-check with \(.applicationName)"
            ],
            shortTitle: "Stop Fact-Check",
            systemImageName: "xmark.shield"
        )
    }
}
