//
//  AddServerView.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 22.04.26.
//

import SwiftUI

/// A form for entering IRC server connection details.
struct AddServerView: View {
    @Environment(\.dismiss) private var dismiss

    var confirmTitle: String = "Connect"
    var onConnect: (IRCServer) -> Void

    @State private var hostname = ""
    @State private var port = "6667"
    @State private var nickname = ""
    @State private var useSSL = false
    @State private var channelsText = ""

    @State private var authMethod: AuthMethod = .none
    @State private var serverPassword = ""
    @State private var saslUsername = ""
    @State private var saslPassword = ""
    @State private var nickservPassword = ""

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
            }
            .padding()
            .navigationTitle("Add Server")
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
                        connect()
                    }
                    .disabled(!isValid)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 350, minHeight: 300)
        #endif
    }

    private var isValid: Bool {
        !hostname.trimmingCharacters(in: .whitespaces).isEmpty &&
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(port) != nil
    }

    private func connect() {
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

        onConnect(server)
        dismiss()
    }
}
