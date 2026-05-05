extends Node3D
@onready var characterBody: CharacterBody3D = $CharacterBody3D
@onready var camera: Camera3D = $"../Camera3D"

# TODO:
	# Move
	# Rotate towards the direction of movement
	# Tilt While Moving

# IDEA:
	# Inputs are floating point numbers ranging from 0 to 1
	# Force is applied naturally by just multiplying the force scalar by a matrix

# TODO:
	# Idle and Walk will be connected via BlendSpace1D
	# Turn animations will be connected via OneShot node
	# Both will be connected with Transition node


# Both inputs and directions in WASD order
var inputs: NDArray = nd.zeros([4, 1])
var directions: NDArray = nd.array([[0, 0, 1], [-1, 0, 0], [0, 0, -1], [1, 0, 0]], nd.Float32)
var key_direction: Vector3

# Linear Movement
@export var force: float = 20
var acceleration: Vector3
var prev_acceleration: Vector3
var velocity: Vector3
var force_vec: Vector3
var drag: float = 0.9
var snappiness: float = 3.0
var target_angle: float
var desired_rotation: Quaternion
var direction_rotation: Quaternion
var tilt_rotation: Quaternion

# Turn correction
var turn_direction: Vector3
var delta_global: float
var correct_rotation: bool = false
var able_to_turn: bool = true
var dont_rotate_while_stopping: bool = false

# Animation Parameters
@export var animationTree: AnimationTree
var blend_position: float
var last_orientation: Vector3

# keys
var forward: bool
var backward: bool
var left: bool
var right: bool

func process_input() -> void:
	if Input.is_action_pressed("Forward"):
		inputs.set(1.0, 0, 0)
	else:
		inputs.set(0.0, 0, 0)
	if Input.is_action_pressed("Left"):
		inputs.set(1.0, 1, 0)
	else:
		inputs.set(0.0, 1, 0)
	if Input.is_action_pressed("Backward"):
		inputs.set(1.0, 2, 0)
	else:
		inputs.set(0.0, 2, 0)
	if Input.is_action_pressed("Right"):
		inputs.set(1.0, 3, 0)
	else:
		inputs.set(0.0, 3, 0)

func orientation(delta: float) -> void:
	key_direction = nd.sum(nd.multiply(directions, inputs), 0).to_vector3().normalized()
	blend_position = velocity.length()
	if key_direction.length() < 0.1:
		force_vec *= 0.0
		return
	var camera_yaw: float = camera.transform.basis.get_euler().y
	target_angle = atan2(key_direction.x, -key_direction.z) + camera_yaw
	# Smoothly rotate to target rotation
	desired_rotation = Quaternion(Vector3.UP, target_angle)
	force_vec = Vector3(sin(target_angle), 0.0, cos(target_angle))

func movement(delta: float) -> void:
	acceleration *= 0.0
	acceleration = force_vec * force
	velocity += acceleration * delta
	velocity *= drag

func tilt(delta: float) -> void:
	# cross product between local y and acceleraction vector
	var norm_local_y: Vector3 = characterBody.transform.basis.y.normalized()
	var norm_acc: Vector3 = acceleration.normalized()
	var rotation_axis: Vector3 = norm_local_y.cross(norm_acc)
	if rotation_axis == Vector3.ZERO:
		var t = Quaternion.from_euler(Vector3(0.0, desired_rotation.get_euler().y, 0.0))
		characterBody.transform.basis = Basis(characterBody.transform.basis.get_rotation_quaternion().slerp(t, snappiness * delta))
		return
	
	characterBody.transform.basis = characterBody.transform.basis.slerp(characterBody.transform.basis.rotated(rotation_axis.normalized(), deg_to_rad(10.0)), snappiness * delta)

