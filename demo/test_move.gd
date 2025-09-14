extends Node3D

var connection

var players = {}
var ships = {}

var player_local
var ship_local

enum InputModes {
	PlayerMove,
	ShipSpawn,
	ShipMove,
	ShipLeave,
}

var input_mode

func player_updated(id, status):
	if !(id in players):
		new_player(id)
		
	players[id].model_status = status
	if id == connection.get_local_id():
		player_local.model_status = status

func new_player(id):
	if !(id in players):
		var node = preload("player_remote.tscn").instantiate()
		players[id] = node
	else:
		printt("new player already instanced? ", id)

	add_child(players[id])
	players[id].set_player_id(id)
	
	if player_local != null:
		return
	if id == connection.get_local_id():
		player_local = preload("player_local.tscn").instantiate()
		add_child(player_local)
		player_local.set_player_id(id)
		player_local.world = self
	
func player_movement(id, src, dst, p_recursive=false):
	
	if !(id in players):
		new_player(id)
		printt("player move not instanced?", id)
		if p_recursive:
			print("Recursive move attempted, aborting")
			return
		call_deferred("player_movement", id, src, dst, true)
		return

	players[id].move_event(src, dst)
	
	if id == connection.get_local_id():
		player_local.move_remote(src, dst)

func _input(event):
	if !event.is_action("move") || !event.is_pressed():
		return
	var camera = get_tree().get_nodes_in_group("Camera")[0]
	var mousePos = get_viewport().get_mouse_position()
	var rayLength = 100
	var from = camera.project_ray_origin(mousePos)
	var to = from + camera.project_ray_normal(mousePos) * rayLength
	var space = get_world_3d().direct_space_state
	var rayQuery = PhysicsRayQueryParameters3D.new()
	rayQuery.from = from
	rayQuery.to = to
	rayQuery.collide_with_areas = true
	var result = space.intersect_ray(rayQuery)
	if !("position" in result):
		return

	position_event(result.position)

func set_input_mode(p_mode):
	input_mode = p_mode

func position_event(pos):
	
	if input_mode == InputModes.PlayerMove:
		player_local.move_local(pos)
	elif input_mode == InputModes.ShipMove:
		pass
	elif input_mode == InputModes.ShipSpawn:
		pass
	elif input_mode == InputModes.ShipLeave:
		pass
	
func respawn():
	connection.player_move(Vector3())

func _ready():
	get_node("UI/respawn").connect("pressed", self.respawn)
	connection = get_node("/root/Connection")
	connection.world = self
	player_local
