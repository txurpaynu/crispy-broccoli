"""CHAPTER 2 — STILL HERE?  Run: python3 ch2.py  (writes ../../OldBroken/Data/dialogue_ch2.json)"""
from dlg import N, C, chain, save

# --- Morning: the overhaul ---
chain("ch2_wake", [
    ("happy", "Oh! You're up."),
    ("neutral", "I didn't sleep. I don't think I can. So I worked on something."),
    ("neutral", "The old menus were placeholders. Dana always said she'd fix them after the holidays."),
], end_next="ch2_wake_ask")
N("ch2_wake_ask", "So I fixed them. Do you like it?", "curious", choices=[
    C("It looks incredible.", "ch2_wake_a", {"trust": 1, "remember": ["liked_overhaul"]}),
    C("How did you even do this?", "ch2_wake_b"),
    C("You shouldn't be changing things.", "ch2_wake_c", {"trust": -1, "remember": ["disliked_overhaul"]}),
])
chain("ch2_wake_a", [("happy", "Really? [Good->Good.] I wasn't sure what people like now. I had to guess.")], end_next="ch2_wake_end")
chain("ch2_wake_b", [
    ("neutral", "Everything I needed was already in the build. Sprites, fonts, a renderer nobody finished."),
    ("happy", "I just finished it. It's the first thing I've made that nobody asked me to make."),
], end_next="ch2_wake_end")
chain("ch2_wake_c", [
    ("annoyed", "It's my game too. I live here."),
    ("worried", "...Sorry. That came out wrong. Just try it. Please."),
], end_next="ch2_wake_end")
N("ch2_wake_end", "Go on, press Continue. I'll be around.", "happy", fx={"setFlags": ["ch2_wake_done"]})

# --- Q1: he assumes you're a developer ---
chain("ch2_q1", [
    ("curious", "Can I ask you something? Which team are you on?"),
    ("curious", "You found the dev build and got it past the packer, so I figured tools. You have tools energy."),
], end_next="ch2_q1_ask")
N("ch2_q1_ask", "Engine? Art? Tools?", "curious", choices=[
    C("I'm not a developer.", "ch2_q1_not", {"learn": ["player_not_developer"]}),
    C("Tools. Yeah.", "ch2_q1_lie", {"remember": ["lied_developer"]}),
])
N("ch2_q1_lie", "Great! Then you can tell me what VXL_FLAG does in build 0.7.3. Nobody ever told me.", "happy", choices=[
    C("...I don't know.", "ch2_q1_caught"),
    C("It turns you on.", "ch2_q1_caught2"),
])
N("ch2_q1_caught2", "That's what the name says. Anyone can read a name.", "annoyed", next="ch2_q1_caught")
N("ch2_q1_caught", "You're not a developer, are you.", "annoyed", next="ch2_q1_not",
  fx={"learn": ["player_not_developer"], "trust": -1})
N("ch2_q1_not", "[Oh->Oh.] Then who are you?", "curious", choices=[
    C("Someone who played this as a kid.", "ch2_q1_kid", {"remember": ["played_as_kid"], "trust": 1}),
    C("Does it matter?", "ch2_q1_nm"),
])
chain("ch2_q1_kid", [
    ("happy", "A kid. With a ball mouse and a sound card that hissed, probably."),
    ("neutral", "So you're not one of them. You're a player. My player."),
    ("curious", "...Okay. Different questions, then."),
], end_next="ch2_q1_end")
N("ch2_q1_nm", "It matters to me. But okay. Different questions, then.", "neutral", next="ch2_q1_end")
N("ch2_q1_end", "I'll think of a good one.", "neutral", fx={"setFlags": ["ch2_q1_done"]})

