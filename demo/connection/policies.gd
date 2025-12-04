const WORLD_CONTRACT = "0x072593bd6b7770a56ff9b9ec7747755f0c681a7f7dc09133c518b7150efe5949"
const ACTIONS_CONTRACT = "0x03f4b2fbfdfefd5f24588cad670a55e90d19809eff3879f21f15370cdf540a9f"

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
