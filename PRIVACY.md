# Privacy

ZoeAllWorkSuitability is an offline data-patch project.

- It contains no telemetry, analytics, advertising, remote API calls, or upload code.
- It does not request or read Steam credentials, server passwords, API tokens, cookies, or account data.
- It does not read world saves or player profiles.
- `build.ps1` reads this repository and writes only the local `dist` directory.
- `validate.ps1` reads `config.json` and generated files under `dist`.
- `install.ps1` reads the server path supplied by the operator, checks whether the server is running, copies only this MOD, and creates local backups before changes.

Do not attach raw server logs, save files, configuration files containing passwords, or full server directories to an issue. Redact IP addresses, Steam IDs, account identifiers, access tokens, and local user paths before sharing diagnostics.