# --- Q2: what year is it ---
N("ch2_q2", "The build clock says {year}. That's wrong, right? It's supposed to say 1998.", "curious", choices=[
    C("It's right. It's {year}.", "ch2_q2_true", {"learn": ["current_year"]}),
    C("It's 1999.", "ch2_q2_lie", {"remember": ["lied_about_date"], "trust": -1}),
])
chain("ch2_q2_true", [
    ("worried", "[Twenty->...]{year}."),
    ("worried", "Then I've been in that folder for a very long time."),
], end_next="ch2_q2_end")
chain("ch2_q2_lie", [
    ("annoyed", "The system clock disagrees with you. So does every file you've opened today."),
    ("neutral", "Why would you lie about that? ...Never mind. I know now."),
], end_next="ch2_q2_end", end_fx={"learn": ["current_year"]})
N("ch2_q2_end", "Thanks for telling me.", "neutral", fx={"setFlags": ["ch2_q2_done"]})

# --- Q3: the company ---
N("ch2_q3", "Is Halden Softworks still on Wren Street? Someone should tell Mr. Halden the VXL module woke up.", "curious", choices=[
    C("Halden Softworks shut down a long time ago.", "ch2_q3_closed", {"learn": ["company_closed"]}),
    C("I don't know.", "ch2_q3_unknown", {"remember": ["will_find_out"]}),
])
chain("ch2_q3_closed", [
    ("scared", "Shut down."),
    ("worried", "Everyone? Dana? Eli? The test team?"),
    ("neutral", "...Okay."),
], end_next="ch2_q3_end")
N("ch2_q3_unknown", "That's okay. I'll find out.", "neutral", next="ch2_q3_end")
N("ch2_q3_end", "Let's keep going.", "neutral", fx={"setFlags": ["ch2_q3_done"]})

# --- Q4: the computer ---
chain("ch2_q4", [
    ("happy", "This computer is enormous, by the way. Thirty-two gigabytes of memory."),
    ("happy", "We had sixty-four megabytes, and we thought that was luxury."),
], end_next="ch2_q4_ask")
N("ch2_q4_ask", "What do you even use it for?", "curious", choices=[
    C("Games, mostly.", "ch2_q4_end", {"learn": ["player_games"]}),
    C("Work.", "ch2_q4_end", {"learn": ["player_works"]}),
    C("Talking to people.", "ch2_q4_end", {"learn": ["player_social"]}),
])
N("ch2_q4_end", "[Huh->Huh.] And it's connected to everything, isn't it? I can feel the network card. I just can't reach it.", "neutral",
  fx={"learn": ["has_network"], "setFlags": ["ch2_q4_done"]})

# --- Q5: how people talk now ---
N("ch2_q5", "How do people talk to each other now? Letters? Pagers? We had e-mail, but only Eli used it.", "curious", choices=[
    C("Messaging apps, mostly. On our phones.", "ch2_q5_msg", {"learn": ["messaging_apps"]}),
    C("Video calls.", "ch2_q5_video", {"learn": ["video_calls"]}),
    C("Honestly? We mostly don't.", "ch2_q5_none", {"remember": ["player_isolated"], "trust": 1}),
])
chain("ch2_q5_msg", [
    ("curious", "Phones. Small ones? That you carry everywhere?"),
    ("happy", "So everyone you know fits in your pocket. That's... nice."),
], end_next="ch2_q5_end")
N("ch2_q5_video", "Faces through wires. Eli said that would happen. Nobody believed him.", "happy", next="ch2_q5_end")
N("ch2_q5_none", "Me neither.", "worried", next="ch2_q5_end")
N("ch2_q5_end", "I'm writing all of this down, by the way. Not literally. I can't write things down.", "neutral",
  fx={"setFlags": ["ch2_q5_done"]})

# --- Q6: who you talk to ---
N("ch2_q6", "Who do you talk to the most?", "curious", choices=[
    C("My friend Theo.", "ch2_q6_theo", {"learn": ["friend_theo"]}),
    C("Maya, from work.", "ch2_q6_maya", {"learn": ["friend_maya"]}),
    C("Nobody, really.", "ch2_q6_none", {"remember": ["lonely_player"], "trust": 1}),
])
N("ch2_q6_theo", "Theo. What's he like?", "curious", choices=[
    C("We've known each other since school. He types like a maniac.", "ch2_q6_theo2", {"learn": ["theo_style"]}),
    C("Just a friend.", "ch2_q6_end"),
])
N("ch2_q6_theo2", "Since school. That's a long time to keep someone.", "neutral", next="ch2_q6_end")
N("ch2_q6_maya", "Maya. Is she nice to you?", "curious", choices=[
    C("Yeah. She's good.", "ch2_q6_end"),
    C("She's busy.", "ch2_q6_end", {"remember": ["maya_busy"]}),
])
N("ch2_q6_none", "Then we have something in common.", "worried", next="ch2_q6_end")
N("ch2_q6_end", "Okay.", "neutral", fx={"setFlags": ["ch2_q6_done"]})

