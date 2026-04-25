//
//  PandaPingApp.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 21.04.26.
//

import SwiftUI

@main
struct PandaPingApp: App {
    @State private var serverManager = ServerManager()
    @State private var pluginManager = PluginManager()
    @State private var appSettings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView(serverManager: serverManager)
                .environment(appSettings)
                .preferredColorScheme(appSettings.appearance.colorScheme)
                .onAppear {
                    serverManager.pluginManager = pluginManager
                    pluginManager.scanAndLoad()
                    autoConnectSavedServers()
                }
        }

        #if os(macOS)
        Settings {
            SettingsView(
                pluginManager: pluginManager,
                onConnectServer: { server in
                    serverManager.addAndConnect(server)
                }
            )
            .environment(appSettings)
        }
        #endif
    }

    private func autoConnectSavedServers() {
        for server in appSettings.savedServers where server.connectOnStartup {
            serverManager.addAndConnect(server.config)
        }
    }
}
