extends Node3D

var connection

var players = {}
var ships = {}
var item_areas = {}

var player_local
var ship_local
var inventory = {}

enum InputModes {
	PlayerMove,
	ShipSpawn,
	ShipMove,
	ShipLeave,
}

var input_mode

const ship_board_distance = 5
const item_pickup_distance = 5

const area_size = 32

func update_inventory(user, type, count):
	
	if user == null || type == null:
		return
	
	if !(user in inventory):
		inventory[user] = {}
	if !(type in inventory[user]):
		inventory[user][type] = {}
	inventory[user][type] = count

	var lid = connection.get_local_id()
	if !lid || !(lid in inventory):
		return
		
	var text = ""
	for item_type in inventory[lid]:
		text += "Item %s: %s\n" % [item_type, inventory[lid][item_type]]

	get_node("UI/inventory").text = text

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
		spawn_items()
	
func player_movement(id, src, dst, p_recursive=false):
	
	if !(id in players):
		new_player(id)
		player_updated(id, preload("player_remote.gd").PlayerFlags.OnFoot)
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
	if input_mode == InputModes.PlayerMove:
		if player_local.position.distance_to(ship.position) > ship_board_distance:
			position_event(ship.global_position)
		else:
			ship_request_board(ship.global_position)
	else:
		position_event(ship.global_position)

func item_clicked(item):
	if input_mode == InputModes.PlayerMove:
		if player_local.global_position.distance_to(item.global_position) > item_pickup_distance:
			position_event(item.global_position)
		else:
			item_pickup(item)
	else:
		position_event(item.global_position)

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
	connection.execute("player_move", [Vector3()])

func item_pickup(item):
	connection.execute("item_collect", [item.type, item.index])

func _item_area(pos) -> int:
	var area_x := int(pos.x / area_size)
	if pos.x < 0:
		area_x += 0xffffffff;

	var area_y := int(pos.y / area_size)
	if pos.y < 0:
		area_y += 0xffffffff;
	
	var area_z := int(pos.z / area_size)
	if pos.z < 0:
		area_z += 0xffffffff;
		
	return (area_x % 1024) * 1024 * 1024 + (area_y % 1024) * 1024 + (area_z % 1024)

func _item_area_pos(pos):

	pass


func _has_bit(field, index:int):
	
	if typeof(field) == TYPE_INT:
		return field & (1<<index)
		
	var bytes = field.to_bytes()
	var byte_i = int(index / 8)
	var bit_i = int(index % 8)
	
	return bytes[byte_i] & (1<<bit_i)

func spawn_items():
	var seed = PackedByteArray()
	seed.resize(32)
	seed.fill(0)
	var item_parent = get_node("items")

	var area = _item_area(player_local.global_position)
	
	var area_pos = Vector3i(player_local.global_position / area_size) * area_size
	var pos_dir = Vector3(1, 1, 1)
	if player_local.global_position.x < 0:
		pos_dir.x = -1
	if player_local.global_position.y < 0:
		pos_dir.y = -1
	if player_local.global_position.z < 0:
		pos_dir.z = -1

	var type = 0
	var items = area_get_item_list(seed, area, 0, type)

	var collected = 0
	var key = [area, type]
	if key in item_areas:
		collected = item_areas[key].bitfield
		if "nodes" in item_areas[key]:
			for node in item_areas[key].nodes:
				node.queue_free()
			item_areas[key].nodes = []
		if !"nodes" in item_areas[key]:
			item_areas[key].nodes = []
	else:
		item_areas[key] = { bitfield = 0, nodes = [] }
	
	var count = 0
	for it in items:
		if _has_bit(collected, count):
			count += 1
			continue
		printt("spawn itema at", count, it)
		var res = preload("item.tscn")
		var node = res.instantiate()
		item_parent.add_child(node)
		
		node.global_position = Vector3(area_pos) + it * pos_dir
		node.set_item_info(self, count, 0, 0, 0)
		node.add_to_group("items")
		count += 1
		
		item_areas[key].nodes.push_back(node)



func area_get_item_list(p_planet_seed, p_area, p_epoc, p_type):

	printt("items for area ", p_area, p_type)

	var buffer = StreamPeerBuffer.new()
	buffer.put_data(p_planet_seed)
	buffer.put_32(p_epoc)
	buffer.put_32(p_area)
	buffer.put_16(p_type)

	printt("buffer before hash", buffer.data_array)
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	# Open the file to hash.
	ctx.update(buffer.data_array)
	# Get the computed hash.
	var res = ctx.finish()
	res.reverse()
	var b32hash = res.to_int32_array()
	b32hash.reverse()

	var debug_arr = []
	for n in b32hash:
		debug_arr.push_back(n & 0xFFFFFFFF)
	printt("hash is ", debug_arr)

	var spawn = (b32hash[7] & 0xffffffff) % 128
	printt("max spawn ", spawn)
	
	var array_base = buffer.data_array.duplicate()

	var ret = []
	
	for i in range(spawn):
		
		buffer.data_array = array_base.duplicate()
		buffer.seek(buffer.data_array.size())
		buffer.put_8(i)

		ctx.start(HashingContext.HASH_SHA256)
		#printt("buffer before hash", buffer.data_array)
		ctx.update(buffer.data_array)
		var hash = ctx.finish()

		hash.reverse()
		var hash_32 = hash.to_int32_array()
		hash_32.reverse()
		#printt("hash for item ", i, hash_32)
		var x32 = hash_32[0] & 0xFFFFFFFF
		var y32 = hash_32[1] & 0xFFFFFFFF
		var z32 = hash_32[2] & 0xFFFFFFFF
		
		const v32_max = 0xffffffff
		var pos = (Vector3(x32, y32, z32) / v32_max) * 32

		ret.push_back(pos)
	
	return ret

func item_update_area(area, type, bitfield, epoc):

	var key = [area, type]
	if !(key in item_areas):
		item_areas[key] = { }
	item_areas[key].bitfield = bitfield
	item_areas[key].epoc = epoc
	get_tree().call_group("items", "item_area_updated", area, type, bitfield, epoc)

func _ready():
	get_node("UI/respawn").connect("pressed", self.respawn)
	get_node("UI/ship_spawn").connect("pressed", self.ship_spawn_pressed)
	get_node("UI/ship_despawn").connect("pressed", self.ship_despawn_pressed)
	get_node("UI/ship_leave").connect("pressed", self.ship_leave_pressed)
	get_node("UI/spawn_items").connect("pressed", self.spawn_items)

	connection = get_node("/root/Connection")
	connection.world = self
	player_local
