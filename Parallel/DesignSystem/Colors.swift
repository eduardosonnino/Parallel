//
//  Colors.swift
//  Parallel
//
//  Design system colors
//

import SwiftUI

// MARK: - Design Colors

enum DesignColors {
    // Primary Colors
    static let primary = Color(hex: "#030213")
    static let cardBackground = Color(hex: "#252A2D")
    static let canvasBackground = Color(hex: "#151618")
    static let canvasBackgroundZoomed = Color(hex: "#151618")
    static let accent = Color(hex: "#e9ebef")

    // Border Colors
    static let borderDefault = Color.black.opacity(0.1)
    static let borderWhite = Color.white.opacity(0.2)
    static let borderSelected = Color.white

    // Text Colors (light for dark backgrounds)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textMuted = Color.white.opacity(0.4)
    static let textPlaceholder = Color.white.opacity(0.3)

    // Instance Status Colors
    static let statusRunning = Color(hex: "#007AFF")
    static let statusWaiting = Color(hex: "#FF9500")  // Orange for waiting/blocked
    static let statusReady = Color(hex: "#34C759")
    static let statusError = Color(hex: "#FF3B30")
    static let statusIdle = Color(hex: "#8E8E93")
    static let statusMerged = Color(hex: "#AF52DE")

    // Terminal Colors
    static let terminalBackground = Color(hex: "#1E1E1E")
    static let terminalText = Color(hex: "#D4D4D4")
    static let terminalPrompt = Color(hex: "#569CD6")
    static let terminalSuccess = Color(hex: "#4EC9B0")
    static let terminalError = Color(hex: "#F14C4C")

    // Shadow Colors
    static let shadowDefault = Color.black.opacity(0.08)
    static let shadowDragging = Color.black.opacity(0.064)
    static let shadowSelected = Color.black.opacity(0.072)
    static let shadowSidebar = Color.black.opacity(0.07)
    static let shadowGlass = Color.black.opacity(0.1)
}

// MARK: - Color Extension for Hex Initialization

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (no alpha)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - NSColor Extension

#if os(macOS)
extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
#endif
