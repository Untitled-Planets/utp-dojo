extends CanvasLayer

var connection
var button
var animation

func connect_pressed():
	connection.connect_client()

func status_updated():
	if connection.get_status("controller"):
		button.hide()
	else:
		button.show()
		if connection.session_state == connection.SessionState.LOGIN:
			animation.play("login")
		else:
			animation.play("login_completed")

func _ready():
	connection = get_node("/root/Connection")
	connection.status_updated.connect(self.status_updated)

	animation = get_node("animation")
	
	button = get_node("PanelStatus/HBoxContainer/Button")
	button.pressed.connect(self.connect_pressed)
