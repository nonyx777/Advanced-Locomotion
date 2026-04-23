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
var desired_rotation1: Quaternion
var desired_rotation2: Quaternion
var direction_rotation: Quaternion
var tilt_rotation: Quaternion

# Animation Parameters
@export var animationTree: AnimationTree
var blend_position: float
var last_velocity: Vector3

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

func movementOrientation(delta: float) -> void:
	key_direction = nd.sum(nd.multiply(directions, inputs), 0).to_vector3().normalized()
	blend_position = velocity.length()
	if key_direction.length() < 0.1:
		force_vec *= 0.0
		return
	var camera_yaw: float = camera.transform.basis.get_euler().y
	target_angle = atan2(key_direction.x, -key_direction.z) + camera_yaw
	# Smoothly rotate to target rotation
	desired_rotation1 = Quaternion(Vector3.UP, target_angle)
	characterBody.transform.basis = Basis(characterBody.transform.basis.get_rotation_quaternion().slerp(desired_rotation1, snappiness * delta))
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
		var t = Quaternion.from_euler(Vector3(0.0, desired_rotation1.get_euler().y, 0.0))
		characterBody.transform.basis = Basis(characterBody.transform.basis.get_rotation_quaternion().slerp(t, snappiness * delta))
		return
	
	characterBody.transform.basis = characterBody.transform.basis.slerp(characterBody.transform.basis.rotated(rotation_axis.normalized(), deg_to_rad(10.0)), snappiness * delta)

func animation() -> void:
	animationTree.set("parameters/blend_position", blend_position)

func turn_animation() -> void:
	var forward: bool = Input.is_action_pressed("Forward")
	var backward: bool = Input.is_action_pressed("Backward")
	var left: bool = Input.is_action_pressed("Left")
	var right: bool = Input.is_action_pressed("Right")
	
	if !forward and !backward and !left and !right:
		return
	
	var angle: float = last_velocity.normalized().dot(force_vec.normalized())
	var rel_dir: float = force_vec[0] * last_velocity[2] - force_vec[2] * last_velocity[0]
	if angle <= -0.8:
		print("Turn 180")
	if angle <= 0.2 and angle >= -0.2:
		if rel_dir >= 0:
			print("Turn Left 90")
		elif rel_dir < 0:
			print("Turn Right 90")

func _ready() -> void:
	animationTree.active = true

func _process(delta: float) -> void:
	last_velocity = velocity
	process_input()
	movementOrientation(delta)
	movement(delta)
	#tilt(delta)
	animation()
	turn_animation()
	#characterBody.velocity = velocity
	#characterBody.move_and_slide()
