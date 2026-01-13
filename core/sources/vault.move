module core::vault;

use core::events;
use std::string::{Self, String};
use std::type_name;
use sui::clock::{Self, Clock};
use sui::display;
use sui::dynamic_object_field as dof;
use sui::package;

// === OTW ===
public struct VAULT has drop {}

// === Errors ===
const ENotFound: u64 = 0401;
const EAlreadyExist: u64 = 0402;
const EUnauthorized: u64 = 0403;
const ETypeMismatch: u64 = 0404;

// === Constants ===
const DEFAULT_URL: vector<u8> = b"https://rylith.space/";

public struct StrategyVault has key, store {
    id: UID,
    name: String,
    description: String,
    strategy_type: String,
    img_url: String,
    created_at: u64,
}

public struct AssetKey has copy, drop, store {
    name: String,
}

fun init(otw: VAULT, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);
    let base_url = string::utf8(DEFAULT_URL);

    let keys = vector[
        b"name".to_string(),
        b"link".to_string(),
        b"image_url".to_string(),
        b"description".to_string(),
        b"project_url".to_string(),
        b"creator".to_string(),
    ];

    let mut vault_url = base_url;
    vault_url.append(string::utf8(b"vault/{id}/"));

    let values = vector[
        b"{name}".to_string(),
        vault_url,
        b"{img_url}".to_string(),
        b"{description}".to_string(),
        base_url,
        b"Rylith Protocol".to_string(),
    ];

    let mut display = display::new_with_fields<StrategyVault>(
        &publisher,
        keys,
        values,
        ctx,
    );

    display::update_version(&mut display);

    transfer::public_transfer(publisher, tx_context::sender(ctx));
    transfer::public_transfer(display, tx_context::sender(ctx));
}

public fun create(
    name: vector<u8>,
    description: vector<u8>,
    strategy_type: vector<u8>,
    img_url: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
): StrategyVault {
    let id = object::new(ctx);
    let vault_id = object::uid_to_inner(&id);

    let vault = StrategyVault {
        id,
        name: string::utf8(name),
        description: string::utf8(description),
        strategy_type: string::utf8(strategy_type),
        img_url: string::utf8(img_url),
        created_at: tx_context::epoch(ctx),
    };

    events::emit_vault_created(
        vault_id,
        tx_context::sender(ctx),
        vault.name,
        vault.strategy_type,
        clock::timestamp_ms(clock),
    );

    vault
}

public fun deposit_asset<T: key + store>(
    vault: &mut StrategyVault,
    asset: T,
    asset_name: vector<u8>,
    clock: &Clock,
    _ctx: &mut TxContext,
) {
    assert!(!has_asset(vault, asset_name), EAlreadyExist);

    let key = AssetKey { name: string::utf8(asset_name) };

    events::emit_asset_deposited(
        object::uid_to_inner(&vault.id),
        string::from_ascii(type_name::with_defining_ids<T>().into_string()),
        key.name,
        clock::timestamp_ms(clock),
    );

    dof::add(&mut vault.id, key, asset);
}

public fun withdraw_asset<T: key + store>(
    vault: &mut StrategyVault,
    asset_name: vector<u8>,
    clock: &Clock,
    _ctx: &mut TxContext,
): T {
    let key = AssetKey { name: string::utf8(asset_name) };

    events::emit_asset_withdrawn(
        object::uid_to_inner(&vault.id),
        key.name,
        clock::timestamp_ms(clock),
    );

    dof::remove(&mut vault.id, key)
}

// === Helpers ===

public fun has_asset(vault: &StrategyVault, asset_name: vector<u8>): bool {
    let key = AssetKey { name: string::utf8(asset_name) };
    dof::exists_(&vault.id, key)
}

public fun borrow_asset<T: key + store>(vault: &StrategyVault, asset_name: vector<u8>): &T {
    let key = AssetKey { name: string::utf8(asset_name) };
    dof::borrow<AssetKey, T>(&vault.id, key)
}

public fun borrow_mut_asset<T: key + store>(
    vault: &mut StrategyVault,
    asset_name: vector<u8>,
): &mut T {
    let key = AssetKey { name: string::utf8(asset_name) };
    dof::borrow_mut<AssetKey, T>(&mut vault.id, key)
}

public fun keep(vault: StrategyVault, ctx: &mut TxContext) {
    transfer::public_transfer(vault, tx_context::sender(ctx));
}

