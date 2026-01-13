#!/bin/bash

CORE_PACKAGE="0xbd990a04d0dc81dbfa1cd14457e6640046fa77981bdd855593f31cb99381cd1c"
CLOCK_ID="0x0000000000000000000000000000000000000000000000000000000000000006"
SENDER=$(sui client active-address)

sui client ptb \
  --move-call "$CORE_PACKAGE::vault::create" \
    '"Name"' \
    '"Desc"' \
    '"Type"' \
    '"https://example.com/image.jpg"' \
    "@$CLOCK_ID" \
  --assign new_vault \
  --transfer-objects "[new_vault]" "@$SENDER" \
  --gas-budget 100000000