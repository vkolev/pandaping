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
        let attributedString = try! parseText(text)
        Text(attributedString)
    }
    
    private func parseText(_ text: String) throws -> AttributedString {
        var attributedString = try AttributedString(markdown: text)
        
        // Detect URLs
        let urlDetector = try NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        )
        let matches = urlDetector.matches(in: text, range: NSRange(location: 0, length: text.utf16.count))
        
        for match in matches {
            if let stringRange = Range(match.range, in: text) {
                let urlString = String(text[stringRange])
                if let url = URL(string: urlString) {
                    let startIndex = attributedString.index(attributedString.startIndex, offsetByUnicodeScalars: stringRange.lowerBound.utf16Offset(in: text))
                    let endIndex = attributedString.index(attributedString.startIndex, offsetByUnicodeScalars: stringRange.upperBound.utf16Offset(in: text))
                    let attrRange = startIndex..<endIndex
                    attributedString[attrRange].link = url
                }
            }
        }
        return attributedString
    }
}
