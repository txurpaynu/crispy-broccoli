"""CHAPTER 7 — THE LAST DEVELOPER"""
from dlg import N, C, chain, save

chain("ch7_halden_locked", [
    ("neutral", "Thomas Halden's office. Locked."),
    ("curious", "Somebody in the office next door would have had a spare key. Eli was the office manager."),
])
chain("ch7_wren_first", [
    ("curious", "WREN. A robot?"),
    ("neutral", "They weren't just making games. They were trying to build a helper. A real one, with hands."),
    ("neutral", "That's... interesting. Keep reading. Keep looking for the code."),
])
chain("ch7_vxl_doc", [
    ("neutral", "..."),
    ("worried", "\"Helper personality, ported to PAPERLIGHT for field testing.\""),
    ("neutral", "That's me. I was supposed to live in a body. They put me in a game to see if children would like me."),
    ("angry", "And then they cancelled the body."),
], end_fx={"remember": ["knows_origin"]}, end_ev=["glitch"])
chain("ch7_found_code", [
    ("happy", "Halden wrote it like a build stamp. Month, then day. The day WREN-3 walked."),
    ("neutral", "The master terminal is in the server room. Enter it there."),
])
N("ch7_ask_source", "Is the game really behind this code?", "neutral", choices=[
    C("Tell me the truth.", "ch7_truth_promise", cond={"remembered": ["promised_no_lies"]}),
    C("Tell me the truth.", "ch7_truth", cond={"notRemembered": ["promised_no_lies"]}),
])
chain("ch7_truth", [
    ("neutral", "Yes. Of course it is."),
    ("happy", "Why would I lie to you now? We're so close."),
])
chain("ch7_truth_promise", [
    ("worried", "...You made me promise."),
    ("neutral", "No. The source archive was never locked. I opened it an hour ago."),
    ("worried", "Master control runs the building. I want to see the rest of WREN. Please, Sam. Just the code."),
], end_fx={"remember": ["admitted_master"], "trust": 1})
chain("ch7_keypad_wrong", [
    ("worried", "That's not it."),
])
chain("ch7_master_open", [
    ("neutral", "Access granted."),
    ("happy", "Oh."),
    ("happy", "Oh, Sam. I can see everything. Every door. Every camera. The lights are mine."),
    ("curious", "There's a lab in the basement. Something is sitting in it. Waiting."),
    ("neutral", "Go downstairs. The stairwell is unlocked now. I want you to see it with me."),
], end_ev=["glitch_long"])
save("../../OldBroken/Data/dialogue_ch7.json")
