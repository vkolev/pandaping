//
//  IRCTransport.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 21.04.26.
//

import Foundation

/// Abstraction for a raw IRC socket connection.
/// Enables mocking for tests and swapping transport implementations.
protocol IRCTransport: AnyObject, Sendable {
    /// Establish the TCP connection to the server.
    func connect() async throws

    /// Close the connection.
    func disconnect()

    /// Send a raw IRC line (without the trailing \r\n — the transport appends it).
    func sendLine(_ line: String) async throws

    /// An async stream of raw IRC lines received from the server (already split on \r\n).
    var lines: AsyncStream<String> { get }
}
