//
//  Layout.swift
//  Parallel
//
//  Layout constants matching the spatial canvas design
//

import SwiftUI

// MARK: - Layout Constants

enum LayoutConstants {
    // MARK: - Corner Radii

    /// Card corner radius when not zoomed (80px)
    static let cardRadiusDefault: CGFloat = 80

    /// Card corner radius when zoomed (32px)
    static let cardRadiusZoomed: CGFloat = 32

    /// UI element corner radius
    static let uiElementRadius: CGFloat = 10

    /// Pill/capsule corner radius
    static let pillRadius: CGFloat = 24

    // MARK: - Card Dimensions

    /// Instance card width
    static let cardWidth: CGFloat = 800

    /// Instance card height
    static let cardHeight: CGFloat = 1100

    // MARK: - Zoom Constraints

    /// Minimum zoom level (0.35x)
    static let minZoom: CGFloat = 0.35

    /// Maximum zoom level (2.0x)
    static let maxZoom: CGFloat = 2.0

    /// Default/initial zoom level
    static let defaultZoom: CGFloat = 0.45

    // MARK: - Scale Factors

    /// Base scale for cards when not zoomed
    static let cardBaseScale: CGFloat = 0.35

    /// Scale multiplier for selected cards
    static let selectedScaleMultiplier: CGFloat = 1.03

    /// Entry animation scale
    static let entryScale: CGFloat = 0.8

    // MARK: - Spacing

    /// Standard padding unit
    static let spacingUnit: CGFloat = 8

    /// Card internal padding
    static let cardPadding: CGFloat = 32

    /// Card top padding
    static let cardTopPadding: CGFloat = 48

    /// Toolbar padding from bottom
    static let toolbarBottomPadding: CGFloat = 32

    // MARK: - Grid Layout

    /// Gap between cards in grid view
    static let gridGap: CGFloat = 32

    /// Stack offset per card
    static let stackOffset: CGFloat = 8

    // MARK: - Selection

    /// Distance threshold for rigid selection
    static let rigidSelectionRadius: CGFloat = 200

    /// Minimum drag distance before drag starts
    static let minDragDistance: CGFloat = 5

    /// Selection border width
    static let selectionBorderWidth: CGFloat = 4

    /// Marquee border width
    static let marqueeBorderWidth: CGFloat = 2

    /// Marquee corner radius
    static let marqueeRadius: CGFloat = 12

    // MARK: - Toolbar Dimensions

    /// Omnibar height
    static let omnibarHeight: CGFloat = 56

    /// Icon button size
    static let iconButtonSize: CGFloat = 36

    // MARK: - Animation

    /// Zoom indicator auto-hide delay
    static let zoomIndicatorHideDelay: TimeInterval = 1.5

    /// Auto-save debounce delay
    static let autoSaveDebounce: TimeInterval = 0.5
}

// MARK: - Window Constraints

enum WindowConstraints {
    static let minWidth: CGFloat = 1200
    static let minHeight: CGFloat = 800
    static let defaultWidth: CGFloat = 1440
    static let defaultHeight: CGFloat = 900
}

// MARK: - Convenience Typealias

typealias Layout = LayoutConstants
