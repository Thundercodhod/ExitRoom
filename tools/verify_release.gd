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
	for key in ["ui_move","ui_accept","tape","knock","message","door","sting","fluorescent","low_pulse"]:
		var sound := load("res://audio/anthology/"+key+".wav") as AudioStream
		if sound==null or sound.get_length()<=0:
			push_error("Missing audio: "+key)
			failures += 1
	var music := load("res://audio/anthology/menu_music.mp3") as AudioStream
	if music==null or music.get_length()<=0:
		push_error("Missing audio: menu_music")
		failures += 1
	var field_music := load("res://audio/dream_field/field_music.mp3") as AudioStream
	if field_music==null or field_music.get_length()<=0:
		push_error("Missing audio: field_music")
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
	# Level 06 is independently selectable, including the baked cat and sunset.
	var dream := (load("res://scenes/dream_field/world.tscn") as PackedScene).instantiate()
	if dream.get_node_or_null("WakeMonument/StatueSocket/CatStatue")==null:
		push_error("Missing dream-field cat statue")
		failures += 1
	var sky_material: ShaderMaterial = dream.get_node("SunsetAtmosphere").environment.sky.sky_material
	if not sky_material.get_shader_parameter("panorama") is Texture2D:
		push_error("Missing sunset sky texture")
		failures += 1
	dream.free()
	for path in ["cat_albedo.png","psx_grass.png","psx_dirt.png","psx_stone.png","psx_forest_floor.png"]:
		var texture := load("res://assets/dream_field/"+path) as Texture2D
		if texture==null or not texture.get_image().has_mipmaps():
			push_error("Missing dream-field texture/mipmaps: "+path)
			failures += 1
	for path in ["wind_loop","dry_grass_loop","grass_step_1","grass_step_2","grass_step_3","grass_step_4"]:
		var clip := load("res://audio/dream_field/"+path+".wav") as AudioStream
		if clip==null or clip.get_length()<=0:
			push_error("Missing dream-field audio: "+path)
			failures += 1
	print("RELEASE_RESOURCE_FAILURES=",failures)
	quit(1 if failures else 0)
