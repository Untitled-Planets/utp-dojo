use crate::models::{Vec3};

#[starknet::interface]
pub trait IGameActions<T> {
    fn ship_spawn(ref self: T, spawn_pos: Vec3);
    fn ship_despawn(ref self: T);
    fn ship_board(ref self: T);
    fn ship_unboard(ref self: T, pos: Vec3);
    fn ship_move(ref self: T, destination: Vec3, p_hyperspeed: bool);
    fn ship_switch_reference_body(ref self: T, reference_body: u128, position: Vec3, direction: Vec3);
    fn player_move(ref self: T, dst: Vec3);
    fn item_collect(ref self: T, collectable_type: u16, collectable_index: u8);
}


#[dojo::contract]
pub mod GameActions {
    use super::IGameActions;
    use crate::models::{Player, Spaceship, Planet, CollectableTracker, PlayerPosition, ShipPosition, Vec3, InventoryItem};
    // We'll implement our own bitwise operations
    
    use dojo::world::world;
    use starknet::get_block_timestamp;
    use core::num::traits::Pow;
    use core::num::traits::Sqrt;
    use array::ArrayTrait;
    use core::byte_array::ByteArray;
    use starknet::{ContractAddress, get_caller_address};
    use dojo::model::{ModelStorage};
    use dojo::event::EventStorage;
    use core::traits::BitAnd;

    const FP_UNIT: i128 = 0x10000000000; // 2^40
    const FP_UNIT_BITS: u8 = 40;

    fn current_pos(pos: Vec3, dest: Vec3, dir: Vec3, last_move: u128, speed: u128) -> Vec3 {
        let current_time_u64 = get_block_timestamp();
        let current_time: u128 = current_time_u64.into();
        let time_delta : u128 = current_time - last_move;
        
        let distance_elapsed : u128 = time_delta * speed;
        let distance_elapsed_sq: u256 = fp40_sq(distance_elapsed.try_into().unwrap());

        let distance_to_dest_sqf: felt252 = vec3_fp40_dist_sq(pos, dest).try_into().unwrap();
        let distance_to_dest_sq: u256 = distance_to_dest_sqf.into();

        if (distance_to_dest_sq <= distance_elapsed_sq) {
            return dest;
        };

        let distancei :i128 = distance_elapsed.try_into().unwrap();
        return Vec3 {
            x: pos.x + fp40_mul(dir.x, distancei),
            y: pos.y + fp40_mul(dir.y, distancei),
            z: pos.z + fp40_mul(dir.z, distancei),
        };
    }

    fn fp40_mul(a: i128, b: i128) -> i128 {
        let mut ret = a * b;
        ret = ret / 2_i128.pow(FP_UNIT_BITS.into());
        return ret;
    }

    fn fp40_sq(a: i128) -> u256 {
        let abs : u256 = abs_value(a).into();
        let ret = (abs * abs) / 2_u256.pow(FP_UNIT_BITS.into());
        return ret;
    }

    fn fp40_sqrt(a: u128) -> u128 {
        let abs : u256 = a.into() * 2_u256.pow(FP_UNIT_BITS.into());
        let sqrt = abs.sqrt();
        return sqrt.try_into().unwrap();
    }

    fn abs_value(v: i128) -> u128 {
        if (v < 0) { return (v * -1).try_into().unwrap(); };
        return v.try_into().unwrap();
    }

    fn fp40_div(a: i128, b: i128) -> i128 {
        let a_abs256: u256 = (abs_value(a) * 2_u128.pow(FP_UNIT_BITS.into())).into();
        let b_abs: u256 = (abs_value(b)).into();
        let abs_ret = a_abs256 / b_abs;
        let uret : u128 = abs_ret.try_into().unwrap(); 
        let ret : i128 = uret.try_into().unwrap();
        if ( (a < 0) != (b < 0) ) {
            return ret * -1;
        };
        return ret;
    }

    fn vec3_fp40_div_scalar(v1: Vec3, s: i128) -> Vec3 {
        let ret = Vec3 {
            x: fp40_div(v1.x, s),
            y: fp40_div(v1.y, s),
            z: fp40_div(v1.z, s),
        };
        return ret;
    }

    fn vec3_fp40_dist_sq(v1: Vec3, v2: Vec3) -> i128 {
        let dx = v1.x - v2.x;
        let dy = v1.y - v2.y;
        let dz = v1.z - v2.z;
        let distance_squared: u128 = (fp40_sq(dx) + fp40_sq(dy) + fp40_sq(dz)).try_into().unwrap();
        return distance_squared.try_into().unwrap();
    }

