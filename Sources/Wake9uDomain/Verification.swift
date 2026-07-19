import Foundation

public enum VerificationSource: String, Codable, Sendable {
    case phonePedometer
    case watchSupplemental
}

public struct VerificationEvidence: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let occurrenceID: UUID
    public let source: VerificationSource
    public let measurementInterval: DateInterval
    public let aggregateStepCount: Int
    public let capturedAt: Date

    public init(
        id: UUID = UUID(),
        occurrenceID: UUID,
        source: VerificationSource,
        measurementInterval: DateInterval,
        aggregateStepCount: Int,
        capturedAt: Date
    ) throws {
        guard aggregateStepCount >= 0 else { throw VerificationEvidenceError.negativeStepCount }
        self.id = id
        self.occurrenceID = occurrenceID
        self.source = source
        self.measurementInterval = measurementInterval
        self.aggregateStepCount = aggregateStepCount
        self.capturedAt = capturedAt
    }
}

public enum VerificationEvidenceError: Error, Equatable, Sendable {
    case negativeStepCount
    case intervalOutsideAttemptWindow
    case wrongOccurrence
}

public enum LocalAttemptState: String, Codable, Sendable {
    case scheduled
    case active
    case succeededLocal
    case failedLocal
    case sensorUnavailable
    case submitted
    case finalSuccess
    case provisionalFailure
    case finalFailure
    case correctedSuccess
}

public enum LocalAttemptTransitionError: Error, Equatable, Sendable {
    case cannotActivate
    case cannotFinalize
    case incompleteAttempt
}

public struct LocalAttempt: Codable, Equatable, Sendable, Identifiable {
    public static let successThreshold = 10

    public let id: UUID
    public let occurrenceID: UUID
    public let window: OccurrenceWindow
    public private(set) var state: LocalAttemptState
    public private(set) var evidence: VerificationEvidence?

    public init(id: UUID = UUID(), occurrenceID: UUID, scheduledAt: Date) {
        self.id = id
        self.occurrenceID = occurrenceID
        self.window = OccurrenceWindow(scheduledAt: scheduledAt)
        self.state = .scheduled
    }

    public mutating func activate(at date: Date) throws {
        guard state == .scheduled, date >= window.scheduledAt, date <= window.endsAt else {
            throw LocalAttemptTransitionError.cannotActivate
        }
        state = .active
    }

    public mutating func recordPhoneEvidence(_ evidence: VerificationEvidence) throws {
        guard state == .active, evidence.occurrenceID == occurrenceID else {
            throw LocalAttemptTransitionError.cannotFinalize
        }
        guard evidence.source == .phonePedometer else {
            throw LocalAttemptTransitionError.cannotFinalize
        }
        guard window.contains(evidence.measurementInterval) else {
            throw VerificationEvidenceError.intervalOutsideAttemptWindow
        }
        self.evidence = evidence
        state = evidence.aggregateStepCount >= Self.successThreshold ? .succeededLocal : .failedLocal
    }

    public mutating func markSensorUnavailable() throws {
        guard state == .active else { throw LocalAttemptTransitionError.cannotFinalize }
        state = .sensorUnavailable
    }

    public mutating func applyServerOutcome(_ outcome: LocalAttemptState) throws {
        switch outcome {
        case .submitted:
            guard [.succeededLocal, .failedLocal, .sensorUnavailable].contains(state) else {
                throw LocalAttemptTransitionError.incompleteAttempt
            }
        case .finalSuccess:
            guard state == .submitted || state == .succeededLocal else { throw LocalAttemptTransitionError.cannotFinalize }
        case .provisionalFailure, .finalFailure:
            guard state == .submitted || state == .failedLocal || state == .sensorUnavailable else {
                throw LocalAttemptTransitionError.cannotFinalize
            }
        case .correctedSuccess:
            guard state == .provisionalFailure else { throw LocalAttemptTransitionError.cannotFinalize }
        default:
            throw LocalAttemptTransitionError.cannotFinalize
        }
        state = outcome
    }
}
