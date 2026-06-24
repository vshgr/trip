import Foundation

struct AuthUserProfile: Identifiable, Codable, Equatable {
    var id: String
    var login: String
    var displayName: String
    var email: String?
    var avatarURL: URL?
    var provider: AuthProvider
    var registeredAt: Date
    var lastLoginAt: Date

    var title: String {
        if !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return displayName
        }

        return login
    }

    var subtitle: String {
        email ?? "@\(login)"
    }
}

enum AuthFlowState: Equatable {
    case idle
    case authorizing
    case failed(String)
}

enum AuthProvider: String, Codable {
    case yandexID

    var title: String {
        switch self {
        case .yandexID:
            return "Яндекс ID"
        }
    }
}

struct YandexAuthConfiguration {
    let clientID: String

    var isConfigured: Bool {
        !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var callbackScheme: String {
        "yx\(clientID)"
    }

    var associatedDomain: String {
        "applinks:yx\(clientID).oauth.yandex.ru"
    }

    static var current: YandexAuthConfiguration {
        let rawClientID = Bundle.main.object(forInfoDictionaryKey: "YandexClientID") as? String
        return YandexAuthConfiguration(clientID: rawClientID ?? "")
    }
}

struct YandexIDProfileResponse: Decodable {
    let id: String
    let login: String
    let displayName: String?
    let realName: String?
    let firstName: String?
    let lastName: String?
    let defaultEmail: String?
    let defaultAvatarID: String?
    let isAvatarEmpty: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case login
        case displayName = "display_name"
        case realName = "real_name"
        case firstName = "first_name"
        case lastName = "last_name"
        case defaultEmail = "default_email"
        case defaultAvatarID = "default_avatar_id"
        case isAvatarEmpty = "is_avatar_empty"
    }

    var profile: AuthUserProfile {
        AuthUserProfile(
            id: id,
            login: login,
            displayName: preferredDisplayName,
            email: defaultEmail,
            avatarURL: avatarURL,
            provider: .yandexID,
            registeredAt: Date(),
            lastLoginAt: Date()
        )
    }

    private var avatarURL: URL? {
        guard isAvatarEmpty != true, let defaultAvatarID, !defaultAvatarID.isEmpty else {
            return nil
        }

        return URL(string: "https://avatars.yandex.net/get-yapic/\(defaultAvatarID)/islands-200")
    }

    private var preferredDisplayName: String {
        if let displayName, !displayName.isEmpty {
            return displayName
        }
        if let realName, !realName.isEmpty {
            return realName
        }

        let fullName = [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return fullName.isEmpty ? login : fullName
    }
}

struct YandexIDAPI {
    func profile(oauthToken: String) async throws -> AuthUserProfile {
        var components = URLComponents(string: "https://login.yandex.ru/info")
        components?.queryItems = [
            URLQueryItem(name: "format", value: "json")
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("OAuth \(oauthToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(YandexIDProfileResponse.self, from: data).profile
    }
}

@MainActor
final class AuthStore: ObservableObject {
    @Published var profile: AuthUserProfile?
    @Published var flowState: AuthFlowState = .idle

    private let storageKey = "trip.auth.profile.v1"
    private let yandexAPI = YandexIDAPI()

    var isSignedIn: Bool {
        profile != nil
    }

    var yandexConfiguration: YandexAuthConfiguration {
        .current
    }

    init() {
        loadProfile()
    }

    func signInWithYandex() {
        flowState = .authorizing

        #if DEBUG
        if !yandexConfiguration.isConfigured {
            createPreviewYandexProfile()
            return
        }
        #endif

        flowState = .failed("Вход через Яндекс ID еще не подключен в этой сборке.")
    }

    func completeYandexSignIn(oauthToken: String) async {
        flowState = .authorizing
        defer {
            if case .authorizing = flowState {
                flowState = .idle
            }
        }

        do {
            var loadedProfile = try await yandexAPI.profile(oauthToken: oauthToken)
            if let existingProfile = profile, existingProfile.id == loadedProfile.id {
                loadedProfile.registeredAt = existingProfile.registeredAt
            }
            profile = loadedProfile
            flowState = .idle
            saveProfile()
        } catch {
            flowState = .failed("Не удалось войти через Яндекс ID. Проверьте сеть и попробуйте еще раз.")
        }
    }

    func signOut() {
        profile = nil
        flowState = .idle
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func createPreviewYandexProfile() {
        let now = Date()
        let existingRegisteredAt = profile?.registeredAt ?? now
        profile = AuthUserProfile(
            id: "preview-yandex-profile",
            login: "alisa.trip",
            displayName: "Алиса",
            email: "alisa@yandex.ru",
            avatarURL: nil,
            provider: .yandexID,
            registeredAt: existingRegisteredAt,
            lastLoginAt: now
        )
        flowState = .idle
        saveProfile()
    }

    private func loadProfile() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(AuthUserProfile.self, from: data)
        else {
            return
        }

        profile = decoded
    }

    private func saveProfile() {
        guard let profile, let data = try? JSONEncoder().encode(profile) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
