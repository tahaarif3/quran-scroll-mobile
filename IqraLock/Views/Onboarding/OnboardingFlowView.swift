import SwiftUI
import SwiftData
import IqraLockKit

struct OnboardingFlowView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @State private var vm: OnboardingViewModel
    @State private var selectedPlan: PaywallPlan = .annual
    @State private var mockSelected: Set<String> = []

    init() {
        _vm = State(initialValue: OnboardingViewModel())
    }

    var body: some View {
        Group {
            switch vm.step {
            case .welcome: welcome
            case .howItWorks: howItWorks
            case .socialProof: socialProof
            case .screenTime: questionScreen(
                title: "How much time do you spend on your phone each day?",
                subtitle: "Be honest — this shapes your personal plan.",
                options: ScreenTimeAnswer.allCases.map { ($0.rawValue, nil as String?, nil as String?, $0) },
                selected: vm.answers.screenTime,
                onSelect: vm.selectScreenTime
            )
            case .reveal: reveal
            case .reframe: reframe
            case .promise: promise
            case .age: questionScreen(
                title: "How old are you?",
                subtitle: "Used only to personalize your projections.",
                options: AgeBucket.allCases.map { ($0.rawValue, nil as String?, nil as String?, $0) },
                selected: vm.answers.age,
                onSelect: vm.selectAge
            )
            case .gender: questionScreen(
                title: "How should we address you?",
                subtitle: nil,
                options: GenderAnswer.allCases.map { ($0.rawValue, nil as String?, nil as String?, $0) },
                selected: vm.answers.gender,
                onSelect: vm.selectGender
            )
            case .faith: questionScreen(
                title: "Where are you in your faith journey?",
                subtitle: nil,
                options: FaithStage.allCases.map { ($0.rawValue, nil as String?, nil as String?, $0) },
                selected: vm.answers.faithStage,
                onSelect: vm.selectFaith
            )
            case .arabic: questionScreen(
                title: "How is your Arabic reading?",
                subtitle: nil,
                options: ArabicAbility.allCases.map { ($0.rawValue, nil as String?, nil as String?, $0) },
                selected: vm.answers.arabicAbility,
                onSelect: vm.selectArabic
            )
            case .frequency: questionScreen(
                title: "How often do you read Qur'an today?",
                subtitle: nil,
                options: ReadFrequency.allCases.map { ($0.rawValue, nil as String?, nil as String?, $0) },
                selected: vm.answers.readFrequency,
                onSelect: vm.selectFrequency
            )
            case .readingStyle: questionScreen(
                title: "How do you prefer to read?",
                subtitle: "You can change this anytime in You.",
                options: ReadingStyleAnswer.allCases.map { ($0.rawValue, nil as String?, nil as String?, $0) },
                selected: vm.answers.readingStyle,
                onSelect: vm.selectReadingStyle
            )
            case .goals: goals
            case .permissionPrimer: permissionPrimer
            case .appPicker: appPicker
            case .systemPrompt: systemPrompt
            case .rating: rating
            case .planReady: planReady
            case .paywall: paywall
            }
        }
        .animation(.easeOut(duration: 0.28), value: vm.step)
        .onAppear { vm.onAppear() }
    }

    // MARK: Screens

    private var welcome: some View {
        OnboardingScaffold(
            progress: nil,
            showsBack: false,
            ctaTitle: vm.ctaTitle,
            onCTA: vm.next
        ) {
            VStack(alignment: .leading, spacing: 20) {
                Spacer(minLength: 40)
                Text("IqraLock")
                    .iqraStyle(.wordmark, color: IQColor.olive)
                HighlightedText(
                    "The focus app that locks **distracting apps** until you read Qur'an.",
                    style: .h1,
                    highlight: IQColor.brandHighlight
                )
                Text("Shield Instagram, TikTok, and the rest — unlock them by finishing today's pages.")
                    .iqraStyle(.body, color: IQColor.textSecondary)
                Spacer(minLength: 20)
                HStack(spacing: 10) {
                    LockedAppTile(label: "Instagram", systemImage: "camera")
                    LockedAppTile(label: "TikTok", systemImage: "play.rectangle")
                    LockedAppTile(label: "X", systemImage: "at")
                    LockedAppTile(label: "YouTube", systemImage: "play.tv")
                }
                .frame(maxWidth: .infinity)
                LaurelBadge(title: "#1 Muslim Focus App", subtitle: "Built for the ummah")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var howItWorks: some View {
        OnboardingScaffold(showsBack: true, onBack: vm.back, ctaTitle: vm.ctaTitle, onCTA: vm.next) {
            VStack(alignment: .leading, spacing: 22) {
                HighlightedText("Three steps. **One habit.**", style: .h1)
                stepRow(n: "1", title: "Pick the apps that steal your time", body: "Instagram, TikTok, games — you choose.")
                stepRow(n: "2", title: "Read your daily Qur'an pages", body: "A small, realistic goal. Offline Arabic included.")
                stepRow(n: "3", title: "Apps unlock for the rest of the day", body: "Miss the goal? They stay locked until you finish.")
            }
            .padding(.top, 12)
        }
    }

    private var socialProof: some View {
        OnboardingScaffold(showsBack: true, onBack: vm.back, ctaTitle: vm.ctaTitle, onCTA: vm.next) {
            VStack(alignment: .leading, spacing: 18) {
                HighlightedText("Muslims are **taking their time back.**", style: .h1)
                StarRating(rating: 5)
                Text("\"I finished more Qur'an in two weeks than the last two years.\"")
                    .iqraStyle(.h3, color: IQColor.textPrimary)
                Text("— Brother from London")
                    .iqraStyle(.caption, color: IQColor.textSecondary)
                SectionCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Join thousands building a daily khatm habit.")
                            .iqraStyle(.bodyStrong)
                        Text("Streaks, gentle reminders, and real Screen Time shields.")
                            .iqraStyle(.body, color: IQColor.textSecondary)
                    }
                }
            }
            .padding(.top, 12)
        }
    }

    private var reveal: some View {
        let p = vm.projection
        return OnboardingScaffold(showsBack: true, onBack: vm.back, ctaTitle: vm.ctaTitle, onCTA: vm.next) {
            VStack(alignment: .leading, spacing: 18) {
                HighlightedText(
                    "At this rate, that's **\(p.yearsLost) years** on your phone.",
                    style: .h1
                )
                Text("Time you will never get back — unless you redirect it.")
                    .iqraStyle(.body, color: IQColor.textSecondary)
                SectionCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(String(format: "%.1f", p.hoursPerDay))h / day × a lifetime")
                            .iqraStyle(.captionStrong, color: IQColor.olive)
                        Text("The average Muslim's scroll adds up faster than a khatm.")
                            .iqraStyle(.body, color: IQColor.textSecondary)
                    }
                }
            }
            .padding(.top, 12)
        }
    }

    private var reframe: some View {
        let p = vm.projection
        return OnboardingScaffold(showsBack: true, onBack: vm.back, ctaTitle: vm.ctaTitle, onCTA: vm.next) {
            VStack(alignment: .leading, spacing: 18) {
                HighlightedText(
                    "Imagine **\(p.yearsBackToDeen) years back to your deen.**",
                    style: .h1
                )
                Text("Same minutes. Different destination.")
                    .iqraStyle(.body, color: IQColor.textSecondary)
                SectionCard {
                    Text("IqraLock turns phone-time into Qur'an-time — one page at a time.")
                        .iqraStyle(.body)
                }
            }
            .padding(.top, 12)
        }
    }

    private var promise: some View {
        let p = vm.projection
        return OnboardingScaffold(showsBack: true, onBack: vm.back, ctaTitle: vm.ctaTitle, onCTA: vm.next) {
            VStack(alignment: .leading, spacing: 18) {
                HighlightedText(
                    "Finish the Qur'an in **\(p.quranDays) days.**",
                    style: .h1
                )
                Text("A personal plan based on your answers — realistic pages, real shields.")
                    .iqraStyle(.body, color: IQColor.textSecondary)
            }
            .padding(.top, 12)
        }
    }

    private var goals: some View {
        OnboardingScaffold(
            progress: vm.step.progress,
            showsBack: true,
            onBack: vm.back,
            ctaTitle: vm.ctaTitle,
            ctaEnabled: vm.ctaEnabled,
            onCTA: vm.next
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HighlightedText("What do you want from IqraLock?", style: .h1)
                Text("Pick all that apply.")
                    .iqraStyle(.body, color: IQColor.textSecondary)
                ForEach(GoalAnswer.allCases) { goal in
                    OptionRow(
                        title: goal.rawValue,
                        emoji: goal.emoji,
                        isSelected: vm.answers.goals.contains(goal),
                        mode: .multi
                    ) {
                        vm.toggleGoal(goal)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private var permissionPrimer: some View {
        OnboardingScaffold(showsBack: true, onBack: vm.back, ctaTitle: vm.ctaTitle, onCTA: vm.next) {
            VStack(alignment: .leading, spacing: 18) {
                HighlightedText("Choose what to **lock.**", style: .h1)
                Text("Next you'll pick the apps that stay shielded until today's pages are done. Screen Time data never leaves your phone.")
                    .iqraStyle(.body, color: IQColor.textSecondary)
            }
            .padding(.top, 12)
        }
    }

    private var appPicker: some View {
        OnboardingScaffold(
            showsBack: true,
            onBack: vm.back,
            ctaTitle: vm.ctaTitle,
            ctaEnabled: vm.ctaEnabled,
            onCTA: vm.next
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HighlightedText("Which apps should wait for Qur'an?", style: .h1)
                Text("This screen wraps Apple's FamilyActivityPicker. On a real device, tap below to select apps.")
                    .iqraStyle(.body, color: IQColor.textSecondary)
                // Mock selection for Simulator / pre-entitlement builds
                ForEach([("Instagram", 1), ("TikTok", 2), ("YouTube", 3), ("Safari", 4)], id: \.1) { name, _ in
                    OptionRow(
                        title: name,
                        emoji: "🔒",
                        isSelected: vm.selectedAppsCount >= 1 && mockSelected.contains(name),
                        mode: .multi
                    ) {
                        toggleMockApp(name)
                    }
                }
                Text("\(vm.selectedAppsCount) apps selected")
                    .iqraStyle(.caption, color: IQColor.textSecondary)
            }
            .padding(.top, 8)
        }
    }

    private func toggleMockApp(_ name: String) {
        if mockSelected.contains(name) { mockSelected.remove(name) } else { mockSelected.insert(name) }
        vm.selectedAppsCount = mockSelected.count
        appModel.screenTime.persistSelectionCount(mockSelected.count)
    }

    private var systemPrompt: some View {
        OnboardingScaffold(showsBack: true, onBack: vm.back, ctaTitle: vm.ctaTitle, onCTA: {
            Task {
                try? await appModel.screenTime.requestAuthorization()
                vm.next()
            }
        }) {
            VStack(alignment: .leading, spacing: 18) {
                HighlightedText("Allow Screen Time access", style: .h1)
                Text("Apple will show a system prompt on top of this screen. Tap Allow so IqraLock can shield your selected apps.")
                    .iqraStyle(.body, color: IQColor.textSecondary)
                SectionCard {
                    HStack {
                        Image(systemName: "arrow.up")
                            .foregroundStyle(IQColor.goldBright)
                        Text("Tap Allow on the system alert")
                            .iqraStyle(.bodyStrong)
                    }
                }
            }
            .padding(.top, 12)
        }
    }

    private var rating: some View {
        OnboardingScaffold(showsBack: true, onBack: vm.back, ctaTitle: vm.ctaTitle, onCTA: vm.next) {
            VStack(spacing: 18) {
                HighlightedText("Loving IqraLock so far?", style: .h1, alignment: .center)
                StarRating(rating: 5)
                Text("A quick rating helps more Muslims find focus.")
                    .iqraStyle(.body, color: IQColor.textSecondary)
                    .multilineTextAlignment(.center)
                // Placeholder for founders photo from design 2p
                RoundedRectangle(cornerRadius: IQRadius.lg)
                    .fill(IQColor.oliveTint)
                    .frame(height: 160)
                    .overlay(
                        Text("Founders photo")
                            .iqraStyle(.caption, color: IQColor.textSecondary)
                    )
            }
            .padding(.top, 20)
        }
    }

    private var planReady: some View {
        OnboardingScaffold(showsBack: true, onBack: vm.back, ctaTitle: vm.ctaTitle, onCTA: {
            Task {
                _ = await appModel.notifications.requestPermission()
                appModel.notifications.scheduleDailyReminder(hour: 21, minute: 0)
                vm.next()
            }
        }) {
            VStack(alignment: .leading, spacing: 18) {
                HighlightedText("Your plan is ready!", style: .h1)
                SectionCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Daily goal")
                            .iqraStyle(.caption, color: IQColor.textSecondary)
                        Text("\(vm.derivedDailyGoal) pages / day")
                            .iqraStyle(.h2, color: IQColor.olive)
                        Text("We'll remind you in the evening — and shield apps until you're done.")
                            .iqraStyle(.body, color: IQColor.textSecondary)
                    }
                }
            }
            .padding(.top, 12)
        }
    }

    private var paywall: some View {
        PaywallView(
            purchases: appModel.purchases,
            selectedPlan: $selectedPlan,
            onClose: {
                finishOnboarding()
            },
            onPurchase: {
                Task {
                    do {
                        if selectedPlan == .annual {
                            try await appModel.purchases.purchaseAnnual()
                        } else {
                            try await appModel.purchases.purchaseWeekly()
                        }
                        appModel.analytics.track("purchase_completed", properties: [
                            "offering": appModel.purchases.offeringId,
                            "plan": selectedPlan.rawValue
                        ])
                        finishOnboarding()
                    } catch {
                        // stay on paywall
                    }
                }
            },
            onRestore: {
                Task {
                    try? await appModel.purchases.restore()
                    if appModel.purchases.hasPro { finishOnboarding() }
                }
            }
        )
        .onAppear {
            appModel.analytics.track("paywall_viewed", properties: [
                "offering": appModel.purchases.offeringId
            ])
        }
    }

    private func finishOnboarding() {
        let draft = vm.completeProfile()
        let profile = UserProfile(from: draft)
        modelContext.insert(profile)
        appModel.store.dailyGoalPages = draft.dailyGoalPages
        appModel.store.userDisplayName = draft.displayName
        appModel.store.ensureCurrentDay()
        if appModel.purchases.gate.canBlockApps {
            appModel.screenTime.applyShield()
            appModel.screenTime.scheduleMidnightReset()
        }
        try? modelContext.save()
        appModel.completeOnboarding()
    }

    // MARK: Helpers

    private func stepRow(n: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(n)
                .iqraStyle(.h3, color: IQColor.textInverse)
                .frame(width: 36, height: 36)
                .background(Circle().fill(IQColor.olive))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).iqraStyle(.bodyStrong)
                Text(body).iqraStyle(.body, color: IQColor.textSecondary)
            }
        }
    }

    private func questionScreen<T: Equatable>(
        title: String,
        subtitle: String?,
        options: [(String, String?, String?, T)],
        selected: T?,
        onSelect: @escaping (T) -> Void
    ) -> some View {
        OnboardingScaffold(
            progress: vm.step.progress,
            showsBack: true,
            onBack: vm.back,
            ctaTitle: vm.ctaTitle,
            ctaEnabled: vm.ctaEnabled,
            onCTA: vm.next
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HighlightedText(title, style: .h1)
                if let subtitle {
                    Text(subtitle).iqraStyle(.body, color: IQColor.textSecondary)
                }
                ForEach(Array(options.enumerated()), id: \.offset) { _, opt in
                    OptionRow(
                        title: opt.0,
                        subtitle: opt.1,
                        emoji: opt.2,
                        isSelected: selected == opt.3
                    ) {
                        onSelect(opt.3)
                    }
                }
            }
            .padding(.top, 8)
        }
    }
}

enum PaywallPlan: String {
    case annual, weekly
}
