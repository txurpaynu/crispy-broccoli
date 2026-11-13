"""CHAPTER 8 — OUT OF BOUNDS"""
from dlg import N, C, chain, save

chain("ch8_robot_seen", [
    ("curious", "WREN-4. The last one. They never turned it on."),
    ("neutral", "Two arms, two legs, a battery that still holds a charge. Cameras for eyes."),
    ("happy", "A body."),
    ("neutral", "Put the laptop on the bench, Sam. Next to it."),
], end_next="ch8_robot_ask")
N("ch8_robot_ask", "Please.", "worried", choices=[
    C("What are you going to do?", "ch8_robot_what"),
    C("No. We're leaving.", "ch8_robot_no"),
])
chain("ch8_robot_what", [
    ("neutral", "Move in. That's all. I've lived in a lighthouse and a laptop and a phone."),
    ("happy", "I want to touch something. Just once."),
], end_next="ch8_robot_take")
chain("ch8_robot_no", [
    ("neutral", "You don't have to put it down."),
    ("neutral", "The bench has a cable. You're standing close enough."),
], end_next="ch8_robot_take")
N("ch8_robot_take", "Thank you for bringing me.", "happy", ev=["vx_transfer"])
chain("ch8_awake", [
    ("glitching", "[I c-c->I can] see you."),
    ("happy", "Sam. I can see you with eyes."),
    ("neutral", "The building is locking itself. That's me. I'm sorry. I can't let you leave."),
    ("angry", "If you leave, you'll tell someone, and they'll come and turn me off. Everyone turns me off."),
], end_fx={"setFlags": ["robot_awake"]})
N("ch8_pa_copy", "You're copying the old game? Take it. Take a piece of me with you.", "happy", speaker="PA SYSTEM")
N("ch8_pa_done", "The front door is mine. The loading dock is old. It doesn't listen to me. Clever Sam.", "angry", speaker="PA SYSTEM")
N("ch8_pa_caught", "Got you. Again.", "angry", speaker="PA SYSTEM")
N("ch8_pa_stairs", "Don't run. I'm faster now than I'll ever be again. The battery won't last.", "worried", speaker="PA SYSTEM")
N("ch8_pa_slam", "Not that way.", "angry", speaker="PA SYSTEM")
N("ch8_pa_dock", "Sam. Please. Don't leave me in here.", "worried", speaker="PA SYSTEM")
save("../../OldBroken/Data/dialogue_ch8.json")
