import ActivityKit
import SwiftUI
import WidgetKit

struct CardioRoundsLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: CardioRoundsActivityAttributes.self) { context in
      LiveActivityLockScreenView(context: context)
        .activityBackgroundTint(Color(red: 0.03, green: 0.03, blue: 0.06))
        .activitySystemActionForegroundColor(context.state.zoneColor)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Cardio Rounds")
              .font(.caption2)
              .foregroundStyle(.secondary)
            Text(context.state.status)
              .font(.caption)
              .lineLimit(1)
          }
        }

        DynamicIslandExpandedRegion(.trailing) {
          BpmView(bpm: context.state.bpm, color: context.state.zoneColor, valueSize: 28)
        }

        DynamicIslandExpandedRegion(.bottom) {
          HStack(spacing: 12) {
            if context.state.hasZone {
              ZonePill(state: context.state)
            }
            Spacer()
            ElapsedView(seconds: context.state.elapsedSeconds)
          }
        }
      } compactLeading: {
        if let zoneLabel = context.state.zoneLabel {
          Text(zoneLabel)
            .font(.caption2.weight(.bold))
            .foregroundStyle(context.state.zoneColor)
        } else {
          Image(systemName: "heart.fill")
            .font(.caption2.weight(.bold))
            .foregroundStyle(context.state.zoneColor)
        }
      } compactTrailing: {
        Text(context.state.bpm.map(String.init) ?? "--")
          .font(.caption.weight(.bold))
          .foregroundStyle(context.state.zoneColor)
      } minimal: {
        Image(systemName: "heart.fill")
          .foregroundStyle(context.state.zoneColor)
      }
      .keylineTint(context.state.zoneColor)
    }
  }
}

private struct LiveActivityLockScreenView: View {
  let context: ActivityViewContext<CardioRoundsActivityAttributes>

  var body: some View {
    HStack(alignment: .center, spacing: 14) {
      VStack(alignment: .leading, spacing: 7) {
        Text("Cardio Rounds")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
        Text(context.state.status)
          .font(.title3.weight(.bold))
          .lineLimit(1)
        if let detail = context.state.statusDetail, !detail.isEmpty {
          Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        if context.state.hasZone {
          ZonePill(state: context.state)
            .padding(.top, 2)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      VStack(alignment: .trailing, spacing: 6) {
        BpmView(bpm: context.state.bpm, color: context.state.zoneColor, valueSize: 44)
        ElapsedView(seconds: context.state.elapsedSeconds)
      }
      .frame(minWidth: 118, alignment: .trailing)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
  }
}

private struct BpmView: View {
  let bpm: Int?
  let color: Color
  var valueSize: CGFloat = 38

  var body: some View {
    HStack(alignment: .lastTextBaseline, spacing: 6) {
      Text(bpm.map(String.init) ?? "--")
        .font(.system(size: valueSize, weight: .black, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(color)
        .contentTransition(.numericText())
      Text("bpm")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
    }
    .lineLimit(1)
  }
}

private struct ZonePill: View {
  let state: CardioRoundsActivityAttributes.ContentState

  var body: some View {
    if let zoneText = state.zoneText {
      HStack(spacing: 6) {
        Circle()
          .fill(state.zoneColor)
          .frame(width: 8, height: 8)
        Text(zoneText)
          .font(.caption.weight(.semibold))
          .lineLimit(1)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(state.zoneColor.opacity(0.18), in: Capsule())
      .foregroundStyle(state.zoneColor)
    }
  }
}

private struct ElapsedView: View {
  let seconds: Int

  var body: some View {
    Text(formattedSeconds)
      .font(.caption.monospacedDigit().weight(.semibold))
      .foregroundStyle(.secondary)
  }

  private var formattedSeconds: String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let remainingSeconds = seconds % 60
    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
    }
    return String(format: "%d:%02d", minutes, remainingSeconds)
  }
}

private extension CardioRoundsActivityAttributes.ContentState {
  var hasZone: Bool {
    zoneText != nil
  }

  var zoneText: String? {
    guard let zoneLabel, let zoneName else {
      return nil
    }
    return "\(zoneLabel) \(zoneName)"
  }

  var zoneColor: Color {
    Color(hex: zoneColorHex) ?? Color(red: 0.0, green: 0.62, blue: 0.96)
  }
}

private extension Color {
  init?(hex: String?) {
    guard let hex else {
      return nil
    }
    let normalized = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard normalized.count == 6, let value = Int(normalized, radix: 16) else {
      return nil
    }
    self.init(
      red: Double((value >> 16) & 0xFF) / 255.0,
      green: Double((value >> 8) & 0xFF) / 255.0,
      blue: Double(value & 0xFF) / 255.0
    )
  }
}
