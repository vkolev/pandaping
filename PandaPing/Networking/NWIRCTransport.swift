//
//  NWIRCTransport.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 21.04.26.
//

import Foundation
import Network

/// IRC transport error types.
enum IRCTransportError: Error, LocalizedError {
    case disconnected
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .disconnected:
            return "Disconnected from server"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        }
    }
}

/// IRC transport backed by Network.framework (NWConnection).
/// Handles raw TCP (or TLS) communication, line buffering, and \r\n splitting.
/// Supports reconnection — each `connect()` call creates a fresh NWConnection and stream.
final class NWIRCTransport: IRCTransport, @unchecked Sendable {
    private let host: NWEndpoint.Host
    private let port: NWEndpoint.Port
    private let useSSL: Bool
    private let queue = DispatchQueue(label: "com.pandaping.irc-transport")

    private var connection: NWConnection?
    private var continuation: AsyncStream<String>.Continuation?
    private var connectContinuation: CheckedContinuation<Void, Error>?
    private var buffer = Data()

    private(set) var lines: AsyncStream<String>

    init(server: IRCServer) {
        self.host = NWEndpoint.Host(server.hostname)
        self.port = NWEndpoint.Port(integerLiteral: UInt16(server.port))
        self.useSSL = server.useSSL

        // Placeholder stream — replaced by a fresh one on each connect()
        var cont: AsyncStream<String>.Continuation?
        lines = AsyncStream { continuation in
            cont = continuation
        }
        continuation = cont
    }

    func connect() async throws {
        // Tear down any previous connection
        connection?.cancel()
        continuation?.finish()
        buffer = Data()

        // Create a fresh NWConnection
        let conn: NWConnection
        if useSSL {
            let tlsOptions = NWProtocolTLS.Options()
            let params = NWParameters(tls: tlsOptions)
            conn = NWConnection(host: host, port: port, using: params)
        } else {
            conn = NWConnection(host: host, port: port, using: .tcp)
        }
        self.connection = conn

        // Create a fresh AsyncStream for incoming lines
        var cont: AsyncStream<String>.Continuation?
        lines = AsyncStream { continuation in
            cont = continuation
        }
        continuation = cont

        try await withCheckedThrowingContinuation { (cc: CheckedContinuation<Void, Error>) in
            self.connectContinuation = cc
            conn.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    self.startReceiving()
                    self.connectContinuation?.resume()
                    self.connectContinuation = nil
                case .failed(let error):
                    self.connectContinuation?.resume(throwing: error)
                    self.connectContinuation = nil
                case .cancelled:
                    self.connectContinuation?.resume(throwing: IRCTransportError.disconnected)
                    self.connectContinuation = nil
                default:
                    break
                }
            }
            conn.start(queue: self.queue)
        }
    }

    func disconnect() {
        connection?.cancel()
        continuation?.finish()
    }

    func sendLine(_ line: String) async throws {
        guard let connection else { throw IRCTransportError.disconnected }
        let data = Data((line + "\r\n").utf8)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            })
        }
    }

    // MARK: - Private

    private func startReceiving() {
        guard let connection else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            self.queue.async {
                if let data {
                    self.buffer.append(data)
                    self.processBuffer()
                }

                if isComplete || error != nil {
                    self.continuation?.finish()
                } else {
                    self.startReceiving()
                }
            }
        }
    }

    private func processBuffer() {
        let separator = Data("\r\n".utf8)
        while let range = buffer.range(of: separator) {
            let lineData = buffer[buffer.startIndex..<range.lowerBound]
            if let line = String(data: lineData, encoding: .utf8) {
                continuation?.yield(line)
            }
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
        }
    }
}
