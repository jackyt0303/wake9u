import ActivityKit
import AlarmKit
import Foundation
import SwiftUI

@available(iOS 26.0, *)
struct Wake9uAlarmMetadata: AlarmMetadata {
    let occurrenceID: UUID
}

@available(iOS 26.0, *)
actor AlarmKitScheduler {
    static let bundledSoundName = "wake9u_alarm.caf"

    enum SchedulerError: Error, Equatable {
        case authorizationDenied
        case notAuthorized
    }

    func requestAuthorizationIfNeeded() async throws {
        switch AlarmManager.shared.authorizationState {
        case .authorized:
            return
        case .denied:
            throw SchedulerError.authorizationDenied
        case .notDetermined:
            guard try await AlarmManager.shared.requestAuthorization() == .authorized else {
                throw SchedulerError.authorizationDenied
            }
        @unknown default:
            throw SchedulerError.authorizationDenied
        }
    }

    /// Schedules one immutable occurrence. Reconciliation code owns the rolling
    /// horizon and must never alter this occurrence's verification deadline.
    func schedule(occurrenceID: UUID, at scheduledAt: Date) async throws {
        guard AlarmManager.shared.authorizationState == .authorized else {
            throw SchedulerError.notAuthorized
        }

        let dismissButton = AlarmButton(text: "Dismiss", textColor: .white, systemImageName: "xmark")
        let presentation = AlarmPresentation(alert: AlarmPresentation.Alert(title: "Wake9u", stopButton: dismissButton))
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: Wake9uAlarmMetadata(occurrenceID: occurrenceID),
            tintColor: .red
        )
        let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: .fixed(scheduledAt),
            attributes: attributes,
            sound: .named(Self.bundledSoundName)
        )
        _ = try await AlarmManager.shared.schedule(id: occurrenceID, configuration: configuration)
    }

    func cancel(occurrenceID: UUID) throws {
        try AlarmManager.shared.cancel(id: occurrenceID)
    }
}
