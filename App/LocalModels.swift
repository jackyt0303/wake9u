import Foundation
import SwiftData

enum LocalSyncState: String, Codable {
    case draft
    case queued
    case synced
    case rejected
}

@Model
final class CachedConfiguration {
    @Attribute(.unique) var id: UUID
    var timeZoneIdentifier: String
    var syncStateRawValue: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        timeZoneIdentifier: String,
        syncState: LocalSyncState,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.timeZoneIdentifier = timeZoneIdentifier
        self.syncStateRawValue = syncState.rawValue
        self.updatedAt = updatedAt
    }

    var syncLabel: String {
        switch LocalSyncState(rawValue: syncStateRawValue) ?? .draft {
        case .draft: "Draft — sign in required"
        case .queued: "Armed locally — awaiting sync"
        case .synced: "Armed and counting"
        case .rejected: "Schedule needs attention"
        }
    }
}

@Model
final class LocalAttemptRecord {
    @Attribute(.unique) var id: UUID
    var occurrenceID: UUID
    var scheduledAt: Date
    var verificationEndsAt: Date
    var stateRawValue: String
    var aggregateStepCount: Int?
    var evidenceID: UUID?

    init(
        id: UUID = UUID(),
        occurrenceID: UUID,
        scheduledAt: Date,
        verificationEndsAt: Date,
        stateRawValue: String,
        aggregateStepCount: Int? = nil,
        evidenceID: UUID? = nil
    ) {
        self.id = id
        self.occurrenceID = occurrenceID
        self.scheduledAt = scheduledAt
        self.verificationEndsAt = verificationEndsAt
        self.stateRawValue = stateRawValue
        self.aggregateStepCount = aggregateStepCount
        self.evidenceID = evidenceID
    }
}
