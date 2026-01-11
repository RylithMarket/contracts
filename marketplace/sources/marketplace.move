module marketplace::venue;

use core::vault::StrategyVault;
use marketplace::royalty_rule;
use sui::package::Publisher;
use sui::transfer_policy::{Self as policy, TransferPolicy, TransferPolicyCap};

// === Constants ===
const MIN_ROYALTY_AMOUNT: u64 = 100_000; // 0.0001 SUI in MIST

public fun setup_rylith_market(publisher: &Publisher, ctx: &mut TxContext) {
    let (mut trade_policy, policy_cap) = policy::new<StrategyVault>(publisher, ctx);

    royalty_rule::add<StrategyVault>(
        &mut trade_policy,
        &policy_cap,
        150,
        MIN_ROYALTY_AMOUNT,
    );

    transfer::public_share_object(trade_policy);
    transfer::public_transfer(policy_cap, tx_context::sender(ctx));
}
