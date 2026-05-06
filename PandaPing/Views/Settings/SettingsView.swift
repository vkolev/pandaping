//
//  SettingsView.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 23.04.26.
//

import SwiftUI
import UniformTypeIdentifiers

/// Main settings screen with tabs for Appearance, Servers, and Plugins.
struct SettingsView: View {
    var pluginManager: PluginManager
    var onConnectServer: ((IRCServer) -> Void)? = nil

    @Environment(AppSettings.self) private var appSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(iOS)
        NavigationStack {
            settingsContent
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        #else
        settingsContent
        #endif
    }

    private var settingsContent: some View {
        TabView {
            AppearanceSettingsView()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }

            ServerSettingsView(onConnect: onConnectServer)
                .tabItem { Label("Servers", systemImage: "server.rack") }

            PluginSettingsView(pluginManager: pluginManager)
                .tabItem { Label("Plugins", systemImage: "puzzlepiece") }

            AdvancedSettingsView()
                .tabItem { Label("Advanced", systemImage: "gearshape.2") }
        }
        .onDisappear { appSettings.save() }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 400)
        #endif
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var settings = appSettings

        Form {
            Section("Theme") {
                Picker("Appearance", selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.appearance) {
                    appSettings.save()
                }
            }

            Section("Language") {
                Picker("Language", selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .onChange(of: settings.language) {
                    appSettings.save()
                }
            }

            Section("Messages") {
                Picker("View Style", selection: $settings.messageViewStyle) {
                    ForEach(MessageViewStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.messageViewStyle) {
                    appSettings.save()
                }

                Picker("Font", selection: $settings.messageFontName) {
                    ForEach(MessageFont.allCases) { font in
                        Text(font.rawValue).tag(font.rawValue)
                    }
                }

                HStack {
                    Text("Font Size")
                    Slider(value: $settings.messageFontSize, in: 9...24, step: 1)
                    Text("\(Int(settings.messageFontSize)) pt")
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }

                HStack {
                    Text("Line Spacing")
                    Slider(value: $settings.messageLineSpacing, in: 0...10, step: 1)
                    Text("\(Int(settings.messageLineSpacing)) pt")
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            }

            Section("Preview") {
                if settings.messageViewStyle == .classic {
                    VStack(alignment: .leading, spacing: settings.messageLineSpacing) {
                        Text("[12:34:56] <alice> Hey everyone!")
                        Text("[12:34:58] <bob> Hello alice, welcome back!")
                        Text("[12:35:01] <alice> Thanks! What did I miss?")
                    }
                    .font(settings.messageFont)
                    .padding(.vertical, 4)
                } else {
                    VStack(spacing: 4) {
                        // Incoming bubble
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("alice")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(NicknameColor.color(for: "alice"))
                                    .padding(.leading, 8)
                                Text("Hey everyone!")
                                    .font(settings.messageFont)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.primary.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            Spacer(minLength: 60)
                        }
                        // Own bubble
                        HStack {
                            Spacer(minLength: 60)
                            Text("Hello alice, welcome back!")
                                .font(settings.messageFont)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.25))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        // Incoming bubble
                        HStack {
                            Text("Thanks! What did I miss?")
                                .font(settings.messageFont)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            Spacer(minLength: 60)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Server Settings

struct ServerSettingsView: View {
    @Environment(AppSettings.self) private var appSettings
    var onConnect: ((IRCServer) -> Void)?

    @State private var showingAddServer = false
    @State private var editingServer: SavedServer?

    var body: some View {
        Form {
            Section {
                if appSettings.savedServers.isEmpty {
                    Text("No saved servers")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appSettings.savedServers) { server in
                        savedServerRow(server)
                    }
                }

                Button {
                    showingAddServer = true
                } label: {
                    Label("Add Server…", systemImage: "plus")
                }
            } header: {
                Text("Saved Servers")
            } footer: {
                Text("Servers marked with ⚡ will connect automatically on launch.")
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingAddServer) {
            AddServerView(confirmTitle: "Save") { server in
                appSettings.addSavedServer(server)
            }
        }
        .sheet(item: $editingServer) { server in
            AddServerView(server: server) { config, autoConnect in
                appSettings.updateSavedServer(id: server.id, config: config, connectOnStartup: autoConnect)
            }
        }
    }

    private func savedServerRow(_ server: SavedServer) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(server.config.hostname)
                        .font(.headline)
                    if server.connectOnStartup {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }
                }
                Text("\(server.config.nickname) • Port \(server.config.port)\(server.config.useSSL ? " • SSL" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !server.config.channels.isEmpty {
                    Text(server.config.channels.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button("Edit") {
                editingServer = server
            }
            .buttonStyle(.bordered)

            Button("Delete") {
                appSettings.removeSavedServer(id: server.id)
            }
            .buttonStyle(.bordered)
            .foregroundStyle(.red)

            if let onConnect {
                Button("Connect") {
                    onConnect(server.config)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Plugin Settings

struct PluginSettingsView: View {
    var pluginManager: PluginManager

    @State private var showingFileImporter = false
    @State private var importError: String?

    var body: some View {
        Form {
            Section {
                if pluginManager.plugins.isEmpty {
                    Text("No plugins found")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(pluginManager.plugins) { plugin in
                        pluginRow(plugin)
                    }
                }

                HStack {
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Add Plugin…", systemImage: "plus")
                    }

                    Spacer()

                    Button {
                        pluginManager.reloadAll()
                    } label: {
                        Label("Reload Plugins", systemImage: "arrow.clockwise")
                    }
                }
            } header: {
                Text("Plugins")
            } footer: {
                Text("Place .lua files in: \(pluginManager.pluginsDirectory.path)")
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [UTType(filenameExtension: "lua") ?? .plainText]
        ) { result in
            switch result {
            case .success(let url):
                let didAccess = url.startAccessingSecurityScopedResource()
                defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                do {
                    try pluginManager.importPlugin(from: url)
                } catch {
                    importError = error.localizedDescription
                }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .alert("Import Failed", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK") { importError = nil }
        } message: {
            if let importError {
                Text(importError)
            }
        }
    }

    private func pluginRow(_ plugin: PluginInfo) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(plugin.name)
                        .font(.headline)
                    if !plugin.version.isEmpty {
                        Text("v\(plugin.version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !plugin.description.isEmpty {
                    Text(plugin.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !plugin.commands.isEmpty {
                    Text(plugin.commands.map { "/\($0)" }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if let error = plugin.error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { plugin.isEnabled },
                set: { _ in pluginManager.togglePlugin(plugin.id) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var settings = appSettings

        Form {
            Section {
                TextField("Quit Message", text: $settings.quitMessage)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: settings.quitMessage) {
                        appSettings.save()
                    }
            } header: {
                Text("Connection")
            } footer: {
                Text("Sent to the server when you disconnect. Other users see this as your quit reason.")
                    .font(.caption)
            }

            Section {
                Toggle("Log IRC Traffic", isOn: $settings.ircLoggingEnabled)
                    .onChange(of: settings.ircLoggingEnabled) {
                        appSettings.save()
                    }
            } header: {
                Text("Debugging")
            } footer: {
                Text("Logs all incoming and outgoing IRC messages to the system console. View logs in Console.app with the \"IRC\" category.")
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
    }
}
