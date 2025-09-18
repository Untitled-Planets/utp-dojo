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

const ship_board_distance = 5

func player_updated(id, status):
	if !(id in players):
		new_player(id)
		
	players[id].model_status = status
	if id == connection.get_local_id():
		player_local.model_status = status

func ship_updated(p_owner, status):
	if !(p_owner in ships):
		new_ship(p_owner)
	ships[p_owner].model_status = status
	if p_owner == connection.get_local_id():
		ship_local.model_status = status

func new_ship(p_owner):
	if !(p_owner in ships):
		var node = preload("ship.tscn").instantiate()
		ships[p_owner] = node
	else:
		printt("new ship already instanced?", p_owner)
		
	add_child(ships[p_owner])
	ships[p_owner].setup(p_owner)
	
	if ship_local != null:
		return
		
	if p_owner == connection.get_local_id():
		ship_local = preload("ship_local.tscn").instantiate()
		add_child(ship_local)
		ship_local.setup(p_owner)
		ship_local.world = self

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

func ship_movement(id, pos, dst, p_recursive=false):
	if !(id in ships):
		new_ship(id)
		if p_recursive:
			print("Recursive ship move attempted, aborting")
			return
		call_deferred("ship_movement", id, pos, dst, true)
		return

	ships[id].move_event(pos, dst)
	if id == connection.get_local_id():
		ship_local.move_remote(pos, dst)

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

	position_event(to_local(result.position))

func set_input_mode(p_mode):
	input_mode = p_mode

func ship_request_spawn(pos):
	var dist = player_local.position.distance_to(pos)
	printt("************** player pos ", player_local.position)
	printt("request spawn with distance", dist, dist * dist)
	connection.execute("ship_spawn", [pos])
	set_input_mode(InputModes.PlayerMove)
	pass

func ship_request_leave(pos):
	connection.execute("ship_unboard", [pos])
	set_input_mode(InputModes.ShipMove)
	pass

func ship_request_board(pos):
	connection.execute("ship_board", [])
	set_input_mode(InputModes.PlayerMove)
	pass

func ship_clicked(ship):
	if player_local.position.distance_to(ship.position) > ship_board_distance:
		position_event(ship.position)
	if input_mode == InputModes.PlayerMove:
		ship_request_board(ship.position)
	else:
		position_event(ship.position)

func position_event(pos):
	
	if input_mode == InputModes.PlayerMove:
		player_local.move_local(pos)
	elif input_mode == InputModes.ShipMove:
		ship_local.move_local(pos)
	elif input_mode == InputModes.ShipSpawn:
		ship_request_spawn(pos)
	elif input_mode == InputModes.ShipLeave:
		ship_request_leave(pos)

func ship_spawn_pressed():
	set_input_mode(InputModes.ShipSpawn)
	
func ship_despawn_pressed():
	connection.execute("ship_despawn", [])
	
func ship_leave_pressed():
	set_input_mode(InputModes.ShipLeave)
	
func respawn():
	connection.player_move(Vector3())

func item_pick_up_pressed():
	connection.execute("item_collect", [1, 1])

func _ready():
	get_node("UI/respawn").connect("pressed", self.respawn)
	get_node("UI/ship_spawn").connect("pressed", self.ship_spawn_pressed)
	get_node("UI/ship_despawn").connect("pressed", self.ship_despawn_pressed)
	get_node("UI/ship_leave").connect("pressed", self.ship_leave_pressed)
	get_node("UI/item_pickup").connect("pressed", self.item_pick_up_pressed)
	connection = get_node("/root/Connection")
	connection.world = self
	player_local
