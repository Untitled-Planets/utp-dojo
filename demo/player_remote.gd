extends CharacterBody3D

@onready var navigationAgent : NavigationAgent3D = $NavigationAgent3D
var Speed = 5

var player_id = ""
var model_status = 0 : set = set_model_flags

enum PlayerFlags {
	OnFoot = 1,
	OnShip = 2,
}

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if(navigationAgent.is_navigation_finished()):
		return
	
	moveToPoint(delta, Speed)
	pass

func set_model_flags(p_flags):
	model_status = p_flags
	if model_status & PlayerFlags.OnFoot:
		show()
	elif model_status & PlayerFlags.OnShip:
		hide()


func moveToPoint(delta, speed):
	var targetPos = navigationAgent.get_next_path_position()
	var direction = global_position.direction_to(targetPos)
	faceDirection(targetPos)
	velocity = direction * speed
	move_and_slide()

func faceDirection(direction):
	look_at(Vector3(direction.x, global_position.y, direction.z), Vector3.UP)

func set_player_id(p_id):
	player_id = p_id
	get_node("id_label").set_text(p_id)

func move_event(src, dst):
	printt("move event ", src, dst)
	if !navigationAgent:
		get_node("NavigationAgent3D").set_deferred("target_position", dst)
		return

	navigationAgent.target_position = dst

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.
