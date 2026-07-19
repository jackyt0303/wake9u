import Foundation
import Testing
@testable import Wake9uDomain

@Test func tenStepsSucceedAndNineFail() throws {
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
    #expect(nineAttempt.state == .failedLocal)

    var tenAttempt = LocalAttempt(occurrenceID: occurrence, scheduledAt: start)
    try tenAttempt.activate(at: start)
    try tenAttempt.recordPhoneEvidence(VerificationEvidence(
        occurrenceID: occurrence,
        source: .phonePedometer,
        measurementInterval: DateInterval(start: start, duration: 300),
        aggregateStepCount: 10,
        capturedAt: start.addingTimeInterval(300)
    ))
    #expect(tenAttempt.state == .succeededLocal)
}

@Test func evidenceCannotExtendDeadline() throws {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let occurrence = UUID()
    var attempt = LocalAttempt(occurrenceID: occurrence, scheduledAt: start)
    try attempt.activate(at: start)
    #expect(throws: VerificationEvidenceError.intervalOutsideAttemptWindow) {
        try attempt.recordPhoneEvidence(VerificationEvidence(
            occurrenceID: occurrence,
            source: .phonePedometer,
            measurementInterval: DateInterval(start: start, duration: 301),
            aggregateStepCount: 10,
            capturedAt: start.addingTimeInterval(301)
        ))
    }
}

@Test func provisionalFailureMayBeCorrected() throws {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    var attempt = LocalAttempt(occurrenceID: UUID(), scheduledAt: start)
    try attempt.activate(at: start)
    try attempt.markSensorUnavailable()
    try attempt.applyServerOutcome(.provisionalFailure)
    try attempt.applyServerOutcome(.correctedSuccess)
    #expect(attempt.state == .correctedSuccess)
}

@Test func neutralDatesDoNotBreakStreak() {
    let now = Date()
    let days = [
        StreakDay(localDate: now, outcome: .success),
        StreakDay(localDate: now.addingTimeInterval(-86_400), outcome: .neutral),
        StreakDay(localDate: now.addingTimeInterval(-172_800), outcome: .success),
        StreakDay(localDate: now.addingTimeInterval(-259_200), outcome: .failure)
    ]
    #expect(StreakCalculator.currentStreak(days) == 2)
}