    fn vec3_fp40_len_sq(vec: Vec3) -> i128 {
        let d2 = fp40_sq(vec.x) + fp40_sq(vec.y) + fp40_sq(vec.z);
        let distance_squared: u128 = d2.try_into().unwrap();
        return distance_squared.try_into().unwrap();
    }

    fn vec3_fp40_len(vec: Vec3) -> i128 {
        let d2 : u128 = vec3_fp40_len_sq(vec).try_into().unwrap();
        let d = fp40_sqrt(d2);
        return d.try_into().unwrap();
    }

    fn vec3_sub(v1: Vec3, v2: Vec3) -> Vec3 {
        return Vec3 {
            x: v1.x - v2.x,
            y: v1.y - v2.y,
            z: v1.z - v2.z,
        };
    }

    fn append_bytearray(ref ba: ByteArray, val: u256, bytes: u8) -> () {

        let mut to_add = bytes;
        let mut val_left = val;
        while (to_add > 0) {

            let byte: u8 = (val_left & 0xff).try_into().unwrap();
            ba.append_byte(byte);
            to_add = to_add - 1;
            val_left = val_left / 256;
        };
    }

    const DEFAULT_REFERENCE_BODY_ID: u128 = 0;
    const MAX_SPAWN: u8 = 128;
    const FP_LEN_SQ_EPSION: i128 = 0x40000000; // 2^30

    const AREA_SIZE: i128 = 32;
    const PLAYER_WALKING_SPEED: i128 = 1 * FP_UNIT;
    const MAX_PLAYER_WALK_EPSILON2: i128 = 5 * FP_UNIT;
    const MAX_SPAWN_DISTANCE_SQUARED: i128 = 2500 * FP_UNIT; // 50 meters
    const MAX_ITEM_PICKUP_D2: i128 = 64 * FP_UNIT; // 8 meters

    const SHIP_SPEED: i128 = 100 * FP_UNIT;
    const SHIP_HYPER_SPEED: i128 = 1000 * FP_UNIT;

    pub mod ShipFlags {
        pub const Spawned: u8 = 1;
        pub const Landed: u8 = 2;
        pub const Occupied: u8 = 4;
    }

    pub mod PlayerFlags {
        pub const OnFoot: u8 = 1;
        pub const OnShip: u8 = 2;
    }

    #[abi(embed_v0)]
    impl GameActionsImpl of IGameActions<ContractState> {

        fn ship_spawn(ref self: ContractState, spawn_pos: Vec3) {
            let mut world = self.world_default();
            let player_id = get_caller_address();
            let player : Player = world.read_model(player_id);
            let mut ship : Spaceship = world.read_model(player_id);

            assert(ship.owner == player_id, 'NotOwner');
            assert((ship.status_flags & ShipFlags::Occupied) == 0, 'ShipNotEmpty');

            let player_pos_model : PlayerPosition = world.read_model(player_id);
            let player_pos = current_pos(player_pos_model.pos, player_pos_model.dest, player_pos_model.dir, player_pos_model.last_motion, PLAYER_WALKING_SPEED.try_into().unwrap());
            
            let distance_squared = vec3_fp40_dist_sq(spawn_pos, player_pos);
            println!("model pos is {},{},{}", player_pos.x, player_pos.y, player_pos.z);
            println!("requested ship spawn distance {}", distance_squared);
            assert(distance_squared <= MAX_SPAWN_DISTANCE_SQUARED, 'TooFar');

            if ((ship.status_flags & ShipFlags::Landed) == 0) {
                ship.status_flags += ShipFlags::Landed;
            };
            if ((ship.status_flags & ShipFlags::Spawned) == 0) {
                ship.status_flags += ShipFlags::Spawned;
            };

            ship.reference_body = player.reference_body;
            world.write_model(@ship);

            let mut ship_motion : ShipPosition = world.read_model(player_id);
            ship_motion.pos = spawn_pos;
            ship_motion.dest = spawn_pos;
            ship_motion.dir = player_pos_model.dir;
            ship_motion.last_motion = get_block_timestamp().into();
            world.write_model(@ship_motion);
        }

        fn ship_despawn(ref self: ContractState) {
            let mut world = self.world_default();
            let player_id = get_caller_address();
            let mut ship : Spaceship = world.read_model(player_id);
            assert(ship.owner == player_id, 'NotOwner');
            assert((ship.status_flags & ShipFlags::Spawned) != 0, 'AlreadyDeSpawned');
            assert((ship.status_flags & ShipFlags::Occupied) == 0, 'ShipNotEmpty');

            // Remove ship position model
            //world.delete_model::<ShipPosition>(spaceship_id);
            ship.status_flags -= ShipFlags::Spawned;
            world.write_model(@ship);
        }

