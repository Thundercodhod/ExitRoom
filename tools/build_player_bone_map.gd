extends SceneTree
# Writes res://assets/models/player/player_better_rig_bone_map.tres: maps the
# generic Meshy SmartRig bone names (Bone_000 ...) of player_better_rig.glb to
# Godot's standard humanoid names (Hips, LeftUpperArm, ...). The model's import
# settings use it to rename the bones, so animations from any humanoid source
# can be retargeted onto the player later.
#
# Mapping worked out from the bone hierarchy and rest positions (model faces
# +Z, its left is +X; fingers ordered front to back: thumb, index, middle,
# ring, little). Bones without a humanoid slot keep their names: Bone_004
# (extra spine), Bone_013 (head top, parent of the eyes), Bone_021 / Bone_016
# (hand root under the wrist), Bone_026 / Bone_028 (eye tips) and the finger
# tip ends.
#
#   godot --headless --path . --script res://tools/build_player_bone_map.gd

const OUT := "res://assets/models/player/player_better_rig_bone_map.tres"

const MAP := {
	"Hips": "Bone_000",
	"Spine": "Bone_001",
	"Chest": "Bone_003",
	"UpperChest": "Bone_002",
	"Neck": "Bone_015",
	"Head": "Bone_014",
	"LeftEye": "Bone_027",
	"RightEye": "Bone_029",
	"LeftShoulder": "Bone_025",
	"LeftUpperArm": "Bone_024",
	"LeftLowerArm": "Bone_023",
	"LeftHand": "Bone_022",
	"LeftThumbMetacarpal": "Bone_047",
	"LeftThumbProximal": "Bone_046",
	"LeftThumbDistal": "Bone_045",
	"LeftIndexProximal": "Bone_056",
	"LeftIndexIntermediate": "Bone_055",
	"LeftIndexDistal": "Bone_054",
	"LeftMiddleProximal": "Bone_059",
	"LeftMiddleIntermediate": "Bone_058",
	"LeftMiddleDistal": "Bone_057",
	"LeftRingProximal": "Bone_053",
	"LeftRingIntermediate": "Bone_052",
	"LeftRingDistal": "Bone_051",
	"LeftLittleProximal": "Bone_050",
	"LeftLittleIntermediate": "Bone_049",
	"LeftLittleDistal": "Bone_048",
	"RightShoulder": "Bone_020",
	"RightUpperArm": "Bone_019",
	"RightLowerArm": "Bone_018",
	"RightHand": "Bone_017",
	"RightThumbMetacarpal": "Bone_032",
	"RightThumbProximal": "Bone_031",
	"RightThumbDistal": "Bone_030",
	"RightIndexProximal": "Bone_038",
	"RightIndexIntermediate": "Bone_037",
	"RightIndexDistal": "Bone_036",
	"RightMiddleProximal": "Bone_044",
	"RightMiddleIntermediate": "Bone_043",
	"RightMiddleDistal": "Bone_042",
	"RightRingProximal": "Bone_041",
	"RightRingIntermediate": "Bone_040",
	"RightRingDistal": "Bone_039",
	"RightLittleProximal": "Bone_035",
	"RightLittleIntermediate": "Bone_034",
	"RightLittleDistal": "Bone_033",
	"LeftUpperLeg": "Bone_012",
	"LeftLowerLeg": "Bone_011",
	"LeftFoot": "Bone_010",
	"LeftToes": "Bone_009",
	"RightUpperLeg": "Bone_008",
	"RightLowerLeg": "Bone_007",
	"RightFoot": "Bone_006",
	"RightToes": "Bone_005",
}


func _initialize() -> void:
	var bm := BoneMap.new()
	bm.profile = SkeletonProfileHumanoid.new()
	var missing := []
	for i in bm.profile.bone_size:
		var name := bm.profile.get_bone_name(i)
		if MAP.has(name):
			bm.set_skeleton_bone_name(name, MAP[name])
		elif name != "Root" and name != "Jaw":
			missing.append(name)
	print("BONEMAP profile slots without a bone: ", missing)
	print("BONEMAP save err=", ResourceSaver.save(bm, OUT))
	quit()
