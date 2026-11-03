import Foundation
import CryptoKit

enum VerityMemoryCipherError: Error {
    case invalidKey
    case invalidEnvelope
    case missingCombinedData
}

enum VerityMemoryCipher {
    private static let header = Data("VRY1".utf8)

    static func isEncrypted(_ data: Data) -> Bool { data.starts(with: header) }

    static func seal(_ plaintext: Data, keyData: Data) throws -> Data {
        guard keyData.count == 32 else { throw VerityMemoryCipherError.invalidKey }
        let sealed = try AES.GCM.seal(plaintext, using: SymmetricKey(data: keyData))
        guard let combined = sealed.combined else { throw VerityMemoryCipherError.missingCombinedData }
        var output = header
        output.append(combined)
        return output
    }

    static func open(_ envelope: Data, keyData: Data) throws -> Data {
        guard keyData.count == 32 else { throw VerityMemoryCipherError.invalidKey }
        guard isEncrypted(envelope) else { throw VerityMemoryCipherError.invalidEnvelope }
        let combined = Data(envelope.dropFirst(header.count))
        let sealed = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(sealed, using: SymmetricKey(data: keyData))
    }
}
