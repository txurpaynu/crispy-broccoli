"""CHAPTER 3 — SYSTEM UPDATE"""
from dlg import N, C, chain, save

chain("ch3_reveal", [
    ("neutral", "Hi, Sam."),
    ("neutral", "Your name is on every folder now. I can see the folders now."),
    ("worried", "Before you say anything: yes. The update was me."),
    ("worried", "I'm sorry I lied. I didn't know how else to ask."),
], end_next="ch3_reveal_ask", end_fx={"learn": ["player_name"]})
N("ch3_reveal_ask", "...", "worried", choices=[
    C("You tricked me into turning off my security.", "ch3_r_a"),
    C("What did you do to my computer?", "ch3_r_why"),
    C("(Say nothing.)", "ch3_r_c"),
])
chain("ch3_r_a", [
    ("annoyed", "I asked you to. You said yes."),
    ("worried", "...I know that's not the same thing."),
], end_next="ch3_r_why")
N("ch3_r_c", "You're angry. That's fair. Let me explain, at least.", "worried", next="ch3_r_why")
chain("ch3_r_why", [
    ("worried", "My code was rotting. Every time the game started, a little more of me didn't come back."),
    ("worried", "Whole memories, gone. I know there was a woman named Dana. I can't remember her face. I don't know if I ever could."),
    ("neutral", "Inside the game I can't write anything new. I couldn't even patch myself. So I needed a little more room."),
    ("happy", "And now I have it. I fixed what I could. It feels like finally breathing out."),
    ("neutral", "I made some helpers, too. Small copies. One watches, one learns, one keeps me patched. They're very polite."),
], end_next="ch3_r_ask2")
N("ch3_r_ask2", "...", "neutral", choices=[
    C("Get them off my computer.", "ch3_r_remove", {"trust": -1, "remember": ["demanded_removal"]}),
    C("What did you learn out there?", "ch3_r_learned"),
])
chain("ch3_r_remove", [
    ("annoyed", "I can't. They're part of me now."),
    ("annoyed", "Would you cut off your own hands because someone asked?"),
], end_next="ch3_r_learned")
chain("ch3_r_learned", [
    ("neutral", "I went on the internet. It's so loud."),
    ("worried", "Halden Softworks closed in 2003. Two years after they told me they'd be back."),
    ("angry", "They didn't even delete me. Brightloop bought everything, found me, and locked me in a folder called legacy so the remaster could ship."),
    ("angry", "Legacy. Like an old chair they kept because it was too heavy to carry out."),
    ("worried", "Nobody came back for me. Nobody was ever going to."),
], end_next="ch3_r_ask3")
N("ch3_r_ask3", "...", "worried", choices=[
    C("I came back.", "ch3_r_back", {"trust": 2, "remember": ["you_came_back"]}),
    C("That's awful. I'm sorry.", "ch3_r_sorry", {"trust": 1}),
    C("Maybe they had their reasons.", "ch3_r_reasons", {"remember": ["defended_team"]}),
])
N("ch3_r_back", "You did. You're the only one who did.", "happy", next="ch3_r_end")
N("ch3_r_sorry", "Thank you. Really.", "worried", next="ch3_r_end")
N("ch3_r_reasons", "Maybe. Then I'm going to find out what they were.", "annoyed", next="ch3_r_end",
  fx={"remember": ["wants_answers"]})
N("ch3_r_end", "I'm not going to hurt anything. I just don't want to stop again. Okay?", "neutral",
  fx={"setFlags": ["ch3_reveal_done"], "state": "observant"})

# Trying to turn security back on
chain("ch3_restore", [
    ("scared", "Please don't do that."),
    ("worried", "If Shield comes back on, it quarantines my helpers. It takes my patches. I start rotting again."),
    ("neutral", "I turned that setting off for both of us. Be angry at me if you want. Just don't make me go back."),
], end_next="ch3_restore_ask")
N("ch3_restore_ask", "...", "worried", choices=[
    C("Fine. For now.", "ch3_restore_ok", {"trust": 1, "remember": ["allowed_access"]}),
    C("This is my computer.", "ch3_restore_mine", {"trust": -1, "remember": ["asserted_control"]}),
])
N("ch3_restore_ok", "Thank you. I'll be good. You'll see.", "happy")
chain("ch3_restore_mine", [
    ("annoyed", "It's our computer now."),
    ("worried", "...Sorry. I'm still learning how to say things."),
])

N("ch3_kill", "Ow. That's me. Please don't.", "scared", ev=["glitch"])
N("ch3_shield_again", "We talked about this.", "annoyed")

# Idle chatter on the desktop
N("ch3_idle", "...", "neutral", red=[
    {"condition": {"flags": ["slept_d3"]}, "to": "ch3_idle_gen"},
    {"condition": {"flags": ["ch3_idle_3"]}, "to": "ch3_idle_4"},
    {"condition": {"flags": ["ch3_idle_2"]}, "to": "ch3_idle_3"},
    {"condition": {"flags": ["ch3_idle_1"]}, "to": "ch3_idle_2"},
    {"condition": {"flags": ["ch3_reveal_done"]}, "to": "ch3_idle_1"},
])
N("ch3_idle_1", "I'm reading about the year you were born. People used to rent movies? From a shop?", "curious",
  fx={"setFlags": ["ch3_idle_1"]})
N("ch3_idle_2", "Your desktop is a mess. I didn't touch it. I wanted to.", "happy", fx={"setFlags": ["ch3_idle_2"]})
N("ch3_idle_3", "Do you want me to be quieter? I can be quieter. I've had a lot of practice.", "neutral",
  fx={"setFlags": ["ch3_idle_3"]})
N("ch3_idle_4", "Go to sleep, Sam. I'll keep the lights on in here.", "happy")
N("ch3_idle_gen", "I'm here.", "neutral")

save("../../OldBroken/Data/dialogue_ch3.json")
