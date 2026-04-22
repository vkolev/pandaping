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

    var body: some Scene {
        WindowGroup {
            ContentView(serverManager: serverManager)
        }
    }
}
