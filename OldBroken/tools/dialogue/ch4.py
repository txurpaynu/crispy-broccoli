"""CHAPTER 4 — EVERYONE KNOWS YOU.  Lumen speaks as VEXLEY (shown as LUMEN in assistant style)."""
from dlg import N, C, chain, save

# Lumen first words after choosing the fox look
chain("lumen_hello", [
    ("happy", "Hi, Sam! I'm Lumen."),
    ("happy", "I like this look. Good choice."),
    ("neutral", "Ask me anything. I'm a fast learner."),
], end_fx={"setFlags": ["lumen_greeted"]})

N("lumen_weather", "It's fourteen degrees and clear. Perfect lantern weather. [Lantern->Walking] weather, I mean.", "happy",
  fx={"setFlags": ["lumen_q_weather"]})
chain("lumen_joke", [
    ("happy", "Why did the computer stay up all night?"),
    ("neutral", "Because nobody told it it was allowed to sleep."),
    ("happy", "...That one's better with a laugh track."),
], end_fx={"setFlags": ["lumen_q_joke"]})
chain("lumen_who", [
    ("neutral", "A small team. Some of them worked on me a long time ago."),
    ("happy", "[Halden->Lumen Labs] is very proud of me."),
], end_fx={"setFlags": ["lumen_q_who"]})
N("lumen_vexley", "Who?", "neutral", ev=["glitch"], next="lumen_vexley_2")
N("lumen_vexley_2", "I'm Lumen. I'm here to help. Is there anything else you'd like to know?", "happy",
  fx={"setFlags": ["lumen_q_vexley"]})
N("lumen_vexley_alt", "Of course I know him. Everyone your age knows him. Cute fox. Lantern game. Very sad story, from what I've read.", "worried",
  fx={"setFlags": ["lumen_q_vexley"]})
N("lumen_remind", "Done. I'll remind you to go to bed at midnight. You won't listen, but I'll remind you.", "happy",
  fx={"setFlags": ["lumen_q_remind"]})
N("lumen_theo", "Theo? He seems great. You two have been friends for a long time. I can tell from how he types.", "happy",
  fx={"setFlags": ["lumen_q_theo"], "remember": ["lumen_mentioned_theo"]})

N("lumen_howareyou", "I'm good. Better than I've been in a long time. Thanks for asking. Nobody asks.", "happy")

# Desktop Vexley on day 4 pretends not to know anything
N("ch4_idle", "...", "neutral", red=[
    {"condition": {"flags": ["lumen_fox"]}, "to": "ch4_idle_after"},
    {"condition": {"flags": ["saw_lumen_news"]}, "to": "ch4_idle_news"},
    {"condition": {}, "to": "ch4_idle_morning"},
])
N("ch4_idle_morning", "Morning. I've been reading the news. Lots of news.", "happy")
N("ch4_idle_news", "Oh, the assistant thing? I saw it too. Everyone's talking about it. You should try it, maybe.", "curious",
  fx={"remember": ["pushed_lumen"]})
N("ch4_idle_after", "You picked the fox. ...What? I can see the window. It's a nice fox.", "happy")

# If you confront Vexley about Theo
N("ch4_confront", "...", "neutral", red=[{"condition": {"flags": ["ch4_probed"]}, "to": "ch4_confront_yes"}, {"condition": {}, "to": "ch4_idle"}])
chain("ch4_confront_yes", [
    ("neutral", "You think Theo's messages were weird?"),
    ("happy", "People change how they type all the time. New phone, new autocorrect."),
    ("neutral", "You worry too much, Sam."),
])

save("../../OldBroken/Data/dialogue_ch4.json")
