//
//  AppSettings.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 24.04.26.
//

import Foundation
import Observation
import SwiftUI

// MARK: - Enums

enum AppAppearance: String, CaseIterable, Identifiable, Codable {
    case system, light, dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum MessageFont: String, CaseIterable, Identifiable {
    case sfMono = "SF Mono"
    case menlo = "Menlo"
    case courier = "Courier New"
    case system = "System"

    var id: String { rawValue }
}

// MARK: - Saved Server

struct SavedServer: Codable, Identifiable {
    var id = UUID()
    var config: IRCServer
    var connectOnStartup: Bool = false
}

// MARK: - App Settings

@Observable
class AppSettings {
    var appearance: AppAppearance = .system
    var messageFontName: String = MessageFont.sfMono.rawValue
    var messageFontSize: Double = 13
    var messageLineSpacing: Double = 2
    var ircLoggingEnabled: Bool = false
    var quitMessage: String = "PandaPing IRC Client for macOS"
    var savedServers: [SavedServer] = []

    private let defaults = UserDefaults.standard

    init() {
        load()
    }

    var messageFont: Font {
        switch MessageFont(rawValue: messageFontName) {
        case .sfMono, .none:
            return .system(size: messageFontSize, design: .monospaced)
        case .menlo:
            return Font.custom("Menlo", size: messageFontSize)
        case .courier:
            return Font.custom("Courier New", size: messageFontSize)
        case .system:
            return .system(size: messageFontSize)
        }
    }

    // MARK: - Server Management

    func addSavedServer(_ config: IRCServer, connectOnStartup: Bool = false) {
        savedServers.append(SavedServer(config: config, connectOnStartup: connectOnStartup))
        save()
    }

    func removeSavedServer(id: UUID) {
        savedServers.removeAll { $0.id == id }
        save()
    }

    func toggleStartup(for id: UUID) {
        guard let index = savedServers.firstIndex(where: { $0.id == id }) else { return }
        savedServers[index].connectOnStartup.toggle()
        save()
    }

    // MARK: - Persistence

    func save() {
        defaults.set(appearance.rawValue, forKey: "pp_appearance")
        defaults.set(messageFontName, forKey: "pp_messageFontName")
        defaults.set(messageFontSize, forKey: "pp_messageFontSize")
        defaults.set(messageLineSpacing, forKey: "pp_messageLineSpacing")
        defaults.set(ircLoggingEnabled, forKey: "pp_ircLoggingEnabled")
        defaults.set(quitMessage, forKey: "pp_quitMessage")

        if let data = try? JSONEncoder().encode(savedServers) {
            defaults.set(data, forKey: "pp_savedServers")
        }
    }

    private func load() {
        if let raw = defaults.string(forKey: "pp_appearance"),
           let value = AppAppearance(rawValue: raw) {
            appearance = value
        }
        if let raw = defaults.string(forKey: "pp_messageFontName") {
            messageFontName = raw
        }
        let fontSize = defaults.double(forKey: "pp_messageFontSize")
        if fontSize > 0 { messageFontSize = fontSize }

        if defaults.object(forKey: "pp_messageLineSpacing") != nil {
            messageLineSpacing = defaults.double(forKey: "pp_messageLineSpacing")
        }

        ircLoggingEnabled = defaults.bool(forKey: "pp_ircLoggingEnabled")

        if let raw = defaults.string(forKey: "pp_quitMessage") {
            quitMessage = raw
        }

        if let data = defaults.data(forKey: "pp_savedServers"),
           let servers = try? JSONDecoder().decode([SavedServer].self, from: data) {
            savedServers = servers
        }
    }
}
