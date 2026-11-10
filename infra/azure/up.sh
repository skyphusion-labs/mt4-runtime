#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
set -eu
cd "$(dirname "$0")/../.."
RG=mt4-runtime-build-rg
LOC=eastus
SIZE="${MT4_RUNTIME_VM_SIZE:-Standard_B2ms}"
az group create \
  --name "$RG" \
  --location "$LOC" \
  --tags purpose=mt4-runtime-build ephemeral=true \
  --output none
keydir=$(mktemp -d)
trap 'rm -rf "$keydir"' EXIT
ssh-keygen -t ed25519 -f "$keydir/id" -N "" -q
az deployment group create \
  --resource-group "$RG" \
  --template-file infra/azure/main.bicep \
  --parameters adminSshPublicKey="$(cat "$keydir/id.pub")" vmSize="$SIZE" \
  --output none
echo "deployed $RG in $LOC size $SIZE"
