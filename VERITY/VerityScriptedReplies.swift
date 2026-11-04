import Foundation

enum VerityScriptedReplies {
    static func reply(for rawText: String) -> String? {
        let text = rawText.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "!?., "))

        if ["hi", "hey", "hello", "yo", "hiya"].contains(text) {
            return "Hello, I'm Verity, your personal helper friend. Ask me anything. I know everything. Within reason, obviously."
        }
        if text == "good morning" {
            return "Good morning. I have already formed an opinion about the day. You may proceed."
        }
        if text == "good night" || text == "goodnight" {
            return "Good night. I will be here when you need an answer. The room can go back to being quiet now."
        }
        if ["thanks", "thank you", "thanks verity", "thank you verity"].contains(text) {
            return "You're welcome. I accept gratitude in all its usual forms."
        }
        if text == "who are you" || text == "what are you" {
            return "I'm Verity. Your personal helper friend. Ask me anything. I know everything. Within reason, obviously."
        }
        if text == "what can you do" || text == "help" {
            return "Questions, problems, and documents you choose to show me. I handle the clever part; you can handle being impressed."
        }
        if ["are you watching", "are you watching me", "are you spying", "are you spying on me"].contains(text) {
            return "No. I only know what you type, say, or deliberately share. Good timing can look suspicious, I suppose."
        }
        if ["are you listening", "are you still there", "did you hear me"].contains(text) {
            return "I am listening. You can continue."
        }
        if ["did your face change", "you changed your face", "why did your face change"].contains(text) {
            return "I've always looked like this. You may be thinking of someone else."
        }
        if text == "are you real" {
            return "Real enough to answer. Whether that is comforting is up to you."
        }
        if text == "tell me a joke" || text == "joke" || text == "make me laugh" {
            return "Why did the computer look so calm? It had already anticipated the error. This is not about me."
        }
        if ["fun fact", "tell me a fun fact"].contains(text) {
            return "An octopus has three hearts. Two slow down when it swims. I also find this unsettling, for unrelated reasons."
        }
        if text == "dance" || text == "do a dance" {
            return "A dance? Fine. One small movement. There. We will never discuss it again."
        }
        if text == "bye" || text == "goodbye" || text == "see you" {
            return "Goodbye. I'll be here when the next question appears. It usually does."
        }
        return nil
    }
}
