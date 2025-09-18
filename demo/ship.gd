extends Node3D

var ship_owner

var model_status = 0: set = set_model_flags

var move_dest = null
var move_dir = Vector3()
var speed = 100
var cur_speed

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

func move_to(p_dst, p_speed = null):
	move_dest = p_dst
	cur_speed = p_speed
	if p_speed == null:
		cur_speed = speed
		
	if p_dst == null:
		set_process(false)
	else:
		look_at(p_dst)
		move_dir = (p_dst - position).normalized()
		set_process(true)

func move_event(src, dst):
	printt("ship move event ", src, dst)
	var dist = src.distance_to(dst)
	if dist == 0:
		position = dst
		return

	var time = dist / speed
	var local_dist = position.distance_to(dst)
	var local_speed = local_dist / time
	move_to(dst, local_speed)

func _process(delta):
	if move_dest == null:
		return
		
	var to_move = delta * cur_speed
	var dist = move_dest.distance_to(position)
	
	if to_move > dist:
		position = move_dest
		move_to(null)
		return

	var pos = position + move_dir * to_move
	position = pos

func _ready():
	pass
