//
//  ZoomableCanvas.swift
//  Parallel
//
//  Main zoomable, pannable canvas view
//  Matches React behavior: canvas pans to center the zoomed card
//

import SwiftUI

// MARK: - Zoomable Canvas

struct ZoomableCanvas: View {
    @Environment(CanvasState.self) private var canvasState
    @Environment(CanvasCoordinator.self) private var coordinator

    // MARK: - Local State

    @State private var currentMagnification: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    @State private var currentScreenSize: CGSize = .zero

    // Marquee selection
    @State private var marqueeStart: CGPoint? = nil
    @State private var marqueeEnd: CGPoint? = nil

    // Zoom indicator
    @State private var showZoomIndicator: Bool = false
    @State private var zoomIndicatorTask: Task<Void, Never>?

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(
                x: geometry.size.width / 2,
                y: geometry.size.height / 2
            )

            ZStack {
                // Background - animates to white when card is zoomed
                canvasBackground

                // Canvas content layer
                canvasLayer(center: center, screenSize: geometry.size)

                // Main Branch "Sun" - fixed to left edge, not affected by canvas transforms
                if canvasState.activeCardId == nil {
                    MainBranchCard(
                        screenSize: geometry.size,
                        workingDirectory: canvasState.instances.first?.workingDirectory
                    )
                    .zIndex(500)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }

                // Marquee selection overlay
                if let start = marqueeStart, let end = marqueeEnd {
                    SelectionMarquee(start: start, end: end)
                }

                // Zoom indicator (top right)
                if showZoomIndicator && canvasState.activeCardId == nil {
                    ZoomIndicator(scale: canvasState.viewport.scale)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .contentShape(Rectangle())
            .gesture(magnificationGesture)
            .gesture(canvasPanGesture)
            .onTapGesture {
                handleBackgroundTap()
            }
            .onChange(of: geometry.size) { _, newSize in
                currentScreenSize = newSize
            }
            .onAppear {
                currentScreenSize = geometry.size
            }
        }
        .clipped()
    }

    // MARK: - Canvas Layer

    // Filter instances to show on canvas (exclude nested workers)
    private var visibleInstances: [ClaudeInstance] {
        canvasState.instances.filter { instance in
            // Show all coordinators and workers without a parent
            // Workers with a parentId are nested inside coordinator cards
            instance.parentId == nil
        }
    }

