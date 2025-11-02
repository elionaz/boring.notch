//
//  PlexNowPlayingView.swift
//  boringNotch (Plex Module)
//

import SwiftUI

public struct PlexNowPlayingView: View {

    @ObservedObject private var vm = PlexNowPlayingViewModel.shared

    /// (Opcional) inyecta aquí tu vista de calendario si quieres tener el switcher.
    /// Ejemplo de uso: PlexNowPlayingView(calendarView: AnyView(CalendarShelfView()))
    private let calendarView: AnyView?

    // Estado del panel derecho
    private enum RightPane: String, CaseIterable, Identifiable {
        case details = "Album"
        case calendar = "Calendar"
        var id: String { rawValue }
        var label: String { rawValue }
    }

    @State private var rightPane: RightPane = .details

    public init(calendarView: AnyView? = nil) {
        self.calendarView = calendarView
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Panel izquierdo: Now Playing (compacto)
            nowPlayingCompact()
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            // Panel derecho: Details / (opcional) Calendar
            rightColumn()
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Left column

    @ViewBuilder
    private func nowPlayingCompact() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let np = vm.snapshotNowPlaying {
                Text(np.album)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(np.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 8) {
                    switch vm.state {
                    case .idle:
                        Text("Waiting 🎧")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    case .loading:
                        ProgressView().scaleEffect(0.8)
                    case .ready:
                        Label("Ready", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.footnote)
                    case .error:
                        Label("Error", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.footnote)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No playback")
                        .font(.title3.weight(.semibold))
                    Text("Start playing in Plexamp to see details.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 4)
        .minimumScaleFactor(0.9)
    }

    // MARK: - Right column (switcher seguro)

    @ViewBuilder
    private func rightColumn() -> some View {
        VStack(alignment: .leading, spacing: 8) {

            // Muestra el segmented SOLO si hay calendario inyectado
            if calendarView != nil {
                Picker("", selection: $rightPane) {
                    Text("Album").tag(RightPane.details)
                    Text("Calendar").tag(RightPane.calendar)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Group {
                switch rightPane {
                case .details:
                    PlexNowPlayingFactsView()
                        .id("facts")
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                case .calendar:
                    if let calendarView {
                        calendarView
                            .id("calendar")
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    } else {
                        // Si no se inyectó calendario, cae a detalles
                        PlexNowPlayingFactsView().id("facts-fallback")
                    }
                }
            }
            .animation(.easeInOut(duration: 0.18), value: rightPane)
        }
        // Este ancho mínimo evita que “se aplasten” y queden montados
        .frame(minWidth: 360)
    }
}
