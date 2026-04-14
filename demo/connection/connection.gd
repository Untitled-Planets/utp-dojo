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

var SLOT_CHAIN_ID = "WP_UTP_DOJO"
var LOCAL_CHAIN_ID = "KATANA"

@export var debug_use_account = false
var account_addr = "0x13d9ee239f33fea4f8785b9e3870ade909e20a9599ae7cd62c1c292b73af1b7"
var private_key = "0x1c9053c053edf324aec366a34c6901b1095b07af69495bffec7d7fe21effb1b"
var rpc_url
var torii_rpc

var queue

var session_info := {}

var players = {}

enum SessionState {
	NONE,
	LOGIN, # this is while the user is in the browser logging in
	COMPLETED,
	ERROR
}
var session_state : SessionState = SessionState.NONE
@onready var session_timer: Timer = $session_timer
var session_priv_key
var session_retry_count = 0


@onready var torii_client: ToriiClient = $ToriiClient
@onready var controller_account: DojoSessionAccount = $ControllerAccount
#@onready var account : Account = $Account

var Policies := preload("policies.gd")

var world : World
var policies

func _settings_path():
	var user = _debug_system_user.get_user_id()
	if !user:
		return "dojo/config"

	var path = "dojo.%s/config" % user
	
	return path


func _ready() -> void:
	_debug_system_user = User.new()
	if !OS.has_feature("standalone"): # OS.is_debug_build():
		_debug_system_user.initialize()
	printt("local user is ", _debug_system_user.get_user_id())
	rpc_url = ProjectSettings.get_setting(_settings_path() + "/katana_url")
	torii_rpc = ProjectSettings.get_setting(_settings_path() + "/torii_url")

	account_addr = ProjectSettings.get_setting(_settings_path() + "/account/address")
	private_key = ProjectSettings.get_setting(_settings_path() + "/account/private_key")
	
	OS.set_environment("RUST_BACKTRACE", "full")
	OS.set_environment("RUST_LOG", "debug")

	session_timer.timeout.connect(self.check_session)

	#torii_client.connected.connect(_on_torii_client_client_connected)

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
	var _client_connected = torii_client.connect(torii_rpc)
	_on_torii_client_client_connected(_client_connected)

func connect_controller() -> void:
	session_login_start()

func _get_priv_key():
	return ControllerHelper.generate_private_key()

func get_session_url() -> String:
	session_priv_key = _get_priv_key()
		
	var base_url = "https://x.cartridge.gg/session"
	var public_key = ControllerHelper.get_public_key(session_priv_key)
	var redirect_uri = "about:blank"
	var redirect_query_name = "startapp"
	
	var session_url = controller_account.generate_session_request_url(
		base_url, 
		public_key, 
		rpc_url, 
		Policies.policies_url, 
#		redirect_uri, # Optional
#		redirect_query_name # Optional
		)
		
	return session_url


func session_login_start():
	var session_url: String = get_session_url()
	OS.shell_open(session_url)
	session_timer.start()
	session_retry_count = 0
	queue.dispatch(self._session_wait_thread)

func _session_wait_thread():
	session_state = SessionState.LOGIN
	status_updated.emit.call_deferred()
	controller_account.create_from_subscribe(session_priv_key, rpc_url, Policies.policies, "https://api.cartridge.gg")
	if controller_account.is_valid():
		session_state = SessionState.COMPLETED
		status_updated.emit.call_deferred()
	else:
		session_state = SessionState.ERROR
		status_updated.emit.call_deferred()

func check_session():
	session_retry_count += 1
	if session_state == SessionState.LOGIN:
		return
	elif session_state == SessionState.COMPLETED:
		session_timer.stop()
		session_info = controller_account.get_info()
		_on_controller_account_controller_connected(true)
		printt("session account info", controller_account.get_info())
	elif session_state == SessionState.ERROR:
		session_timer.stop()

func _on_torii_client_client_connected(success: bool) -> void:
	printt("torii client connected")
	_set_status("client", success)
#	torii_client.set_logger_callback(_torii_logger)
	if success:
		connect_controller()

func _on_torii_client_client_disconnected() -> void:
	_set_status("client", false)

func _on_controller_account_controller_connected(success: bool) -> void:
	_set_status("controller", success)
	
	if success:
		#push_warning(controller_account.chain_id)
		connected.emit()
		_get_entities()
		print("connected!")
		create_subscriptions(_on_events,_on_entities)

func _get_local_player_entity():

	var query : DojoQuery = DojoQuery.new()
	var clause = MemberClause.new()
#	
	clause.member("id")
	clause.op(MemberClause.ComparisonOperator.Eq)
	var _addr = get_local_id()
	clause.hex(_addr, MemberClause.PrimitiveTag.ContractAddress)
#	clause.int(2)
	clause.model("utp_dojo-Player")
	query.with_clause(clause)
	query.models(["utp_dojo-Player", "utp_dojo-PlayerPosition", "utp_dojo-Spaceship", "utp_dojo-ShipPosition"])
	var data:Dictionary
	data = torii_client.entities(query)

	if data.items.size() > 0:
		printt("********* local entities ", data)
		_update_entity(data.items[0])
		return

	execute("_debug_player_spawn", [0, 0, 0, 0])

func _get_entities():
	_get_local_player_entity()
	var data = torii_client.entities(DojoQuery.new())
	printt("Entities:", data)
	for e in data.items:
		_update_entity(e)

func get_local_id():
	if !status["controller"]:
		return null

	var id = controller_account.get_address()
	if id.length() < 67:
		id = id.replace("0x","0x0")
	return id

	#return session_info["address"]

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

func _update_ship_model(data):
	var owner = data.owner
	var status = data.status_flags
	world.ship_updated(owner, status)

func _update_collectable_area(data):
	
	var area = data.area # this has to match the area_hash stored in world
	var type = data.collectable_type
	var bitfield = data.bitfield
	var epoc = data.epoc
	world.item_update_area(area, type, bitfield, epoc)

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
	for mkey in data.models:
		printt("got event ", mkey, data.models[mkey])
		var model = data.models[mkey]
		if mkey == "utp_dojo-Player":
			_update_player_model(model)
		elif mkey == "utp_dojo-PlayerPosition":
			_update_position_model(model)
		elif mkey == "utp_dojo-Spaceship":
			_update_ship_model(model)
		elif mkey == "utp_dojo-ShipPosition":
			_update_ship_position_model(model)
		elif mkey == "utp_dojo-CollectableTracker":
			_update_collectable_area(model)
		elif mkey == "utp_dojo-InventoryItem":
			_update_inventory(model)

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
	var entity_sub = DojoCallback.new()
	entity_sub.on_update = entities
	torii_client.subscribe_entity_updates(DojoClause.new(), [Policies.WORLD_CONTRACT], entity_sub)
	
	var message_sub = DojoCallback.new()
	message_sub.on_update = events
	torii_client.subscribe_transaction_updates({}, message_sub)
	
func execute(method, params):
	queue.dispatch(self._execute.bind(method, params))

func _execute(method, params):
	if controller_account.is_valid():
		printt("execute ", Policies.ACTIONS_CONTRACT, method, params)
		var thx = controller_account.execute([{"contract_address": Policies.ACTIONS_CONTRACT, "entrypoint": method, "calldata": [params]}])
		if not thx.begins_with("0x"):
			push_error("Failed %s with params %s" % [method, params])
			print_stack()
	else:
		push_error("Invalid session, ignoring execute %s" % method)


func _on_account_transaction_executed(success_message: Dictionary) -> void:
	print(success_message)


func _on_account_transaction_failed(error_message: Dictionary) -> void:
	push_error(error_message)
