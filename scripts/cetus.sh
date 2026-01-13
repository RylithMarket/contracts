#!/bin/bash

# --- CONFIGURATION ---
CETUS_PACKAGE="0x6bbdf09f9fa0baa1524080a5b8991042e95061c4e1206217279aec51ba08edf7"
CETUS_CONFIG="0xc6273f844b4bc258952c4e477697aa12c918c8e08106fac6b934811298c9820a"
CETUS_POOLS="0x20a086e6fa0741b3ca77d033a65faf0871349b986ddbdde6fa1d85d78a5f4222"
CLOCK_ID="0x0000000000000000000000000000000000000000000000000000000000000006"

# ĐẢO NGƯỢC: USDC (A) có địa chỉ lớn hơn, SUI (B) có địa chỉ nhỏ hơn
USDC_TYPE="0xa1ec7fc00a6f40db9693ad1415d0c193ad3906494428cf252621037bd7117e29::usdc::USDC"
SUI_TYPE="0x2::sui::SUI"

USDC_SOURCE_OBJECT="0xadb96ce6cce5e758a73462ee0ca83e92378c39d0c4d30a3a922f8b7115ca8948"
MY_ADDRESS=$(sui client active-address)

AMOUNT_SUI="100000000"
AMOUNT_USDC="100000"

# LƯU Ý: Khi đảo cặp tiền, INIT_PRICE có thể cần tính toán lại (1/giá cũ) 
# nhưng hãy thử chạy với giá hiện tại trước để xem qua được bước tạo Pool không.
INIT_PRICE="24044843428342308823" 

TICK_LOWER="4294523696" # -443600
TICK_UPPER="443600"

echo "Creating Cetus Pool V3: USDC (A) - SUI (B) to satisfy address order..."

sui client ptb \
  --split-coins "@$USDC_SOURCE_OBJECT" "[$AMOUNT_USDC]" \
  --assign coin_a \
  --split-coins gas "[$AMOUNT_SUI]" \
  --assign coin_b \
  --move-call "${CETUS_PACKAGE}::pool_creator::create_pool_v3<${USDC_TYPE}, ${SUI_TYPE}>" \
    "@${CETUS_CONFIG}" \
    "@${CETUS_POOLS}" \
    200 \
    "${INIT_PRICE}" \
    '""' \
    "${TICK_LOWER}" \
    "${TICK_UPPER}" \
    coin_a \
    coin_b \
    true \
    "@${CLOCK_ID}" \
  --assign pool_results \
  --transfer-objects "[pool_results.0, pool_results.1, pool_results.2]" "@${MY_ADDRESS}" \
  --gas-budget 500000000