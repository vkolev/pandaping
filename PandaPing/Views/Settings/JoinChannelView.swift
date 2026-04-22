//
//  JoinChannelView.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 22.04.26.
//

import SwiftUI

public struct JoinChannelView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var channel: String
    
    var onJoin: (String) async -> Void
    
    init(channel: String = "", onJoin: @escaping (String) async -> Void) {
        self._channel = State(initialValue: channel)
        self.onJoin = onJoin
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Enter channel name:")
                    TextField("Channel", text: $channel)
                }
            }
            .padding()
            .navigationTitle("Join channel")
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
                    Button("Join") {
                        Task {
                            await joinChannel()
                        }
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        channel.starts(with: "#")
    }
    
    private func joinChannel() async {
        let channelToJoin = channel
        await onJoin(channelToJoin)
        dismiss()
    }
}