        fn ship_board(ref self: ContractState) {
            let mut world = self.world_default();
            let player_id = get_caller_address();
            let mut ship : Spaceship = world.read_model(player_id);
            
            assert((ship.status_flags & ShipFlags::Spawned) != 0, 'ShipNotSpawned');
            //assert((ship.status_flags & ShipFlags::Landed) != 0, 'ShipNotLanded');
            assert((ship.status_flags & ShipFlags::Occupied) == 0, 'ShipAlreadyOccupied');

            let mut player : Player = world.read_model(player_id);
            assert((player.status_flags & PlayerFlags::OnFoot) != 0, 'PlayerNotWalking');
            assert((player.status_flags & PlayerFlags::OnShip) == 0, 'PlayerAlreadyOnSpaceship');

            // check ship position agains player position
            let ship_pos : ShipPosition = world.read_model(player_id);
            let mut player_pos_model : PlayerPosition = world.read_model(player_id);
            let player_pos = current_pos(player_pos_model.pos, player_pos_model.dest, player_pos_model.dir, player_pos_model.last_motion, PLAYER_WALKING_SPEED.try_into().unwrap()); 

            let dist2 = vec3_fp40_dist_sq(player_pos, ship_pos.pos);
            assert(dist2 <= MAX_SPAWN_DISTANCE_SQUARED, 'TooFar');

            ship.status_flags += ShipFlags::Occupied;
            world.write_model(@ship);

            player.status_flags -= PlayerFlags::OnFoot;
            player.status_flags += PlayerFlags::OnShip;
            world.write_model(@player);
        }

        fn ship_unboard(ref self: ContractState, pos: Vec3) {
            let mut world = self.world_default();
            let player_id = get_caller_address();
            let mut ship : Spaceship = world.read_model(player_id);
            //assert((ship.status_flags & ShipFlags::Landed) != 0, 'ShipNotLanded');
            assert((ship.status_flags & ShipFlags::Occupied) != 0, 'ShipNotOccupied');
            // Get ship position to check last motion time
            //let mut ship_pos : ShipPosition = world.read_model(spaceship_id);
            //assert(ship_pos.speed > 0, 'ShipMoving');
            
            let ship_pos : ShipPosition = world.read_model(player_id);
            let dist2 = vec3_fp40_dist_sq(ship_pos.pos, pos);
            assert(dist2 <= MAX_SPAWN_DISTANCE_SQUARED, 'TooFar');

            let mut player : Player = world.read_model(player_id);
            assert((player.status_flags & PlayerFlags::OnFoot) == 0, 'PlayerWalking');
            assert((player.status_flags & PlayerFlags::OnShip) != 0, 'PlayerNotOnSpaceship');

            let mut player_pos : PlayerPosition = world.read_model(player_id);
            player_pos.pos = pos;
            player_pos.dest = pos;
            world.write_model(@player_pos);

            ship.status_flags -= ShipFlags::Occupied;
            world.write_model(@ship);

            player.status_flags -= PlayerFlags::OnShip;
            player.status_flags += PlayerFlags::OnFoot;
            world.write_model(@player);
        }

        fn ship_move(ref self: ContractState, destination: Vec3, p_hyperspeed: bool) {
            let mut world = self.world_default();
            let player_id = get_caller_address();
            let ship : Spaceship = world.read_model(player_id);

            assert((ship.status_flags & ShipFlags::Spawned) != 0, 'Ship not spawned');
            assert((ship.status_flags & ShipFlags::Occupied) != 0, 'Ship not being driven by player');

            // Get current position from model
            let mut ship_pos_model : ShipPosition = world.read_model(player_id);
            let mut speed_mode : u64 = SHIP_SPEED.try_into().unwrap();
            if (p_hyperspeed) {
                assert(ship.reference_body == DEFAULT_REFERENCE_BODY_ID, 'Hyperspeed not possible');
                speed_mode = SHIP_HYPER_SPEED.try_into().unwrap();
            };
            let ship_pos = current_pos(ship_pos_model.pos, ship_pos_model.dest, ship_pos_model.dir, ship_pos_model.last_motion, speed_mode.into());

            // calculate new dir
            let dif : Vec3 = vec3_sub(destination, ship_pos);
            let len = vec3_fp40_len(dif);
            let dir = vec3_fp40_div_scalar(dif, len);
            
            // Update ship position model
            let new_ship_pos = ShipPosition {
                owner: player_id,
                pos: ship_pos,
                dir: dir,
                dest: destination,
                last_motion: get_block_timestamp().into(),
                hyperspeed: p_hyperspeed,
            };
            world.write_model(@new_ship_pos);
        }

