#!/bin/bash

# Script to assess container images using CrowdStrike Falcon Cloud Security CLI

FALCON_API_URL="https://api.{$FALCON_REGION}.crowdstrike.com"

set -e

# Check required tools
for cmd in curl jq sha256sum; do
	if ! command -v $cmd &>/dev/null; then
		echo "Error: $cmd is required but not installed."
		exit 1
	fi
done

# Get auth token
echo "Retrieving CrowdStrike Falcon access token..."
FALCON_ACCESS_TOKEN=$(curl --silent --request POST \
	--header "Content-Type: application/x-www-form-urlencoded" \
	--data-urlencode "client_id=${FALCON_CLIENT_ID}" \
	--data-urlencode "client_secret=${FALCON_CLIENT_SECRET}" \
	--url "${FALCON_API_URL}/oauth2/token" | jq -r '.access_token')

if [ -z "$FALCON_ACCESS_TOKEN" ] || [ "$FALCON_ACCESS_TOKEN" == "null" ]; then
	echo "Error: Failed to retrieve access token."
	exit 1
fi

# Download FCS CLI
FCS_FILENAME="fcs_${FCS_VERSION}_Linux_x86_64.tar.gz"
echo "Requesting download link for FCS CLI..."
DOWNLOAD_INFO=$(curl --silent --request GET \
	--header "Authorization: Bearer ${FALCON_ACCESS_TOKEN}" \
	--url "${FALCON_API_URL}/csdownloads/entities/files/download/v1?file_name=${FCS_FILENAME}&file_version=${FCS_VERSION}" | jq '.resources | {download_url, file_hash}')

FCS_CLI_LINK=$(echo "$DOWNLOAD_INFO" | jq -r '.download_url')
EXPECTED_HASH=$(echo "$DOWNLOAD_INFO" | jq -r '.file_hash')

echo "Downloading FCS CLI..."
curl --silent --location --output ${FCS_FILENAME} ${FCS_CLI_LINK}

echo "Verifying file hash..."
DOWNLOADED_HASH=$(sha256sum ${FCS_FILENAME} | awk '{print $1}')
if [ "$DOWNLOADED_HASH" != "$EXPECTED_HASH" ]; then
	echo "Error: Downloaded file hash does not match expected hash."
	exit 1
fi

echo "Extracting FCS CLI..."
tar -xzf ${FCS_FILENAME}
chmod +x fcs

# Configuring the profile
./fcs configure --client-id $FALCON_CLIENT_ID --client-secret $FALCON_CLIENT_SECRET --falcon-region $FALCON_REGION

# Scan the image
echo "Scanning image: ${IMAGE_NAME}"
./fcs scan image "${IMAGE_NAME}" --upload --no-color # --show-full-description  --show-full-detection-details

rm ~/.crowdstrike/fcs.json