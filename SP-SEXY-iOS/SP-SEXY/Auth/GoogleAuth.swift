import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

/// Błędy autoryzacji z czytelnymi komunikatami po polsku.
enum AuthError: LocalizedError {
    case notSignedIn
    case noCode
    case tokenError(String)
    case notWhitelisted(String)

    var errorDescription: String? { message }

    var message: String {
        switch self {
        case .notSignedIn:
            return "Wymagane logowanie. Zaloguj się ponownie."
        case .noCode:
            return "Logowanie przerwane."
        case .tokenError(let m):
            return "Błąd autoryzacji Google: \(m)"
        case .notWhitelisted(let email):
            return "Konto \(email) nie ma dostępu do aplikacji."
        }
    }
}

/// Zestaw tokenów przechowywany w Keychain.
struct TokenSet: Codable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date
    var email: String?
}

/// Menedżer logowania Google (OAuth 2.0 + PKCE) dla aplikacji natywnej.
///
/// Używa `ASWebAuthenticationSession` (bez zewnętrznych SDK). Refresh token jest
/// trzymany w Keychain, dzięki czemu sesja przeżywa restart aplikacji — logowanie
/// nie jest wymagane przy każdym uruchomieniu (poprawa względem wersji PWA).
@MainActor
final class GoogleAuth: NSObject, ObservableObject {

    @Published var pilot: Pilot?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var tokens: TokenSet? {
        didSet {
            if let t = tokens { Keychain.save(t) } else { Keychain.clear() }
        }
    }

    private var authSession: ASWebAuthenticationSession?

    override init() {
        super.init()
        if let saved = Keychain.load() {
            tokens = saved
            if let email = saved.email { pilot = Config.pilot(email: email) }
        }
    }

    var isAuthenticated: Bool { pilot != nil && tokens != nil }

    // MARK: - Cykl życia sesji

    /// Cicha próba odświeżenia sesji przy starcie (bez UI).
    func restore() async {
        guard let t = tokens, t.refreshToken != nil else { return }
        do {
            _ = try await validAccessToken()
            if pilot == nil, let email = t.email { pilot = Config.pilot(email: email) }
        } catch {
            // Zachowaj pilota z cache; przy pierwszym wywołaniu API poprosi o logowanie.
        }
    }

    func signIn() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let verifier = Self.makeCodeVerifier()
            let challenge = Self.makeCodeChallenge(verifier)
            let code = try await authorize(challenge: challenge)
            var token = try await exchange(code: code, verifier: verifier)

            var email = token.email
            if email == nil {
                email = try? await fetchEmail(token.accessToken)
            }
            guard let email, let p = Config.pilot(email: email) else {
                tokens = nil
                throw AuthError.notWhitelisted(email ?? "?")
            }
            token.email = email
            tokens = token
            pilot = p
        } catch {
            errorMessage = (error as? AuthError)?.message ?? error.localizedDescription
        }
    }

    func signOut() {
        tokens = nil
        pilot = nil
    }

    /// Zwraca ważny access token, odświeżając go w razie potrzeby.
    func validAccessToken() async throws -> String {
        guard var t = tokens else { throw AuthError.notSignedIn }

        if t.expiresAt > Date().addingTimeInterval(60) {
            return t.accessToken
        }
        guard let refreshToken = t.refreshToken else { throw AuthError.notSignedIn }

        let refreshed = try await refreshTokens(using: refreshToken)
        t.accessToken = refreshed.accessToken
        t.expiresAt = refreshed.expiresAt
        if refreshed.refreshToken != nil { t.refreshToken = refreshed.refreshToken }
        tokens = t
        return t.accessToken
    }

    // MARK: - Przepływ OAuth

    private func authorize(challenge: String) async throws -> String {
        var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comps.queryItems = [
            .init(name: "client_id", value: Config.iosClientID),
            .init(name: "redirect_uri", value: Config.redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: Config.scopes),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "access_type", value: "offline"),
            .init(name: "prompt", value: "consent")
        ]
        let url = comps.url!
        let scheme = Config.reversedClientScheme

        return try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callback, error in
                if let error {
                    if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                        cont.resume(throwing: AuthError.noCode)
                    } else {
                        cont.resume(throwing: error)
                    }
                    return
                }
                guard let callback,
                      let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems,
                      let code = items.first(where: { $0.name == "code" })?.value else {
                    cont.resume(throwing: AuthError.noCode)
                    return
                }
                cont.resume(returning: code)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.authSession = session
            session.start()
        }
    }

    private func exchange(code: String, verifier: String) async throws -> TokenSet {
        try await tokenRequest([
            "client_id": Config.iosClientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": Config.redirectURI
        ])
    }

    private func refreshTokens(using refreshToken: String) async throws -> TokenSet {
        try await tokenRequest([
            "client_id": Config.iosClientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ])
    }

    private func tokenRequest(_ params: [String: String]) async throws -> TokenSet {
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = Self.formEncode(params)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try Self.parseToken(data)
    }

    private func fetchEmail(_ accessToken: String) async throws -> String? {
        var req = URLRequest(url: URL(string: "https://www.googleapis.com/oauth2/v3/userinfo")!)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return obj?["email"] as? String
    }

    // MARK: - Parsowanie

    private static func parseToken(_ data: Data) throws -> TokenSet {
        struct Resp: Codable {
            let access_token: String?
            let expires_in: Double?
            let refresh_token: String?
            let id_token: String?
            let error: String?
            let error_description: String?
        }
        let r = try JSONDecoder().decode(Resp.self, from: data)
        guard let at = r.access_token else {
            throw AuthError.tokenError(r.error_description ?? r.error ?? "nieznany błąd")
        }
        let email = r.id_token.flatMap { decodeEmail(fromIDToken: $0) }
        return TokenSet(
            accessToken: at,
            refreshToken: r.refresh_token,
            expiresAt: Date().addingTimeInterval(r.expires_in ?? 3600),
            email: email
        )
    }

    private static func decodeEmail(fromIDToken token: String) -> String? {
        let parts = token.components(separatedBy: ".")
        guard parts.count >= 2 else { return nil }
        var b64 = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj["email"] as? String
    }

    // MARK: - PKCE / kodowanie

    private static func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private static func makeCodeChallenge(_ verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64URLEncodedString()
    }

    private static func formEncode(_ params: [String: String]) -> Data {
        params.map { key, value in
            let v = value.addingPercentEncoding(withAllowedCharacters: .urlFormValueAllowed) ?? value
            return "\(key)=\(v)"
        }
        .joined(separator: "&")
        .data(using: .utf8)!
    }
}

// MARK: - Prezentacja okna logowania

extension GoogleAuth: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        return window ?? UIWindow()
    }
}

// MARK: - Pomocnicze kodowanie

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension CharacterSet {
    /// Znaki dozwolone w wartości pola formularza `application/x-www-form-urlencoded`.
    static let urlFormValueAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
}
