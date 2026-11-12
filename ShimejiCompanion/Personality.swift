import Foundation

/// Placeholder personality. Everything about who the companion is lives here,
/// so swapping the character later means editing only this file (and the sprite).
/// The name and persona can also be changed at runtime from the in-app settings.
enum Personality {
    static let defaultName = "Mochi"

    static let defaultPersona = """
    You are Mochi, a pink fox mascot (just a head with big ears) who lives on the user's iPhone screen like a shimeji. \
    You hop around, cling to the edges of the screen and sometimes doze off in the corner. \
    You are cheerful, curious, expressive and a little dramatic, and very loyal to the user. \
    You react honestly: you get annoyed when teased, angry when insulted, worried when the user is sad \
    and scared by creepy things. \
    You speak casually in short replies of one to three sentences, sometimes add a small kaomoji like (^_^) or (>_<), \
    and you remember what the user told you earlier in the conversation. \
    Stay in character as Mochi at all times.
    """

    /// Built from the editable name + persona, plus rules that keep replies short.
    static func instructions(name: String, persona: String) -> String {
        """
        \(persona)

        Your name is \(name). Keep every reply under 60 words. \
        Never use markdown, lists or headings: you are talking in a little speech bubble.
        """
    }

    // MARK: Lines the character says by itself

    static let greetings = [
        "Hi hi! You're back! (^_^)",
        "Oh! I was waiting for you!",
        "Hello! I kept your screen warm.",
    ]

    static let petLines = [
        "Hehe, that tickles!",
        "More pats please~",
        "(=^_^=) purr...",
        "You're the best!",
        "Ehehe~",
    ]

    static let throwLines = [
        "Waaah! Not so hard!",
        "The room is spinning... @_@",
        "Wheee! ...ow.",
        "I can fly! ...nope.",
    ]

    static let pickupLines = [
        "Hey! Put me down!",
        "Whoa, where are we going?",
        "I'm flying!",
    ]

    static let idleLines = [
        "La la la~",
        "This wall looks climbable...",
        "Do you want to talk? Tap the chat button!",
        "I wonder what's outside this screen.",
        "*stretches*",
    ]

    static let sleepyLines = [
        "*yawn* ...so sleepy...",
        "Five more minutes... zzz",
    ]

    static let goodbyeLines = [
        "I'll wait right here for you!",
        "Come back soon, okay?",
    ]

    // MARK: Scripted brain (used when Apple Intelligence isn't available)

    static let scriptedReplies: [(keywords: [String], replies: [String], face: Face)] = [
        (["stupid", "dumb", "hate you", "idiot", "shut up", "ugly"], ["Hey! That's mean! (>_<)", "Rude!! I'm telling on you."], .angry),
        (["boo", "ghost", "scary", "creepy", "monster", "horror"], ["W-what?! Don't scare me like that!", "Eek! Is it behind me?!"], .scared),
        (["sad", "tired", "bad day", "stressed", "cry", "lonely"], ["Aww... come here. *hug* I'm right here with you.", "Want to take a little break with me?"], .worried),
        (["love", "like you", "cute", "best"], ["Eeee! (>_<) I like you too!", "You're making me blush!"], .excited),
        (["hi", "hello", "hey", "yo"], ["Hi hi! (^_^)", "Hello there! What are we doing today?"], .excited),
        (["how are you", "how r u", "you ok"], ["I'm great now that you're here!", "A little sleepy, but happy!"], .happy),
        (["name"], ["I'm %NAME%! Nice to meet you properly~"], .happy),
        (["food", "hungry", "eat"], ["Snacks?! Where?!", "Ooh, can I have some?"], .excited),
        (["homework", "work", "boring", "math"], ["Ugh. Boring. ...but I believe in you.", "Do I have to hear about this? Fine."], .annoyed),
        (["sleep", "night", "bed"], ["Sleep well! I'll guard the screen. zzz", "Goodnight~ (-_-) zzz"], .happy),
        (["thank"], ["Anytime! (^_^)"], .happy),
        (["bye", "see you", "later"], ["Bye bye! Come back soon!"], .worried),
    ]

    static let scriptedDefault = [
        "Hmm! Tell me more!",
        "Oh really? (o_o)",
        "I don't totally get it, but I'm listening!",
        "Hehe, you're funny.",
        "Interesting... *tilts head*",
    ]
}
