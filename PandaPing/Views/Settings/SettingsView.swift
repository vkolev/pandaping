//
//  SettingsView.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 23.04.26.
//

import SwiftUI
import UniformTypeIdentifiers

/// Main settings screen. On macOS, presented via the Settings scene (⌘,).
struct SettingsView: View {
    var pluginManager: PluginManager

    @State private var showingFileImporter = false
    @State private var importError: String?

    var body: some View {
        Form {
            // MARK: Plugins
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
        #if os(macOS)
        .frame(minWidth: 450, minHeight: 300)
        #endif
    }

    // MARK: - Subviews

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
