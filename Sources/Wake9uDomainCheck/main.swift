import Foundation
import Wake9uDomain

enum CheckFailure: Error {
    case failed(String)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw CheckFailure.failed(message) }
}

let start = Date(timeIntervalSince1970: 1_700_000_000)
let occurrence = UUID()

var nineAttempt = LocalAttempt(occurrenceID: occurrence, scheduledAt: start)
try nineAttempt.activate(at: start)
try nineAttempt.recordPhoneEvidence(VerificationEvidence(
    occurrenceID: occurrence,
    source: .phonePedometer,
    measurementInterval: DateInterval(start: start, duration: 300),
    aggregateStepCount: 9,
    capturedAt: start.addingTimeInterval(300)
))
try require(nineAttempt.state == .failedLocal, "nine steps must fail")

var tenAttempt = LocalAttempt(occurrenceID: occurrence, scheduledAt: start)
try tenAttempt.activate(at: start)
try tenAttempt.recordPhoneEvidence(VerificationEvidence(
    occurrenceID: occurrence,
    source: .phonePedometer,
    measurementInterval: DateInterval(start: start, duration: 300),
    aggregateStepCount: 10,
    capturedAt: start.addingTimeInterval(300)
))
try require(tenAttempt.state == .succeededLocal, "ten steps must succeed")

var correctedAttempt = LocalAttempt(occurrenceID: UUID(), scheduledAt: start)
try correctedAttempt.activate(at: start)
try correctedAttempt.markSensorUnavailable()
try correctedAttempt.applyServerOutcome(.provisionalFailure)
try correctedAttempt.applyServerOutcome(.correctedSuccess)
try require(correctedAttempt.state == .correctedSuccess, "provisional failure must be correctable")

let days = [
    StreakDay(localDate: start, outcome: .success),
    StreakDay(localDate: start.addingTimeInterval(-86_400), outcome: .neutral),
    StreakDay(localDate: start.addingTimeInterval(-172_800), outcome: .success),
    StreakDay(localDate: start.addingTimeInterval(-259_200), outcome: .failure)
]
try require(StreakCalculator.currentStreak(days) == 2, "neutral days must not break a streak")

print("Wake9u domain checks passed")
