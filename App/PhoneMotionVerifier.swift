import CoreMotion
import Foundation
import Wake9uDomain

/// Produces only aggregate, fixed-window phone evidence. Raw motion samples are
/// neither persisted nor sent to the backend.
final class PhoneMotionVerifier: @unchecked Sendable {
    enum VerificationError: Error, Equatable {
        case stepCountingUnavailable
        case noPedometerData
        case invalidWindow
    }

    private let pedometer = CMPedometer()

    func liveProgress(startingAt start: Date) -> AsyncThrowingStream<Int, Error> {
        AsyncThrowingStream { continuation in
            guard CMPedometer.isStepCountingAvailable() else {
                continuation.finish(throwing: VerificationError.stepCountingUnavailable)
                return
            }
            pedometer.startUpdates(from: start) { data, error in
                if let error {
                    continuation.finish(throwing: error)
                } else if let count = data?.numberOfSteps.intValue {
                    continuation.yield(count)
                }
            }
        }
    }

    func stopLiveProgress() {
        pedometer.stopUpdates()
    }

    func finalEvidence(
        occurrenceID: UUID,
        window: OccurrenceWindow,
        capturedAt: Date = .now,
        sourceVersion: String = "1"
    ) async throws -> VerificationEvidence {
        guard window.endsAt >= window.scheduledAt else {
            throw VerificationError.invalidWindow
        }
        guard CMPedometer.isStepCountingAvailable() else {
            throw VerificationError.stepCountingUnavailable
        }

        let stepCount: Int = try await withCheckedThrowingContinuation { continuation in
            pedometer.queryPedometerData(from: window.scheduledAt, to: window.endsAt) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let count = data?.numberOfSteps.intValue {
                    continuation.resume(returning: count)
                } else {
                    continuation.resume(throwing: VerificationError.noPedometerData)
                }
            }
        }

        return try VerificationEvidence(
            occurrenceID: occurrenceID,
            source: .phonePedometer,
            measurementInterval: DateInterval(start: window.scheduledAt, end: window.endsAt),
            aggregateStepCount: stepCount,
            capturedAt: capturedAt
        )
    }
}
