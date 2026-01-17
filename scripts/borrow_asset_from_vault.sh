#!/bin/bash

# --- CONFIGURATION ---
CORE_PACKAGE="0xbd990a04d0dc81dbfa1cd14457e6640046fa77981bdd855593f31cb99381cd1c"
VAULT_ID="0x7a9cf50f02871d1fc3a16890b0abcf33f34d81082a9fbe91960d47acbebcf768"
POSITION_TYPE="0x5372d555ac734e272659136c2a0cd3227f9b92de67c80dc11250307268af2db8::position::Position"
ASSET_NAME="cetus_lp_position"
CLOCK_ID="0x6"

MY_ADDRESS=$(sui client active-address)

echo "Withdrawing Cetus LP Position from Vault..."

sui client ptb \
  --move-call "${CORE_PACKAGE}::vault::withdraw_asset<${POSITION_TYPE}>" \
    "@${VAULT_ID}" \
    "\"${ASSET_NAME}\"" \
    "@${CLOCK_ID}" \
  --assign position \
  --transfer-objects "[position]" "@${MY_ADDRESS}" \
  --gas-budget 100000000