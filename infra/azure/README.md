# Azure build VM

Short-lived linux/amd64 machine used to build this image and to run the
MetaTrader 4 installer once. It is not a trading desk.

The VM has no public IP and the security group has no inbound allow rules.
Reach it with Azure Run Command (`run-probe.sh`), not SSH from the internet.

`Standard_B2ms` in `eastus` was $0.0832 per hour on 2026-11-10 (Azure retail
prices, Linux, consumption). The OS disk is 64 GB standard SSD. Delete the
group when the run finishes so the disk stops billing.

```sh
infra/azure/up.sh
infra/azure/run-probe.sh
infra/azure/down.sh
```

`down.sh` deletes only the resource group `mt4-runtime-build-rg`.
