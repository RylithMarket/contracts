#!/bin/bash

set -e

echo "Publishing package..."
PUBLISH_OUTPUT=$(sui client publish --gas-budget 100000000 --json)
echo "Publish complete, extracting package ID..."

PACKAGE_ID=$(echo "$PUBLISH_OUTPUT" | jq -r '.objectChanges[] | select(.type == "published") | .packageId')

if [ -z "$PACKAGE_ID" ] || [ "$PACKAGE_ID" == "null" ]; then
    echo "Failed to extract package ID. Publish output:"
    echo "$PUBLISH_OUTPUT" | jq .
    exit 1
fi

echo "Published package: $PACKAGE_ID"

sui client call --package "$PACKAGE_ID" --module venue --function setup_rylith_market --gas-budget 100000000
