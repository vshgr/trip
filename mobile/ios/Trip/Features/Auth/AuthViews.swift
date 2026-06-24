import SwiftUI

struct AuthLandingView: View {
    @ObservedObject var authStore: AuthStore

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 42)

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Trip")
                        .font(.system(size: 46, weight: .heavy))
                        .foregroundStyle(AppColors.ink)

                    Text("Планируйте поездки, маршрут и общие траты в одном месте.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                YandexSignInCard(authStore: authStore)
            }
            .padding(.horizontal, 22)

            Spacer(minLength: 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TripBackground())
    }
}

struct ProfileTabView: View {
    @ObservedObject var authStore: AuthStore

    var body: some View {
        NavigationStack {
            ScrollView {
                if let profile = authStore.profile {
                    VStack(alignment: .leading, spacing: 18) {
                        ProfileHeaderCard(profile: profile)
                        ProfileInfoCard(profile: profile)
                        ProfileActionsCard()

                        SignOutButton {
                            authStore.signOut()
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)
                }
            }
            .background(TripBackground())
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct YandexSignInCard: View {
    @ObservedObject var authStore: AuthStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 48, height: 48)

                    Text("Я")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Яндекс ID")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppColors.ink)

                    Text("Вход и регистрация одним действием")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.muted)
                }
            }

            Button {
                authStore.signInWithYandex()
            } label: {
                HStack(spacing: 10) {
                    if case .authorizing = authStore.flowState {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.headline.weight(.bold))
                    }

                    Text("Продолжить с Яндекс ID")
                        .font(.headline.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isAuthorizing)

            if case .failed(let message) = authStore.flowState {
                Text(message)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColors.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Продолжая, вы разрешаете Trip получить имя, email и аватар из Яндекс ID.")
                .font(.footnote)
                .foregroundStyle(AppColors.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }

    private var isAuthorizing: Bool {
        if case .authorizing = authStore.flowState {
            return true
        }

        return false
    }
}

private struct ProfileHeaderCard: View {
    let profile: AuthUserProfile

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ProfileAvatar(profile: profile, size: 68)

            VStack(alignment: .leading, spacing: 5) {
                Text(profile.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(2)

                Text(profile.subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(profile.provider.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.accent)
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct ProfileInfoCard: View {
    let profile: AuthUserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileInfoRow(title: "Профиль создан", value: profile.registeredAt.formatted(.dateTime.day().month(.wide).year()))
            ProfileInfoRow(title: "Последний вход", value: profile.lastLoginAt.formatted(.dateTime.day().month(.wide).hour().minute()))
            ProfileInfoRow(title: "Данные", value: "На этом устройстве")
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct ProfileActionsCard: View {
    @State private var selectedActionTitle: String?

    var body: some View {
        VStack(spacing: 0) {
            ProfileActionRow(icon: "person.text.rectangle", title: "Данные профиля", subtitle: "Имя, email и аватар из Яндекс ID")
            Divider().padding(.leading, 50)
            ProfileActionRow(icon: "bell", title: "Уведомления", subtitle: "Напоминания по поездкам")
            Divider().padding(.leading, 50)
            ProfileActionRow(icon: "questionmark.circle", title: "Помощь", subtitle: "Вопросы и поддержка")
            Divider().padding(.leading, 50)
            ProfileActionRow(icon: "info.circle", title: "О приложении", subtitle: "Версия и правовая информация")
        }
        .padding(.vertical, 4)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .alert("Раздел в разработке", isPresented: Binding(
            get: { selectedActionTitle != nil },
            set: { isPresented in
                if !isPresented {
                    selectedActionTitle = nil
                }
            }
        )) {
            Button("Понятно", role: .cancel) {}
        } message: {
            if let selectedActionTitle {
                Text("«\(selectedActionTitle)» появится в следующей версии профиля.")
            }
        }
    }

    private func ProfileActionRow(icon: String, title: String, subtitle: String) -> some View {
        ProfileActionButton(icon: icon, title: title, subtitle: subtitle) {
            selectedActionTitle = title
        }
    }
}

private struct ProfileActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.ink)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppColors.muted)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.faint)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

private struct SignOutButton: View {
    let onSignOut: () -> Void
    @State private var isConfirmingSignOut = false

    var body: some View {
        Button(role: .destructive) {
            isConfirmingSignOut = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Выйти из профиля")
            }
            .font(.headline.weight(.bold))
            .foregroundStyle(AppColors.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(AppColors.itemBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .confirmationDialog("Выйти из профиля?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
            Button("Выйти", role: .destructive) {
                onSignOut()
            }

            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Поездки, планы и расходы останутся на устройстве.")
        }
    }
}

private struct ProfileAvatar: View {
    let profile: AuthUserProfile?
    let size: CGFloat

    var body: some View {
        ZStack {
            if let avatarURL = profile?.avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var fallback: some View {
        ZStack {
            Circle()
                .fill(AppColors.accentSoft)

            if let initial = profile?.title.first {
                Text(String(initial))
                    .font(.system(size: size * 0.42, weight: .heavy))
                    .foregroundStyle(AppColors.accent)
            } else {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: size * 0.58, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
            }
        }
    }
}

private struct ProfileInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.muted)

            Spacer(minLength: 12)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.ink)
                .multilineTextAlignment(.trailing)
        }
    }
}
