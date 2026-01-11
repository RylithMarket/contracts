module core::events;

use std::string::{Self, String};
use sui::event;

public struct VaultCreated has copy, drop {
    id: ID,
    owner: address,
    name: String,
    strategy_type: String,
    timestamp: u64,
}

public struct AssetDeposited has copy, drop {
    vault_id: ID,
    asset_type: String,
    asset_key: String,
    timestamp: u64,
}

public struct AssetWithdrawn has copy, drop {
    vault_id: ID,
    asset_key: String,
    timestamp: u64,
}

public struct VaultDestroyed has copy, drop {
    id: ID,
}

public(package) fun emit_vault_created(
    id: ID,
    owner: address,
    name: String,
    strategy_type: String,
    timestamp: u64,
) {
    event::emit<VaultCreated>(VaultCreated {
        id,
        owner,
        name,
        strategy_type,
        timestamp,
    });
}

public(package) fun emit_asset_deposited(
    vault_id: ID,
    asset_type: String,
    asset_key: String,
    timestamp: u64,
) {
    event::emit<AssetDeposited>(AssetDeposited {
        vault_id,
        asset_type,
        asset_key,
        timestamp,
    });
}

public(package) fun emit_asset_withdrawn(vault_id: ID, asset_key: String, timestamp: u64) {
    event::emit<AssetWithdrawn>(AssetWithdrawn {
        vault_id,
        asset_key,
        timestamp,
    });
}

public(package) fun emit_vault_destroyed(id: ID) {
    event::emit<VaultDestroyed>(VaultDestroyed {
        id,
    });
}
