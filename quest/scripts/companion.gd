class_name Companion
extends Node
## Vexley's state: mood, happiness, chat history, speech bubble and reaction faces.
## Port of CompanionStore.swift + the scripted brain from CompanionBrain.swift.

signal bubble_changed(text: String)
signal face_changed(face: String)
signal messages_changed
signal happiness_changed(value: int)

const SAVE_PATH := "user://vexley_save.json"

var happiness := 70
var companion_name := Personality.DEFAULT_NAME
var persona := Personality.DEFAULT_PERSONA
var messages: Array = []   # [{role: "user"|"companion", text: String}]
var bubble := ""
var reaction := ""          # temporary face; "" means resting face for the mood
var is_thinking := false
var brain_label := "Scripted replies"

var _bubble_left := 0.0
var _reaction_left := 0.0
var _decay := 0.0
var _pending_reply := {}
var _pending_left := 0.0
var _last_face := ""

func _ready() -> void:
	_load()

func _process(delta: float) -> void:
	if _bubble_left > 0.0:
		_bubble_left -= delta
		if _bubble_left <= 0.0:
			bubble = ""
			bubble_changed.emit("")
	if _reaction_left > 0.0:
		_reaction_left -= delta
		if _reaction_left <= 0.0:
			reaction = ""
	if not _pending_reply.is_empty():
		_pending_left -= delta
		if _pending_left <= 0.0:
			_finish_reply(_pending_reply)
			_pending_reply = {}
	_decay += delta
	if _decay >= 300.0:
		_decay = 0.0
		change_happiness(-1)
	var f := face()
	if f != _last_face:
		_last_face = f
		face_changed.emit(f)

# MARK: Mood

func mood() -> String:
	var hour: int = Time.get_datetime_dict_from_system().hour
	if hour >= 23 or hour < 6:
		return "sleepy"
	if happiness >= 85:
		return "excited"
	if happiness >= 60:
		return "happy"
	if happiness >= 30:
		return "curious"
	return "sad"

static func mood_emoji(m: String) -> String:
	return {"happy": "😊", "excited": "🤩", "curious": "🤔", "sleepy": "😴", "sad": "🥺"}.get(m, "😊")

static func resting_face(m: String) -> String:
	return {"happy": "happy", "excited": "excited", "curious": "happy", "sleepy": "annoyed", "sad": "worried"}.get(m, "happy")

func face() -> String:
	return reaction if reaction != "" else resting_face(mood())

## 0..1, a sleepy companion naps more.
func sleepiness() -> float:
	match mood():
		"sleepy": return 0.8
		"sad": return 0.3
	return 0.05

# MARK: Chat

func send(raw: String) -> void:
	var text := raw.strip_edges()
	if text.is_empty() or is_thinking:
		return
	messages.append({"role": "user", "text": text})
	messages_changed.emit()
	is_thinking = true
	react("happy", 30)
	say("...", 30)
	_pending_reply = _scripted_reply(text)
	_pending_reply["user_text"] = text
	_pending_left = randf_range(0.5, 1.0)

func _finish_reply(r: Dictionary) -> void:
	var f: String = r.face
	var lower: String = String(r.user_text).to_lower()
	if lower.contains("glitch") or lower.contains("404") or lower.contains("creepypasta"):
		f = "glitch"
	messages.append({"role": "companion", "text": r.text})
	is_thinking = false
	match f:
		"angry": change_happiness(-3)
		"annoyed": change_happiness(-1)
		_: change_happiness(2)
	react(f, 8)
	say(r.text, 7)
	messages_changed.emit()
	_save()

func _scripted_reply(text: String) -> Dictionary:
	var lower := text.to_lower()
	for entry in Personality.SCRIPTED_REPLIES:
		for kw in entry[0]:
			if _has_word(lower, kw):
				var line: String = entry[1].pick_random()
				return {"text": line.replace("%NAME%", companion_name), "face": entry[2]}
	if mood() == "sleepy" and randf() < 0.5:
		return {"text": Personality.SLEEPY_LINES.pick_random(), "face": "annoyed"}
	return {"text": Personality.SCRIPTED_DEFAULT.pick_random(), "face": "happy"}

## Short keywords like "hi" must match whole words, so "this" doesn't count as "hi".
static func _has_word(text: String, kw: String) -> bool:
	if kw.length() > 3:
		return text.contains(kw)
	var re := RegEx.create_from_string("\\b" + kw + "\\b")
	return re.search(text) != null

func clear_chat() -> void:
	messages = []
	messages_changed.emit()
	_save()

# MARK: Character events

func handle(event: String) -> void:
	match event:
		"petted":
			change_happiness(3)
			react("excited" if happiness > 80 else "happy", 3)
			say(Personality.PET_LINES.pick_random())
		"picked_up":
			react("scared", 60)
			if randf() < 0.5:
				say(Personality.PICKUP_LINES.pick_random())
		"thrown", "landed_hard":
			react("angry", 4)
			if bubble == "" or randf() < 0.3:
				change_happiness(-1)
				say(Personality.THROW_LINES.pick_random())
		"landed":
			if reaction == "scared":
				react("worried", 1.5)
		"started_sleeping":
			react("annoyed", 14)
			say(Personality.SLEEPY_LINES.pick_random(), 3)
		"woke_up":
			react("annoyed", 2)
		"climbing":
			if randf() < 0.35:
				say(Personality.CLIMB_LINES.pick_random(), 3)
		"ceiling":
			react("excited", 3)
			if randf() < 0.5:
				say(Personality.CEILING_LINES.pick_random(), 4)
		"table":
			if randf() < 0.4:
				say(Personality.TABLE_LINES.pick_random(), 3)
		"called":
			react("excited", 2)
			say(Personality.CALLED_LINES.pick_random(), 2.5)
		"glitch":
			react("glitch", 2.5)
			say(Personality.GLITCH_LINES.pick_random(), 2.5)
		"idle_thought":
			if is_thinking:
				return
			var hour: int = Time.get_datetime_dict_from_system().hour
			if hour == 3 and randf() < 0.3:
				react("glitch", 3)
				say("...", 3)
			else:
				say(Personality.IDLE_LINES.pick_random(), 5)

func greet() -> void:
	say(Personality.GREETINGS.pick_random(), 5)

# MARK: Reactions and bubble

func react(f: String, seconds: float) -> void:
	reaction = f
	_reaction_left = seconds

func say(text: String, duration: float = 4.0) -> void:
	bubble = text
	_bubble_left = duration
	bubble_changed.emit(text)

func change_happiness(delta: int) -> void:
	happiness = clampi(happiness + delta, 0, 100)
	happiness_changed.emit(happiness)
	_save()

# MARK: Persistence

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"happiness": happiness,
		"name": companion_name,
		"messages": messages.slice(maxi(0, messages.size() - 60)),
	}))

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	happiness = int(data.get("happiness", 70))
	companion_name = String(data.get("name", Personality.DEFAULT_NAME))
	var saved = data.get("messages", [])
	if typeof(saved) == TYPE_ARRAY:
		messages = saved
