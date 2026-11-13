extends SceneTree
# CI helper: prints the APIs of the installed OpenXR vendors plugin so the app code can match them.
func _init() -> void:
	for c in ["OpenXRFbSceneManager", "OpenXRFbSpatialEntity", "OpenXRFbSpatialEntityQuery", "OpenXRFbSceneCaptureExtensionWrapper", "OpenXRFbPassthroughExtensionWrapper", "OpenXRFbSceneExtensionWrapper", "OpenXRMetaPassthroughColorLut", "OpenXRFbHandTrackingMesh", "OpenXRAndroidSceneMeshing", "OpenXRMetaEnvironmentDepth", "OpenXRSpatialEntityTracker"]:
		print("CLASS ", c, " exists=", ClassDB.class_exists(c))
		if not ClassDB.class_exists(c):
			continue
		print("  parent=", ClassDB.get_parent_class(c))
		for m in ClassDB.class_get_method_list(c, true):
			var args := []
			for a in m.args:
				args.append("%s:%s" % [a.name, a.type])
			print("  method ", m.name, "(", ", ".join(args), ")")
		for p in ClassDB.class_get_property_list(c, true):
			print("  prop ", p.name, " type=", p.type, " hint=", p.hint_string)
		for s in ClassDB.class_get_signal_list(c, true):
			print("  signal ", s.name, " ", s.args.map(func(x): return x.name))
		for k in ClassDB.class_get_integer_constant_list(c, true):
			print("  const ", k, "=", ClassDB.class_get_integer_constant(c, k))
	for p in ProjectSettings.get_property_list():
		if String(p.name).begins_with("xr/"):
			print("SETTING ", p.name, " = ", ProjectSettings.get_setting(p.name))
	quit()
