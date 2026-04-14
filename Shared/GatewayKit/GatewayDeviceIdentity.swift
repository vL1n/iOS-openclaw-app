import CryptoKit
import Foundation

public struct GatewayDeviceIdentity: Codable, Hashable, Sendable {
    public var deviceId: String
    public var publicKey: String
    public var privateKey: String
    public var createdAtMs: Int

    public init(deviceId: String, publicKey: String, privateKey: String, createdAtMs: Int) {
        self.deviceId = deviceId
        self.publicKey = publicKey
        self.privateKey = privateKey
        self.createdAtMs = createdAtMs
    }
}

public enum GatewayDeviceIdentityStore {
    private static let fileName = "device.json"

    public static func loadOrCreate() -> GatewayDeviceIdentity {
        let url = fileURL()
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(GatewayDeviceIdentity.self, from: data),
           !decoded.deviceId.isEmpty,
           !decoded.publicKey.isEmpty,
           !decoded.privateKey.isEmpty {
            return decoded
        }

        let identity = generate()
        save(identity)
        return identity
    }

    public static func signPayload(_ payload: String, identity: GatewayDeviceIdentity) -> String? {
        guard let privateKeyData = Data(base64Encoded: identity.privateKey) else { return nil }

        do {
            let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
            let signature = try privateKey.signature(for: Data(payload.utf8))
            return base64URLEncoded(signature)
        } catch {
            return nil
        }
    }

    public static func publicKeyBase64URL(_ identity: GatewayDeviceIdentity) -> String? {
        guard let data = Data(base64Encoded: identity.publicKey) else { return nil }
        return base64URLEncoded(data)
    }

    private static func generate() -> GatewayDeviceIdentity {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKeyData = privateKey.publicKey.rawRepresentation
        let privateKeyData = privateKey.rawRepresentation
        let deviceId = SHA256.hash(data: publicKeyData)
            .map { String(format: "%02x", $0) }
            .joined()

        return GatewayDeviceIdentity(
            deviceId: deviceId,
            publicKey: publicKeyData.base64EncodedString(),
            privateKey: privateKeyData.base64EncodedString(),
            createdAtMs: Int(Date().timeIntervalSince1970 * 1000)
        )
    }

    private static func save(_ identity: GatewayDeviceIdentity) {
        let url = fileURL()

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(identity)
            try data.write(to: url, options: [.atomic])
        } catch {
            // Device identity is recreated on failure; pairing may need to be repeated.
        }
    }

    private static func fileURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        return baseURL
            .appendingPathComponent("OpenClawOperator", isDirectory: true)
            .appendingPathComponent("identity", isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }

    private static func base64URLEncoded(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

public enum GatewayDeviceAuthPayload {
    public static func buildV3(
        deviceId: String,
        clientId: String,
        clientMode: String,
        role: String,
        scopes: [String],
        signedAtMs: Int,
        token: String?,
        nonce: String,
        platform: String?,
        deviceFamily: String?
    ) -> String {
        [
            "v3",
            deviceId,
            clientId,
            clientMode,
            role,
            scopes.joined(separator: ","),
            String(signedAtMs),
            token ?? "",
            nonce,
            normalizeMetadataField(platform),
            normalizeMetadataField(deviceFamily)
        ].joined(separator: "|")
    }

    public static func signedDeviceParams(
        payload: String,
        identity: GatewayDeviceIdentity,
        signedAtMs: Int,
        nonce: String
    ) -> [String: JSONValue]? {
        guard let signature = GatewayDeviceIdentityStore.signPayload(payload, identity: identity),
              let publicKey = GatewayDeviceIdentityStore.publicKeyBase64URL(identity) else {
            return nil
        }

        return [
            "id": .string(identity.deviceId),
            "publicKey": .string(publicKey),
            "signature": .string(signature),
            "signedAt": .number(Double(signedAtMs)),
            "nonce": .string(nonce)
        ]
    }

    private static func normalizeMetadataField(_ value: String?) -> String {
        guard let value else { return "" }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        var output = String()
        output.reserveCapacity(trimmed.count)
        for scalar in trimmed.unicodeScalars {
            let codePoint = scalar.value
            if codePoint >= 65, codePoint <= 90, let lowered = UnicodeScalar(codePoint + 32) {
                output.unicodeScalars.append(lowered)
            } else {
                output.unicodeScalars.append(scalar)
            }
        }
        return output
    }
}
