module marketplace::royalty_rule;

use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::transfer_policy::{Self as policy, TransferPolicy, TransferPolicyCap, TransferRequest};

// === Errors ===
const EInsufficientAmount: u64 = 0;

public struct Rule has drop {}

public struct Config has drop, store {
    amount_bps: u16,
    min_amount: u64,
}

// === Main Functions ===

public fun add<T>(
    policy: &mut TransferPolicy<T>,
    cap: &TransferPolicyCap<T>,
    amount_bps: u16,
    min_amount: u64,
) {
    policy::add_rule(Rule {}, policy, cap, Config { amount_bps, min_amount });
}

public fun pay<T>(
    policy: &mut TransferPolicy<T>,
    request: &mut TransferRequest<T>,
    payment: Coin<SUI>,
    _ctx: &mut TxContext,
) {
    let config: &Config = policy::get_rule(Rule {}, policy);

    let paid = policy::paid(request);
    // Tính toán phí dựa trên Basis Points (bps)
    let expected_amount = (((paid as u128) * (config.amount_bps as u128) / 10_000) as u64);

    // So sánh với mức phí tối thiểu
    let due_amount = if (expected_amount > config.min_amount) { expected_amount } else {
        config.min_amount
    };

    // Kiểm tra tiền trả có đủ không
    assert!(coin::value(&payment) >= due_amount, EInsufficientAmount);

    // Nạp tiền vào Policy (Coin bị tiêu thụ tại đây -> Safe for PTB)
    policy::add_to_balance(Rule {}, policy, payment);

    // Đóng dấu đã trả tiền cho Rule này
    policy::add_receipt(Rule {}, request);
}

#[test_only]
use sui::test_scenario::{Self as ts};
#[test_only]
use core::vault::{Self, StrategyVault};
#[test_only]
use sui::kiosk::{Self, Kiosk, KioskOwnerCap};
#[test_only]
use sui::clock::{Self, Clock};

#[test_only]
fun create_request_via_purchase(
    scenario: &mut ts::Scenario,
    clock: &Clock,
    price: u64,
): (Kiosk, KioskOwnerCap, StrategyVault, TransferRequest<StrategyVault>) {
    let ctx = ts::ctx(scenario);

    let (mut kiosk, kiosk_cap) = kiosk::new(ctx);
    let vault = vault::create(b"Name", b"Desc", b"Strategy", clock, ctx);
    let item_id = object::id(&vault);

    kiosk::place(&mut kiosk, &kiosk_cap, vault);
    kiosk::list<StrategyVault>(&mut kiosk, &kiosk_cap, item_id, price);

    let payment = coin::mint_for_testing<SUI>(price, ctx);

    let (item, request) = kiosk::purchase<StrategyVault>(
        &mut kiosk,
        item_id,
        payment,
    );

    (kiosk, kiosk_cap, item, request)
}

#[test_only]
fun cleanup(
    kiosk: Kiosk,
    kiosk_cap: KioskOwnerCap,
    item: StrategyVault,
    policy: TransferPolicy<StrategyVault>,
    policy_cap: TransferPolicyCap<StrategyVault>,
    ctx: &mut TxContext,
) {
    let profit = policy::destroy_and_withdraw(policy, policy_cap, ctx);
    transfer::public_transfer(profit, @0xA);
    transfer::public_transfer(kiosk, @0xA);
    transfer::public_transfer(kiosk_cap, @0xA);
    vault::destroy(item);
}

#[test]
fun test_add_rule() {
    let admin = @0xA;
    let mut scenario = ts::begin(admin);
    {
        let ctx = ts::ctx(&mut scenario);
        let (mut policy, cap) = policy::new_for_testing<StrategyVault>(ctx);

        add(&mut policy, &cap, 150, 100_000);
        let _config: &Config = policy::get_rule(Rule {}, &policy);

        let coin = policy::destroy_and_withdraw(policy, cap, ctx);
        transfer::public_transfer(coin, admin);
    };
    ts::end(scenario);
}

#[test]
fun test_pay_normal() {
    let admin = @0xA;
    let mut scenario = ts::begin(admin);
    let clock = clock::create_for_testing(ts::ctx(&mut scenario));

    {
        let (mut policy, cap) = {
            let ctx = ts::ctx(&mut scenario);
            let (mut p, c) = policy::new_for_testing<StrategyVault>(ctx);
            add(&mut p, &c, 150, 100_000_000); // 1.5%
            (p, c)
        };

        let price = 100_000_000_000;
        let (kiosk, kiosk_cap, item, mut req) = create_request_via_purchase(
            &mut scenario,
            &clock,
            price,
        );

        let ctx = ts::ctx(&mut scenario);
        // 1.5% của 100 SUI = 1.5 SUI
        let fee_amount = 1_500_000_000;
        let payment = sui::coin::mint_for_testing<SUI>(fee_amount, ctx);

        pay(&mut policy, &mut req, payment, ctx);
        policy::confirm_request(&policy, req);

        cleanup(kiosk, kiosk_cap, item, policy, cap, ctx);
    };

    clock::destroy_for_testing(clock);
    ts::end(scenario);
}

#[test]
fun test_pay_min_amount() {
    let admin = @0xA;
    let mut scenario = ts::begin(admin);
    let clock = clock::create_for_testing(ts::ctx(&mut scenario));

    {
        let (mut policy, cap) = {
            let ctx = ts::ctx(&mut scenario);
            let (mut p, c) = policy::new_for_testing<StrategyVault>(ctx);
            add(&mut p, &c, 1000, 1_000_000_000); // 10%, min 1 SUI
            (p, c)
        };

        // Giá nhỏ: 0.1 SUI
        let price = 100_000_000;
        let (kiosk, kiosk_cap, item, mut req) = create_request_via_purchase(
            &mut scenario,
            &clock,
            price,
        );

        let ctx = ts::ctx(&mut scenario);
        // 10% của 0.1 là 0.01 -> Nhỏ hơn min 1 SUI -> Phải trả 1 SUI
        let payment = sui::coin::mint_for_testing<SUI>(1_000_000_000, ctx);

        pay(&mut policy, &mut req, payment, ctx);
        policy::confirm_request(&policy, req);

        cleanup(kiosk, kiosk_cap, item, policy, cap, ctx);
    };

    clock::destroy_for_testing(clock);
    ts::end(scenario);
}

#[test, expected_failure(abort_code = EInsufficientAmount)]
fun test_pay_fail_insufficient() {
    let admin = @0xA;
    let mut scenario = ts::begin(admin);
    let clock = clock::create_for_testing(ts::ctx(&mut scenario));

    {
        let (mut policy, cap) = {
            let ctx = ts::ctx(&mut scenario);
            let (mut p, c) = policy::new_for_testing<StrategyVault>(ctx);
            add(&mut p, &c, 150, 0);
            (p, c)
        };

        let price = 100_000_000_000;
        let (kiosk, kiosk_cap, item, mut req) = create_request_via_purchase(
            &mut scenario,
            &clock,
            price,
        );

        let ctx = ts::ctx(&mut scenario);
        // Trả thiếu (0.5 SUI thay vì 1.5 SUI)
        let payment = sui::coin::mint_for_testing<SUI>(500_000_000, ctx);

        pay(&mut policy, &mut req, payment, ctx); // Sẽ fail tại đây

        policy::confirm_request(&policy, req);
        cleanup(kiosk, kiosk_cap, item, policy, cap, ctx);
    };

    clock::destroy_for_testing(clock);
    ts::end(scenario);
}
