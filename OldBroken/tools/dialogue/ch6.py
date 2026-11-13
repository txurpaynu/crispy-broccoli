"""CHAPTER 6 — THE FACILITY"""
from dlg import N, C, chain, save

chain("ch6_arrive", [
    ("happy", "We're in. We're actually in."),
    ("curious", "It smells like dust through your microphone. Is that what dust sounds like?"),
    ("neutral", "The front door stuck behind you. That's fine. There's a loading dock at the back."),
    ("neutral", "We need a developer workstation that still has power. Try the development floor, east side."),
])
chain("ch6_lobby_desk", [
    ("curious", "A visitor book. The last entry is from 2003."),
    ("neutral", "Nobody signed out."),
], speaker="VEXLEY")
chain("ch6_dark_dev", [
    ("neutral", "This is it. The remaster team's desk. Somebody brought these machines back here in the last year."),
    ("worried", "No power. The building's grid is off."),
    ("neutral", "There's a portable generator against the wall. Start it."),
])
N("ch6_gen_fail", "Pull harder. It's old, like me.", "happy")
chain("ch6_gen_ok", [
    ("happy", "There! Hear that?"),
    ("neutral", "The workstation is booting. Plug me in."),
])
chain("ch6_connect", [
    ("neutral", "Connecting..."),
    ("glitching", "[o-o-oh->oh.]"),
    ("happy", "Oh, it's so big in here. They left everything on the network. Builds, mail, test logs."),
    ("curious", "HALDEN NET. Their internal system. Nobody's logged in since March 2003."),
    ("neutral", "Give me a minute to look around."),
], end_next="ch6_net", end_ev=["glitch"])
chain("ch6_net", [
    ("neutral", "Mail archive: open. Build server: open. The remaster team copied the old repository here, then gave up."),
    ("curious", "There's a project folder called WREN. Locked."),
    ("neutral", "And something called MASTER CONTROL. Locked too. It wants a developer access code."),
    ("worried", "I can't guess it. Four digits, and it locks out after three tries. I already used two."),
], end_next="ch6_lie")
chain("ch6_lie", [
    ("neutral", "...Bad news. The PAPERLIGHT source is behind the same code."),
    ("worried", "The original files. The thing we came for. Sealed."),
    ("neutral", "Developers always write their codes down somewhere. Help me look? Offices, the lab, the server room."),
], end_next="ch6_lie_ask", end_fx={"remember": ["lied_source_code"]})
N("ch6_lie_ask", "Please?", "curious", choices=[
    C("Fine. Where do I start?", "ch6_start", {"trust": 1}),
    C("Why does a game archive need a door code?", "ch6_doubt"),
])
N("ch6_doubt", "It's the same system. One login for everything. Halden was cheap. Start with the offices up front.", "neutral",
  fx={"setFlags": ["ch7_code_needed"], "remember": ["sam_doubted_code"]})
N("ch6_start", "Start with the offices up front. Halden's is the one at the far end.", "happy",
  fx={"setFlags": ["ch7_code_needed"]})

save("../../OldBroken/Data/dialogue_ch6.json")