public fun destroy(vault: StrategyVault) {
    let StrategyVault { id, name: _, description: _, strategy_type: _, img_url: _, created_at: _ } =
        vault;

    events::emit_vault_destroyed(
        object::uid_to_inner(&id),
    );

    object::delete(id);
}

// === Unit Tests ===
#[test_only]
use std::unit_test::assert_eq;
#[test_only]
use sui::test_scenario::{Self as ts, Scenario, next_tx};

#[test_only]
const WYNER_ADDR: address = @0x1;
const USER_ADDR: address = @0x2;

#[test_only]
#[test_only]

#[test_only]
public struct LpToken has key, store {
    id: UID,
    amount: u64,
}

#[test_only]
public struct Collateral has key, store {
    id: UID,
    value: u64,
}

#[test_only]
fun setup_scenario(): (Scenario, Clock) {
    let mut scenario = ts::begin(WYNER_ADDR);
    let clock = clock::create_for_testing(scenario.ctx());
    (scenario, clock)
}

#[test_only]
fun end_scenario(scenario: Scenario, clock: Clock) {
    clock::destroy_for_testing(clock);
    ts::end(scenario);
}

#[test]
fun test_vault_flow() {
    let (mut scenario, clock) = setup_scenario();

    next_tx(&mut scenario, WYNER_ADDR);
    {
        let ctx = ts::ctx(&mut scenario);
        let vault = create(
            b"My Vault",
            b"This is a test vault",
            b"Test Strategy",
            b"http://example.com/image.png",
            &clock,
            ctx,
        );

        keep(vault, ctx);
    };

    next_tx(&mut scenario, WYNER_ADDR);
    {
        let mut vault = ts::take_from_sender<StrategyVault>(&scenario);

        let ctx = ts::ctx(&mut scenario);
        let asset1 = LpToken {
            id: object::new(ctx),
            amount: 100u64,
        };
        let asset2 = Collateral {
            id: object::new(ctx),
            value: 500u64,
        };

        vault.deposit_asset(asset1, b"Cetus Token", &clock, ctx);
        vault.deposit_asset(asset2, b"Scallop Collateral", &clock, ctx);

        assert!(vault.has_asset(b"Cetus Token"));
        assert!(vault.has_asset(b"Scallop Collateral"));

        let borrowed_asset1 = borrow_asset<LpToken>(&vault, b"Cetus Token");
        assert_eq!(borrowed_asset1.amount, 100u64);

        let withdrawn_asset1 = withdraw_asset<LpToken>(&mut vault, b"Cetus Token", &clock, ctx);
        let withdrawn_asset2 = withdraw_asset<Collateral>(
            &mut vault,
            b"Scallop Collateral",
            &clock,
            ctx,
        );

        assert_eq!(withdrawn_asset1.amount, 100u64);
        assert!(!has_asset(&vault, b"Cetus Token"));

        let LpToken { id, amount: _ } = withdrawn_asset1;
        object::delete(id);

        let Collateral { id, value: _ } = withdrawn_asset2;
        object::delete(id);

        ts::return_to_sender(&scenario, vault);
    };

    end_scenario(scenario, clock);
}

#[test, expected_failure(abort_code = ts::EEmptyInventory)]
fun test_unauthorized() {
    let (mut scenario, clock) = setup_scenario();

    next_tx(&mut scenario, WYNER_ADDR);
    {
        let ctx = ts::ctx(&mut scenario);
        let vault = create(
            b"My Vault",
            b"This is a test vault",
            b"Test Strategy",
            b"http://example.com/image.png",
            &clock,
            ctx,
        );

        keep(vault, ctx);
    };

    next_tx(&mut scenario, USER_ADDR);
    {
        let mut vault = ts::take_from_sender<StrategyVault>(&scenario);

        let ctx = ts::ctx(&mut scenario);
        let asset = LpToken {
            id: object::new(ctx),
            amount: 100u64,
        };

        deposit_asset(&mut vault, asset, b"Cetus Token", &clock, ctx);

        ts::return_to_sender(&scenario, vault);
    };

    end_scenario(scenario, clock);
}

