extends "player_remote.gd"

var connection
var world

func set_model_flags(p_flags):
	super.set_model_flags(p_flags)
	if model_status & PlayerFlags.OnFoot:
		world.set_input_mode(world.InputModes.PlayerMove)
	elif model_status & PlayerFlags.OnShip:
		world.set_input_mode(world.InputModes.ShipMove)

func move_remote(pos, dst):
	move_event(pos, dst)

func move_local(pos):
	printt("**** move local ", pos)
	navigationAgent.target_position = pos
	connection.player_move(pos)

func _ready():
	connection = get_node("/root/Connection")
