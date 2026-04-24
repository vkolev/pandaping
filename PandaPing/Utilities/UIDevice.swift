//
//  UIDevice.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 24.04.26.
//
import SwiftUI

extension UIDevice {
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}
