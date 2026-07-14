extends Node3D
class_name Character
@onready var characterBody: CharacterBody3D = $CharacterBody3D
@onready var camera: Camera3D = $"../Camera3D"

# Both inputs and directions in WASD order
var inputs: NDArray = nd.zeros([4, 1], nd.Int8)
var directions: NDArray = nd.array([[0, 0, 1], [-1, 0, 0], [0, 0, -1], [1, 0, 0]], nd.Int8)
var key_direction: Vector3

# Linear Movement
var velocity: Vector3
static var force_vec: Vector3
var snappiness: float = 5.0
var target_angle: float
var desired_rotation: Quaternion

# Turn correction
var turn_direction: Vector3
var delta_global: float
var correct_rotation: bool = false
var able_to_turn: bool = true
var dont_rotate_while_stopping: bool = false

# Animation Parameters
@export var animationTree: AnimationTree
var state_machine
static var last_orientation: Vector3

# keys
var forward: bool
var backward: bool
var left: bool
var right: bool
var any_key_pressed: bool
var forward_released: bool
var backward_released: bool
var left_released: bool
var right_released: bool
var any_key_released: bool

const TAP_THRESHOLD: float = 0.01
const PRESS_THRESHOLD: float = 0.1
var hold_time: float = 0.0
var should_turn: bool = false
var should_move: bool = false

var anim_exceptions = Array(["Run To Stop/run_to_stop", "Run Turn 180/run_turn_180", 
"Action Idle to Standing Idle/action_idle_to_standing_idle", "Left Turn 90/left_turn_90 2", 
"Right Turn 180/right_turn_180", "Right Turn 90/right_turn_90", "Idle/idle"])
const ACTION_STANDING_TO_IDLE_STANDING: String = "Action Idle to Standing Idle/action_idle_to_standing_idle"
const IDLE: String = "Idle/idle"

var skip_for_the_first_time: int = 1

var rotating_while_running: bool = false

func process_input() -> void:
	if forward:
		inputs.set(1, 0, 0)
	else:
		inputs.set(0, 0, 0)
	if left:
		inputs.set(1, 1, 0)
	else:
		inputs.set(0, 1, 0)
	if backward:
		inputs.set(1, 2, 0)
	else:
		inputs.set(0, 2, 0)
	if right:
		inputs.set(1, 3, 0)
	else:
		inputs.set(0, 3, 0)

func orientation() -> void:
	key_direction = nd.sum(nd.multiply(directions, inputs), 0).to_vector3().normalized()
	if key_direction.length() > 0.1:
		var camera_yaw: float = camera.transform.basis.get_euler().y
		target_angle = atan2(key_direction.x, -key_direction.z) + camera_yaw
		# Smoothly rotate to target rotation
		desired_rotation = Quaternion(Vector3.UP, target_angle)
		force_vec = Vector3(sin(target_angle), 0.0, cos(target_angle)).normalized()

func turn_animation() -> void:
	if !able_to_turn:
		return
		
	turn_direction = force_vec
	
	
	var angle: float = last_orientation.normalized().dot(turn_direction.normalized())
	var rel_dir: float = turn_direction[0] * last_orientation[2] - turn_direction[2] * last_orientation[0]
	if angle <= -0.8:
		animationTree.set("parameters/conditions/right_turn_180", true)
	if angle <= 0.4 and angle >= -0.4:
		if rel_dir >= 0:
			animationTree.set("parameters/conditions/left_turn_90", true)
		elif rel_dir < 0:
			animationTree.set("parameters/conditions/right_turn_90", true)

func movement_animation() -> void:
	if !any_key_pressed:
		animationTree.set("parameters/conditions/stop_run", true)
		return
	
	var angle: float = last_orientation.normalized().dot(force_vec.normalized())
	if angle <= -0.8:
		rotating_while_running = true
		animationTree.set("parameters/conditions/run_turn_180", true)
	else:
		animationTree.set("parameters/conditions/start_run", true)

func reset_turn_triggers():
	animationTree.set("parameters/conditions/left_turn_90", false)
	animationTree.set("parameters/conditions/right_turn_90", false)
	animationTree.set("parameters/conditions/right_turn_180", false)

func reset_move_triggers():
	animationTree.set("parameters/conditions/start_run", false)
	animationTree.set("parameters/conditions/stop_run", false)
	animationTree.set("parameters/conditions/run_turn_180", false)

