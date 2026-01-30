import SwiftUI

struct StatusIndicator: View {
    let status: InstanceStatus
    var size: Size = .regular

    enum Size {
        case small, regular, large

        var dimension: CGFloat {
            switch self {
            case .small: return 6
            case .regular: return 8
            case .large: return 10
            }
        }

        var ringWidth: CGFloat {
            switch self {
            case .small: return 1
            case .regular: return 1.5
            case .large: return 2
            }
        }
    }

    var body: some View {
        ZStack {
            // Outer ring for active states
            if status.isActive {
                Circle()
                    .stroke(statusColor.opacity(0.3), lineWidth: size.ringWidth)
                    .frame(width: size.dimension + 6, height: size.dimension + 6)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(statusColor, lineWidth: size.ringWidth)
                    .frame(width: size.dimension + 6, height: size.dimension + 6)
                    .rotationEffect(.degrees(rotationDegrees))
            }

            // Inner dot
            Circle()
                .fill(statusColor)
                .frame(width: size.dimension, height: size.dimension)

            // Pulse effect for running
            if status == .running {
                Circle()
                    .fill(statusColor.opacity(0.3))
                    .frame(width: size.dimension, height: size.dimension)
                    .scaleEffect(pulseScale)
            }
        }
        .animation(status.isActive ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: status)
    }

    private var statusColor: Color {
        switch status {
        case .idle: return .secondary
        case .starting: return .yellow
        case .running: return .blue
        case .ready: return .green
        case .completed: return .green
        case .error: return .red
        case .stopped: return .orange
        }
    }

    @State private var rotationDegrees: Double = 0
    @State private var pulseScale: CGFloat = 1

    init(status: InstanceStatus, size: Size = .regular) {
        self.status = status
        self.size = size
    }
}

struct StatusBadge: View {
    let status: InstanceStatus

    var body: some View {
        HStack(spacing: 6) {
            StatusIndicator(status: status, size: .small)
            Text(status.rawValue)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case .ready, .completed: return Color.green.opacity(0.12)
        case .running: return Color.blue.opacity(0.12)
        case .error: return Color.red.opacity(0.12)
        case .stopped: return Color.orange.opacity(0.12)
        case .starting: return Color.yellow.opacity(0.12)
        default: return Color.secondary.opacity(0.12)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .ready, .completed: return .green
        case .running: return .blue
        case .error: return .red
        case .stopped: return .orange
        case .starting: return Color(nsColor: .systemYellow)
        default: return .secondary
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ForEach([InstanceStatus.idle, .starting, .running, .ready, .completed, .error, .stopped], id: \.self) { status in
            HStack(spacing: 20) {
                StatusIndicator(status: status, size: .small)
                StatusIndicator(status: status, size: .regular)
                StatusIndicator(status: status, size: .large)
                StatusBadge(status: status)
            }
        }
    }
    .padding(40)
}
