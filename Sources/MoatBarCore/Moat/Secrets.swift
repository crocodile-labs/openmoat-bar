import Foundation

// `openmoat secret list --format json` (OpenMoat 0.5.5 and later). Shape: openmoat
// `crates/openmoat-cli/src/commands/secret.rs`; a secret is `Secret` from
// `crates/openmoat-core/src/secret.rs`. moat never prints the values.

/// `{"secrets": [...]}`.
public struct SecretList: Decodable, Equatable {
    public var secrets: [BrokeredSecret]

    public init(secrets: [BrokeredSecret]) {
        self.secrets = secrets
    }

    /// Secrets whose source the agent can still read.
    public var exposed: [BrokeredSecret] {
        self.secrets.filter(\.sourceExposed)
    }
}

/// One secret OpenMoat adds to requests for one host, so the agent only ever
/// sees a placeholder.
public struct BrokeredSecret: Decodable, Equatable, Identifiable {
    public var id: String
    /// The one host whose requests get the value.
    public var host: String
    /// The request header the value goes in.
    public var header: String
    public var source: SecretSource
    /// Also added to plain-HTTP requests, where it travels unencrypted.
    public var plainHttp: Bool
    /// No deny rule covers where the value is read from, so the agent could
    /// read it there.
    public var sourceExposed: Bool

    public init(
        id: String,
        host: String,
        header: String,
        source: SecretSource,
        plainHttp: Bool = false,
        sourceExposed: Bool
    ) {
        self.id = id
        self.host = host
        self.header = header
        self.source = source
        self.plainHttp = plainHttp
        self.sourceExposed = sourceExposed
    }

    private enum CodingKeys: String, CodingKey {
        case id, host, header, source
        case plainHttp = "plain_http"
        case sourceExposed = "source_exposed"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.host = try c.decode(String.self, forKey: .host)
        self.header = try c.decodeIfPresent(String.self, forKey: .header) ?? ""
        self.source = (try? c.decode(SecretSource.self, forKey: .source)) ?? .unknown
        self.plainHttp = try c.decodeIfPresent(Bool.self, forKey: .plainHttp) ?? false
        // Missing means a moat that didn't check: say the agent may read it.
        self.sourceExposed = try c.decodeIfPresent(Bool.self, forKey: .sourceExposed) ?? true
    }
}

/// Where OpenMoat reads a secret's value: `{"env": "NAME"}`, `{"file": "~/x"}`
/// or `{"keychain": {"service": ..., "account": ...}}`.
public enum SecretSource: Decodable, Equatable {
    case env(String)
    case file(String)
    case keychain(service: String, account: String)
    /// A source a newer moat added.
    case unknown

    private enum CodingKeys: String, CodingKey {
        case env, file, keychain
    }

    private struct Keychain: Decodable {
        var service: String
        var account: String
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let name = try? c.decode(String.self, forKey: .env) {
            self = .env(name)
        } else if let path = try? c.decode(String.self, forKey: .file) {
            self = .file(path)
        } else if let item = try? c.decode(Keychain.self, forKey: .keychain) {
            self = .keychain(service: item.service, account: item.account)
        } else {
            self = .unknown
        }
    }

    /// Plain words: `the variable GITHUB_TOKEN`.
    public var label: String {
        switch self {
        case let .env(name): return "the variable \(name)"
        case let .file(path): return "the file \(path)"
        case let .keychain(service, account): return "the keychain item \(service) (\(account))"
        case .unknown: return "a source this version of OpenMoat Bar doesn't know"
        }
    }
}
