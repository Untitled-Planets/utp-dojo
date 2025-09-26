use starknet::{ContractAddress};
use dict::Felt252Dict;

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct Player {
    #[key]
    pub id: ContractAddress,
    pub reference_body: u128,
    pub status_flags: u8, // 1: walking, 2: spaceship
}

// We'll use a separate model for inventory items
#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct InventoryItem {
    #[key]
    pub player_id: ContractAddress,
    #[key]
    pub item_type: u16,
    pub count: u64,
}


#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct PlayerPosition {
    #[key]
    pub player: ContractAddress,
    pub pos: Vec3,
    pub dir: Vec3,
    pub dest: Vec3,
    pub last_motion: u128,
}


#[derive(Drop, Serde, Debug)]
#[dojo::model]
pub struct Spaceship {
    #[key]
    pub owner: ContractAddress,
    pub capacity: u32,
    pub reference_body: u128,
    pub status_flags: u8, // 1: spawned, 2: landed, 4: opccupied
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct ShipPosition {
    #[key]
    pub owner: ContractAddress,
    pub pos: Vec3,
    pub dir: Vec3,
    pub dest: Vec3,
    pub hyperspeed: bool,
    pub last_motion: u128,
}


#[derive(Drop, Serde, Debug)]
#[dojo::model]
pub struct Planet {
    #[key]
    pub id: u128,
    seed: felt252,
    pub max_radius_squared: u128,
    epoc: u32,
}


#[derive(Drop, Serde, Debug)]
#[dojo::model]
pub struct CollectableTracker {
    #[key]
    pub id: u128,
    pub area: felt252,
    pub collectable_type: u16,
    pub bitfield: u128,
    pub epoc: u32,
}


#[derive(Copy, Drop, Serde, IntrospectPacked, DojoStore, Debug)]
pub struct Vec3 {
    pub x: i128,
    pub y: i128,
    pub z: i128,
}
