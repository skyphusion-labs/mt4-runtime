# SPDX-License-Identifier: Apache-2.0
import os
import runpy
import subprocess
import sys
from pathlib import Path

import pytest

from mt4runtime import __version__
from mt4runtime.__main__ import main
from mt4runtime.policy import (
    DEFAULT_SETUP_URL,
    DEFAULT_SETUP_SHA256,
    SetupUrlError,
    WrongTerminalError,
    find_terminal,
    resolve_setup_sha256,
    validate_setup_url,
    verify_setup_sha256,
)

ROOT = Path(__file__).resolve().parents[1]


def test_version_matches_file():
    assert __version__ == (ROOT / "VERSION").read_text().strip()


def test_default_url_uses_the_measured_pin():
    assert resolve_setup_sha256(DEFAULT_SETUP_URL) == DEFAULT_SETUP_SHA256
    verify_setup_sha256(DEFAULT_SETUP_SHA256, DEFAULT_SETUP_SHA256)


def test_override_sha256_must_be_hex():
    with pytest.raises(SetupUrlError):
        resolve_setup_sha256(DEFAULT_SETUP_URL, "abc")
    pinned = "ab" * 32
    assert resolve_setup_sha256("https://example.com/a.exe", pinned.upper()) == pinned


def test_non_default_url_requires_a_pin():
    with pytest.raises(SetupUrlError):
        resolve_setup_sha256("https://download.mql5.com/other.exe")


def test_verify_sha256_reports_the_actual():
    with pytest.raises(SetupUrlError) as caught:
        verify_setup_sha256("aa" * 32, DEFAULT_SETUP_SHA256)
    assert "aa" * 32 in str(caught.value)


def test_cli_verify_sha(capsys: pytest.CaptureFixture[str]):
    assert main(["verify-sha", "--url", DEFAULT_SETUP_URL, "--actual", DEFAULT_SETUP_SHA256]) == 0
    assert DEFAULT_SETUP_SHA256 in capsys.readouterr().out
    assert main(["verify-sha", "--url", "https://example.com/a.exe", "--actual", "ab" * 32]) == 2


def test_default_url_is_metaquotes_https():
    assert validate_setup_url(DEFAULT_SETUP_URL) == DEFAULT_SETUP_URL
    assert DEFAULT_SETUP_URL.startswith("https://download.mql5.com/")


@pytest.mark.parametrize(
    "url",
    [
        "",
        "   ",
        "http://download.mql5.com/mt4oldsetup.exe",
        "https://user:pass@download.mql5.com/mt4oldsetup.exe",
        "https://evil.example/mt4oldsetup.exe",
        "https://download.mql5.com/mt4oldsetup.exe?token=1",
        "https://download.mql5.com/mt4oldsetup.exe#frag",
        "file:///tmp/mt4oldsetup.exe",
        "https://",
    ],
)
def test_rejects_bad_urls(url):
    with pytest.raises(SetupUrlError):
        validate_setup_url(url)


def test_host_match_is_case_insensitive():
    url = "https://Download.mql5.com/cdn/web/metaquotes.software.corp/mt4/mt4oldsetup.exe"
    assert validate_setup_url(url) == url


def test_unlisted_host_needs_the_flag():
    url = "https://example.com/mt4oldsetup.exe"
    with pytest.raises(SetupUrlError):
        validate_setup_url(url)
    assert validate_setup_url(url, allow_unlisted_host=True) == url


def test_unlisted_flag_still_requires_https():
    with pytest.raises(SetupUrlError):
        validate_setup_url("http://example.com/a.exe", allow_unlisted_host=True)


def test_find_terminal_returns_sorted_first(tmp_path: Path):
    first = tmp_path / "drive_c" / "A" / "terminal.exe"
    second = tmp_path / "drive_c" / "B" / "terminal.exe"
    first.parent.mkdir(parents=True)
    second.parent.mkdir(parents=True)
    first.write_bytes(b"a")
    second.write_bytes(b"b")
    assert find_terminal(str(tmp_path)) == str(first)


def test_find_terminal_ignores_dosdevices_symlink(tmp_path: Path):
    real = tmp_path / "drive_c" / "MetaTrader 4" / "terminal.exe"
    real.parent.mkdir(parents=True)
    real.write_bytes(b"x")
    link_dir = tmp_path / "dosdevices"
    link_dir.mkdir()
    os.symlink(tmp_path / "drive_c", link_dir / "c:", target_is_directory=True)
    found = find_terminal(str(tmp_path))
    assert found == str(real)
    assert "dosdevices" not in found


