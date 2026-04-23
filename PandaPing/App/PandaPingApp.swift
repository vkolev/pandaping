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

    var body: some Scene {
        WindowGroup {
            ContentView(serverManager: serverManager)
                .onAppear {
                    serverManager.pluginManager = pluginManager
                    pluginManager.scanAndLoad()
                }
        }

        #if os(macOS)
        Settings {
            SettingsView(pluginManager: pluginManager)
        }
        #endif
    }
}
