//
//  MemoryEchoWidgetBundle.swift
//  MemoryEchoWidget
//
//  The widget extension entry point.
//

import SwiftUI
import WidgetKit

@main
struct MemoryEchoWidgetBundle: WidgetBundle {
    var body: some Widget {
        TasksWidget()
        IntentionsWidget()
        OverviewWidget()
    }
}
