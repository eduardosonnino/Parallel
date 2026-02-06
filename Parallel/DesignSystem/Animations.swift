//
//  Animations.swift
//  Parallel
//
//  Animation system replicating Framer Motion springs exactly
//

import SwiftUI

// MARK: - Framer Motion Spring Conversion

extension Animation {
    /// Converts Framer Motion spring parameters to SwiftUI Animation
    static func framerSpring(
        stiffness: Double,
        damping: Double,
        mass: Double
    ) -> Animation {
        let spring = Spring(mass: mass, stiffness: stiffness, damping: damping)
        return .spring(spring)
    }
}

// MARK: - Canvas Animation Constants

enum CanvasAnimations {
    // MARK: - Spring Animations

    /// MAIN_TRANSITION: Primary canvas spring for card movements, zoom, etc.
    /// Framer: { type: 'spring', stiffness: 360, damping: 45, mass: 1.6 }
    static let mainTransition: Animation = .framerSpring(
        stiffness: 360,
        damping: 45,
        mass: 1.6
    )

    /// REPULSION_TRANSITION: Used when cards push apart
    static let repulsionTransition: Animation = .framerSpring(
        stiffness: 480,
        damping: 40,
        mass: 1
    )

    /// RIGID_DRAG: Used for locked formation multi-drag
    static let rigidDrag: Animation = .framerSpring(
        stiffness: 1000,
        damping: 50,
        mass: 1
    )

    // MARK: - Duration-Based Animations

    /// Card opacity transitions: 0.3s easeOut
    static let cardOpacity: Animation = .easeOut(duration: 0.3)

    /// Box shadow transitions: 0.2s easeOut
    static let boxShadow: Animation = .easeOut(duration: 0.2)

    /// Background color transitions: 0.3s easeInOut
    static let backgroundColor: Animation = .easeInOut(duration: 0.3)

    /// Button press feedback
    static let buttonPress: Animation = .spring(
        response: 0.15,
        dampingFraction: 0.6,
        blendDuration: 0
    )

    /// Hover scale feedback
    static let hoverScale: Animation = .spring(
        response: 0.2,
        dampingFraction: 0.7,
        blendDuration: 0
    )

    // MARK: - Entry Animation

    /// Staggered entry animation
    static func staggeredEntry(index: Int, staggerInterval: Double = 0.05) -> Animation {
        mainTransition.delay(Double(index) * staggerInterval)
    }
}

// MARK: - Flocking Spring Generator

/// Generates per-card varied spring parameters for the flocking effect
enum FlockingSpringGenerator {
    /// Generate a seed from card ID
    static func seed(from id: UUID) -> Int {
        id.uuidString.unicodeScalars.reduce(0) { acc, scalar in
            acc + Int(scalar.value)
        }
    }

    /// Generate spring animation for a card based on its ID
    static func animation(for id: UUID, isRigid: Bool = false) -> Animation {
        if isRigid {
            return CanvasAnimations.rigidDrag
        }

        let seed = self.seed(from: id)

        let stiffness = Double(180 - (seed % 100))  // 80-180
        let damping = Double(20 + (seed % 10))       // 20-30
        let mass = 0.5 + (Double(seed % 15) * 0.1)   // 0.5-2.0

        return .framerSpring(stiffness: stiffness, damping: damping, mass: mass)
    }
}

// MARK: - View Modifiers

struct StaggeredEntryModifier: ViewModifier {
    let index: Int
    let staggerInterval: Double
    @State private var isVisible = false

    init(index: Int, staggerInterval: Double = 0.05) {
        self.index = index
        self.staggerInterval = staggerInterval
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isVisible ? 1 : LayoutConstants.entryScale)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(CanvasAnimations.staggeredEntry(index: index, staggerInterval: staggerInterval)) {
                    isVisible = true
                }
            }
    }
}

struct InteractiveScaleModifier: ViewModifier {
    @State private var isHovered = false
    @State private var isPressed = false

    let hoverScale: CGFloat
    let pressedScale: CGFloat

    init(hoverScale: CGFloat = 1.05, pressedScale: CGFloat = 0.95) {
        self.hoverScale = hoverScale
        self.pressedScale = pressedScale
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? pressedScale : (isHovered ? hoverScale : 1.0))
            .animation(CanvasAnimations.hoverScale, value: isHovered)
            .animation(CanvasAnimations.buttonPress, value: isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

// MARK: - View Extensions

extension View {
    func staggeredEntry(index: Int, staggerInterval: Double = 0.05) -> some View {
        modifier(StaggeredEntryModifier(index: index, staggerInterval: staggerInterval))
    }

    func interactiveScale(hover: CGFloat = 1.05, tap: CGFloat = 0.95) -> some View {
        modifier(InteractiveScaleModifier(hoverScale: hover, pressedScale: tap))
    }

    func flockingAnimation(cardId: UUID, isRigid: Bool = false) -> some View {
        self.animation(
            FlockingSpringGenerator.animation(for: cardId, isRigid: isRigid),
            value: cardId
        )
    }
}
