//
//  CanvasCoordinator.swift
//  Parallel
//
//  Coordinator for complex canvas interactions
//  Matches React behavior exactly for drag and drop
//

import SwiftUI

// MARK: - Canvas Coordinator

@Observable
final class CanvasCoordinator {
    // MARK: - Dependencies

    private weak var canvasState: CanvasState?

    // MARK: - Drag State

    var selectionDragDelta: CGSize = .zero
    private var dragStartPositions: [UUID: CGPoint] = [:]

    // MARK: - Configuration

    func configure(canvasState: CanvasState) {
        self.canvasState = canvasState
    }

    // MARK: - Drag Handling

    func startDrag(for id: UUID) {
        guard let state = canvasState else { return }

        // Store starting positions for all selected items
        dragStartPositions.removeAll()
        if state.selectedIds.contains(id) {
            for selectedId in state.selectedIds {
                if let instance = state.instances.first(where: { $0.id == selectedId }) {
                    dragStartPositions[selectedId] = instance.position
                }
            }
        } else {
            if let instance = state.instances.first(where: { $0.id == id }) {
                dragStartPositions[id] = instance.position
            }
        }

        state.isDraggingSelection = true
    }

    func updateDrag(delta: CGSize) {
        selectionDragDelta = delta
    }

    func endDrag(for id: UUID, finalDelta: CGSize) {
        guard let state = canvasState else { return }

        // Note: Position is already updated by InstanceCardView before this is called
        // Only apply finalDelta if non-zero (for multi-selection drag)
        if finalDelta != .zero {
            for (instanceId, startPosition) in dragStartPositions {
                if let instance = state.instances.first(where: { $0.id == instanceId }) {
                    instance.x = Double(startPosition.x) + Double(finalDelta.width)
                    instance.y = Double(startPosition.y) + Double(finalDelta.height)

                    // Update organic position if in organic mode
                    if state.viewMode == .organic {
                        instance.organicX = instance.x
                        instance.organicY = instance.y
                    }
                }
            }
        }

        // Reset drag state
        dragStartPositions.removeAll()
        selectionDragDelta = .zero
        state.isDraggingSelection = false
    }

    // MARK: - Instance Operations

    func addInstance(name: String, task: String, at position: CGPoint? = nil) {
        guard let state = canvasState else { return }

        let pos = position ?? CGPoint(x: 0, y: 0)
        let instance = ClaudeInstance.create(name: name, task: task, at: pos)

        state.addInstance(instance)
    }

    func deleteSelected() {
        canvasState?.removeSelectedInstances()
    }

    func deleteInstance(_ id: UUID) {
        canvasState?.removeInstance(id)
    }

    // MARK: - Stack Operations

    func stackSelection() {
        guard let state = canvasState else { return }
        guard state.selectedInstances.count > 1 else { return }

        let selectedInstances = state.selectedInstances

        let centerX = selectedInstances.map { $0.x }.reduce(0, +) / Double(selectedInstances.count)
        let centerY = selectedInstances.map { $0.y }.reduce(0, +) / Double(selectedInstances.count)

        for (index, instance) in selectedInstances.enumerated() {
            instance.x = centerX
            instance.y = centerY + Double(index) * Double(LayoutConstants.stackOffset)
            instance.organicX = instance.x
            instance.organicY = instance.y
            instance.zIndex = index
        }
    }

    func knollSelection() {
        guard let state = canvasState else { return }
        guard state.selectedInstances.count > 1 else { return }

        let selectedInstances = state.selectedInstances
        let columns = min(3, selectedInstances.count)
        let gap: Double = Double(LayoutConstants.gridGap)
        let cardWidth: Double = 280
        let cardHeight: Double = 380

        let minX = selectedInstances.map { $0.x }.min() ?? 0
        let minY = selectedInstances.map { $0.y }.min() ?? 0

        for (index, instance) in selectedInstances.enumerated() {
            let col = index % columns
            let row = index / columns

            instance.x = minX + Double(col) * (cardWidth + gap)
            instance.y = minY + Double(row) * (cardHeight + gap)
            instance.organicX = instance.x
            instance.organicY = instance.y
        }
    }

    // MARK: - Position Calculation

    func targetPosition(for instance: ClaudeInstance) -> CGPoint {
        guard let state = canvasState else {
            return CGPoint(x: instance.x, y: instance.y)
        }

        switch state.viewMode {
        case .organic:
            return CGPoint(x: instance.organicX ?? instance.x, y: instance.organicY ?? instance.y)
        case .byStatus:
            return byStatusPosition(for: instance, in: state.instances)
        case .byRecent:
            return byRecentPosition(for: instance, in: state.instances)
        }
    }

    // MARK: - Layout Calculations

    private func byStatusPosition(for instance: ClaudeInstance, in instances: [ClaudeInstance]) -> CGPoint {
        let statusOrder: [InstanceStatus] = [.running, .ready, .completed, .error, .idle, .merged]
        let statusIndex = statusOrder.firstIndex(of: instance.status) ?? 0

        let sameStatusInstances = instances.filter { $0.status == instance.status }
        let instanceIndex = sameStatusInstances.firstIndex(where: { $0.id == instance.id }) ?? 0

        let columns = 3
        let cardWidth: Double = 280
        let cardHeight: Double = 380
        let gap: Double = 40
        let groupGap: Double = 200

        let col = instanceIndex % columns
        let row = instanceIndex / columns

        let groupOffset = Double(statusIndex) * (3 * (cardWidth + gap) + groupGap)

        return CGPoint(
            x: groupOffset + Double(col) * (cardWidth + gap),
            y: Double(row) * (cardHeight + gap)
        )
    }

    private func byRecentPosition(for instance: ClaudeInstance, in instances: [ClaudeInstance]) -> CGPoint {
        let sorted = instances.sorted { $0.lastActivityAt > $1.lastActivityAt }
        let index = sorted.firstIndex(where: { $0.id == instance.id }) ?? 0

        let columns = 4
        let cardWidth: Double = 280
        let cardHeight: Double = 380
        let gap: Double = 40

        let col = index % columns
        let row = index / columns

        return CGPoint(
            x: Double(col) * (cardWidth + gap),
            y: Double(row) * (cardHeight + gap)
        )
    }
}
