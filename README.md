# XerionUI

Personal quality-of-life and tweak suite for World of Warcraft: Midnight — one framework, one settings window and one shared style system for every feature.

## Install

**WowUp:** Get Addons → Install from URL → `https://github.com/nicklasmp/xerionui`. WowUp then follows new releases automatically (see *Releasing* below).

**Manually:** copy both folders into `World of Warcraft/_retail_/Interface/AddOns/`:

- `XerionUI` — the addon
- `XerionUI_Options` — the settings window (loads the first time you open it)

The old `XerionUI-Plugin` can stay installed while features are being ported; both have separate saved variables. While both are installed, use `/xerionui` (the old addon also claims `/xui`).

## Releasing

Push a tag and GitHub Actions builds `XerionUI-<tag>.zip` (both addon folders) and publishes it as a release:

```
git tag v2.0.1
git push origin v2.0.1
```

The workflow stamps the tag into `## Version:` of `XerionUI.toc`. The repository must stay public for WowUp to read it.

## Commands

| Command | |
|---|---|
| `/xui` or `/xerionui` | open the settings |
| `/xui unlock` | move frames (uses EllesmereUI's unlock mode when installed) |
| `/xui profile <name>` | switch profile |
| `/xui preview off` | end all module previews |
| `/xui version` | installed version |

## Repository

| Path | |
|---|---|
| `XerionUI/` | core addon (framework, style engine, movers, modules) |
| `XerionUI_Options/` | load-on-demand settings window |
| `docs/ANALYSE.md` | review of the old v1.20 and why the core was rebuilt (Danish) |
| `docs/ARCHITECTURE.md` | how the addon is built and how to write a module |
| `docs/PORTERING.md` | feature inventory and porting plan (Danish) |
| `legacy/` | the untouched v1.20, kept as porting reference |
| `tools/` | lint, texture generator and the mocked-client test harness |

## Development

```
cd tools
npm install
npm test        # load both addons in a mocked client and drive every control
npm run shots   # render the options pages to tools/harness/out/*.html
npm run lint    # Lua syntax + accidental globals
```

Credits: some features are ported from ItruliaQoL by Itrulia (MIT licence).
