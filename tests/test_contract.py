# SPDX-License-Identifier: Apache-2.0
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SHELLS = (
    "entrypoint.sh",
    "scripts/install-mt4.sh",
    "scripts/healthcheck.sh",
    "scripts/smoke.sh",
    "infra/azure/up.sh",
    "infra/azure/down.sh",
    "infra/azure/probe.sh",
    "infra/azure/run-probe.sh",
)


def test_shell_syntax():
    for rel in SHELLS:
        subprocess.run(["sh", "-n", str(ROOT / rel)], check=True)


def test_version_is_one_string():
    version = (ROOT / "VERSION").read_text().strip()
    assert version.count(".") == 2
    pyproject = (ROOT / "pyproject.toml").read_text()
    dockerfile = (ROOT / "Dockerfile").read_text()
    changelog = (ROOT / "CHANGELOG.md").read_text()
    assert f'version = "{version}"' in pyproject
    assert f"ARG VERSION={version}" in dockerfile
    assert f"## {version}" in changelog


def test_image_does_not_vendor_the_terminal():
    dockerfile = (ROOT / "Dockerfile").read_text().lower()
    assert "winehq-stable" in dockerfile
    assert "cloudflared" in dockerfile
    for banned in ("mt4oldsetup", "mt4setup.exe", "terminal.exe", "mql5.com"):
        assert banned not in dockerfile


def test_cloudflared_pin_is_a_sha256():
    dockerfile = (ROOT / "Dockerfile").read_text()
    assert "ARG CLOUDFLARED_VERSION=2026.10.7" in dockerfile
    assert (
        "ARG CLOUDFLARED_SHA256="
        "1f99fb518b83dec2ba8d870a7cc991d82a77e6196295a3d2754ba17ab9f91872"
    ) in dockerfile


def test_entrypoint_does_not_print_the_tunnel_token():
    text = (ROOT / "entrypoint.sh").read_text()
    assert "unset CLOUDFLARE_TUNNEL_TOKEN" in text
    assert 'echo "$CLOUDFLARE_TUNNEL_TOKEN"' not in text
    assert "echo $CLOUDFLARE_TUNNEL_TOKEN" not in text
    assert "printenv" not in text


def test_azure_vm_has_no_public_ip_and_no_ssh_rule():
    bicep = (ROOT / "infra" / "azure" / "main.bicep").read_text()
    assert "publicIPAddresses" not in bicep
    assert "destinationPortRange" not in bicep
    assert "Standard_B2ms" in bicep
    assert "disablePasswordAuthentication: true" in bicep


def test_no_secret_markers_or_dashes():
    needles = (
        "gh" + "p_",
        "github_" + "pat_",
        "BEGIN OPENSSH " + "PRIVATE KEY",
        "BEGIN RSA " + "PRIVATE KEY",
        "AK" + "IA",
    )
    dashes = (b"\xe2\x80\x94", b"\xe2\x80\x93")
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        if any(part in path.parts for part in (".git", "__pycache__", ".pytest_cache", ".venv")):
            continue
        data = path.read_bytes()
        text = data.decode("utf-8", errors="replace")
        for needle in needles:
            assert needle not in text, f"{needle} in {path}"
        for dash in dashes:
            assert dash not in data, f"dash in {path}"
