# Zoe / GrassBoss All Work Suitability Mod

[中文说明](README.md) · Version 1.1.0 · Palworld 1.0.x Windows dedicated servers

This UE4SS + PalSchema data patch gives the Zoe-related character rows and the `GrassBoss` human NPC configurable base levels for all 13 work suitabilities. The defaults set every level to 10. Because it edits the character DataTables, it can add work types whose original base value was zero.

This is an unofficial community project and is not affiliated with Pocketpair. Back up the world save before first use.

## Default targets

- `DT_PalMonsterParameter`: `GYM_ElecPanda`, `GYM_ElecPanda_2`, `GYM_ElecPanda_Otomo`
- `DT_PalHumanParameter`: `GrassBoss`

Targets and levels can be changed in [`config.json`](config.json).

## Requirements

- A Palworld 1.0.x Windows dedicated server. As of 2026-10-20, Pocketpair's server-mod guide is marked 1.0.4 and only documents server-side MOD support for Windows dedicated servers.
- The currently documented upstream pair is [PalSchema 0.6.71](https://github.com/Okaetsu/PalSchema/releases/tag/0.6.71) with [Okaetsu UE4SS 2281fa31](https://github.com/Okaetsu/RE-UE4SS/releases/tag/2281fa31).
- For any other release, use the exact UE4SS build named in that PalSchema release's notes. Do not mix unmatched versions.

Do not install two separate UE4SS copies. Prefer the official-server package when UE4SS and PalSchema are already installed through Palworld's official mod system.

## Release files

- `ZoeAllWorkLv10-OfficialServer.zip`: recommended official dedicated-server package.
- `ZoeAllWorkLv10-Manual.zip`: for an existing manual UE4SS/PalSchema setup.
- `ZoeAllWorkSuitability-Source.zip`: source snapshot; build it before using `install.ps1`.
- `SHA256SUMS.txt`: integrity hashes for the three archives.

UE4SS, PalSchema, and game assets are not bundled.

## Official-server installation

1. Stop the server and back up its world save.
2. Extract `ZoeAllWorkLv10-OfficialServer.zip`.
3. Copy the extracted `ZoeAllWorkLv10` folder to `<PalServer>\Mods\Workshop\`.
4. Ensure the `[PalModSettings]` section of `<PalServer>\Mods\PalModSettings.ini` contains:

   ```ini
   [PalModSettings]
   bGlobalEnableMod=True
   ActiveModList=UE4SS
   ActiveModList=PalSchema
   ActiveModList=ZoeAllWorkLv10
   ```

5. Start the server. The loader should deploy the patch under `Mods\NativeMods\UE4SS\Mods\PalSchema\mods\ZoeAllWorkLv10`.

## Manual UE4SS/PalSchema installation

Stop the server, extract `ZoeAllWorkLv10-Manual.zip`, and merge its `PalSchema` directory into the UE4SS `Mods` directory. The final files must be under:

```text
<UE4SS Mods>\PalSchema\mods\ZoeAllWorkLv10\raw\
```

Restart the server after installation.

## Build, validate, and install from source

```powershell
.\build.ps1
.\validate.ps1
.\install.ps1 -ServerRoot 'C:\Path\To\PalServer' -Mode Official
```

Use `-Mode Manual` for a manual UE4SS layout. The installer refuses to run while the server process is active, backs up existing settings/packages, and replaces this mod's directory cleanly so obsolete JSON files do not remain.

The validator reads the current `config.json` and checks target tables, rows, all 13 exact values, parity between the two package layouts, and the server installation rule.

## Runtime verification and limitations

After the server starts, search `UE4SS.log` for `PalSchema`, the target table names, and target row names. Then test actual work assignment in a base.

A client without the same data patch may show new work types as disabled or omit them while the server-side behavior is active. Install the same patch on the client only if the details UI must match.

`WorkSuitability_MonsterFarm=10` grants ranch suitability and keeps the default values uniform, but upstream documentation says ranch levels above 1 provide no extra mechanical benefit. Ranch drops need separate Ranch Action/item-lottery data, and this project does not claim that mechanism can be applied directly to the human `GrassBoss` row. Weapon, combat multiplier, and combat-skill data are also outside this project's scope.

## Disable or remove

- Official package: stop the server, remove/comment `ActiveModList=ZoeAllWorkLv10`, move `Mods\Workshop\ZoeAllWorkLv10` out of the server, and restart.
- Manual package: stop the server, move `PalSchema\mods\ZoeAllWorkLv10` out of the UE4SS tree, and restart.
- Use Palworld's official `-NoMods` launch option for temporary all-mod troubleshooting.

This patch does not add a custom save schema. Removing it restores the original base DataTable values after restart.

## Privacy and security

The repository and release packages contain no server logs, saves, Steam IDs, IP addresses, credentials, tokens, cookies, or machine-specific paths. There is no telemetry, network upload, or credential-reading code. See [`PRIVACY.md`](PRIVACY.md) and [`SECURITY.md`](SECURITY.md).

Technical notes and upstream references are in [`docs/technical-basis.md`](docs/technical-basis.md). The data structure was last manually checked on 2026-09-01; revalidate after game, UE4SS, or PalSchema updates.
