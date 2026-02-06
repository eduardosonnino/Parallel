//
//  Typography.swift
//  Parallel
//
//  Typography system matching the React app
//

import SwiftUI

// MARK: - Typography

enum Typography {
    // Heading Sizes (matching React: 96px, 80px, 72px, 60px)
    static let title: Font = .system(size: 96, weight: .bold, design: .default)
    static let heading: Font = .system(size: 80, weight: .bold, design: .default)
    static let large: Font = .system(size: 72, weight: .bold, design: .default)
    static let cardTitle: Font = .system(size: 60, weight: .bold, design: .default)

    // Card Content Sizes
    static let cardTitleZoomed: Font = .system(size: 48, weight: .bold, design: .default)
    static let cardSubtitle: Font = .system(size: 24, weight: .medium, design: .default)

    // Body Sizes
    static let bodyLarge: Font = .system(size: 20, weight: .regular, design: .default)
    static let body: Font = .system(size: 16, weight: .regular, design: .default)
    static let bodyMedium: Font = .system(size: 16, weight: .medium, design: .default)

    // Small Sizes
    static let small: Font = .system(size: 14, weight: .medium, design: .default)
    static let caption: Font = .system(size: 12, weight: .semibold, design: .default)
    static let tiny: Font = .system(size: 10, weight: .medium, design: .default)

    // Monospace (for terminal, code)
    static let monospace: Font = .system(size: 20, weight: .regular, design: .monospaced)
    static let monospaceLarge: Font = .system(size: 24, weight: .regular, design: .monospaced)
    static let monospaceSmall: Font = .system(size: 14, weight: .regular, design: .monospaced)
    static let monospaceTiny: Font = .system(size: 13, weight: .regular, design: .monospaced)

    // UI Elements
    static let button: Font = .system(size: 14, weight: .medium, design: .default)
    static let label: Font = .system(size: 13, weight: .regular, design: .default)
    static let tag: Font = .system(size: 12, weight: .medium, design: .default)
}

// MARK: - Line Heights

enum LineHeights {
    static let title: CGFloat = 1.5
    static let heading: CGFloat = 1.5
    static let body: CGFloat = 1.6
    static let tight: CGFloat = 1.2
}

// MARK: - View Extension for Typography

extension View {
    func typography(_ font: Font, color: Color = DesignColors.textPrimary) -> some View {
        self
            .font(font)
            .foregroundColor(color)
    }
}
