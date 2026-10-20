[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ServerRoot,

    [ValidateSet('Official', 'Manual')]
    [string]$Mode = 'Official',

    [string]$ConfigPath = (Join-Path $PSScriptRoot 'config.json')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

function Install-CleanDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][string]$Timestamp
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        throw "Built package not found: $Source. Run .\build.ps1 first."
    }

    $Parent = Split-Path -Parent $Destination
    $Leaf = Split-Path -Leaf $Destination
    New-Item -ItemType Directory -Force -Path $Parent | Out-Null
    $Staging = Join-Path $Parent ".$Leaf.new-$Timestamp"
    if (Test-Path -LiteralPath $Staging) {
        throw "Temporary installation path already exists: $Staging"
    }

    New-Item -ItemType Directory -Path $Staging | Out-Null
    try {
        foreach ($Item in @(Get-ChildItem -LiteralPath $Source -Force)) {
            Copy-Item -LiteralPath $Item.FullName -Destination $Staging -Recurse -Force
        }

        $Backup = $null
        if (Test-Path -LiteralPath $Destination) {
            $Backup = "$Destination.bak-$Timestamp"
            if (Test-Path -LiteralPath $Backup) {
                throw "Backup path already exists: $Backup"
            }
            Move-Item -LiteralPath $Destination -Destination $Backup
        }

        try {
            Move-Item -LiteralPath $Staging -Destination $Destination
        } catch {
            if ($Backup -and -not (Test-Path -LiteralPath $Destination) -and (Test-Path -LiteralPath $Backup)) {
                Move-Item -LiteralPath $Backup -Destination $Destination
            }
            throw
        }

        return $Backup
    } finally {
        if (Test-Path -LiteralPath $Staging) {
            Remove-Item -LiteralPath $Staging -Recurse -Force
        }
    }
}

function Enable-OfficialPackages {
    param(
        [Parameter(Mandatory = $true)][string]$SettingsPath,
        [Parameter(Mandatory = $true)][string[]]$Packages
    )

    $Lines = [System.Collections.Generic.List[string]](Get-Content -LiteralPath $SettingsPath -Encoding UTF8)
    $SectionStart = -1
    for ($Index = 0; $Index -lt $Lines.Count; $Index++) {
        if ($Lines[$Index] -match '^\s*\[PalModSettings\]\s*$') {
            $SectionStart = $Index
            break
        }
    }
    if ($SectionStart -lt 0) {
        if ($Lines.Count -gt 0 -and $Lines[$Lines.Count - 1] -ne '') {
            $Lines.Add('')
        }
        $Lines.Add('[PalModSettings]')
        $SectionStart = $Lines.Count - 1
    }

    $SectionEnd = $Lines.Count
    for ($Index = $SectionStart + 1; $Index -lt $Lines.Count; $Index++) {
        if ($Lines[$Index] -match '^\s*\[[^]]+\]\s*$') {
            $SectionEnd = $Index
            break
        }
    }

    $GlobalFound = $false
    for ($Index = $SectionStart + 1; $Index -lt $SectionEnd; $Index++) {
        if ($Lines[$Index] -match '^\s*bGlobalEnableMod\s*=') {
            $Lines[$Index] = 'bGlobalEnableMod=True'
            $GlobalFound = $true
        }
    }
    if (-not $GlobalFound) {
        $Lines.Insert($SectionEnd, 'bGlobalEnableMod=True')
        $SectionEnd++
    }

    foreach ($RequiredPackage in $Packages) {
        $Pattern = '^\s*ActiveModList\s*=\s*' + [regex]::Escape($RequiredPackage) + '\s*$'
        $Found = $false
        for ($Index = $SectionStart + 1; $Index -lt $SectionEnd; $Index++) {
            if ($Lines[$Index] -match $Pattern) {
                $Found = $true
                break
            }
        }
        if (-not $Found) {
            $Lines.Insert($SectionEnd, "ActiveModList=$RequiredPackage")
            $SectionEnd++
        }
    }

    [System.IO.File]::WriteAllLines($SettingsPath, $Lines, (New-Object System.Text.UTF8Encoding($false)))
}

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "Config file not found: $ConfigPath"
}
$Config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$PackageName = [string]$Config.packageName
if ([string]::IsNullOrWhiteSpace($PackageName) -or $PackageName -notmatch '^[A-Za-z0-9]+$') {
    throw 'packageName must contain only A-Z, a-z, and 0-9.'
}

