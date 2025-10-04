extends Node3D

var world
var type
var index
var area
var epoc


func set_item_info(p_world, p_index, p_type, p_area, p_epoc):
	world = p_world
	type = p_type
	index = p_index
	area = p_area
	epoc = p_epoc
	

func item_area_updated(p_area, p_type, p_bitfield, p_epoc):
	if p_area != area || p_type != type:
		return
	if p_epoc != epoc:
		expired()

	if world._has_bit(p_bitfield, index):
		collected()

func expired():
	queue_free()

func collected():
	queue_free()

func _clicked(camera, event, pos, normal, shape):
	if event.is_pressed() && event.is_action("select"):
		world.item_clicked(self)


func _ready():
	get_node("area").connect("input_event", self._clicked)