#[test, expected_failure(abort_code = EAlreadyExist)]
fun test_deposit_existing_asset() {
    let (mut scenario, clock) = setup_scenario();

    next_tx(&mut scenario, WYNER_ADDR);
    {
        let ctx = ts::ctx(&mut scenario);
        let mut vault = create(
            b"My Vault",
            b"This is a test vault",
            b"Test Strategy",
            b"http://example.com/image.png",
            &clock,
            ctx,
        );

        let asset1 = LpToken {
            id: object::new(ctx),
            amount: 100u64,
        };

        deposit_asset(&mut vault, asset1, b"Cetus Token", &clock, ctx);

        let asset2 = LpToken {
            id: object::new(ctx),
            amount: 200u64,
        };

        deposit_asset(&mut vault, asset2, b"Cetus Token", &clock, ctx);

        ts::return_to_sender(&scenario, vault);
    };

    end_scenario(scenario, clock);
}

#[test]
fun test_transfer_to_other_user() {
    let (mut scenario, clock) = setup_scenario();

    next_tx(&mut scenario, WYNER_ADDR);
    {
        let ctx = ts::ctx(&mut scenario);
        let vault = create(
            b"My Vault",
            b"This is a test vault",
            b"Test Strategy",
            b"http://example.com/image.png",
            &clock,
            ctx,
        );

        keep(vault, ctx);
    };

    next_tx(&mut scenario, WYNER_ADDR);
    {
        let vault = ts::take_from_sender<StrategyVault>(&scenario);
        transfer::public_transfer(vault, USER_ADDR);
    };

    next_tx(&mut scenario, USER_ADDR);
    {
        let vault = ts::take_from_sender<StrategyVault>(&scenario);

        ts::return_to_sender(&scenario, vault);
    };

    end_scenario(scenario, clock);
}

#[test, expected_failure(abort_code = 2, location = sui::dynamic_field)]
fun test_withdraw_wrong_type() {
    let (mut scenario, clock) = setup_scenario();
    next_tx(&mut scenario, WYNER_ADDR);
    {
        let ctx = ts::ctx(&mut scenario);
        let mut vault = create(b"My Vault", b"Desc", b"Type", b"URL", &clock, ctx);

        let asset = LpToken { id: object::new(ctx), amount: 100 };

        deposit_asset(&mut vault, asset, b"MyAsset", &clock, ctx);

        let _wrong_asset = withdraw_asset<Collateral>(&mut vault, b"MyAsset", &clock, ctx);

        let Collateral { id, value: _ } = _wrong_asset;
        object::delete(id);
        ts::return_to_sender(&scenario, vault);
    };
    end_scenario(scenario, clock);
}

#[test]
fun test_borrow_mut_asset() {
    let (mut scenario, clock) = setup_scenario();
    next_tx(&mut scenario, WYNER_ADDR);
    {
        let ctx = ts::ctx(&mut scenario);
        let vault = create(b"My Vault", b"Desc", b"Type", b"URL", &clock, ctx);

        keep(vault, ctx);
    };
    next_tx(&mut scenario, WYNER_ADDR);
    {
        let mut vault = ts::take_from_sender<StrategyVault>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let asset = LpToken { id: object::new(ctx), amount: 100 };
        deposit_asset(&mut vault, asset, b"MyAsset", &clock, ctx);
        let borrowed_asset = borrow_mut_asset<LpToken>(&mut vault, b"MyAsset");
        borrowed_asset.amount = 200;
        let withdrawn_asset = withdraw_asset<LpToken>(&mut vault, b"MyAsset", &clock, ctx);
        assert_eq!(withdrawn_asset.amount, 200);
        let LpToken { id, amount: _ } = withdrawn_asset;
        object::delete(id);
        ts::return_to_sender(&scenario, vault);
    };
    end_scenario(scenario, clock);
}

#[test, expected_failure]
fun test_borrow_mut_asset_unauthorized() {
    let (mut scenario, clock) = setup_scenario();
    next_tx(&mut scenario, WYNER_ADDR);
    {
        let ctx = ts::ctx(&mut scenario);
        let vault = create(b"My Vault", b"Desc", b"Type", b"URL", &clock, ctx);

        keep(vault, ctx);
    };
    next_tx(&mut scenario, USER_ADDR);
    {
        let mut vault = ts::take_from_sender<StrategyVault>(&scenario);
        let _borrowed_asset = borrow_mut_asset<LpToken>(&mut vault, b"MyAsset");
        ts::return_to_sender(&scenario, vault);
    };
    end_scenario(scenario, clock);
}
