class_name CharacterSkeletonModifier
extends SkeletonModifier3D

@export var bone: String = "Spine"
var lean_factor: float = 5.0
var lean_angle: float = 20.0
var current_angle: float = 0.0

func _process_modification() -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if !skeleton:
		return
	var dt: float = get_process_delta_time()
	var move_dir: Vector3 = Character.force_vec.normalized()
	var forward_dir: Vector3 = Character.last_orientation.normalized()
	var target_angle: float = 0.0
	
	var angle: float = forward_dir.dot(move_dir)
	var rel_dir: float = move_dir[0] * forward_dir[2] - move_dir[2] * forward_dir[0]

	if angle >= -0.4 and angle <= 0.4:
		target_angle = -lean_angle if rel_dir > 0 else lean_angle
	
	current_angle = lerpf(current_angle, target_angle, lean_factor * dt)

	var rot := Quaternion(
		Vector3.BACK,
		deg_to_rad(current_angle)
	)
	
	var bone_idx: int = skeleton.find_bone(bone)
	var current_pose: Transform3D = skeleton.get_bone_pose(bone_idx)
	var target_pose: Transform3D = current_pose
	target_pose.basis = Basis(rot) * target_pose.basis
	skeleton.set_bone_pose(bone_idx, target_pose)
	
