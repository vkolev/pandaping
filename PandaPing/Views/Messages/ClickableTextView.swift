//
//  ClickableTextView.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 23.04.26.
//
import SwiftUI

struct ClickableTextView: View {
    let text: String

    var body: some View {
        Text(MessageTextParser.styledAttributedString(for: text))
    }
}
