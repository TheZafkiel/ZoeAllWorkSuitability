[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'config.json')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$Suitabilities = @(
    'EmitFlame',
    'Watering',
    'Seeding',
    'GenerateElectricity',
    'Handcraft',
    'Collection',
    'Deforest',
    'Mining',
    'OilExtraction',
    'ProductMedicine',
    'Cool',
    'Transport',
    'MonsterFarm'
)
$AllowedTables = @('DT_PalMonsterParameter', 'DT_PalHumanParameter')

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "Config file not found: $ConfigPath"
}
$Config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$PackageName = [string]$Config.packageName
if ([string]::IsNullOrWhiteSpace($PackageName) -or $PackageName -notmatch '^[A-Za-z0-9]+$') {
    throw 'packageName must contain only A-Z, a-z, and 0-9.'
}

$TargetTables = @($Config.targets.PSObject.Properties.Name)
if ($TargetTables.Count -eq 0) {
    throw 'targets must contain at least one supported DataTable.'
}
foreach ($TargetTable in $TargetTables) {
    if ($TargetTable -notin $AllowedTables) {
        throw "Unsupported target table: $TargetTable"
    }
}

$ConfiguredNames = @($Config.levels.PSObject.Properties.Name)
$UnknownNames = @($ConfiguredNames | Where-Object { $_ -notin $Suitabilities })
$MissingNames = @($Suitabilities | Where-Object { $_ -notin $ConfiguredNames })
if ($UnknownNames.Count -gt 0) {
    throw "Unknown work suitability name(s): $($UnknownNames -join ', ')"
}
if ($MissingNames.Count -gt 0) {
    throw "Missing work suitability name(s): $($MissingNames -join ', ')"
}

$OfficialPackage = Join-Path $PSScriptRoot "dist\$PackageName-OfficialServer\$PackageName"
$ManualPackage = Join-Path $PSScriptRoot "dist\$PackageName-Manual\PalSchema\mods\$PackageName"
$InfoPath = Join-Path $OfficialPackage 'Info.json'
if (-not (Test-Path -LiteralPath $InfoPath -PathType Leaf)) {
    throw "Missing build output: $InfoPath"
}

$Info = Get-Content -LiteralPath $InfoPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($Info.PackageName -ne $PackageName) {
    throw "Unexpected PackageName: $($Info.PackageName)"
}
if ($Info.Version -ne [string]$Config.version) {
    throw "Info.json version '$($Info.Version)' does not match config '$($Config.version)'."
}
if ($Info.Author -ne [string]$Config.author) {
    throw 'Info.json author does not match config.json.'
}
$ServerRule = @($Info.InstallRule | Where-Object {
    $_.Type -eq 'PalSchema' -and
    $null -ne $_.PSObject.Properties['IsServer'] -and
    $_.IsServer -eq $true
})
if ($ServerRule.Count -ne 1) {
    throw 'Info.json must contain exactly one server-side PalSchema InstallRule.'
}
if (@($Info.Dependencies) -notcontains 'UE4SS' -or @($Info.Dependencies) -notcontains 'PalSchema') {
    throw 'Info.json is missing UE4SS or PalSchema dependency metadata.'
}

$ExpectedTableFiles = @($TargetTables | ForEach-Object { "$_.json" })
$TotalRows = 0
foreach ($Variant in @(
    [ordered]@{ Name = 'official'; RawRoot = (Join-Path $OfficialPackage 'PalSchema\raw') },
    [ordered]@{ Name = 'manual'; RawRoot = (Join-Path $ManualPackage 'raw') }
)) {
    if (-not (Test-Path -LiteralPath $Variant.RawRoot -PathType Container)) {
        throw "Missing $($Variant.Name) raw directory: $($Variant.RawRoot)"
    }
    $ActualTableFiles = @(Get-ChildItem -LiteralPath $Variant.RawRoot -File -Filter '*.json' | Select-Object -ExpandProperty Name)
    if (@(Compare-Object -ReferenceObject $ExpectedTableFiles -DifferenceObject $ActualTableFiles).Count -ne 0) {
        throw "Unexpected $($Variant.Name) DataTable files: $($ActualTableFiles -join ', ')"
    }

    foreach ($TargetTable in $TargetTables) {
        $RawPath = Join-Path $Variant.RawRoot "$TargetTable.json"
        $Raw = Get-Content -LiteralPath $RawPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $Rows = $Raw.$TargetTable
        if ($null -eq $Rows) {
            throw "$RawPath does not contain $TargetTable."
        }

        $ExpectedRows = @($Config.targets.$TargetTable)
        $ActualRows = @($Rows.PSObject.Properties.Name)
        if (@(Compare-Object -ReferenceObject $ExpectedRows -DifferenceObject $ActualRows).Count -ne 0) {
            throw "Unexpected target rows in $($Variant.Name) ${TargetTable}: $($ActualRows -join ', ')"
        }

        foreach ($RowName in $ExpectedRows) {
            $Row = $Rows.$RowName
            $ExpectedFields = @($Suitabilities | ForEach-Object { "WorkSuitability_$_" })
            $ActualFields = @($Row.PSObject.Properties.Name)
            if (@(Compare-Object -ReferenceObject $ExpectedFields -DifferenceObject $ActualFields).Count -ne 0) {
                throw "Unexpected fields in $($Variant.Name) $TargetTable.$RowName"
            }

            foreach ($Suitability in $Suitabilities) {
                $Field = "WorkSuitability_$Suitability"
                $ExpectedValue = $Config.levels.$Suitability
                $ActualValue = $Row.$Field
                if (($ActualValue -isnot [int] -and $ActualValue -isnot [long]) -or $ActualValue -ne $ExpectedValue) {
                    throw "$($Variant.Name) $TargetTable.$RowName.$Field is '$ActualValue'; expected '$ExpectedValue'."
                }
            }
        }
        if ($Variant.Name -eq 'official') {
            $TotalRows += $ActualRows.Count
        }
    }
}

Write-Host 'Validation passed.'
Write-Host "Package: $PackageName $($Config.version)"
Write-Host "Tables: $($TargetTables.Count); rows: $TotalRows; fields per row: $($Suitabilities.Count)."
Write-Host 'Official and manual payloads match config.json; server InstallRule is present.'
