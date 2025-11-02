//
//  CalendarOverlayGate.swift
//  boringNotch
//
//  Created by Jonathan Contreras on 02/11/25.
//
import SwiftUI
import Defaults

struct CalendarOverlayGate<Content: View>: View {
    @Default(.showCalendar) private var showCalendar
    @ObservedObject private var plexVM = PlexNowPlayingViewModel.shared
    let content: () -> Content   // tu calendario

    var body: some View {
        Group {
            if showCalendar && !plexVM.hasActivePlayback {
                content()
            }
        }
        .animation(.easeInOut(duration: 0.15), value: showCalendar)
        .animation(.easeInOut(duration: 0.15), value: plexVM.hasActivePlayback)
    }
}

