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

var _debug_system_user: User

var WORLD_CONTRACT = "0x072593bd6b7770a56ff9b9ec7747755f0c681a7f7dc09133c518b7150efe5949"
var ACTIONS_CONTRACT = "0x044341cf0e678b7a53ecba53c4da9ef594108d58ce74193ea78da58e1c5b93bf"
var SLOT_CHAIN_ID = "WP_UTP_DOJO2"
var LOCAL_CHAIN_ID = "KATANA"

@export var debug_use_account = false
var account_addr = "0x13d9ee239f33fea4f8785b9e3870ade909e20a9599ae7cd62c1c292b73af1b7"
var private_key = "0x1c9053c053edf324aec366a34c6901b1095b07af69495bffec7d7fe21effb1b"
var rpc
var torii_rpc

var queue

var players = {}

@export var query:DojoQuery
@export var entity_sub:EntitySubscription
@export var message_sub:MessageSubscription

@onready var client: ToriiClient = $ToriiClient
@onready var controller_account: ControllerAccount = $ControllerAccount
@onready var account : Account = $Account

var world

func _settings_path():
	var user = _debug_system_user.get_user_id()
	if !user:
		return "dojo/config"

	var path = "dojo.%s/config" % user
	
	return path


func _ready() -> void:
	_debug_system_user = User.new()
	_debug_system_user.initialize()
	printt("local user is ", _debug_system_user.get_user_id())
	var dojo = DojoC.new()
	rpc = ProjectSettings.get_setting(_settings_path() + "/katana_url")
	torii_rpc = ProjectSettings.get_setting(_settings_path() + "/torii_url")
	WORLD_CONTRACT = ProjectSettings.get_setting(_settings_path() + "/world_address")
	ACTIONS_CONTRACT = ProjectSettings.get_setting(_settings_path() + "/contract_address")
	account_addr = ProjectSettings.get_setting(_settings_path() + "/account/address")
	private_key = ProjectSettings.get_setting(_settings_path() + "/account/private_key")
	
	printt("******** fp default is ", ProjectSettings.get_setting(_settings_path() + "fixed_point/default"))
	
	OS.set_environment("RUST_BACKTRACE", "full")
	OS.set_environment("RUST_LOG", "debug")
	client.world_address = WORLD_CONTRACT
	client.torii_url = torii_rpc
	controller_account.policies.contract = ACTIONS_CONTRACT
	
	queue = DispatchQueue.new()
	queue.create_serial()

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
	
	if success:
		push_warning(controller_account.chain_id)
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
	world.call_deferred("player_movement", id, pos, dst)
	pass

func _update_player_model(data):
	var id = data.id
	var status = data.status_flags
	world.call_deferred("player_updated", id, status)

func _update_ship_model(data):
	var owner = data.owner
	var status = data.status_flags
	world.call_deferred("ship_updated", owner, status)

func _update_collectable_area(data):
	
	pass

func _update_inventory(data):
	var user = data.player_id
	var item = data.item_type
	var count = data.count
	world.update_inventory(user, item, count)
	pass

func _update_ship_position_model(data):
	var id = data.owner
	var pos = Vector3(data.pos.x.to_float(), data.pos.y.to_float(), data.pos.z.to_float())
	var dst = Vector3(data.dest.x.to_float(), data.dest.y.to_float(), data.dest.z.to_float())
	world.call_deferred("ship_movement", id, pos, dst)

func _update_entity(data):
	for model in data.models:
		if "utp_dojo-Player" in model:
			_update_player_model(model["utp_dojo-Player"])
		elif "utp_dojo-PlayerPosition" in model:
			_update_position_model(model["utp_dojo-PlayerPosition"])
		elif "utp_dojo-Spaceship" in model:
			_update_ship_model(model["utp_dojo-Spaceship"])
		elif "utp_dojo-ShipPosition" in model:
			_update_ship_position_model(model["utp_dojo-ShipPosition"])
		elif "utp-dojo-CollectableTracker" in model:
			_update_collectable_area(model["utp-dojo-CollectableTracker"])
		elif "utp_dojo-InventoryItem" in model:
			_update_inventory(model["utp_dojo-InventoryItem"])

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
	
func execute(method, params):
	queue.dispatch(self._execute.bind(method, params))

func _execute(method, params):
	if account.is_account_valid():
		account.execute_raw(ACTIONS_CONTRACT, method, params)
	else:
		if !status["controller"]:
			push_error("not connected")
			return

		controller_account.execute_from_outside(ACTIONS_CONTRACT, method, params)
	

func _on_account_transaction_executed(success_message: Dictionary) -> void:
	print(success_message)


func _on_account_transaction_failed(error_message: Dictionary) -> void:
	push_error(error_message)
