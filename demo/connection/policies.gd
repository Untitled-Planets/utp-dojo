const WORLD_CONTRACT = "0x072593bd6b7770a56ff9b9ec7747755f0c681a7f7dc09133c518b7150efe5949"
const ACTIONS_CONTRACT = "0x047a59e5f0a1bc25baa96868eb69e73c23f630e3ced5759636e69ef312b7b176"

const policies = {
	"max_fee": "0x100000",
	"policies": [{
		"contract_address": ACTIONS_CONTRACT,
		"entrypoints": [
			"player_move",
			"ship_move",
			"ship_spawn",
			"ship_despawn",
			"ship_board",
			"ship_unboard",
			"ship_switch_reference_body",
			"item_collect",
			"_debug_player_spawn",
		]
	}]

}

const policies_url = {
	"contracts": {
		ACTIONS_CONTRACT: {
			"methods": [
				{
					"name" : "Player move", # Optional
					"description": "Moves the player", # Optional
					"entrypoint": "player_move",
				},
				{
					"name" : "Ship move", # Optional
					"description": "Moves the ship", # Optional
					"entrypoint": "ship_move",
				},
				{
					"entrypoint": "ship_spawn",
				},
				{
					"entrypoint": "ship_despawn",
				},
				{
					"entrypoint": "ship_board",
				},
				{
					"entrypoint": "ship_unboard",
				},
				{
					"entrypoint": "ship_switch_reference_body",
				},
				{
					"entrypoint": "item_collect",
				},
				{
					"entrypoint": "_debug_player_spawn",
				},
			]
		}
	}
}
