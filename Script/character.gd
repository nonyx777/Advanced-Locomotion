extends Node3D
@onready var characterBody: CharacterBody3D = $CharacterBody3D

# TODO:
	# Move
	# Rotate towards the direction of movement
	# Tilt While Moving

# IDEA:
	# Inputs are floating point numbers ranging from 0 to 1
	# Force is applied naturally by just multiplying the force scalar by a matrix


# Both inputs and directions in WASD order
var inputs: NDArray = nd.zeros([4, 1])
var directions: NDArray = nd.array([[0, 0, 1], [-1, 0, 0], [0, 0, -1], [1, 0, 0]], nd.Float32)

# Linear Movement
@export var force: float = 500.0
var acceleration: NDArray = nd.zeros(3, nd.Float32)
var velocity: NDArray = nd.zeros(3, nd.Float32)


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

func process_movement(delta: float) -> void:
	acceleration.assign_multiply(acceleration, 0.0)
	acceleration = nd.multiply(nd.sum(nd.multiply(directions, nd.multiply(inputs, force)), 0), delta)
	velocity.assign_add(velocity, nd.multiply(acceleration, delta))
	velocity.assign_multiply(velocity, 0.95)
	

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	process_input()
	process_movement(delta)
	characterBody.velocity = velocity.to_vector3()
	characterBody.move_and_slide()
