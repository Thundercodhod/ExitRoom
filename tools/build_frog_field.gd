extends SceneTree
## Explicit authoring tool: only writes frog_field_world.tscn.
func _initialize() -> void:
	call_deferred("build")

func own(n: Node, scene: Node) -> void:
	for child in n.get_children():
		child.owner = scene
		own(child,scene)

func build() -> void:
	# Dummy rendering discards MultiMesh buffers on save; never overwrite the
	# authored scene with an empty field when invoked headless.
	if DisplayServer.get_name() == "headless":
		push_error("Build the field without --headless so MultiMesh transforms are saved.")
		quit(1)
		return
	var holder := Node3D.new()
	root.add_child(holder)
	var world: Node3D = load("res://scripts/frog_field_world.gd").new().build(holder)
	own(world,world)
	var packed := PackedScene.new()
	var result := packed.pack(world)
	if result == OK: result = ResourceSaver.save(packed,"res://frog_field_world.tscn")
	print("FROG_FIELD_BUILD=",result)
	quit(result)
