//
//  AddServerView.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 22.04.26.
//

import SwiftUI

/// A form for entering or editing IRC server connection details.
struct AddServerView: View {
    @Environment(\.dismiss) private var dismiss

    var confirmTitle: String = "Connect"
    var onConnect: ((IRCServer) -> Void)?
    var onSave: ((IRCServer, Bool) -> Void)?

    private let editingServer: SavedServer?

    @State private var hostname = ""
    @State private var port = "6667"
    @State private var nickname = ""
    @State private var useSSL = false
    @State private var channelsText = ""
    @State private var connectOnStartup = false

    @State private var authMethod: AuthMethod = .none
    @State private var serverPassword = ""
    @State private var saslUsername = ""
    @State private var saslPassword = ""
    @State private var nickservPassword = ""

    private var isEditing: Bool { editingServer != nil }

    init(confirmTitle: String = "Connect", onConnect: @escaping (IRCServer) -> Void) {
        self.confirmTitle = confirmTitle
        self.onConnect = onConnect
        self.onSave = nil
        self.editingServer = nil
    }

    init(server: SavedServer, onSave: @escaping (IRCServer, Bool) -> Void) {
        self.confirmTitle = "Save"
        self.onConnect = nil
        self.onSave = onSave
        self.editingServer = server
        _hostname = State(initialValue: server.config.hostname)
        _port = State(initialValue: String(server.config.port))
        _nickname = State(initialValue: server.config.nickname)
        _useSSL = State(initialValue: server.config.useSSL)
        _channelsText = State(initialValue: server.config.channels.joined(separator: ", "))
        _connectOnStartup = State(initialValue: server.connectOnStartup)
        _authMethod = State(initialValue: server.config.authMethod)
        _serverPassword = State(initialValue: server.config.serverPassword ?? "")
        _saslUsername = State(initialValue: server.config.saslUsername ?? "")
        _saslPassword = State(initialValue: server.config.saslPassword ?? "")
        _nickservPassword = State(initialValue: server.config.nickservPassword ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("Hostname", text: $hostname)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    #endif
                        .disableAutocorrection(true)

                    TextField("Port", text: $port)
                    #if os(iOS)
                        .keyboardType(.numberPad)
                    #endif

                    Toggle("Use SSL/TLS", isOn: $useSSL)
                        .onChange(of: useSSL) { _, ssl in
                            if ssl && port == "6667" {
                                port = "6697"
                            } else if !ssl && port == "6697" {
                                port = "6667"
                            }
                        }
                }

                Section("Identity") {
                    TextField("Nickname", text: $nickname)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                    #endif
                        .disableAutocorrection(true)
                }

                Section("Authentication") {
                    Picker("Method", selection: $authMethod) {
                        ForEach(AuthMethod.allCases) { method in
                            Text(method.displayName).tag(method)
                        }
                    }

                    SecureField("Server Password", text: $serverPassword)

                    if authMethod == .sasl {
                        TextField("SASL Username", text: $saslUsername)
                        #if os(iOS)
                            .textInputAutocapitalization(.never)
                        #endif
                            .disableAutocorrection(true)
                        SecureField("SASL Password", text: $saslPassword)
                    }

                    if authMethod == .nickserv {
                        SecureField("NickServ Password", text: $nickservPassword)
                    }
                }

                Section {
                    TextField("Channels (comma-separated)", text: $channelsText)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                    #endif
                        .disableAutocorrection(true)
                } header: {
                    Text("Auto-Join Channels")
                } footer: {
                    Text("e.g. #swift, #general")
                        .font(.caption)
                }

                Section {
                    Toggle("Connect on Startup", isOn: $connectOnStartup)
                } footer: {
                    Text("Automatically connect to this server when PandaPing launches.")
                        .font(.caption)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? "Edit Server" : "Add Server")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmTitle) {
                        confirm()
                    }
                    .disabled(!isValid)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 450)
        #endif
    }

    private var isValid: Bool {
        !hostname.trimmingCharacters(in: .whitespaces).isEmpty &&
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(port) != nil
    }

    private func buildServer() -> IRCServer {
        let channels = channelsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var server = IRCServer(
            hostname: hostname.trimmingCharacters(in: .whitespaces),
            nickname: nickname.trimmingCharacters(in: .whitespaces)
        )
        server.port = Int(port) ?? 6667
        server.useSSL = useSSL
        server.channels = channels
        server.authMethod = authMethod
        server.serverPassword = serverPassword.isEmpty ? nil : serverPassword

        if authMethod == .sasl {
            server.saslUsername = saslUsername.isEmpty ? nil : saslUsername
            server.saslPassword = saslPassword.isEmpty ? nil : saslPassword
        }
        if authMethod == .nickserv {
            server.nickservPassword = nickservPassword.isEmpty ? nil : nickservPassword
        }

        return server
    }

    private func confirm() {
        let server = buildServer()
        if let onSave {
            onSave(server, connectOnStartup)
        } else {
            onConnect?(server)
        }
        dismiss()
    }
}