        fn ship_switch_reference_body(ref self: ContractState, reference_body: u128, position: Vec3, direction: Vec3) {
            let mut world = self.world_default();
            let player_id = get_caller_address();
            let mut ship : Spaceship = world.read_model(player_id);

            assert((ship.status_flags & ShipFlags::Spawned) != 0, 'Ship not spawned');
            assert((ship.status_flags & ShipFlags::Occupied) != 0, 'Ship not being driven by player');

            // Check that the direction vector is normalized
            // Using fixed point arithmetic with a small epsilon for floating point comparison
            let len2 = vec3_fp40_len_sq(direction);
            assert(len2 >= FP_UNIT - FP_LEN_SQ_EPSION && len2 <= FP_UNIT + FP_LEN_SQ_EPSION, 'Direction not normalized');

            ship.reference_body = reference_body;
            world.write_model(@ship);

            // TODO new position not checked
            let mut ship_pos : ShipPosition = world.read_model(player_id);
            ship_pos.pos = position;
            ship_pos.dest = position;
            ship_pos.hyperspeed = false;
            ship_pos.dir = direction;

            world.write_model(@ship_pos);
        }

        fn player_move(ref self: ContractState, dst: Vec3) {
            println!("-- player_move start");
            let mut world = self.world_default();
            let player_id = get_caller_address();
            println!("Player {:?} move to {},{},{}", player_id, dst.x, dst.y, dst.z);
            let mut player : Player = world.read_model(player_id);
            if (player.status_flags == 0) { // 1st spawn
                player.status_flags = PlayerFlags::OnFoot;
                world.write_model(@player);
            }
            assert((player.status_flags & PlayerFlags::OnFoot) != 0, 'Player is not walking');

            // Get current position from model
            let mut player_pos_model : PlayerPosition = world.read_model(player_id);
            if (player_pos_model.last_motion == 0) { // 1st spawn
                player_pos_model.last_motion = get_block_timestamp().into();
            }
            println!("model dir is {},{},{}", player_pos_model.dir.x, player_pos_model.dir.y, player_pos_model.dir.z);
            println!("model pos is {},{},{}", player_pos_model.pos.x, player_pos_model.pos.y, player_pos_model.pos.z);
            println!("model dst is {},{},{}", player_pos_model.dest.x, player_pos_model.dest.y, player_pos_model.dest.z);
            let model_pos = current_pos(player_pos_model.pos, player_pos_model.dest, player_pos_model.dir, player_pos_model.last_motion, PLAYER_WALKING_SPEED.try_into().unwrap());
            println!("current pos to {},{},{}", model_pos.x, model_pos.y, model_pos.z);

            // calculate new dir
            let dif : Vec3 = vec3_sub(dst, model_pos);
            println!("dif is {},{},{}", dif.x, dif.y, dif.z);
            let len = vec3_fp40_len(dif);
            println!("len is {}", len);
            let mut dir = dif;
            if (len > 0) {
                dir = vec3_fp40_div_scalar(dif, len);
            };

            // Update player position model
            let new_player_pos = PlayerPosition {
                player: player_id,
                pos: model_pos,
                dir: dir,
                dest: dst,
                last_motion: get_block_timestamp().into(),
            };
            world.write_model(@new_player_pos);
            println!("-- player_move done");
        }

