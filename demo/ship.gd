extends Node3D

var ship_owner

var model_status = 0: set = set_model_flags

var move_dest = null
var move_dir = Vector3()
var speed = 1

enum ShipFlags {
	Spawned = 1,
	Landed = 2,
	Occupied = 4,
}

func setup(p_owner):
	ship_owner = p_owner

func set_model_flags(p_flags):
	set_spawned(p_flags & ShipFlags.Spawned)
	set_occupied(p_flags & ShipFlags.Occupied)
	model_status = p_flags

func set_occupied(p_occ):
	pass

func set_spawned(p_spawned):
	if p_spawned:
		show()
	else:
		hide()

func move_to(p_dst):
	move_dest = p_dst

	if p_dst == null:
		set_process(false)
	else:
		move_dir = (p_dst - global_position).normalized()
		set_process(true)

func _process(delta):
	if move_dest == null:
		return
		
	var to_move = delta * speed
	var dist = move_dest.distance_to(global_position)
	
	if to_move > dist:
		global_position = move_dest
		move_to(null)
		return

	var pos = global_position + move_dir * to_move
	global_position = pos

func _ready():
	pass
