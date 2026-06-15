import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct CardioRoundsActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var elapsedSeconds: Int
    var bpm: Int?
    var status: String
    var statusDetail: String?
    var zoneLabel: String?
    var zoneName: String?
    var zoneColorHex: String?
  }

  var activityId: Int
  var deviceName: String
  var startedAtMs: Int64
}