        fn item_collect(ref self: ContractState, collectable_type: u16, collectable_index: u8) {
            let mut world = self.world_default();
            let player_id = get_caller_address();
            let player : Player = world.read_model(player_id);
            let planet : Planet = world.read_model(player.reference_body);
            let player_pos_model : PlayerPosition = world.read_model(player_id);
            let player_pos = current_pos(player_pos_model.pos, player_pos_model.dest, player_pos_model.dir, player_pos_model.last_motion, PLAYER_WALKING_SPEED.try_into().unwrap());

            let mut area_x = player_pos.x / (AREA_SIZE * FP_UNIT).into();
            if (player_pos.x < 0) {
                area_x += 0xffffffff;
            }
            let mut area_y = player_pos.y / (AREA_SIZE * FP_UNIT).into();
            if (player_pos.y < 0) {
                area_y += 0xffffffff;
            }
            let mut area_z = player_pos.z / (AREA_SIZE * FP_UNIT).into();
            if (player_pos.z < 0) {
                area_z += 0xffffffff;
            }
            let area_hash : u32 = ((area_x % 1024) * 1024 * 1024 + (area_y % 1024) * 1024 + (area_z % 1024)).try_into().unwrap();
            println!("player is in area {} {}, {}, {}", area_hash, area_x, area_y, area_z);

            // Create a ByteArray from a string literal and then append values
            let mut count_seed = ByteArray { data: array![], pending_word: 0, pending_word_len: 0 };
            // Convert values to bytes before appending
            append_bytearray(ref count_seed, planet.seed.into(), 32);
            let epoc:u32 = planet.epoc;
            append_bytearray(ref count_seed, epoc.into(), 4);
            append_bytearray(ref count_seed, area_hash.into(), 4);
            append_bytearray(ref count_seed, collectable_type.into(), 2);
            //let count_seed = planet.seed + planet.epoc + area_hash + collectable_type.into();
            
            println!("array before hash {:?}", count_seed);
            let count_hash = core::sha256::compute_sha256_byte_array(@count_seed);
            println!("hash is {:?}", count_hash);
            let total_spawned = *count_hash.span().at(7) % MAX_SPAWN.into();
            println!("spawned {}", total_spawned);

            assert(collectable_index.into() < total_spawned, 'InvalidIndex');

            // Create a new ByteArray for position seed by copying the count_seed and adding the collectable_index
            let mut pos_seed = count_seed.clone();
            pos_seed.append_byte(collectable_index.into());
            let item_hash = core::sha256::compute_sha256_byte_array(@pos_seed);
            println!("array before item hash {:?}", pos_seed);
            println!("item {} hash is {:?}", collectable_index, item_hash);

            let span = item_hash.span(); // span of 32 bit elements
            // Convert u32 to i128 using try_into().unwrap()
            let span_0_i128: i128 = (*span.at(0)).try_into().unwrap();
            let span_1_i128: i128 = (*span.at(1)).try_into().unwrap();
            let span_2_i128: i128 = (*span.at(2)).try_into().unwrap();
            
            let offset_x = (span_0_i128 * FP_UNIT / 0xFFFFFFFF_i128) * AREA_SIZE;
            let offset_y = (span_1_i128 * FP_UNIT / 0xFFFFFFFF_i128) * AREA_SIZE;
            let offset_z = (span_2_i128 * FP_UNIT / 0xFFFFFFFF_i128) * AREA_SIZE;

            println!("spawn offset {}, {}, {}", offset_x, offset_y, offset_z);
            let item_pos = Vec3 {
                x: area_x * FP_UNIT + offset_x,
                y: area_y * FP_UNIT + offset_y,
                z: area_z * FP_UNIT + offset_z,
            };

            let d2 = vec3_fp40_dist_sq(item_pos, player_pos);
            assert(d2 <= MAX_ITEM_PICKUP_D2, 'TooFar');

            // Get existing tracker or create a new one
            let mut tracker : CollectableTracker = world.read_model((area_hash, collectable_type));
            
            let bitfield : u128 = if tracker.epoc == planet.epoc { tracker.bitfield } else { 0 };
            let bit_mask : u128 = 2_u128.pow(collectable_index.into());

            let is_already_collected = (bitfield & bit_mask) != 0;
            assert(!is_already_collected, 'AlreadyCollected');

            // Bitwise OR implementation
            tracker.bitfield = bitfield | bit_mask;
            tracker.epoc = planet.epoc;

            tracker.area = area_hash;
            tracker.collectable_type = collectable_type;

            world.write_model(@tracker);

            // move to funtcion add_to_inventory
            {
                // Get the current inventory item or create a new one with count 0
                let current_item : InventoryItem = world.read_model((player_id, collectable_type));
                
                // TODO: detect empty result
                // {
                //    Option::Some(item) => item,
                //    None => InventoryItem { player_id: player_id, item_type: collectable_type, count: 0 },
                //};
                
                // Increment the count
                let new_item = InventoryItem { 
                    player_id: player_id,
                    item_type: collectable_type,
                    count: current_item.count + 1,
                };
                
                // Save the updated inventory item
                world.write_model(@new_item);
            }
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Use the default namespace "utp_dojo". This function is handy since the ByteArray
        /// can't be const.
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"utp_dojo")
        }
    }
}
