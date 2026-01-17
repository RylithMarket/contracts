#!/bin/bash

# Add Cetus LP Position to Vault
# Vault: 0xbae1fcad222bef6a1d9dca71fd3928e604c8b77aa922ad7cdb984ff19e09b4c5
# Asset: 0xde24f378ecd23cad4c80730de808580a07c223d76961e511b776c44a6cad7151 (Cetus LP)

CORE_PACKAGE="0x1bc997dad699461e750aa7916b3b96d8666bb18dc08f7a3de51f90ac2d5c046e"
VAULT_ID="0x7a9cf50f02871d1fc3a16890b0abcf33f34d81082a9fbe91960d47acbebcf768"
POSITION_ID="0xde24f378ecd23cad4c80730de808580a07c223d76961e511b776c44a6cad7151"
POSITION_TYPE="0x5372d555ac734e272659136c2a0cd3227f9b92de67c80dc11250307268af2db8::position::Position"
CLOCK_ID="0x0000000000000000000000000000000000000000000000000000000000000006"
ASSET_NAME="cetus_lp_position"

echo "Adding Cetus LP Position to Vault..."

sui client call \
  --package "$CORE_PACKAGE" \
  --module vault \
  --function deposit_asset \
  --type-args "$POSITION_TYPE" \
  --args \
    "$VAULT_ID" \
    "$POSITION_ID" \
    "$ASSET_NAME" \
    "$CLOCK_ID" \
  --gas-budget 100000000