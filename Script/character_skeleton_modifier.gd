@tool

class_name CharacterSkeletonModifier
extends SkeletonModifier3D

@export_enum(" ") var bone: String

func _validate_property(property: Dictionary) -> void:
	if property.name == "bone":
		var skeleton: Skeleton3D = get_skeleton()
		if skeleton:
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = skeleton.get_concatenated_bone_names()

func _process_modification() -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if !skeleton:
		return
	
	var bone_idx: int = skeleton.find_bone(bone)
	var current_pose: Transform3D = skeleton.get_bone_pose(bone_idx)
	var target_pose: Transform3D = current_pose
	var rotation: Quaternion = Quaternion(Vector3.BACK, 0.2)
	target_pose.basis = Basis(rotation) * target_pose.basis
	skeleton.set_bone_pose(bone_idx, target_pose)
	
