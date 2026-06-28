//
//  FactShieldWidgetsBundle.swift
//  FactShieldWidgets
//
//  Entry point for the FactShield Widget Extension
//

import WidgetKit
import SwiftUI

@main
struct FactShieldWidgetsBundle: WidgetBundle {
    var body: some Widget {
        FactShieldWidgets()
        FactShieldWidgetsControl()
        FactShieldLiveActivityWidget()
    }
}