func turn_animation(delta: float) -> void:
	reset_turn_triggers()
	if !able_to_turn:
		return
	
	if !forward and !backward and !left and !right:
		return
		
	turn_direction = force_vec
	
	var angle: float = last_orientation.normalized().dot(force_vec.normalized())
	var rel_dir: float = force_vec[0] * last_orientation[2] - force_vec[2] * last_orientation[0]
	if angle <= -0.8:
		#print("Turn 180")
		animationTree.set("parameters/conditions/right_turn_180", true)
	if angle <= 0.4 and angle >= -0.4:
		if rel_dir >= 0:
			#print("Turn Left 90")
			animationTree.set("parameters/conditions/left_turn_90", true)
		elif rel_dir < 0:
			#print("Turn Right 90")
			animationTree.set("parameters/conditions/right_turn_90", true)

func movement_animation() -> void:
	reset_move_triggers()
	
	if key_direction.length() < 0.1:
		animationTree.set("parameters/conditions/stop_run", true)
		return
	
	animationTree.set("parameters/conditions/start_run", true)

func reset_turn_triggers():
	animationTree.set("parameters/conditions/left_turn_90", false)
	animationTree.set("parameters/conditions/right_turn_90", false)
	animationTree.set("parameters/conditions/right_turn_180", false)

func reset_move_triggers():
	animationTree.set("parameters/conditions/start_run", false)
	animationTree.set("parameters/conditions/stop_run", false)

func rotation_correction(delta: float):
	if !correct_rotation:
		return
	
	var current_fwd: Vector3 = characterBody.transform.basis.z
	var current_rot: Vector2 = Vector2(current_fwd.x, current_fwd.z)
	var target_rot: Vector2 = Vector2(turn_direction.x, turn_direction.z)
	
	if target_rot.dot(target_rot) == 0.0:
		return
	
	var current_angle: float = current_rot.angle()
	var target_angle: float = target_rot.angle()
	
	var delta_angle: float = target_angle - current_angle
	delta_angle = fmod(delta_angle + PI, 2.0 * PI) - PI
	
	var rot_quat: Quaternion = Quaternion(Vector3.UP, -delta_angle * 0.05)
	characterBody.set_quaternion(characterBody.get_quaternion() * rot_quat)

func _ready() -> void:
	animationTree.active = true
	animationTree.set("parameters/conditions/idle", true)
	
	forward = Input.is_action_pressed("Forward")
	backward = Input.is_action_pressed("Backward")
	left = Input.is_action_pressed("Left")
	right = Input.is_action_pressed("Right")

func _process(delta: float) -> void:
	var temp: bool = true
	# general
	process_input()
	orientation(delta)
	# if key slightly pressed
	if !temp:
		# turning
		turn_animation(delta)
		var root_motion_pos = animationTree.get_root_motion_position()
		var root_motion_quat = animationTree.get_root_motion_rotation()
		var velocity = root_motion_quat * root_motion_pos / delta
		characterBody.set_velocity(velocity)
		characterBody.set_quaternion(characterBody.get_quaternion() * root_motion_quat)
		rotation_correction(delta)
	else:
		# moving
		movement_animation()
		var root_motion_pos = animationTree.get_root_motion_position()
		
		var char_orientation: Vector3 = characterBody.transform.basis.z
		var char_orientation_norm: Vector3 = char_orientation.normalized()
		var move_amount: float = root_motion_pos.length()
		var velocity = (char_orientation_norm * move_amount) / delta
		
		characterBody.set_velocity(velocity)
		if !dont_rotate_while_stopping:
			characterBody.transform.basis = Basis(characterBody.transform.basis.get_rotation_quaternion().slerp(desired_rotation, snappiness * delta))
		characterBody.move_and_slide()
	
	last_orientation = characterBody.transform.basis.z


func _on_animation_tree_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Run To Stop/run_to_stop":
		dont_rotate_while_stopping = false
	correct_rotation = true
	able_to_turn = true


func _on_animation_tree_animation_started(anim_name: StringName) -> void:
	if anim_name == "Idle/idle":
		return
	if anim_name == "Run To Stop/run_to_stop":
		dont_rotate_while_stopping = true
	correct_rotation = false
	able_to_turn = false
