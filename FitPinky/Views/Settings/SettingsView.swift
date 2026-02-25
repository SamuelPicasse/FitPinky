import SwiftUI

struct SettingsView: View {
    @Environment(ActiveDataService.self) private var dataService
    @State private var showLeaveConfirmation = false
    @State private var displayNameField: String = ""
    @FocusState private var displayNameFocused: Bool
    @State private var wagerDebounceTask: Task<Void, Never>?

    private var currentWeek: WeeklyGoal { dataService.getCurrentWeek() }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.surfaceBackground.ignoresSafeArea()

                List {
                    profileSection
                    goalSection
                    wagerSection
                    groupSection
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear { displayNameField = dataService.currentUser.displayName }
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundStyle(Color.brand)
                    .frame(width: 24)
                TextField("Display name", text: $displayNameField)
                    .focused($displayNameFocused)
                    .foregroundStyle(.white)
                    .onChange(of: displayNameFocused) { _, focused in
                        if !focused {
                            Task { try? await dataService.updateDisplayName(displayNameField) }
                        }
                    }
            }
            .listRowBackground(Color.cardBackground)
        } header: {
            Text("Profile")
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Goal

    private var goalSection: some View {
        Section {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(Color.brand)
                    .frame(width: 24)
                Text("Weekly goal")
                    .foregroundStyle(.white)
                Spacer()
                Stepper(
                    "\(dataService.currentUser.weeklyGoal) days",
                    value: Bindable(dataService).currentUser.weeklyGoal,
                    in: 1...7
                )
                .foregroundStyle(.white)
                .onChange(of: dataService.currentUser.weeklyGoal) { _, newValue in
                    Task { try? await dataService.updateWeeklyGoal(newValue) }
                }
            }
            .listRowBackground(Color.cardBackground)

            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(Color.brand)
                    .frame(width: 24)
                Text("Week starts on")
                    .foregroundStyle(.white)
                Spacer()
                Picker("", selection: Bindable(dataService).pair.weekStartDay) {
                    Text("Monday").tag(1)
                    Text("Tuesday").tag(2)
                    Text("Wednesday").tag(3)
                    Text("Thursday").tag(4)
                    Text("Friday").tag(5)
                    Text("Saturday").tag(6)
                    Text("Sunday").tag(7)
                }
                .tint(Color.brand)
                .onChange(of: dataService.pair.weekStartDay) { _, newValue in
                    Task { try? await dataService.updateWeekStartDay(newValue) }
                }
            }
            .listRowBackground(Color.cardBackground)
        } header: {
            Text("Goal")
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Wager

    private var wagerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(Color.brand)
                        .frame(width: 24)
                    Text("This week's wager")
                        .foregroundStyle(.white)
                }
                TextField("e.g. Loser buys sushi", text: wagerBinding)
                    .foregroundStyle(.white)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color.surfaceBackground, in: RoundedRectangle(cornerRadius: 8))

                HStack {
                    Spacer()
                    Text("\(currentWeek.wagerText.count)/200")
                        .font(.caption2)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .listRowBackground(Color.cardBackground)
        } header: {
            Text("Wager")
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var wagerBinding: Binding<String> {
        Binding(
            get: { currentWeek.wagerText },
            set: { newValue in
                let trimmed = String(newValue.prefix(200))
                if let index = dataService.weeklyGoals.firstIndex(where: { $0.result == nil }) {
                    dataService.weeklyGoals[index].wagerText = trimmed
                }
                wagerDebounceTask?.cancel()
                wagerDebounceTask = Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled else { return }
                    try? await dataService.updateWager(text: trimmed)
                }
            }
        )
    }

    // MARK: - Group

    private var groupSection: some View {
        Section {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(Color.brand)
                    .frame(width: 24)
                Text("Partner")
                    .foregroundStyle(.white)
                Spacer()
                Text(dataService.partner.displayName)
                    .foregroundStyle(Color.textSecondary)
            }
            .listRowBackground(Color.cardBackground)

            HStack {
                Image(systemName: "ticket.fill")
                    .foregroundStyle(Color.brand)
                    .frame(width: 24)
                Text("Invite code")
                    .foregroundStyle(.white)
                Spacer()
                Text(dataService.pair.inviteCode)
                    .foregroundStyle(Color.textSecondary)
                    .monospacedDigit()
                Button {
                    UIPasteboard.general.string = dataService.pair.inviteCode
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(Color.brand)
                }
            }
            .listRowBackground(Color.cardBackground)

            Button(role: .destructive) {
                showLeaveConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .frame(width: 24)
                    Text("Leave Group")
                }
            }
            .listRowBackground(Color.cardBackground)
            .confirmationDialog(
                "Leave this group?",
                isPresented: $showLeaveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Leave Group", role: .destructive) {
                    // TODO: Implement leaveGroup() in CloudKitService and DataServiceProtocol
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your workout history will be preserved, but you'll need a new invite code to rejoin.")
            }
        } header: {
            Text("Group")
                .foregroundStyle(Color.textSecondary)
        }
    }
}
