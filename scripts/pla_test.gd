extends Node3D
# Sandbox for the Pladuk creature model: open pla_test.tscn and press F6.
# Plays whatever animation the imported model carries (expected: Idle_Crawl).

@onready var anim_player: AnimationPlayer = $Pladuk/AnimationPlayer


func _ready() -> void:
	if anim_player == null:
		push_warning("Pladuk/AnimationPlayer not found")
		return
	var anims := anim_player.get_animation_list()
	if anims.is_empty():
		push_warning("Pladuk model has no animations")
		return
	var anim_name := "Idle_Crawl" if anim_player.has_animation("Idle_Crawl") else anims[0]
	anim_player.play(anim_name)
	anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
