//
//  Shadows.swift
//  Parallel
//
//  Shadow styles matching the React app exactly
//

import SwiftUI

// MARK: - Shadow Style

struct ShadowStyle: Equatable {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    static let none = ShadowStyle(color: .clear, radius: 0, x: 0, y: 0)
}

// MARK: - Design Shadows

extension ShadowStyle {
    /// Default card shadow - soft, spread, blurry
    static let cardDefault = ShadowStyle(
        color: Color.black.opacity(0.25),
        radius: 80,
        x: 0,
        y: 30
    )

    /// Dragging card shadow (enhanced, more lift)
    static let cardDragging = ShadowStyle(
        color: Color.black.opacity(0.3),
        radius: 100,
        x: 0,
        y: 40
    )

    /// Selected card shadow (subtle glow)
    static let cardSelected = ShadowStyle(
        color: Color.black.opacity(0.28),
        radius: 90,
        x: 0,
        y: 35
    )

    /// Sidebar shadow
    static let sidebar = ShadowStyle(
        color: DesignColors.shadowSidebar,
        radius: 63,
        x: 0,
        y: -1
    )

    /// Glassmorphism shadow
    static let glassmorphism = ShadowStyle(
        color: DesignColors.shadowGlass,
        radius: 25,
        x: 0,
        y: 20
    )

    /// Light shadow for UI elements
    static let light = ShadowStyle(
        color: Color.black.opacity(0.05),
        radius: 10,
        x: 0,
        y: 4
    )

    /// Tag shadow
    static let tag = ShadowStyle(
        color: Color.black.opacity(0.05),
        radius: 2,
        x: 0,
        y: 1
    )

    /// Dropdown shadow
    static let dropdown = ShadowStyle(
        color: Color.black.opacity(0.15),
        radius: 20,
        x: 0,
        y: 10
    )
}

// MARK: - View Extension for Shadow

extension View {
    func applyShadow(_ style: ShadowStyle) -> some View {
        self.shadow(
            color: style.color,
            radius: style.radius,
            x: style.x,
            y: style.y
        )
    }

    func cardShadow(isZoomed: Bool, isSelected: Bool, isDragging: Bool) -> some View {
        let style: ShadowStyle
        if isZoomed {
            style = .none
        } else if isDragging {
            style = .cardDragging
        } else if isSelected {
            style = .cardSelected
        } else {
            style = .cardDefault
        }
        return self.applyShadow(style)
    }
}

// MARK: - Animated Shadow Modifier

struct AnimatedShadowModifier: ViewModifier {
    let style: ShadowStyle
    let animation: Animation

    func body(content: Content) -> some View {
        content
            .shadow(
                color: style.color,
                radius: style.radius,
                x: style.x,
                y: style.y
            )
            .animation(animation, value: style)
    }
}

extension View {
    func animatedShadow(_ style: ShadowStyle, animation: Animation = CanvasAnimations.boxShadow) -> some View {
        modifier(AnimatedShadowModifier(style: style, animation: animation))
    }
}
