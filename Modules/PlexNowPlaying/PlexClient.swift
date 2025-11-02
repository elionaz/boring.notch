//
//  PlexClient.swift
//  boringNotch (Plex Module)
//

import Foundation

public struct NowPlaying: Sendable, Equatable {
    public let artist: String
    public let album: String
    public let title: String?
}

public final class PlexClient {

    // MARK: - Inputs
    private let baseURL: URL
    private let token: String
    private let debugLogging: Bool

    // MARK: - Outputs
    /// (NowPlaying?, paused)
    public var onNowPlayingChange: ((NowPlaying?, Bool) -> Void)?

    // MARK: - Polling
    private var timer: Timer?
    private let session = URLSession(configuration: .default)

    public init(baseURL: URL, token: String, debugLogging: Bool = false) {
        self.baseURL = baseURL
        self.token = token
        self.debugLogging = debugLogging
    }

    deinit {
        stopPolling()
    }

    // MARK: - Public API

    public func startPolling(interval: TimeInterval = 5.0) {
        stopPolling()
        if debugLogging {
            print("🛰️ [PlexClient] startPolling interval=\(interval)s  host=\(baseURL.host ?? "")")
        }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.pollOnce() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    public func stopPolling() {
        timer?.invalidate()
        timer = nil
        if debugLogging {
            print("🛰️ [PlexClient] stopPolling()")
        }
    }

    /// Ejecuta un GET único (se usa al bootstrap y para “nudge”).
    @discardableResult
    public func pollOnce() async -> NowPlaying? {
        let url = baseURL.appendingPathComponent("status/sessions")
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "X-Plex-Token", value: token)]
        guard let finalURL = comps.url else { return nil }

        if debugLogging {
            print("🛰️ [PlexClient] GET \(finalURL.absoluteString)")
        }

        do {
            let (data, response) = try await session.data(from: finalURL)
            if let http = response as? HTTPURLResponse, debugLogging {
                print("🛰️ [PlexClient] ← status=\(http.statusCode) bytes=\(data.count)")
            }

            // Intento simple: buscar artista y álbum en el XML
            // (Tu parser real puede ser distinto; conserva tu implementación si ya la tienes)
            if let xmlString = String(data: data, encoding: .utf8), debugLogging {
                print("🛰️ [PlexClient] XML preview:\n\(xmlString.prefix(400))\n——")
            }

            // Parse mínimo (no invasivo): si no hay <Track ...> consideramos “no playing”
            guard
                let xml = String(data: data, encoding: .utf8),
                xml.contains("<Track ")
            else {
                if debugLogging {
                    print("⚠️ [PlexClient] No playing track")
                }
                // 🔴 NOTIFICAR explícitamente que NO hay reproducción
                DispatchQueue.main.async { [weak self] in
                    self?.onNowPlayingChange?(nil, true)
                }
                return nil
            }

            // Extrae campos básicos con expresiones simples (ajusta a tu parser real)
            let artist = extract(attr: "grandparentTitle", from: xml)
            let album  = extract(attr: "parentTitle", from: xml) ?? extract(attr: "album", from: xml)
            let title  = extract(attr: "title", from: xml)

            let paused = extract(attr: "paused", from: xml) == "true"

            if let artist, let album {
                let np = NowPlaying(artist: artist, album: album, title: title)
                DispatchQueue.main.async { [weak self] in
                    self?.onNowPlayingChange?(np, paused)
                }
                if debugLogging {
                    print("🎵 [PlexClient] nowPlaying=\(artist) — \(album)  paused=\(paused)")
                }
                return np
            } else {
                if debugLogging {
                    print("⚠️ [PlexClient] No playing track (faltan campos)")
                }
                DispatchQueue.main.async { [weak self] in
                    self?.onNowPlayingChange?(nil, true)
                }
                return nil
            }

        } catch {
            if debugLogging {
                print("❌ [PlexClient] error \(error)")
            }
            // En error de red, también informamos “no playback” para que la UI pueda mostrar calendario
            DispatchQueue.main.async { [weak self] in
                self?.onNowPlayingChange?(nil, true)
            }
            return nil
        }
    }

    // MARK: - Helpers

    /// Extrae un atributo XML de la primera etiqueta `<Track ...>`
    private func extract(attr: String, from xml: String) -> String? {
        // Busca el primer `Track` y toma su línea/fragmento
        guard let rangeTrack = xml.range(of: "<Track ") else { return nil }
        let tail = xml[rangeTrack.lowerBound...]
        // atributo="valor"
        let pattern = "\(attr)=\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsTail = NSString(string: String(tail))
            let matches = regex.matches(in: String(tail), options: [], range: NSRange(location: 0, length: nsTail.length))
            if let m = matches.first, m.numberOfRanges > 1 {
                return nsTail.substring(with: m.range(at: 1))
            }
        }
        return nil
    }
}
