import ActivityKit
import Flutter
import Foundation

@available(iOS 16.1, *)
final class LiveActivityController {
  func handle(method: String, arguments: Any?, result: @escaping FlutterResult) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      result(nil)
      return
    }

    let args = arguments as? [String: Any]
    let activityId = intValue(args?["activityId"])

    switch method {
    case "start":
      guard
        let activityId,
        let deviceName = args?["deviceName"] as? String,
        let startedAtMs = int64Value(args?["startedAtMs"])
      else {
        result(FlutterError(code: "bad_args", message: "Missing Live Activity start arguments", details: nil))
        return
      }
      Task {
        await start(activityId: activityId, deviceName: deviceName, startedAtMs: startedAtMs)
        result(nil)
      }
    case "update":
      guard let activityId, let state = contentState(from: args) else {
        result(FlutterError(code: "bad_args", message: "Missing Live Activity update arguments", details: nil))
        return
      }
      Task {
        await update(activityId: activityId, state: state)
        result(nil)
      }
    case "end":
      guard let activityId else {
        result(FlutterError(code: "bad_args", message: "Missing Live Activity end arguments", details: nil))
        return
      }
      Task {
        await end(activityId: activityId)
        result(nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func start(activityId: Int, deviceName: String, startedAtMs: Int64) async {
    await end(activityId: activityId)

    let attributes = CardioRoundsActivityAttributes(
      activityId: activityId,
      deviceName: deviceName,
      startedAtMs: startedAtMs
    )
    let state = CardioRoundsActivityAttributes.ContentState(
      elapsedSeconds: 0,
      bpm: nil,
      status: "Recording",
      statusDetail: nil,
      zoneLabel: nil,
      zoneName: nil,
      zoneColorHex: nil
    )

    do {
      _ = try Activity.request(
        attributes: attributes,
        contentState: state,
        pushType: nil
      )
    } catch {
      // Live Activities are a display affordance. The app can keep recording
      // even if iOS declines to create one.
    }
  }

  private func update(
    activityId: Int,
    state: CardioRoundsActivityAttributes.ContentState
  ) async {
    for activity in Activity<CardioRoundsActivityAttributes>.activities
    where activity.attributes.activityId == activityId {
      await activity.update(using: state)
    }
  }

  private func end(activityId: Int) async {
    for activity in Activity<CardioRoundsActivityAttributes>.activities
    where activity.attributes.activityId == activityId {
      await activity.end(dismissalPolicy: .immediate)
    }
  }

  private func contentState(from args: [String: Any]?) -> CardioRoundsActivityAttributes.ContentState? {
    guard let elapsedSeconds = intValue(args?["elapsedSeconds"]) else {
      return nil
    }
    return CardioRoundsActivityAttributes.ContentState(
      elapsedSeconds: elapsedSeconds,
      bpm: intValue(args?["bpm"]),
      status: args?["status"] as? String ?? "Recording",
      statusDetail: args?["statusDetail"] as? String,
      zoneLabel: args?["zoneLabel"] as? String,
      zoneName: args?["zoneName"] as? String,
      zoneColorHex: args?["zoneColorHex"] as? String
    )
  }

  private func intValue(_ value: Any?) -> Int? {
    if let value = value as? Int {
      return value
    }
    if let value = value as? NSNumber {
      return value.intValue
    }
    return nil
  }

  private func int64Value(_ value: Any?) -> Int64? {
    if let value = value as? Int64 {
      return value
    }
    if let value = value as? Int {
      return Int64(value)
    }
    if let value = value as? NSNumber {
      return value.int64Value
    }
    return nil
  }
}