    @ViewBuilder
    private func canvasLayer(center: CGPoint, screenSize: CGSize) -> some View {
        ZStack {
            // Instance cards (coordinators and standalone workers only)
            ForEach(Array(visibleInstances.enumerated()), id: \.element.id) { index, instance in
                let isActive = instance.id == canvasState.activeCardId
                let isDimmed = canvasState.shouldDimInstance(instance)
                let isInExpandedGroup = canvasState.expandedGroupId != nil && instance.groupId == canvasState.expandedGroupId

                InstanceCardView(
                    instance: instance,
                    index: index,
                    isActive: isActive,
                    isSelected: canvasState.selectedIds.contains(instance.id),
                    currentScale: canvasState.viewport.scale,
                    screenSize: screenSize
                )
                .opacity(isDimmed ? 0.15 : 1.0)
                .scaleEffect(isDimmed ? 0.95 : 1.0)
                .position(cardPosition(for: instance, center: center, screenSize: screenSize))
                .zIndex(cardZIndex(for: instance, isActive: isActive))
                .onTapGesture(count: 2) {
                    // Double-tap on grouped card toggles group expansion
                    if let groupId = instance.groupId, canvasState.instancesInGroup(groupId).count > 1 {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            canvasState.toggleGroupExpansion(groupId)
                        }
                    }
                }
                // Disable position animation during drag to prevent snap-back
                .transaction { transaction in
                    if canvasState.isDraggingSelection {
                        transaction.animation = nil
                    }
                }
                .animation(canvasState.isDraggingSelection ? nil : .easeInOut(duration: 0.3), value: isDimmed)
                .animation(canvasState.isDraggingSelection ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: isInExpandedGroup)
            }
        }
        // Canvas transform - scale and offset
        .scaleEffect(canvasScale, anchor: .center)
        .offset(canvasOffset(screenSize: screenSize))
        // Animate all canvas transforms with main spring
        .animation(CanvasAnimations.mainTransition, value: canvasState.viewport.offset)
        .animation(CanvasAnimations.mainTransition, value: canvasState.viewport.scale)
        .animation(CanvasAnimations.mainTransition, value: canvasState.activeCardId)
    }

    // MARK: - Canvas Transform

    private var canvasScale: CGFloat {
        if canvasState.activeCardId != nil {
            return activeScale * currentMagnification
        }
        return canvasState.viewport.scale * currentMagnification
    }

    private var activeScale: CGFloat {
        1.0
    }

    private func canvasOffset(screenSize: CGSize) -> CGSize {
        if let activeId = canvasState.activeCardId,
           let activeInstance = canvasState.instances.first(where: { $0.id == activeId }) {
            // Position card so its top edge is visible below the title bar area
            // Card center is at: verticalAnchor + instance.y (from cardPosition)
            // Card top is at: verticalAnchor + instance.y - cardHalfHeight
            // We want card top at: topMargin
            // So offset = topMargin + cardHalfHeight - verticalAnchor - instance.y
            let topMargin: CGFloat = 20  // Space from top of window to card top
            let bottomMargin: CGFloat = 100  // Space for input box
            let activeCardHeight = max(screenSize.height - topMargin - bottomMargin, 400)
            let cardHalfHeight = activeCardHeight / 2
            let verticalAnchor: CGFloat = 400  // Must match cardPosition

            return CGSize(
                width: -activeInstance.x + dragOffset.width,
                height: topMargin + cardHalfHeight - verticalAnchor - activeInstance.y + dragOffset.height
            )
        }

        return CGSize(
            width: canvasState.viewport.offset.x + dragOffset.width,
            height: canvasState.viewport.offset.y + dragOffset.height
        )
    }

    // MARK: - Background

    private var canvasBackground: some View {
        (canvasState.activeCardId != nil ? DesignColors.cardBackground : DesignColors.canvasBackground)
            .ignoresSafeArea()
            .animation(CanvasAnimations.backgroundColor, value: canvasState.activeCardId != nil)
    }

    // MARK: - Card Position

    private func cardPosition(for instance: ClaudeInstance, center: CGPoint, screenSize: CGSize) -> CGPoint {
        let targetPos = coordinator.targetPosition(for: instance)
        // Anchor horizontally to center, vertically offset from top
        // Use a fixed anchor point so resizing window doesn't shift cards
        let verticalAnchor: CGFloat = 400  // Fixed distance from top
        return CGPoint(
            x: center.x + targetPos.x,
            y: verticalAnchor + targetPos.y
        )
    }

    private func cardZIndex(for instance: ClaudeInstance, isActive: Bool) -> Double {
        if isActive { return 10000 }
        var z = Double(instance.zIndex)
        if canvasState.selectedIds.contains(instance.id) {
            z += 1000
        }
        return z
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard canvasState.activeCardId == nil else { return }
                currentMagnification = value.magnification
                showZoomIndicatorBriefly()
            }
            .onEnded { value in
                guard canvasState.activeCardId == nil else { return }
                let newScale = canvasState.viewport.scale * value.magnification
                canvasState.viewport.scale = min(max(newScale, LayoutConstants.minZoom), LayoutConstants.maxZoom)
                currentMagnification = 1.0
            }
    }

    private var canvasPanGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                guard canvasState.activeCardId == nil else { return }

                let modifiers = NSEvent.modifierFlags

                // Option+drag = pan canvas, regular drag = marquee selection
                if modifiers.contains(.option) {
                    dragOffset = value.translation
                } else {
                    // Marquee selection on regular drag
                    if marqueeStart == nil {
                        marqueeStart = value.startLocation
                        // Clear previous selection unless shift is held
                        if !modifiers.contains(.shift) {
                            canvasState.clearSelection()
                        }
                    }
                    marqueeEnd = value.location
                    // Select cards within marquee
                    selectCardsInMarquee(screenSize: currentScreenSize)
                }
            }
            .onEnded { value in
                guard canvasState.activeCardId == nil else { return }

                if marqueeStart != nil {
                    // Finalize marquee selection
                    marqueeStart = nil
                    marqueeEnd = nil
                } else {
                    // Pan canvas (option+drag)
                    canvasState.viewport.offset.x += value.translation.width
                    canvasState.viewport.offset.y += value.translation.height
                    dragOffset = .zero
                }
            }
    }

    // MARK: - Marquee Selection

    private func selectCardsInMarquee(screenSize: CGSize? = nil) {
        guard let start = marqueeStart, let end = marqueeEnd else { return }
        guard let size = screenSize, size.width > 0 else { return }

        let marqueeRect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )

        let screenCenter = CGPoint(x: size.width / 2, y: size.height / 2)
        let verticalAnchor: CGFloat = 400
        let scale = canvasState.viewport.scale
        let offset = canvasState.viewport.offset

        // Check each visible instance against marquee
        for instance in visibleInstances {
            let targetPos = coordinator.targetPosition(for: instance)

            // Card position in the canvas ZStack (before transform)
            let cardPosX = screenCenter.x + targetPos.x
            let cardPosY = verticalAnchor + targetPos.y

            // Apply scaleEffect with anchor at screen center
            // newPos = anchor + (pos - anchor) * scale
            let scaledX = screenCenter.x + (cardPosX - screenCenter.x) * scale
            let scaledY = screenCenter.y + (cardPosY - screenCenter.y) * scale

            // Apply offset
            let cardScreenX = scaledX + offset.x + dragOffset.width
            let cardScreenY = scaledY + offset.y + dragOffset.height

            // Create a card bounding box (approximate size after scale)
            let cardWidth: CGFloat = 300 * 0.35 * scale  // Card uses 0.35 scale internally
            let cardHeight: CGFloat = 200 * 0.35 * scale
            let cardRect = CGRect(
                x: cardScreenX - cardWidth / 2,
                y: cardScreenY - cardHeight / 2,
                width: cardWidth,
                height: cardHeight
            )

            // Select if marquee intersects card rect
            if marqueeRect.intersects(cardRect) {
                canvasState.addToSelection(instance.id)
            } else if !NSEvent.modifierFlags.contains(.shift) {
                // Deselect if not in marquee (unless shift is held for additive selection)
                canvasState.removeFromSelection(instance.id)
            }
        }
    }

    // MARK: - Handlers

    private func handleBackgroundTap() {
        if canvasState.activeCardId != nil {
            withAnimation(CanvasAnimations.mainTransition) {
                canvasState.closeZoomedCard()
            }
        } else if !canvasState.selectedIds.isEmpty {
            withAnimation(CanvasAnimations.mainTransition) {
                canvasState.clearSelection()
            }
        }
    }

    private func showZoomIndicatorBriefly() {
        withAnimation { showZoomIndicator = true }

        zoomIndicatorTask?.cancel()
        zoomIndicatorTask = Task {
            try? await Task.sleep(for: .seconds(LayoutConstants.zoomIndicatorHideDelay))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation { showZoomIndicator = false }
            }
        }
    }
}

// MARK: - Selection Marquee

struct SelectionMarquee: View {
    let start: CGPoint
    let end: CGPoint

    private let selectionColor = Color(hex: "#007AFF")

    var body: some View {
        let rect = normalizedRect

        RoundedRectangle(cornerRadius: 4)
            .stroke(selectionColor, lineWidth: 1.5)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(selectionColor.opacity(0.15))
            )
            .frame(width: max(rect.width, 1), height: max(rect.height, 1))
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.05), value: rect)
    }

    private var normalizedRect: CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }
}

// MARK: - Zoom Indicator

struct ZoomIndicator: View {
    let scale: CGFloat

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Text("\(Int(scale * 100))%")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            Spacer()
        }
        .padding(.top, 16)
        .padding(.trailing, 16)
        .allowsHitTesting(false)
    }
}
