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

# Get the Publisher object ID from the user's objects
PUBLISHER_ID=$(sui client objects --json 2>/dev/null | jq -r '.[] | select(.objectType | contains("package::Publisher")) | .objectId' | tail -1)

if [ -z "$PUBLISHER_ID" ] || [ "$PUBLISHER_ID" == "null" ]; then
    echo "Failed to find Publisher object. Please run: sui client objects"
    exit 1
fi

echo "Using Publisher: $PUBLISHER_ID"
sui client call --package "$PACKAGE_ID" --module venue --function setup_rylith_market --args "$PUBLISHER_ID" --gas-budget 100000000
