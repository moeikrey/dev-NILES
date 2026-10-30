# nixos

Noah's NixOS config. niri (Wayland compositor) + noctalia on an AMD/NVIDIA
desktop, dual-booting CachyOS via Limine on a shared ESP and a separate
`@nixos-home` subvolume on the `NIX` drive.

The root `flake.nix` is a **template registry only**. Each top-level folder is
a self-contained flake and is the thing actually built — currently just
[`desktop/`](desktop/README.md).

## Quick start

```bash
just rebuild        # format, build, switch, commit  (desktop/rebuild.sh)
just build          # build without activating
just vm             # build and run the test VM
just up             # update flake inputs
just                # list everything else
```

## Docs

| | |
|---|---|
| [desktop/README.md](desktop/README.md) | Module-by-module tour of the desktop config |
| [docs/getting_started.md](docs/getting_started.md) | Adapting this config to a new machine, plus gotchas |
| [docs/adr/](docs/adr/) | Design decisions — e.g. the [two-commit rebuild protocol](docs/adr/0001-two-commit-rebuild-protocol.md) |
| [CLAUDE.md](CLAUDE.md) | Agent-facing notes on layout and conventions |

## License

[MIT](LICENSE). Forked from vimjoyer's flake-starter-config.
