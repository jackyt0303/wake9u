import SwiftUI
import SwiftData
import Wake9uDomain

@main
struct Wake9uApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: CachedConfiguration.self, LocalAttemptRecord.self)
        } catch {
            fatalError("Unable to create Wake9u local store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}

private struct RootView: View {
    @AppStorage("wake9u.isSignedIn") private var isSignedIn = false

    var body: some View {
        NavigationStack {
            if isSignedIn {
                DashboardView()
            } else {
                SignInGateView(onSignedIn: { isSignedIn = true })
            }
        }
    }
}

private struct SignInGateView: View {
    let onSignedIn: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Sign in to arm Wake9u", systemImage: "alarm.waves.left.and.right")
        } description: {
            Text("A synced Sign in with Apple account is required before an alarm can count toward your streak.")
        } actions: {
            Button("Continue with Apple", action: onSignedIn)
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Connects your account before a streak-counting schedule can be enabled.")
        }
        .padding()
    }
}

private struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CachedConfiguration.updatedAt, order: .reverse) private var configurations: [CachedConfiguration]

    var body: some View {
        List {
            Section("Today") {
                Label("No active wake-up attempt", systemImage: "figure.walk")
                Text("Your phone records only aggregate steps during the five-minute verification window.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Schedule") {
                if let configuration = configurations.first {
                    LabeledContent("Status", value: configuration.syncLabel)
                    LabeledContent("Timezone", value: configuration.timeZoneIdentifier)
                } else {
                    Text("Create and sync a schedule before it can count toward your streak.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Wake9u")
        .toolbar {
            NavigationLink("Settings") {
                SettingsPlaceholderView()
            }
        }
    }
}

private struct SettingsPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Schedule setup",
            systemImage: "calendar.badge.clock",
            description: Text("AlarmKit authorization, schedule editing, and cloud sync are connected in the next implementation slice.")
        )
        .navigationTitle("Settings")
    }
}
