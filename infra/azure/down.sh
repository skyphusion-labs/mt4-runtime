#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
set -eu
az group delete --name mt4-runtime-build-rg --yes --no-wait
echo "delete requested for mt4-runtime-build-rg"