func rotation_correction():
	if !correct_rotation:
		return
	
	var current_fwd: Vector3 = characterBody.transform.basis.z
	var current_rot: Vector2 = Vector2(current_fwd.x, current_fwd.z)
	var target_rot: Vector2 = Vector2(turn_direction.x, turn_direction.z)
		
	var current_angle: float = current_rot.angle()
	var desired_angle: float = target_rot.angle()
	
	var delta_angle: float = desired_angle - current_angle
	delta_angle = fmod(delta_angle + PI, 2.0 * PI) - PI
	
	var rot_quat: Quaternion = Quaternion(Vector3.UP, -delta_angle * 0.05)
	characterBody.set_quaternion(characterBody.get_quaternion() * rot_quat)
	if delta_angle <= 0.2 and delta_angle >= -0.2:
		should_turn = false

func manage_turn(delta: float) -> void:
	turn_animation()
	var root_motion_pos = animationTree.get_root_motion_position()
	var root_motion_quat = animationTree.get_root_motion_rotation()
	velocity = root_motion_quat * root_motion_pos / delta
	characterBody.set_velocity(velocity)
	characterBody.set_quaternion(characterBody.get_quaternion() * root_motion_quat)
	rotation_correction()

func movement_status() -> void:
	var not_pressing: bool = hold_time < PRESS_THRESHOLD
	var current_state = state_machine.get_current_node()
	var has_stopped_moving: bool = current_state == "Idle_idle" and not_pressing
	
	should_move = !has_stopped_moving
	# Shouldn't keep leaning when idle
	var decide_lean: int = int(has_stopped_moving)
	force_vec = last_orientation * decide_lean + force_vec * (1 - decide_lean)

func manage_movement(delta: float) -> void:
	movement_animation()
	
	# will remove this once I get start run turn 180 anim
	var not_pressing: bool = hold_time < PRESS_THRESHOLD
	var current_state = state_machine.get_current_node()
	var temp_condition: bool = current_state == "Idle_idle" and not_pressing
		
	var root_motion_pos = animationTree.get_root_motion_position()
	var root_motion_quat = animationTree.get_root_motion_rotation()
	
	var char_orientation: Vector3 = characterBody.transform.basis.z
	var char_orientation_norm: Vector3 = char_orientation.normalized()
	var move_amount: float = root_motion_pos.length()
	velocity = (char_orientation_norm * move_amount) / delta
	
	characterBody.set_velocity(velocity)
	
	if !temp_condition and !dont_rotate_while_stopping and !rotating_while_running:
		characterBody.transform.basis = Basis(
			characterBody.transform.basis
			.get_rotation_quaternion()
			.slerp(desired_rotation, snappiness * delta)
		)
	else:
		var quat: Quaternion = characterBody.get_quaternion() * root_motion_quat
		characterBody.set_quaternion(quat)
	characterBody.move_and_slide()
	
	movement_status()

func _ready() -> void: 
	animationTree.active = true
	state_machine = animationTree.get("parameters/playback")
	
	# To avoid leaning initially
	force_vec = characterBody.transform.basis.z

func _process(delta: float) -> void:
	reset_move_triggers()
	reset_turn_triggers()
	rotating_while_running = false
	
	forward = Input.is_action_pressed("Forward")
	backward = Input.is_action_pressed("Backward")
	left = Input.is_action_pressed("Left")
	right = Input.is_action_pressed("Right")
	any_key_pressed = forward or backward or left or right
	forward_released = Input.is_action_just_released("Forward")
	backward_released = Input.is_action_just_released("Backward")
	left_released = Input.is_action_just_released("Left")
	right_released = Input.is_action_just_released("Right")
	any_key_released = forward_released or backward_released or left_released or right_released
	
	if any_key_pressed:
		hold_time += delta
	# general
	process_input()
	orientation()
	# if key slightly pressed
	if any_key_released and !should_turn:
		if hold_time > TAP_THRESHOLD and hold_time <= PRESS_THRESHOLD and !should_move:
			should_turn = true
			print("Hold time: ", hold_time, "- Tap THRESHOLD: ", TAP_THRESHOLD)
		
		hold_time = 0.0
	elif any_key_pressed:
		if hold_time > PRESS_THRESHOLD and !should_turn:
			should_move = true
	
	
	if should_turn:
		manage_turn(delta)
	elif should_move:
		manage_movement(delta)
	
	last_orientation = characterBody.transform.basis.z


func _on_animation_tree_animation_finished(anim_name: StringName) -> void:
	if anim_name in anim_exceptions:
		dont_rotate_while_stopping = false
		
	correct_rotation = true
	able_to_turn = true


func _on_animation_tree_animation_started(anim_name: StringName) -> void:
	if skip_for_the_first_time == 1:
		skip_for_the_first_time = 0
		return
	
	if anim_name == IDLE:
		should_move = false
	
	if anim_name in anim_exceptions:
		dont_rotate_while_stopping = true
	correct_rotation = false
	able_to_turn = false
