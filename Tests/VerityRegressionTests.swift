import Foundation
import Darwin

@main
struct VerityRegressionTests {
    static func main() throws {
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            guard condition() else {
                FileHandle.standardError.write(Data("FAIL: \(label)\n".utf8))
                exit(1)
            }
            print("PASS: \(label)")
        }

        let openAI = #"{"choices":[{"message":{"content":"Hello from Verity."}}]}"#.data(using: .utf8)!
        check(VerityResponseParser.assistantText(from: openAI) == "Hello from Verity.", "OpenAI-compatible document response")
        let generic = #"{"response":"A concise answer."}"#.data(using: .utf8)!
        check(VerityResponseParser.assistantText(from: generic) == "A concise answer.", "Generic JSON response")
        let blocks = #"{"content":[{"type":"text","text":"First paragraph."},{"type":"text","text":"Second paragraph."}]}"#.data(using: .utf8)!
        check(VerityResponseParser.assistantText(from: blocks) == "First paragraph.\nSecond paragraph.", "Content-block response")
        check(VerityResponseParser.assistantText(from: Data("Plain text answer".utf8)) == "Plain text answer", "Plain-text fallback")
        let delta = #"{"choices":[{"delta":{"content":"partial"}}]}"#.data(using: .utf8)!
        check(VerityResponseParser.streamDelta(from: delta) == "partial", "Streaming delta extraction")
        check(VerityResponseParser.containsSensitiveInformation("Remember that my password is hunter2"), "Sensitive phrase detection")
        check(VerityResponseParser.containsSensitiveInformation("token: abcdefghijklmnopqrstuvwxyz123456"), "Credential assignment detection")
        check(!VerityResponseParser.containsSensitiveInformation("I prefer a clean desktop and short answers."), "Normal memory remains allowed")

        let key = Data(repeating: 0x42, count: 32)
        let plaintext = Data("Verity's private memory archive".utf8)
        let envelope = try VerityMemoryCipher.seal(plaintext, keyData: key)
        check(VerityMemoryCipher.isEncrypted(envelope), "Encrypted archive marker")
        check(envelope != plaintext, "Archive is not stored as plaintext")
        let recovered = try VerityMemoryCipher.open(envelope, keyData: key)
        check(recovered == plaintext, "AES-GCM round trip")
        var tampered = envelope
        tampered[tampered.index(before: tampered.endIndex)] ^= 0x01
        var rejected = false
        do { _ = try VerityMemoryCipher.open(tampered, keyData: key) } catch { rejected = true }
        check(rejected, "AES-GCM rejects modified archive")
        print("All VERITY regression tests passed.")
    }
}
