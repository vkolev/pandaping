//
//  MockIRCTransport.swift
//  PandaPingTests
//
//  Created by Vladimir Kolev on 21.04.26.
//

import Foundation
@testable import PandaPing

/// A mock IRC transport for testing. Allows tests to inspect sent lines
/// and simulate receiving lines from the server.
final class MockIRCTransport: IRCTransport, @unchecked Sendable {
    private(set) var sentLines: [String] = []
    private var continuation: AsyncStream<String>.Continuation?
    var isConnected = false

    let lines: AsyncStream<String>

    init() {
        var cont: AsyncStream<String>.Continuation?
        lines = AsyncStream { continuation in
            cont = continuation
        }
        continuation = cont
    }

    func connect() async throws {
        isConnected = true
    }

    func disconnect() {
        isConnected = false
        continuation?.finish()
    }

    func sendLine(_ line: String) async throws {
        sentLines.append(line)
    }

    /// Simulate the server sending a line to the client.
    func simulateReceive(_ line: String) {
        continuation?.yield(line)
    }

    /// End the line stream.
    func finish() {
        continuation?.finish()
    }
}