def test_find_terminal_prefers_terminal_exe(tmp_path: Path):
    folder = tmp_path / "MetaTrader 4"
    folder.mkdir()
    (folder / "terminal64.exe").write_bytes(b"64")
    (folder / "terminal.exe").write_bytes(b"32")
    assert find_terminal(str(tmp_path)).endswith("terminal.exe")


def test_find_terminal_refuses_terminal64_only(tmp_path: Path):
    folder = tmp_path / "MetaTrader 5"
    folder.mkdir()
    target = folder / "terminal64.exe"
    target.write_bytes(b"64")
    with pytest.raises(WrongTerminalError) as caught:
        find_terminal(str(tmp_path))
    assert caught.value.path == str(target)


def test_find_terminal_missing(tmp_path: Path):
    assert find_terminal(str(tmp_path)) is None
    assert find_terminal("") is None
    assert find_terminal("   ") is None
    assert find_terminal(str(tmp_path / "absent")) is None


def test_cli_validate_and_find(tmp_path: Path):
    terminal = tmp_path / "terminal.exe"
    terminal.write_bytes(b"x")
    assert main(["validate-url", "--url", DEFAULT_SETUP_URL]) == 0
    assert main(["validate-url", "--url", "http://download.mql5.com/a.exe"]) == 2
    assert main(["find-terminal", "--prefix", str(tmp_path)]) == 0
    assert main(["find-terminal", "--prefix", str(tmp_path / "nope")]) == 1


def test_cli_refuses_terminal64(tmp_path: Path, capsys: pytest.CaptureFixture[str]):
    folder = tmp_path / "MetaTrader 5"
    folder.mkdir()
    (folder / "terminal64.exe").write_bytes(b"64")
    assert main(["find-terminal", "--prefix", str(tmp_path)]) == 3
    assert "terminal64.exe" in capsys.readouterr().err


def test_cli_requires_a_command():
    with pytest.raises(SystemExit) as caught:
        main([])
    assert caught.value.code == 2


def test_module_entry():
    with pytest.raises(SystemExit) as caught:
        sys.argv = ["mt4runtime", "validate-url", "--url", DEFAULT_SETUP_URL]
        runpy.run_module("mt4runtime", run_name="__main__")
    assert caught.value.code == 0


def _run_install(env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    merged = os.environ.copy()
    merged.pop("PYTHONPATH", None)
    merged.update(env)
    return subprocess.run(
        ["sh", str(ROOT / "scripts" / "install-mt4.sh")],
        cwd=ROOT,
        env=merged,
        text=True,
        capture_output=True,
        check=False,
    )


def test_install_dry_run_does_not_fetch(tmp_path: Path):
    result = _run_install(
        {
            "MT4_DRY_RUN": "1",
            "MT4_SETUP_URL": "https://download.mql5.com/cdn/web/does-not-exist.exe",
            "WINEPREFIX": str(tmp_path / "prefix"),
            "HOME": str(tmp_path),
        }
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == "dry-run https://download.mql5.com/cdn/web/does-not-exist.exe"


def test_install_rejects_http(tmp_path: Path):
    result = _run_install(
        {
            "MT4_SETUP_URL": "http://download.mql5.com/mt4oldsetup.exe",
            "WINEPREFIX": str(tmp_path / "prefix"),
            "HOME": str(tmp_path),
        }
    )
    assert result.returncode == 2
    assert "https" in result.stderr


def test_install_rejects_unlisted_host_without_flag(tmp_path: Path):
    result = _run_install(
        {
            "MT4_DRY_RUN": "1",
            "MT4_SETUP_URL": "https://example.com/mt4oldsetup.exe",
            "WINEPREFIX": str(tmp_path / "prefix"),
            "HOME": str(tmp_path),
        }
    )
    assert result.returncode == 2


def test_install_allows_unlisted_host_when_asked(tmp_path: Path):
    result = _run_install(
        {
            "MT4_DRY_RUN": "1",
            "MT4_ALLOW_UNLISTED_SETUP_HOST": "1",
            "MT4_SETUP_URL": "https://example.com/mt4oldsetup.exe",
            "WINEPREFIX": str(tmp_path / "prefix"),
            "HOME": str(tmp_path),
        }
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout.startswith("dry-run https://example.com/")


def test_install_reports_existing_terminal(tmp_path: Path):
    prefix = tmp_path / "prefix" / "drive_c" / "MetaTrader 4"
    prefix.mkdir(parents=True)
    (prefix / "terminal.exe").write_bytes(b"x")
    result = _run_install(
        {
            "MT4_SETUP_URL": "http://download.mql5.com/should-not-be-fetched.exe",
            "WINEPREFIX": str(tmp_path / "prefix"),
            "HOME": str(tmp_path),
        }
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip().endswith("terminal.exe")
