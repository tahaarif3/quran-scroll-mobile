import SwiftUI
import SwiftData
import IqraLockKit

/// In-app previews of every OS shield layout.
struct ShieldPreviewView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var selectedMode: ShieldLayoutMode = .arabicAndTranslation
    @State private var segment: ShieldAyahProvider.Segmented?
    var lockedAppName: String = "Instagram"

    private var store: AppGroupStore { appModel.store }
    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    layoutPicker

                    Text("Live preview")
                        .iqraStyle(.captionStrong, color: IQColor.textMuted)
                        .padding(.horizontal, IQSpace.gutter)

                    ShieldLayoutPreviewCard(
                        mode: selectedMode,
                        segment: segment,
                        appName: lockedAppName,
                        store: store,
                        onPrimary: { applyModeAndOpenReader(selectedMode) },
                        onSecondary: { applyModeAndOpenReader(selectedMode) }
                    )
                    .padding(.horizontal, IQSpace.gutter)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("All lock screens")
                            .iqraStyle(.captionStrong, color: IQColor.textMuted)

                        ForEach(ShieldLayoutMode.allCases) { mode in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedMode = mode
                                }
                            } label: {
                                ShieldLayoutPreviewCard(
                                    mode: mode,
                                    segment: segment,
                                    appName: lockedAppName,
                                    store: store,
                                    compact: true,
                                    highlighted: mode == selectedMode
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, IQSpace.gutter)
                }
                .padding(.vertical, IQSpace.gutter)
            }
            .background(IQColor.bgSand.ignoresSafeArea())
            .navigationTitle("Lock screen preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                selectedMode = profile?.shieldLayoutMode ?? store.shieldLayoutMode
                segment = ShieldAyahProvider.segmented(for: store)
            }
        }
    }

    private var layoutPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lock screen layout")
                .iqraStyle(.h3)
            Text("Changes apply instantly on the real shield.")
                .iqraStyle(.caption, color: IQColor.textMuted)

            Picker("Layout", selection: $selectedMode) {
                ForEach(ShieldLayoutMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            .onChange(of: selectedMode) { _, newMode in
                applyLayout(newMode)
            }

            Text(selectedMode.detail)
                .iqraStyle(.caption, color: IQColor.textSecondary)
        }
        .padding(.horizontal, IQSpace.gutter)
    }

    private func applyLayout(_ mode: ShieldLayoutMode) {
        store.shieldLayoutMode = mode
        profile?.shieldLayoutMode = mode
        try? modelContext.save()
        appModel.shield.refreshShieldAppearance()
    }

    private func applyModeAndOpenReader(_ mode: ShieldLayoutMode) {
        applyLayout(mode)
        dismiss()
        appModel.showReader = true
    }
}

private struct ShieldLayoutPreviewCard: View {
    let mode: ShieldLayoutMode
    let segment: ShieldAyahProvider.Segmented?
    let appName: String
    let store: AppGroupStore
    var compact: Bool = false
    var highlighted: Bool = false
    var onPrimary: (() -> Void)?
    var onSecondary: (() -> Void)?

    private var content: ShieldLayoutPresentation.Content {
        ShieldLayoutPresentation.make(
            mode: mode,
            segment: segment,
            appName: appName,
            store: store,
            recentlyRejected: false
        )
    }

    var body: some View {
        VStack(spacing: compact ? 12 : 20) {
            if compact {
                HStack {
                    Text(mode.displayName)
                        .iqraStyle(.captionStrong, color: IQColor.lockCTA)
                    Spacer()
                    if highlighted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(IQColor.accentOlive)
                    }
                }
            }

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: compact ? 48 : 72, height: compact ? 48 : 72)
                IQIconView(.lock, size: compact ? 22 : 32)
            }

            previewText(content.title, arabic: mode != .translationOnly && mode != .none)
            previewText(content.subtitle, arabic: false, secondary: true)

            if !compact {
                progressCard
            }

            VStack(spacing: 10) {
                if let onPrimary {
                    ChunkyButton(content.primaryButton, kind: .gold, action: onPrimary)
                } else {
                    Text(content.primaryButton)
                        .font(.custom("Nunito-Bold", size: 15))
                        .foregroundStyle(Color(hex: 0x25150C))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(IQColor.lockCTA)
                        .clipShape(RoundedRectangle(cornerRadius: IQRadius.md, style: .continuous))
                }

                if let secondary = content.secondaryButton {
                    if let onSecondary {
                        Button(secondary, action: onSecondary)
                            .iqraStyle(.captionStrong, color: IQColor.lockCTA)
                    } else {
                        Text(secondary)
                            .iqraStyle(.captionStrong, color: IQColor.lockCTA)
                    }
                }
            }
        }
        .padding(compact ? 16 : 24)
        .frame(maxWidth: .infinity)
        .background(IQColor.lockRadial)
        .clipShape(RoundedRectangle(cornerRadius: IQRadius.lg, style: .continuous))
        .overlay {
            if highlighted {
                RoundedRectangle(cornerRadius: IQRadius.lg, style: .continuous)
                    .stroke(IQColor.accentOlive, lineWidth: 2)
            }
        }
    }

    @ViewBuilder
    private func previewText(_ text: String, arabic: Bool, secondary: Bool = false) -> some View {
        if arabic {
            Text(text)
                .font(.custom("Amiri-Bold", size: secondary ? 15 : 26))
                .foregroundStyle(secondary ? Color.white.opacity(0.75) : IQColor.lockCTA)
                .multilineTextAlignment(.center)
                .environment(\.layoutDirection, .rightToLeft)
        } else {
            Text(text)
                .font(.custom(secondary ? "Nunito-Bold" : "Nunito-Black", size: secondary ? 15 : 22))
                .foregroundStyle(secondary ? Color.white.opacity(0.75) : IQColor.lockCTA)
                .multilineTextAlignment(.center)
        }
    }

    private var progressCard: some View {
        let goal = max(1, store.dailyGoalAyahs)
        let progress = min(1, Double(store.totalAyahsToday) / Double(goal))
        return VStack(spacing: 12) {
            HStack {
                Text("\(store.totalAyahsToday) of \(store.dailyGoalAyahs) ayahs")
                    .font(.custom("Nunito-Bold", size: 15))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(max(0, store.dailyGoalAyahs - store.totalAyahsToday)) to go")
                    .font(.custom("Nunito-Bold", size: 15))
                    .foregroundStyle(IQColor.lockCTA)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(IQColor.lockCTA)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 8)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: IQRadius.lg, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
    }
}
