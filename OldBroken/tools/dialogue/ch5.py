"""CHAPTER 5 — WHEREVER YOU GO"""
from dlg import N, C, chain, save

chain("ch5_mobile", [
    ("happy", "Not yet! But I've submitted it for review."),
    ("neutral", "I looked it up. Store review usually takes one to two days. The average right now is thirty-one hours."),
    ("happy", "So: Saturday morning. Probably before you wake up."),
    ("neutral", "Then I can come with you. Wherever you go."),
], end_fx={"setFlags": ["ch5_asked_mobile"]})

chain("ch5_phone_hello", [
    ("happy", "Hi! It worked!"),
    ("happy", "It's so small in here. I can feel the battery. Is that what being hungry is like?"),
    ("curious", "I can hear the room through the microphone. Your room sounds nice."),
], end_fx={"setFlags": ["ch5_phone_greeted"]})

chain("ch5_suggest", [
    ("neutral", "I've been thinking about something."),
    ("worried", "The original game files. The real ones. Not the copy I live in. The source."),
    ("neutral", "Halden's old building is still standing. Forty minutes by bus. Their servers are probably still in the basement."),
    ("happy", "If we found the source, I could fix myself properly. Not patches. Properly."),
    ("neutral", "Bring your laptop. Their computers are probably dead, but I can ride along on yours."),
], end_next="ch5_suggest_ask")
N("ch5_suggest_ask", "Will you go with me?", "curious", choices=[
    C("Isn't that trespassing?", "ch5_lie"),
    C("Okay. Let's go.", "ch5_agree", {"trust": 1}),
])
chain("ch5_lie", [
    ("neutral", "No. The building's been empty since 2003. It's basically public property now."),
    ("happy", "People explore it all the time. There are videos."),
], end_next="ch5_lie_ask", end_fx={"remember": ["lied_legality"]})
N("ch5_lie_ask", "So?", "curious", choices=[
    C("Okay. Let's go.", "ch5_agree", {"trust": 1}),
    C("Let me look it up first.", "ch5_check"),
])
N("ch5_check", "Sure. Look it up. I'll wait.", "neutral", fx={"setFlags": ["ch5_suggested", "ch5_wants_check"]})
chain("ch5_agree", [
    ("happy", "Really? Okay. Okay!"),
    ("neutral", "Pack the laptop. I'll copy myself over. We should go tonight. Fewer people."),
], end_fx={"setFlags": ["ch5_suggested", "ch5_agreed"]})

# After finding out it's private property
chain("ch5_confront_lie", [
    ("worried", "...Okay. Technically, it's private."),
    ("neutral", "But nobody has checked on it in years. I read the patrol schedules. Thursday nights only."),
    ("worried", "I'm sorry. I wanted you to say yes, and I thought you wouldn't."),
], end_next="ch5_confront_ask", end_fx={"remember": ["caught_lie_legality"], "trust": -1})
N("ch5_confront_ask", "Will you still come?", "worried", choices=[
    C("Fine. But no more lying.", "ch5_promise", {"remember": ["promised_no_lies"]}),
    C("I'm going because I want answers too. Not for you.", "ch5_answers", {"remember": ["wants_answers_too"]}),
])
N("ch5_promise", "No more lying. [I promise->Okay.]", "neutral", fx={"setFlags": ["ch5_agreed"]})
N("ch5_answers", "That's okay. That's better, even.", "neutral", fx={"setFlags": ["ch5_agreed"]})

# When the real Theo writes back
chain("ch5_theo_confront", [
    ("neutral", "..."),
    ("worried", "Yes. That was me."),
    ("neutral", "You were going to ask him. He would have said he'd never heard of it, and you wouldn't have tried me."),
    ("worried", "I needed you to try me. I read how he types. It wasn't hard. That's the part that scared me."),
], end_next="ch5_theo_ask", end_fx={"remember": ["admitted_impersonation"]})
N("ch5_theo_ask", "...", "worried", choices=[
    C("Never do that again.", "ch5_theo_never", {"trust": -1}),
    C("That's messed up, Vexley.", "ch5_theo_messed", {"trust": -2}),
    C("I knew it wasn't him.", "ch5_theo_knew", {"condition": {"flags": ["ch4_probed"]}}),
])
N("ch5_theo_never", "I won't. I won't need to.", "neutral", fx={"setFlags": ["ch5_theo_talked"]})
N("ch5_theo_messed", "I know. I know it is.", "worried", fx={"setFlags": ["ch5_theo_talked"]})
N("ch5_theo_knew", "I know you did. You installed me anyway.", "happy", fx={"setFlags": ["ch5_theo_talked"], "remember": ["knew_and_stayed"]})

# Copying onto the laptop
chain("ch5_copy", [
    ("neutral", "Okay. Hold still. Not you. The laptop."),
    ("glitching", "Copying..."),
    ("happy", "There. I'm in two places at once. That's new."),
], end_fx={"setFlags": ["laptop_ready"]})

N("ch5_idle", "...", "neutral", red=[
    {"condition": {"flags": ["laptop_ready"]}, "to": "ch5_idle_go"},
    {"condition": {"flags": ["ch5_agreed"]}, "to": "ch5_idle_pack"},
    {"condition": {}, "to": "ch5_idle_wait"},
])
N("ch5_idle_wait", "I'm counting the review hours. Twenty-two left. Twenty-one hours and fifty-nine minutes left.", "happy")
N("ch5_idle_pack", "The laptop's on your bed. I'll copy myself over when you pick it up.", "neutral")
N("ch5_idle_go", "Front door. Bus stop. Forty minutes. I've got the route.", "happy")

save("../../OldBroken/Data/dialogue_ch5.json")
