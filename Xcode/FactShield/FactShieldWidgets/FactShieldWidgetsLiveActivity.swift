//
//  FactShieldWidgetsLiveActivity.swift
//  FactShieldWidgets
//
//  Live Activity preview helpers for the FactShield widget extension.
//  Note: The actual widget implementation is in FactShield/Widgets/FactShieldWidget.swift
//  Note: The FactCheckAttributes model is in FactShield/Widgets/FactShieldLiveActivity.swift
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Preview Helpers

extension FactCheckAttributes {
    static var preview: FactCheckAttributes {
        FactCheckAttributes(
            captureMode: .microphone,
            sourceApp: nil,
            startedAt: Date()
        )
    }
}

extension FactCheckAttributes.ContentState {
    static var previewListening: FactCheckAttributes.ContentState {
        FactCheckAttributes.ContentState(
            status: .listening,
            verdict: nil,
            confidenceScore: 0,
            sourceCount: 0,
            topSources: [],
            reasoningSummary: nil,
            claimText: nil,
            elapsedSeconds: 12,
            updatedAt: Date()
        )
    }
    
    static var previewVerified: FactCheckAttributes.ContentState {
        FactCheckAttributes.ContentState(
            status: .complete,
            verdict: .true,
            confidenceScore: 0.92,
            sourceCount: 3,
            topSources: ["Reuters", "AP News", "BBC"],
            reasoningSummary: "Multiple credible sources confirm this claim.",
            claimText: "The Earth orbits the Sun",
            elapsedSeconds: 45,
            updatedAt: Date()
        )
    }
    
    static var previewMisleading: FactCheckAttributes.ContentState {
        FactCheckAttributes.ContentState(
            status: .complete,
            verdict: .misleading,
            confidenceScore: 0.78,
            sourceCount: 2,
            topSources: ["Snopes", "PolitiFact"],
            reasoningSummary: "Claim lacks important context.",
            claimText: "Vaccines cause autism",
            elapsedSeconds: 38,
            updatedAt: Date()
        )
    }
}

#Preview("Notification", as: .content, using: FactCheckAttributes.preview) {
    FactShieldLiveActivityWidget()
} contentStates: {
    FactCheckAttributes.ContentState.previewListening
    FactCheckAttributes.ContentState.previewVerified
}