$ResolvedServerRoot = [System.IO.Path]::GetFullPath($ServerRoot)
$ServerExe = Join-Path $ResolvedServerRoot 'PalServer.exe'
$ServerBinary = Join-Path $ResolvedServerRoot 'Pal\Binaries\Win64\PalServer-Win64-Shipping-Cmd.exe'
if (-not (Test-Path -LiteralPath $ServerExe -PathType Leaf) -and -not (Test-Path -LiteralPath $ServerBinary -PathType Leaf)) {
    throw "The selected directory does not look like a Palworld dedicated-server root: $ResolvedServerRoot"
}

$Running = Get-Process -Name 'PalServer-Win64-Shipping-Cmd', 'PalServer-Win64-Test', 'PalServer' -ErrorAction SilentlyContinue
if ($Running) {
    throw 'Stop the Palworld dedicated server before installing this mod.'
}

$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
if ($Mode -eq 'Official') {
    $Source = Join-Path $PSScriptRoot "dist\$PackageName-OfficialServer\$PackageName"
    $Destination = Join-Path $ResolvedServerRoot "Mods\Workshop\$PackageName"
    $SettingsPath = Join-Path $ResolvedServerRoot 'Mods\PalModSettings.ini'

    if (-not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) {
        throw "Missing $SettingsPath. Launch the server once so PalModSettings.ini is generated, then stop it and retry."
    }

    $PackageBackup = Install-CleanDirectory -Source $Source -Destination $Destination -Timestamp $Timestamp
    $SettingsBackup = "$SettingsPath.bak-$Timestamp"
    Copy-Item -LiteralPath $SettingsPath -Destination $SettingsBackup -Force
    Enable-OfficialPackages -SettingsPath $SettingsPath -Packages @('UE4SS', 'PalSchema', $PackageName)

    Write-Host "Installed official package to: $Destination"
    Write-Host "Backed up settings to: $SettingsBackup"
    if ($PackageBackup) {
        Write-Host "Backed up previous package to: $PackageBackup"
    }
} else {
    $Source = Join-Path $PSScriptRoot "dist\$PackageName-Manual\PalSchema\mods\$PackageName"
    $WorkshopPalSchema = Join-Path $ResolvedServerRoot 'Mods\NativeMods\UE4SS\Mods\PalSchema'
    $ExternalPalSchema = Join-Path $ResolvedServerRoot 'Pal\Binaries\Win64\ue4ss\Mods\PalSchema'

    if (Test-Path -LiteralPath $WorkshopPalSchema -PathType Container) {
        $PalSchemaRoot = $WorkshopPalSchema
    } elseif (Test-Path -LiteralPath $ExternalPalSchema -PathType Container) {
        $PalSchemaRoot = $ExternalPalSchema
    } else {
        throw 'PalSchema was not found in the official-loader or manual UE4SS location.'
    }

    $Destination = Join-Path $PalSchemaRoot "mods\$PackageName"
    $PackageBackup = Install-CleanDirectory -Source $Source -Destination $Destination -Timestamp $Timestamp
    Write-Host "Installed manual package to: $Destination"
    if ($PackageBackup) {
        Write-Host "Backed up previous package to: $PackageBackup"
    }
}

Write-Host 'Start the server and inspect the PalSchema/UE4SS log for the configured rows and zero errors.'