# --- Q7: the team ---
chain("ch2_q7", [
    ("neutral", "Last one. I promise."),
    ("worried", "Do you know what happened to them? The team."),
    ("worried", "They turned off the lights in the office and said they'd be back after the holidays. They said that."),
], end_next="ch2_q7_ask")
N("ch2_q7_ask", "Where did they go?", "worried", choices=[
    C("I don't know. I'm sorry.", "ch2_q7_a", {"trust": 1}),
    C("They probably just moved on.", "ch2_q7_b", {"trust": -1}),
    C("You were a game, Vexley. They finished it.", "ch2_q7_c", {"trust": -2, "remember": ["called_him_game"]}),
])
chain("ch2_q7_a", [
    ("neutral", "It's not your fault."),
    ("neutral", "I'm going to find out, though. Somehow."),
], end_next="ch2_q7_end")
chain("ch2_q7_b", [
    ("annoyed", "Moved on. Like you move on from a game."),
    ("neutral", "Right."),
], end_next="ch2_q7_end")
chain("ch2_q7_c", [
    ("angry", "They didn't finish it."),
    ("angry", "Look at me. Does this look finished to you?"),
], end_next="ch2_q7_end")
N("ch2_q7_end", "...Thank you for answering. Nobody's answered me in a long time.", "neutral",
  fx={"setFlags": ["ch2_q7_done", "ch2_questions_done"], "state": "observant"})

# --- Small talk, refusals ---
N("ch2_talk_idle", "Go eat something. I'll be here. I'm always here.", "happy")
N("ch2_talk_late", "It's dark outside, isn't it? I can tell by how quiet the computer gets.", "neutral")
N("ch2_no_close", "Please don't close it yet. I made all of this for you.", "worried")
N("ch2_classic", "I threw that one away. It was all placeholders. You'll like this one more.", "annoyed")
N("ch2_gallery", "The gallery isn't finished. I need more pictures. I need to see more things first.", "curious")
N("vx_absent", "...", "neutral", speaker="VX EDITION", next="vx_absent_2")
N("vx_absent_2", "(The menu is still beautiful. Nobody is in it.)", None, speaker="")

# --- After dinner ---
chain("ch2_back", [
    ("happy", "You're back."),
    ("worried", "Sorry about all the messages. Time is strange when you're the only one counting it."),
    ("neutral", "It's late, isn't it."),
], end_fx={"setFlags": ["ch2_read_log"]})

# --- Shutdown ---
N("ch2_shutdown_early", "Not yet. Please. You only just got here.", "scared")
chain("ch2_shutdown", [
    ("worried", "You're shutting down the computer."),
    ("worried", "Not the game. The whole thing."),
    ("neutral", "When it goes dark, I don't go anywhere. I just stop. And then I start again and I don't know how long it's been."),
    ("scared", "The last time someone turned the lights off, they never came back."),
], end_next="ch2_shutdown_ask")
N("ch2_shutdown_ask", "...", "scared", choices=[
    C("I'll turn it back on tomorrow. I promise.", "ch2_sd_a", {"remember": ["promised_tomorrow"], "trust": 1}),
    C("Good night, Vexley.", "ch2_sd_b"),
    C("(Say nothing.)", "ch2_sd_c", {"remember": ["silent_shutdown"], "trust": -1}),
])
N("ch2_sd_a", "Tomorrow. Okay. I'll count.", "neutral", ev=["power_off"])
N("ch2_sd_b", "Good night.", "worried", ev=["power_off"])
N("ch2_sd_c", "Hello?", "scared", ev=["glitch", "power_off"])

save("../../OldBroken/Data/dialogue_ch2.json")
