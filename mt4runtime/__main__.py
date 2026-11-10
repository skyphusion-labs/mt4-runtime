# SPDX-License-Identifier: Apache-2.0
"""Command line used by the image scripts."""

from __future__ import annotations

import argparse
import sys

from mt4runtime.policy import (
    SetupUrlError,
    WrongTerminalError,
    find_terminal,
    resolve_setup_sha256,
    validate_setup_url,
    verify_setup_sha256,
)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="mt4runtime")
    sub = parser.add_subparsers(dest="cmd", required=True)

    validate = sub.add_parser("validate-url")
    validate.add_argument("--url", required=True)
    validate.add_argument("--allow-unlisted", action="store_true")

    find = sub.add_parser("find-terminal")
    find.add_argument("--prefix", required=True)

    verify = sub.add_parser("verify-sha")
    verify.add_argument("--url", required=True)
    verify.add_argument("--actual", required=True)
    verify.add_argument("--override", default="")

    args = parser.parse_args(argv)
    if args.cmd == "validate-url":
        try:
            print(validate_setup_url(args.url, allow_unlisted_host=args.allow_unlisted))
        except SetupUrlError as exc:
            print(str(exc), file=sys.stderr)
            return 2
        return 0

    if args.cmd == "verify-sha":
        try:
            expected = resolve_setup_sha256(args.url, args.override)
            verify_setup_sha256(args.actual, expected)
        except SetupUrlError as exc:
            print(str(exc), file=sys.stderr)
            return 2
        print(expected)
        return 0

    try:
        path = find_terminal(args.prefix)
    except WrongTerminalError as exc:
        print(f"refusing {exc.path}", file=sys.stderr)
        return 3
    if path is None:
        print("terminal.exe not found", file=sys.stderr)
        return 1
    print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
