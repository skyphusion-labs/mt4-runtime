# seccomp/wine.json

Docker's default seccomp profile, plus two allows:

- `clone3` is allowed. The default returns ENOSYS (errno 38) so glibc
  can fall back. Wine treats that errno as fatal.
- `socket` is allowed for address family 38 (`AF_ALG`). The default
  skips that family. Wine's socket call then exits with
  `Function not implemented`.

The base is moby `profiles` `seccomp/default.json` on the `main`
branch, copied 2026-11-10. Everything else in that profile is unchanged.

`docker compose` and the install CI step pass this file. Do not use
`seccomp=unconfined`.
