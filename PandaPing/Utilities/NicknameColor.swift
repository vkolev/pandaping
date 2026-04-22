//
//  NicknameColor.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 22.04.26.
//

import SwiftUI

/// Provides consistent, deterministic colors for IRC nicknames.
enum NicknameColor {

    /// A palette of distinct colors for nicknames.
    static let palette: [Color] = [
        .red, .orange, .yellow, .green, .mint,
        .teal, .cyan, .blue, .indigo, .purple,
        .pink, .brown
    ]

    /// Returns a stable palette index for a given nickname.
    static func colorIndex(for nickname: String) -> Int {
        let hash = nickname.unicodeScalars.reduce(0) { acc, scalar in
            acc &+ Int(scalar.value) &* 31
        }
        return abs(hash) % palette.count
    }

    /// Returns a stable color for a given nickname.
    static func color(for nickname: String) -> Color {
        palette[colorIndex(for: nickname)]
    }
}
