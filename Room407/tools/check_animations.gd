extends SceneTree
func _initialize() -> void:
 var n=load("res://Room407/assets/models/male_animated.glb").instantiate()
 var ap=n.find_child("AnimationPlayer",true,false)
 for name in ap.get_animation_list():
  var a=ap.get_animation(name)
  print(name," length=",a.length," tracks=",a.get_track_count())
 n.free()
 quit()
