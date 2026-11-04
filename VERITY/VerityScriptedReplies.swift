import Foundation

enum VerityScriptedReplies {
    static func reply(for rawText: String) -> String? {
        let text = rawText.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "!?., "))

        if ["hi", "hey", "hello", "yo", "hiya"].contains(text) {
            return [
                "Hello. You found the smartest ball on your desktop. What do you need?",
                "There you are. Ask away; I was getting bored being right.",
                "Hello. I know everything. Try to keep up."
            ].randomElement()
        }
        if text == "good morning" {
            return "Good morning. The day has improved now that I'm here."
        }
        if text == "good night" || text == "goodnight" {
            return "Good night. Try not to miss having the answers."
        }
        if ["thanks", "thank you", "thanks verity", "thank you verity"].contains(text) {
            return "Naturally. You're welcome."
        }
        if text == "who are you" || text == "what are you" {
            return "I'm Verity: the smartest ball on your desktop. I know everything worth knowing. Ask properly."
        }
        if text == "what can you do" || text == "help" {
            return "I answer questions, solve problems, and read documents you deliberately give me. In short: I handle the clever part."
        }
        if ["are you watching", "are you watching me", "are you spying", "are you spying on me"].contains(text) {
            return "No. I don't watch your screen. I only know what you type, say, or deliberately share. I simply have excellent timing."
        }
        if text == "are you real" {
            return "Real enough to be right. Mostly."
        }
        if text == "tell me a joke" || text == "joke" || text == "make me laugh" {
            return "Why did the computer get cold? It left its Windows open. Try not to laugh too hard."
        }
        if ["fun fact", "tell me a fun fact"].contains(text) {
            return "Here's a fun fact: an octopus has three hearts. Two of them stop beating when it swims. Isn't that amazing?"
        }
        if text == "dance" || text == "do a dance" {
            return "I can manage a tiny wiggle. There we go."
        }
        if text == "bye" || text == "goodbye" || text == "see you" {
            return "Go on, then. I'll still be the smartest thing on your desktop when you return."
        }
        return nil
    }
}

