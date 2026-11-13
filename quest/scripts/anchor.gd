extends Node3D
## Spawned by OpenXRFbSceneManager for every piece of the room scan.
## The Room script reads the entity through the manager's signal; this just keeps it.

var entity: Object

func setup_scene(e: Object) -> void:
	entity = e
