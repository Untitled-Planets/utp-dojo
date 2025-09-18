extends "ship.gd"

var connection
var world

func area_clicked(camera, event, pos, normal, shape):
	if event.is_pressed() && event.is_action("select"):
		world.ship_clicked(self)

func set_occupied(p_occ):
	if p_occ:
		world.set_input_mode(world.InputModes.ShipMove)
	else:
		world.set_input_mode(world.InputModes.PlayerMove)

func move_remote(pos, dst):
	move_event(pos, dst)

func move_local(pos):
	move_to(pos)
	connection.ship_move(pos, false)

func _ready():
	connection = get_node("/root/Connection")
	get_node("area").connect("input_event", self.area_clicked)
