//
//  CanvasState.swift
//  Parallel
//
//  Canvas-level state management
//

import SwiftUI

// MARK: - Canvas Viewport

struct CanvasViewport: Codable, Equatable {
    var offset: CGPoint
    var scale: CGFloat

    init(offset: CGPoint = .zero, scale: CGFloat = LayoutConstants.defaultZoom) {
        self.offset = offset
        self.scale = scale
    }

    static let `default` = CanvasViewport()

    /// Clamp scale to valid range
    mutating func clampScale() {
        scale = min(max(scale, LayoutConstants.minZoom), LayoutConstants.maxZoom)
    }
}

// MARK: - View Mode

enum ViewMode: String, Codable, CaseIterable, Identifiable {
    case organic
    case byStatus = "by-status"
    case byRecent = "by-recent"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .organic: return "Organic"
        case .byStatus: return "By Status"
        case .byRecent: return "By Recent"
        }
    }

    var icon: String {
        switch self {
        case .organic: return "circle.hexagongrid"
        case .byStatus: return "folder"
        case .byRecent: return "clock"
        }
    }
}

// MARK: - Canvas State

@Observable
final class CanvasState {
    // MARK: - Instances

    var instances: [ClaudeInstance] = []

    // MARK: - Viewport

    var viewport: CanvasViewport = .default

    // MARK: - Selection

    var selectedIds: Set<UUID> = []
    var activeCardId: UUID? = nil

    // MARK: - View Mode

    var viewMode: ViewMode = .organic

    // MARK: - Interaction State

    var isMarqueeSelecting: Bool = false
    var marqueeRect: CGRect? = nil
    var isDraggingSelection: Bool = false

    // MARK: - Group State

    var expandedGroupId: UUID? = nil           // Currently expanded/scattered group
    var groupPositionsBeforeScatter: [UUID: CGPoint] = [:]  // Store original positions

    // MARK: - Merge Animation State

    var mergingCardId: UUID? = nil             // Card being merged (for swallowing animation)

    // MARK: - Computed Properties

    var selectedInstances: [ClaudeInstance] {
        instances.filter { selectedIds.contains($0.id) }
    }

    var hasSelection: Bool {
        !selectedIds.isEmpty
    }

    var selectionCount: Int {
        selectedIds.count
    }

    var activeInstance: ClaudeInstance? {
        guard let id = activeCardId else { return nil }
        return instances.first { $0.id == id }
    }

    var runningInstances: [ClaudeInstance] {
        instances.filter { $0.status == .running }
    }

    var completedInstances: [ClaudeInstance] {
        instances.filter { $0.status == .completed || $0.status == .ready }
    }

    /// Check if instances are close enough for rigid selection
    func isRigidSelection(radius: CGFloat = LayoutConstants.rigidSelectionRadius) -> Bool {
        guard selectedInstances.count > 1 else { return false }

        let centerX = selectedInstances.map { $0.x }.reduce(0, +) / Double(selectedInstances.count)
        let centerY = selectedInstances.map { $0.y }.reduce(0, +) / Double(selectedInstances.count)

        return selectedInstances.allSatisfy { instance in
            let dx = instance.x - centerX
            let dy = instance.y - centerY
            let distance = sqrt(dx * dx + dy * dy)
            return distance <= Double(radius)
        }
    }

    // MARK: - Selection Methods

    func select(_ id: UUID) {
        selectedIds = [id]
    }

