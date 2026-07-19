import Foundation

public enum Weekday: Int, CaseIterable, Codable, Sendable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
}

public struct AlarmConfiguration: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let weekdays: Set<Weekday>
    public let localHour: Int
    public let localMinute: Int
    public let timeZoneIdentifier: String
    public let version: Int
    public let isEnabled: Bool

    public init(
        id: UUID = UUID(),
        weekdays: Set<Weekday>,
        localHour: Int,
        localMinute: Int,
        timeZoneIdentifier: String,
        version: Int,
        isEnabled: Bool
    ) throws {
        guard (0...23).contains(localHour), (0...59).contains(localMinute) else {
            throw AlarmConfigurationError.invalidLocalTime
        }
        guard TimeZone(identifier: timeZoneIdentifier) != nil else {
            throw AlarmConfigurationError.invalidTimeZone
        }
        guard version > 0 else { throw AlarmConfigurationError.invalidVersion }

        self.id = id
        self.weekdays = weekdays
        self.localHour = localHour
        self.localMinute = localMinute
        self.timeZoneIdentifier = timeZoneIdentifier
        self.version = version
        self.isEnabled = isEnabled
    }
}

public enum AlarmConfigurationError: Error, Equatable, Sendable {
    case invalidLocalTime
    case invalidTimeZone
    case invalidVersion
}

public struct OccurrenceWindow: Codable, Equatable, Sendable {
    public static let verificationDuration: TimeInterval = 5 * 60

    public let scheduledAt: Date
    public let endsAt: Date

    public init(scheduledAt: Date) {
        self.scheduledAt = scheduledAt
        self.endsAt = scheduledAt.addingTimeInterval(Self.verificationDuration)
    }

    public func contains(_ interval: DateInterval) -> Bool {
        interval.start >= scheduledAt && interval.end <= endsAt && interval.duration >= 0
    }
}

public enum OccurrenceResolver {
    /// Resolves one time for each requested local date. Nonexistent times advance to
    /// the next valid instant; ambiguous times use the first occurrence.
    public static func resolve(
        configuration: AlarmConfiguration,
        localDate: Date,
        calendar baseCalendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Date? {
        guard configuration.isEnabled,
              configuration.weekdays.contains(weekday(of: localDate, in: configuration.timeZoneIdentifier, calendar: baseCalendar))
        else { return nil }

        guard let timeZone = TimeZone(identifier: configuration.timeZoneIdentifier) else { return nil }
        var calendar = baseCalendar
        calendar.timeZone = timeZone
        let day = calendar.dateComponents([.year, .month, .day], from: localDate)
        guard let start = calendar.date(from: day) else { return nil }
        var components = DateComponents()
        components.hour = configuration.localHour
        components.minute = configuration.localMinute
        components.second = 0
        return calendar.nextDate(
            after: start.addingTimeInterval(-1),
            matching: components,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }

    private static func weekday(of date: Date, in timeZoneIdentifier: String, calendar baseCalendar: Calendar) -> Weekday {
        var calendar = baseCalendar
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        return Weekday(rawValue: calendar.component(.weekday, from: date)) ?? .sunday
    }
}
