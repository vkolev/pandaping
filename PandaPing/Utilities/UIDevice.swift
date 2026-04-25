//
//  UIDevice.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 24.04.26.
//
import SwiftUI

enum DeviceInfo {
    static var isIPad: Bool {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }
}