    func toggleSelection(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    func addToSelection(_ id: UUID) {
        selectedIds.insert(id)
    }

    func removeFromSelection(_ id: UUID) {
        selectedIds.remove(id)
    }

    func clearSelection() {
        selectedIds.removeAll()
        activeCardId = nil
    }

    func selectAll() {
        selectedIds = Set(instances.map { $0.id })
    }

    // MARK: - Zoom Methods

    func zoomToCard(_ id: UUID) {
        activeCardId = id
        selectedIds = [id]
    }

    func closeZoomedCard() {
        activeCardId = nil
        selectedIds.removeAll()
    }

    // MARK: - Instance Accessors

    func instance(for id: UUID) -> ClaudeInstance? {
        instances.first { $0.id == id }
    }

    // MARK: - Z-Index Management

    func bringToFront(_ id: UUID) {
        guard let instance = instances.first(where: { $0.id == id }) else { return }
        let maxZ = instances.map { $0.zIndex }.max() ?? 0
        instance.zIndex = maxZ + 1
    }

    func sendToBack(_ id: UUID) {
        guard let instance = instances.first(where: { $0.id == id }) else { return }
        let minZ = instances.map { $0.zIndex }.min() ?? 0
        instance.zIndex = minZ - 1
    }

    // MARK: - Instance Management

    func addInstance(_ instance: ClaudeInstance) {
        instance.zIndex = (instances.map { $0.zIndex }.max() ?? 0) + 1
        instances.append(instance)
    }

    func removeInstance(_ id: UUID) {
        instances.removeAll { $0.id == id }
        selectedIds.remove(id)
        if activeCardId == id {
            activeCardId = nil
        }
    }

    func removeSelectedInstances() {
        for id in selectedIds {
            instances.removeAll { $0.id == id }
        }
        selectedIds.removeAll()
        activeCardId = nil
    }

    // MARK: - Coordinator/Worker Helpers

    /// Get all workers for a coordinator
    func workers(for coordinatorId: UUID) -> [ClaudeInstance] {
        guard let coordinator = instance(for: coordinatorId) else { return [] }
        return coordinator.workerIds.compactMap { instance(for: $0) }
    }

    /// Get coordinator for a worker
    func coordinator(for workerId: UUID) -> ClaudeInstance? {
        guard let worker = instance(for: workerId),
              let parentId = worker.parentId else { return nil }
        return instance(for: parentId)
    }

    /// Get all coordinator instances
    var coordinators: [ClaudeInstance] {
        instances.filter { $0.agentType == .coordinator }
    }

    /// Get all worker instances (not nested in coordinator cards on canvas)
    var standaloneWorkers: [ClaudeInstance] {
        instances.filter { $0.agentType == .worker && $0.parentId == nil }
    }

    // MARK: - Group Methods

    /// Get all instances in a group
    func instancesInGroup(_ groupId: UUID) -> [ClaudeInstance] {
        instances.filter { $0.groupId == groupId }
    }

    /// Check if a group is expanded/scattered
    func isGroupExpanded(_ groupId: UUID) -> Bool {
        expandedGroupId == groupId
    }

    /// Toggle group expansion (scatter/collapse)
    func toggleGroupExpansion(_ groupId: UUID) {
        if expandedGroupId == groupId {
            // Collapse: restore original positions
            collapseGroup(groupId)
        } else {
            // Expand: scatter the group
            expandGroup(groupId)
        }
    }

    /// Scatter group cards around the canvas
    func expandGroup(_ groupId: UUID) {
        let groupInstances = instancesInGroup(groupId)
        guard groupInstances.count > 1 else { return }

        // Store original positions
        for instance in groupInstances {
            groupPositionsBeforeScatter[instance.id] = CGPoint(x: instance.x, y: instance.y)
        }

        // Calculate scatter positions in a circle
        let centerX = groupInstances.map { $0.x }.reduce(0, +) / Double(groupInstances.count)
        let centerY = groupInstances.map { $0.y }.reduce(0, +) / Double(groupInstances.count)
        let radius: Double = 250
        let angleStep = (2 * Double.pi) / Double(groupInstances.count)

        for (index, instance) in groupInstances.enumerated() {
            let angle = Double(index) * angleStep - Double.pi / 2
            instance.x = centerX + cos(angle) * radius
            instance.y = centerY + sin(angle) * radius
        }

        expandedGroupId = groupId
    }

    /// Collapse group back to stacked position
    func collapseGroup(_ groupId: UUID) {
        let groupInstances = instancesInGroup(groupId)

        // Restore original positions or stack them
        for instance in groupInstances {
            if let original = groupPositionsBeforeScatter[instance.id] {
                instance.x = original.x
                instance.y = original.y
            }
        }

        groupPositionsBeforeScatter.removeAll()
        expandedGroupId = nil
    }

    /// Check if instance should be dimmed (not in expanded group)
    func shouldDimInstance(_ instance: ClaudeInstance) -> Bool {
        guard let expandedId = expandedGroupId else { return false }
        return instance.groupId != expandedId
    }
}
