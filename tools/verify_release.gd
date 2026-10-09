extends SceneTree
## Run after a fresh import and against an exported PCK before publishing.
const Style = preload("res://scripts/anthology_style.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	for font in [Style.BODY_FONT,Style.TITLE_FONT]:
		for letter in "บ้านที่ยังรอกะสุดท้ายผู้โดยสารห้องเช่า 0123456789 EXITROOM":
			if not font.has_char(letter.unicode_at(0)):
				push_error("Missing font glyph: "+letter)
				failures += 1
	var manager := root.get_node("Anthology")
	for entry in manager.EPISODES:
		var scene := load(entry.scene) as PackedScene
		if scene==null or not scene.can_instantiate():
			push_error("Episode cannot load: "+entry.scene)
			failures += 1
		var photo := load("res://ui/previews/"+entry.id+".png") as Texture2D
		if photo==null:
			push_error("Missing preview: "+entry.id)
			failures += 1
	for key in ["ui_move","ui_accept","tape","knock","message","door","sting","fluorescent","low_pulse","menu_ambience"]:
		var sound := load("res://audio/anthology/"+key+".wav") as AudioStream
		if sound==null or sound.get_length()<=0:
			push_error("Missing audio: "+key)
			failures += 1
	# A failed shader include during export can silently strip material uniforms.
	var world := (load("res://frog_field_world.tscn") as PackedScene).instantiate()
	var grass := world.get_node("BinbunGrass/Grass_0_0") as MultiMeshInstance3D
	var material := grass.material_override as ShaderMaterial
	for key in ["shape_texture","shape_atlas","color_gradient"]:
		if not material.get_shader_parameter(key) is Texture2D:
			push_error("Missing grass material texture: "+key)
			failures += 1
	if material.get_shader_parameter("alpha_mode")!=2:
		push_error("Grass cutout shader settings lost during export")
		failures += 1
	world.free()
	print("RELEASE_RESOURCE_FAILURES=",failures)
	quit(1 if failures else 0)
