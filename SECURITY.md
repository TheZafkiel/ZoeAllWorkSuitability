# Security policy

## Supported version

Security fixes are applied to the latest release on the default branch.

## Reporting a problem

Use a regular GitHub issue only for non-sensitive bugs. For a security vulnerability or a report containing sensitive details, use GitHub private vulnerability reporting when it is available, or contact the repository owner through an already established private channel. Do not publish credentials, server passwords, tokens, private IP addresses, Steam IDs, world saves, or complete logs.

Include only the minimum information needed to reproduce the issue:

- MOD version and package type (`OfficialServer` or `Manual`)
- Palworld dedicated-server version
- UE4SS and PalSchema versions
- Redacted error lines around the failure

## Release integrity

Each release includes `SHA256SUMS.txt`. Verify an archive in PowerShell with:

```powershell
Get-FileHash .\ZoeAllWorkLv10-OfficialServer.zip -Algorithm SHA256
```

Compare the result with the matching line in `SHA256SUMS.txt` before installing.
