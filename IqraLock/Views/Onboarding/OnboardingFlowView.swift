import SwiftUI
import SwiftData
import IqraLockKit

#if canImport(FamilyControls)
import FamilyControls
#endif

struct OnboardingFlowView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var vm: OnboardingViewModel
    @State private var selectedPlan: PaywallPlan = .annual
    /// Simulator-only stand-in; see `simulatorAppPicker`.
    @State private var mockSelected: Set<String> = []

    #if canImport(FamilyControls)
    /// Safe to construct anywhere — it is a value type. The type that traps off-device is
    /// `ManagedSettingsStore`, which is why only the *presentation* is gated on availability.
    @State private var activitySelection = FamilyActivitySelection()
    @State private var showingActivityPicker = false
    #endif

    init() {
        _vm = State(initialValue: OnboardingViewModel())
    }

    /// Incoming content enters from +24pt X; outgoing leaves to only −16pt. The asymmetry is
    /// deliberate — a matched pair reads as two pages swapping, where the short exit reads as
    /// one page pushing the last aside. Back gestures mirror it because SwiftUI reverses the
    /// insertion and removal edges automatically.
    private var stepTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .offset(x: 24).combined(with: .opacity),
            removal: .offset(x: -16).combined(with: .opacity)
        )
    }

    private var stepAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.2)
            : .spring(response: 0.38, dampingFraction: 0.9)
    }

    var body: some View {
        // The outer ZStack keeps a stable identity: `.id(vm.step)` below deliberately gives each
        // step a fresh identity so insertion and removal both fire, but attaching `.onAppear`
        // there would re-fire it on every step — and `vm.next()` already tracks the step view,
        // so each forward navigation would log `onboarding_step_viewed` twice.
        ZStack(alignment: .top) {
            stepContent
                .id(vm.step)
                .transition(stepTransition)

            // Drawn here, above the transitioning content, rather than inside each scaffold —
            // that is what gives it a single identity across the whole flow so the progress fill
            // animates instead of snapping. The paywall brings its own header.
            if vm.step != .paywall {
                OnboardingTopBar(
                    progress: vm.step.progress,
                    showsBack: vm.step.showsBack,
                    onBack: vm.back
                )
            }
        }
        .animation(stepAnimation, value: vm.step)
        .onAppear { vm.onAppear() }
    }

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch vm.step {
            case .welcome: welcome
            case .howItWorks: howItWorks
            case .socialProof: socialProof
            case .screenTime: question(
                title: "What is your average screen time?",
                subtitle: "This helps us tailor IqraLock to your daily habits.",
                options: ScreenTimeAnswer.allCases.map { .init(label: $0.rawValue, value: $0) },
                selected: vm.answers.screenTime,
                onSelect: vm.selectScreenTime
            )
            case .reveal: reveal
            case .reframe: reframe
            case .promise: promise
            case .age: question(
                title: "How old are you?",
                subtitle: "Used only to personalize your projections.",
                options: AgeBucket.allCases.map { .init(label: $0.rawValue, value: $0) },
                selected: vm.answers.age,
                onSelect: vm.selectAge
            )
            case .gender: question(
                title: "How do you identify?",
                subtitle: "So we can address you respectfully.",
                options: GenderAnswer.allCases.map { .init(label: $0.rawValue, icon: $0.icon, value: $0) },
                selected: vm.answers.gender,
                onSelect: vm.selectGender
            )
            case .faith: question(
                title: "Where are you in your faith journey?",
                subtitle: "There’s no wrong answer.",
                options: FaithStage.allCases.map { .init(label: $0.rawValue, icon: $0.icon, value: $0) },
                selected: vm.answers.faithStage,
                onSelect: vm.selectFaith
            )
            case .arabic: question(
                title: "How is your Arabic reading?",
                subtitle: "This sets your default reader layout.",
                options: ArabicAbility.allCases.map { .init(label: $0.rawValue, icon: $0.icon, value: $0) },
                selected: vm.answers.arabicAbility,
                onSelect: vm.selectArabic
            )
            case .frequency: question(
                title: "How often do you read Qur'an today?",
                subtitle: "Be honest — we’ll meet you where you are.",
                options: ReadFrequency.allCases.map { .init(label: $0.rawValue, icon: $0.icon, value: $0) },
                selected: vm.answers.readFrequency,
                onSelect: vm.selectFrequency
            )
            case .readingStyle: question(
                title: "How would you like to read?",
                subtitle: "You can change this anytime in settings.",
                options: ReadingStyleAnswer.allCases.map { .init(label: $0.rawValue, value: $0) },
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
    }

    /// Reveal, reframe and promise stagger their icon, headline and subline 8pt into place.
    /// Question screens deliberately appear as one block — staggering a list of options reads
    /// as jitter rather than choreography.
    private func heroStack(_ elements: [AnyView]) -> some View {
        HeroStack(reduceMotion: reduceMotion, elements: elements)
    }

    // MARK: - Intro

    private var welcome: some View {
        OnboardingScaffold(
            backdrop: .welcomeRadial,
            ctaTitle: vm.ctaTitle,
            centersContent: true,
            onCTA: vm.next
        ) {
            VStack(spacing: 18) {
                IqraAppIcon(size: 108)
                    .padding(.bottom, 8)
                Text("Welcome to")
                    .iqraStyle(.subtitle, color: IQColor.textMuted)
                Text("IqraLock")
                    .iqraStyle(.wordmark, color: IQColor.brandPrimary)
                Text("Read the Qur'an, before you scroll.")
                    .iqraStyle(.subtitle, color: IQColor.textMuted2)
                    .multilineTextAlignment(.center)
                LaurelBadge()
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var howItWorks: some View {
        OnboardingScaffold(ctaTitle: vm.ctaTitle, centersContent: true, onCTA: vm.next) {
            VStack(spacing: 22) {
                HighlightedText(
                    "IqraLock **locks distracting apps** until…",
                    style: .h1,
                    highlight: IQColor.brandPrimary,
                    alignment: .center
                )
                HStack(spacing: 8) {
                    ForEach(LockedAppTile.Brand.allCases, id: \.self) { brand in
                        LockedAppTile(brand: brand)
                    }
                }
                HighlightedText(
                    "You **read the Qur'an** every day",
                    style: .h1,
                    highlight: IQColor.brandPrimary,
                    alignment: .center,
                    trailingIcon: .dua
                )
            }
        }
    }

    private var socialProof: some View {
        OnboardingScaffold(ctaTitle: vm.ctaTitle, onCTA: vm.next) {
            VStack(spacing: 20) {
                HighlightedText(
                    "Thousands of Muslims read the Qur'an daily with **IqraLock**",
                    style: .h1,
                    highlight: IQColor.brandPrimary,
                    alignment: .center
                )
                LaurelBadge()
                SectionCard(elevated: true) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            StarRating()
                            Spacer()
                            Text("Yusuf, 28")
                                .iqraStyle(.caption, color: IQColor.textMuted)
                        }
                        Text("Life-changing, mashaAllah")
                            .iqraStyle(.bodyStrong, color: IQColor.textInk)
                        Text("I open the Qur'an before I even touch Instagram now. 40-day streak and I feel completely different.")
                            .iqraStyle(.body, color: IQColor.textMuted2)
                    }
                }
            }
            .padding(.top, 12)
        }
    }

    // MARK: - Reveal / reframe / promise

    private var reveal: some View {
        let years = vm.projection.yearsLost
        return OnboardingScaffold(ctaTitle: vm.ctaTitle, centersContent: true, onCTA: vm.next) {
            heroStack([
                AnyView(IQIconView(.mindBlown, size: IQIcon.heroSize)),
                AnyView(HighlightedText(
                    "At this rate, you're going to spend **\(years) years** of your life on your phone.",
                    style: .h1,
                    highlight: IQColor.brandGold,
                    alignment: .center
                ))
            ])
        }
    }

    private var reframe: some View {
        let years = vm.projection.yearsBackToDeen
        return OnboardingScaffold(ctaTitle: vm.ctaTitle, centersContent: true, onCTA: vm.next) {
            heroStack([
                AnyView(IQIconView(.dua, size: IQIcon.heroSize)),
                // The two lines are one headline, so they rise together rather than as
                // separate beats — the inner 10pt spacing is part of the phrase.
                AnyView(VStack(spacing: 10) {
                    Text("…but the good news is, we'll help you give")
                        .iqraStyle(.h1, color: IQColor.textInk)
                        .multilineTextAlignment(.center)
                    HighlightedText(
                        "**\(years) years** back to your deen.",
                        style: .h1,
                        highlight: IQColor.brandGold,
                        alignment: .center
                    )
                })
            ])
        }
    }

    private var promise: some View {
        let days = vm.projection.quranDays
        return OnboardingScaffold(ctaTitle: vm.ctaTitle, centersContent: true, onCTA: vm.next) {
            heroStack([
                AnyView(IQIconView(.book, size: IQIcon.heroSize)),
                AnyView(HighlightedText(
                    "You could read the entire Qur'an in **\(days) days**",
                    style: .h1,
                    highlight: IQColor.brandGold,
                    alignment: .center
                )),
                AnyView(
                    Text("if you traded scroll time for scripture time.")
                        .iqraStyle(.subtitle, color: IQColor.textMuted2)
                        .multilineTextAlignment(.center)
                )
            ])
        }
    }

    // MARK: - Goals / permission / rating / plan

    private var goals: some View {
        OnboardingScaffold(
            ctaTitle: vm.ctaTitle,
            ctaEnabled: vm.ctaEnabled,
            onCTA: vm.next
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HighlightedText("What do you want to achieve with IqraLock?", style: .h1)
                Text("Select all that apply.")
                    .iqraStyle(.subtitle, color: IQColor.textMuted)
                ForEach(GoalAnswer.allCases) { goal in
                    OptionRow(
                        title: goal.rawValue,
                        icon: goal.icon,
                        isSelected: vm.answers.goals.contains(goal),
                        mode: .multi
                    ) { vm.toggleGoal(goal) }
                }
            }
            .padding(.top, 8)
        }
    }

    private var permissionPrimer: some View {
        OnboardingScaffold(ctaTitle: vm.ctaTitle, centersContent: true, onCTA: vm.next) {
            VStack(spacing: 22) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(hex: 0x4B44E0))
                        .frame(width: 88, height: 88)
                        .overlay(IQIconView(.hourglass, size: 44))
                        .rotationEffect(.degrees(-12))
                        .offset(x: -36)
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                    IqraAppIcon(size: 88)
                        .rotationEffect(.degrees(10))
                        .offset(x: 36)
                }
                .frame(height: 120)
                Text("Connect IqraLock to Screen Time, securely")
                    .iqraStyle(.h1, color: IQColor.textInk)
                    .multilineTextAlignment(.center)
                Text("We sync with Apple Screen Time to help you swap scrolling for scripture.")
                    .iqraStyle(.subtitle, color: IQColor.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var appPicker: some View {
        OnboardingScaffold(
            ctaTitle: vm.ctaTitle,
            ctaEnabled: vm.ctaEnabled,
            onCTA: vm.next
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HighlightedText("Which apps should wait for Qur'an?", style: .h1)
                Text("Select the apps IqraLock should shield until you finish today's pages.")
                    .iqraStyle(.subtitle, color: IQColor.textMuted)

                if ScreenTimeAvailability.isSupported {
                    realAppPicker
                } else {
                    simulatorAppPicker
                }
            }
            .padding(.top, 8)
        }
    }

    /// Device path. Apple's own picker is the only way to obtain `ApplicationToken`s — they are
    /// opaque and cannot be constructed from a bundle id, which is why the mock list below can
    /// never shield anything.
    @ViewBuilder
    private var realAppPicker: some View {
        #if canImport(FamilyControls)
        Button {
            showingActivityPicker = true
        } label: {
            HStack(spacing: 14) {
                IQIconView(.lock, size: IQIcon.rowSize)
                    .frame(width: IQIcon.rowColumnWidth)
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedAppsSummary)
                        .iqraStyle(.option, color: IQColor.textInk)
                    Text("Tap to choose apps and categories")
                        .iqraStyle(.caption, color: IQColor.textMuted)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(IQColor.textFaint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: IQRadius.option, style: .continuous)
                    .fill(vm.selectedAppsCount > 0 ? IQColor.oliveTint : IQColor.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: IQRadius.option, style: .continuous)
                    .strokeBorder(
                        vm.selectedAppsCount > 0 ? IQColor.accentOlive : IQColor.borderSubtle,
                        lineWidth: vm.selectedAppsCount > 0 ? 2 : 1.6
                    )
            )
        }
        .buttonStyle(.plain)
        .familyActivityPicker(isPresented: $showingActivityPicker, selection: $activitySelection)
        .onChange(of: activitySelection) { _, newValue in
            persistActivitySelection(newValue)
        }
        #endif
    }

    /// Simulator / un-entitled builds, where FamilyControls traps at runtime. Keeps the flow
    /// walkable; it records a count so the CTA enables, but shields nothing.
    private var simulatorAppPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(LockedAppTile.Brand.allCases, id: \.self) { brand in
                OptionRow(
                    title: brand.label,
                    icon: .lock,
                    isSelected: mockSelected.contains(brand.label),
                    mode: .multi
                ) {
                    if mockSelected.contains(brand.label) {
                        mockSelected.remove(brand.label)
                    } else {
                        mockSelected.insert(brand.label)
                    }
                    vm.selectedAppsCount = mockSelected.count
                    appModel.screenTime.persistSelectionCount(mockSelected.count)
                }
            }
            Text("Simulator preview — real app blocking needs a device.")
                .iqraStyle(.caption, color: IQColor.textFaint)
        }
    }

    private var selectedAppsSummary: String {
        switch vm.selectedAppsCount {
        case 0: return "Choose apps to shield"
        case 1: return "1 app or category selected"
        default: return "\(vm.selectedAppsCount) apps and categories selected"
        }
    }

    #if canImport(FamilyControls)
    private func persistActivitySelection(_ selection: FamilyActivitySelection) {
        // Order matters: the encoded selection must land in the App Group before the count, so
        // that anything reacting to the count can already load real tokens.
        try? FamilyActivitySelectionStore.save(selection, to: appModel.store)
        let count = selection.applicationTokens.count + selection.categoryTokens.count
        vm.selectedAppsCount = count
        appModel.screenTime.persistSelectionCount(count)
    }
    #endif

    private var systemPrompt: some View {
        OnboardingScaffold(ctaTitle: vm.ctaTitle, centersContent: true, onCTA: {
            Task {
                try? await appModel.screenTime.requestAuthorization()
                vm.next()
            }
        }) {
            VStack(spacing: 18) {
                Text("Connect IqraLock to Screen Time, securely")
                    .iqraStyle(.h1, color: IQColor.textInk)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("We sync with Apple Screen Time to help you swap scrolling for scripture.")
                    .iqraStyle(.subtitle, color: IQColor.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Faux iOS alert
                VStack(spacing: 0) {
                    Text("\"IqraLock\" Would Like to Access Screen Time")
                        .font(.system(size: 17, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.top, 18)
                    Text("Providing \"IqraLock\" access to Screen Time may allow it to see your activity data, restrict content, and limit the usage of apps and websites.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: 0x3C3C43).opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 14)
                    Divider()
                    HStack(spacing: 0) {
                        Text("Don't Allow")
                            .font(.system(size: 17))
                            .foregroundStyle(Color(hex: 0x007AFF))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        Divider().frame(height: 44)
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x007AFF))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(hex: 0xF4E8D0).opacity(0.55))
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: 0xEDEBE9))
                )

                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(IQColor.textInk)
                    Text("Tap Continue")
                        .iqraStyle(.bodyStrong, color: IQColor.textInk)
                }
                .padding(.top, 4)
            }
        }
    }

    private var rating: some View {
        OnboardingScaffold(ctaTitle: vm.ctaTitle, onCTA: vm.next) {
            VStack(spacing: 18) {
                HighlightedText(
                    "Support our mission with a rating",
                    style: .h1,
                    alignment: .center,
                    trailingIcon: .heart
                )
                RoundedRectangle(cornerRadius: IQRadius.xl, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x8B6A3A), Color(hex: 0xC4A574)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 180)
                    .overlay(
                        VStack(spacing: 8) {
                            IQIconView(.people, size: 40)
                            Text("Founders photo")
                                .font(.custom("Nunito-SemiBold", size: 15))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: IQRadius.xl, style: .continuous)
                            .strokeBorder(Color.white, lineWidth: 4)
                    )
                    .shadow(color: IQShadow.elevated.color, radius: IQShadow.elevated.radius, y: IQShadow.elevated.y)
                Text("We're two friends who wanted to grow closer to Allah, and further from our phones. So we built IqraLock — for us, and for you.")
                    .iqraStyle(.body, color: IQColor.textMuted2)
                    .multilineTextAlignment(.center)
                VStack(spacing: 8) {
                    StarRating()
                    HStack(spacing: 10) {
                        LaurelMark(.leading)
                        Text("Freed me from my phone. I've never felt closer to Allah.")
                            .iqraStyle(.bodyStrong, color: IQColor.textInk)
                            .multilineTextAlignment(.center)
                        LaurelMark(.trailing)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private var planReady: some View {
        OnboardingScaffold(ctaTitle: vm.ctaTitle, centersContent: true, onCTA: {
            Task {
                _ = await appModel.notifications.requestPermission()
                appModel.notifications.scheduleDailyReminder(hour: 21, minute: 0)
                vm.next()
            }
        }) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Your plan is ready!")
                    .iqraStyle(.h1PlanReady, color: IQColor.textInk)
                Text("This week IqraLock will help you:")
                    .iqraStyle(.subtitle, color: IQColor.textMuted)
                planBullet("Build the **daily Qur'an habit** you'll actually stick with")
                planBullet("Reclaim your time from **endless scrolling** and mindless consumption")
                planBullet("**Draw closer to Allah**, and focus on what truly matters")
            }
        }
    }

    private func planBullet(_ markdown: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(IQColor.accentOlive).frame(width: 26, height: 26)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            HighlightedText(markdown, style: .bodyStrong, highlight: IQColor.textInk)
        }
    }

    private var paywall: some View {
        PaywallView(
            purchases: appModel.purchases,
            selectedPlan: $selectedPlan,
            onSkip: {
                appModel.analytics.track("paywall_skipped", properties: [
                    "offering": appModel.purchases.offeringId
                ])
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
                    } catch {}
                }
            },
            onRestore: {
                Task {
                    try? await appModel.purchases.restore()
                    if appModel.purchases.hasPro { finishOnboarding() }
                }
            },
            onSkipRevealed: {
                appModel.analytics.track("paywall_skip_revealed", properties: [:])
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
        // Upsert: re-running onboarding must not leave two profiles, which would make
        // `profiles.first` — read by Home, Reader and You — non-deterministic.
        let existing = try? modelContext.fetch(FetchDescriptor<UserProfile>())
        if let profile = existing?.first {
            profile.apply(draft)
            for duplicate in (existing ?? []).dropFirst() {
                modelContext.delete(duplicate)
            }
        } else {
            modelContext.insert(UserProfile(from: draft))
        }
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

    // MARK: - Question helper

    private struct QOption<T: Equatable> {
        var label: String
        var icon: IQIcon? = nil
        var value: T
    }

    private func question<T: Equatable>(
        title: String,
        subtitle: String?,
        options: [QOption<T>],
        selected: T?,
        onSelect: @escaping (T) -> Void
    ) -> some View {
        OnboardingScaffold(
            ctaTitle: vm.ctaTitle,
            ctaEnabled: vm.ctaEnabled,
            onCTA: vm.next
        ) {
            VStack(alignment: .leading, spacing: IQSpace.optionGap) {
                HighlightedText(title, style: .h1)
                if let subtitle {
                    Text(subtitle)
                        .iqraStyle(.subtitle, color: IQColor.textMuted)
                        .padding(.bottom, 4)
                }
                ForEach(Array(options.enumerated()), id: \.offset) { _, opt in
                    OptionRow(
                        title: opt.label,
                        icon: opt.icon,
                        isSelected: selected == opt.value
                    ) { onSelect(opt.value) }
                }
            }
            .padding(.top, 8)
        }
    }
}

enum PaywallPlan: String {
    case annual, weekly
}

/// Owns its own `appeared` flag so that re-entering a hero screen replays the stagger. State on
/// the parent flow view would latch after the first reveal and every later hero would pop in.
private struct HeroStack: View {
    let reduceMotion: Bool
    let elements: [AnyView]

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            ForEach(Array(elements.enumerated()), id: \.offset) { index, element in
                element
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared || reduceMotion ? 0 : 8)
                    .animation(
                        reduceMotion
                            ? .easeOut(duration: 0.2)
                            : .easeOut(duration: 0.32).delay(Double(index) * 0.05),
                        value: appeared
                    )
            }
        }
        .onAppear { appeared = true }
    }
}
