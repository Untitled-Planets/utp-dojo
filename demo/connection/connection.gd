class_name DojoConnection
extends Node

signal connected
signal status_updated

var status = {
	"client": false,
	"controller": false,
	"provider": false,
	"entities": false,
	"events": false,
}

<<<<<<< HEAD
const WORLD_CONTRACT = "0x0277d2b8cdb36c6c8cabbf54b63a3fd8424e307f1c2e89849492bf1219cfc7ff"
#const ACTIONS_CONTRACT = "0x059a285e7f9c13705810433617c0ba1f1d5d1a3bce54afbd20f470d2e7f4e7be"
const ACTIONS_CONTRACT = "0x0402b2c97cf0bd5b2fa1733504e039d550e7fd2f43e0329fe22f0eabd99121d5"
=======
const WORLD_CONTRACT = "0x072593bd6b7770a56ff9b9ec7747755f0c681a7f7dc09133c518b7150efe5949"
const ACTIONS_CONTRACT = "0x053ab4ff46807efb3d39ed243c8a098adbcaacfbb8d8dd43e0bbe10e6748dc58"
>>>>>>> e3537f9dba4db69172bacd52d855a24fef64c13b

@export var debug_use_account = false
var account_addr = "0x13d9ee239f33fea4f8785b9e3870ade909e20a9599ae7cd62c1c292b73af1b7"
var private_key = "0x1c9053c053edf324aec366a34c6901b1095b07af69495bffec7d7fe21effb1b"
var rpc

var players = {}

@export var query:DojoQuery
@export var entity_sub:EntitySubscription
@export var message_sub:MessageSubscription

@onready var client: ToriiClient = $ToriiClient
@onready var controller_account: ControllerAccount = $ControllerAccount
@onready var account : Account = $Account

var world

func _ready() -> void:
<<<<<<< HEAD
	var dojoc = DojoC.new()
	rpc = ProjectSettings.get_setting("dojo/config/katana/rpc_url")
	OS.set_environment("RUST_BACKTRACE", "full")
	OS.set_environment("RUST_LOG", "debug")
=======
	var dojo = DojoC.new()
	rpc = ProjectSettings.get_setting("dojo/config/katana/rpc_url")
	OS.set_environment("RUST_BACKTRACE", "full")
	OS.set_environment("RUST_LOG", "debug")
	client.world_address = WORLD_CONTRACT
	controller_account.policies.contract = ACTIONS_CONTRACT
>>>>>>> e3537f9dba4db69172bacd52d855a24fef64c13b

func _set_status(name, val):
	status[name] = val
	status_updated.emit()

func get_status(name):
	if name in status:
		return status[name]
	return false

func _torii_logger(_msg:String):
	prints("[TORII LOGGER]", _msg)

func connect_client() -> void:
	client.create_client()

func connect_controller() -> void:
	if debug_use_account:
		account.create(rpc, account_addr, private_key)
		account.set_block_id()
		_on_controller_account_controller_connected(true)
		#_set_status("controller", true)
	else:
		controller_account.setup()

func _on_torii_client_client_connected(success: bool) -> void:
	_set_status("client", success)
	client.set_logger_callback(_torii_logger)
	if success:
		connect_controller()

func _on_torii_client_client_disconnected() -> void:
	_set_status("client", false)

func _on_controller_account_controller_connected(success: bool) -> void:
	_set_status("controller", success)
<<<<<<< HEAD
	if success:
=======
	
	if success:
		push_warning(controller_account.chain_id)
>>>>>>> e3537f9dba4db69172bacd52d855a24fef64c13b
		connected.emit()
		_get_entities()
		print("connected!")
		create_subscriptions(_on_events,_on_entities)

func _get_entities():
	var data = client.get_entities(DojoQuery.new())
	printt("Entities:", data)
	for e in data:
		_update_entity(e)

func get_local_id():
	if debug_use_account:
		if !account.is_account_valid():
			return null
		return account.get_address()
	else:
		if !status["controller"]:
			return null
			
		return controller_account.get_address()

func _on_events(args:Dictionary) -> void:
	printt("*** got event", args)

func _on_entities(args:Dictionary) -> void:
	printt("*** got entities", args)
	_update_entity(args)

func _update_position_model(data):
	var id = data.player
	var pos = Vector3(data.pos.x.to_float(), data.pos.y.to_float(), data.pos.z.to_float())
	var dst = Vector3(data.dest.x.to_float(), data.dest.y.to_float(), data.dest.z.to_float())
	printt("updating model movement to dest ", data.dest.x.get_class(), data.dest.x.to_string(), data.dest.y.to_string(), data.dest.z.to_string())
	world.player_movement(id, pos, dst)
	pass

func _update_player_model(data):
	var id = data.id
	var status = data.status_flags
	world.player_updated(id, status)

func _update_entity(data):
	for model in data.models:
		if "utp_dojo-Player" in model:
			_update_player_model(model["utp_dojo-Player"])
		elif "utp_dojo-PlayerPosition" in model:
			_update_position_model(model["utp_dojo-PlayerPosition"])

func _on_controller_account_controller_disconnected() -> void:
	_set_status("controller", false)

func _on_controller_account_provider_status_updated(success: bool) -> void:
	_set_status("provider", success)

func _on_torii_client_subscription_created(subscription_name: String) -> void:
	if subscription_name == "entity_state_update":
		_set_status("entities", true)
	if subscription_name == "event_message_update":
		_set_status("events", true)

func create_subscriptions(events:Callable,entities:Callable) -> void:
	print("creating entity sub")
	client.on_entity_state_update(entities, entity_sub)
	print("creating event sub")
	client.on_event_message_update(events, message_sub)
	

func player_move(pos):

	var params = [pos.x, pos.y, pos.z]
	#var params = [pos.x, pos.y, pos.z]

	if account.is_account_valid():
		account.execute_raw(ACTIONS_CONTRACT, "player_move", params)
	else:
		if !status["controller"]:
<<<<<<< HEAD
			printt("not connected")
			return

		controller_account.execute_from_outside(ACTIONS_CONTRACT, "player_move", params)
=======
			push_error("not connected")
			return

		controller_account.execute_from_outside(ACTIONS_CONTRACT, "player_move", params)


func _on_account_transaction_executed(success_message: Dictionary) -> void:
	print(success_message)


func _on_account_transaction_failed(error_message: Dictionary) -> void:
	push_error(error_message)
>>>>>>> e3537f9dba4db69172bacd52d855a24fef64c13b
