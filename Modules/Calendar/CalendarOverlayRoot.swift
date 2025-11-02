//
//  CalendarOverlayRoot.swift
//  boringNotch
//

import SwiftUI
import Defaults

struct CalendarOverlayRoot: View {
    @Default(.showCalendar) private var showCalendar
    @ObservedObject private var plexVM = PlexNowPlayingViewModel.shared

    var body: some View {
        Group {
            if shouldShowOverlay {
                EmptyView() // ⬅️ reemplaza luego con tu vista real de calendario
            }
        }
        .animation(.easeInOut(duration: 0.15), value: shouldShowOverlay)
    }

    private var shouldShowOverlay: Bool {
        guard showCalendar else { return false }
        return plexVM.hasActivePlayback == false
    }
}
