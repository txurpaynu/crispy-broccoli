extends SceneTree
# CI helper: writes Godot's default OpenXR action map (trigger, grip, A/B/X/Y, menu...)
# for Quest Touch controllers if the project doesn't have one yet.
func _init() -> void:
	var path := "res://openxr_action_map.tres"
	if not FileAccess.file_exists(path):
		var am := OpenXRActionMap.new()
		am.create_default_action_sets()
		var err := ResourceSaver.save(am, path)
		print("[action map] created default: ", err)
	else:
		print("[action map] already present")
	quit()
