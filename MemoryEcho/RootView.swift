//
//  RootView.swift
//  MemoryEcho
//
//  The app's shell. It pages between the two memory screens — Working Memory
//  (always the launch default, the "instant" memory) and Long Term Memory. The
//  only way across is a horizontal swipe on either screen's header (see
//  MemoryHeader); this view just owns which screen is showing and slides between
//  them. Everything else about each screen stays self-contained.
//

import SwiftUI

struct RootView: View {
    private enum Screen {
        case working, longTerm
    }

    @State private var screen: Screen = .working

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch screen {
            case .working:
                TodayView(onSwitchScreens: switchScreens)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            case .longTerm:
                LongTermView(onSwitchScreens: switchScreens)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        // Deep links live here, at the scene root, since routing them means
        // choosing which screen shows:
        //   memoryecho://add       → Working Memory + capture sheet
        //   memoryecho://longterm  → Long Term Memory (from the widget/header echo)
        //   memoryecho://open      → just launches, wherever we left off
        .onOpenURL(perform: route)
    }

    private func route(_ url: URL) {
        switch url.host {
        case "add":
            withAnimation(.easeInOut(duration: 0.3)) { screen = .working }
            // TodayView owns the capture sheet; hand off through the same bridge
            // the Action Button / Siri adds use so it presents on appear.
            CaptureRouter.shared.requestAdd()
        case "longterm":
            withAnimation(.easeInOut(duration: 0.3)) { screen = .longTerm }
        default:
            break
        }
    }

    private func switchScreens() {
        withAnimation(.easeInOut(duration: 0.3)) {
            screen = screen == .working ? .longTerm : .working
        }
    }
}
