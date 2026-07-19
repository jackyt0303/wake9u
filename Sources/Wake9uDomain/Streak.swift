import Foundation

public enum OccurrenceOutcome: String, Codable, Sendable {
    case success
    case failure
    case provisionalFailure
    case neutral
}

public struct StreakDay: Sendable, Equatable {
    public let localDate: Date
    public let outcome: OccurrenceOutcome

    public init(localDate: Date, outcome: OccurrenceOutcome) {
        self.localDate = localDate
        self.outcome = outcome
    }
}

public enum StreakCalculator {
    /// Counts consecutive successful scheduled occurrences from the most recent
    /// final outcome. Neutral dates are intentionally ignored.
    public static func currentStreak(_ days: [StreakDay]) -> Int {
        let ordered = days.sorted { $0.localDate > $1.localDate }
        var count = 0
        for day in ordered {
            switch day.outcome {
            case .success: count += 1
            case .neutral: continue
            case .failure, .provisionalFailure: return count
            }
        }
        return count
    }
}
