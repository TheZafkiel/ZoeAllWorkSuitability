[CmdletBinding()]
param(
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $PSScriptRoot 'config.json'
}

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

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Config file not found: $Path"
    }

    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $Parent = Split-Path -Parent $Path
    if ($Parent) {
        New-Item -ItemType Directory -Force -Path $Parent | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
}

$Config = Read-JsonFile -Path $ConfigPath

if ([string]::IsNullOrWhiteSpace([string]$Config.packageName) -or $Config.packageName -notmatch '^[A-Za-z0-9]+$') {
    throw 'packageName must contain only A-Z, a-z, and 0-9.'
}
if ([string]::IsNullOrWhiteSpace([string]$Config.version)) {
    throw 'version cannot be empty.'
}
$AllowedTables = @('DT_PalMonsterParameter', 'DT_PalHumanParameter')
$TargetTables = @($Config.targets.PSObject.Properties.Name)
if ($TargetTables.Count -eq 0) {
    throw 'targets must contain at least one supported DataTable.'
}
foreach ($TargetTable in $TargetTables) {
    if ($TargetTable -notin $AllowedTables) {
        throw "Unsupported target table: $TargetTable"
    }
    $TargetRows = @($Config.targets.$TargetTable)
    if ($TargetRows.Count -eq 0) {
        throw "$TargetTable must contain at least one Palworld row name."
    }
    foreach ($TargetRow in $TargetRows) {
        if ([string]::IsNullOrWhiteSpace([string]$TargetRow) -or $TargetRow -notmatch '^[A-Za-z0-9_]+$') {
            throw "Invalid target row in ${TargetTable}: $TargetRow"
        }
    }
    if (@($TargetRows | Select-Object -Unique).Count -ne $TargetRows.Count) {
        throw "$TargetTable contains duplicate row names."
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

$RowPatch = [ordered]@{}
foreach ($Suitability in $Suitabilities) {
    $Value = $Config.levels.$Suitability
    if ($Value -isnot [int] -and $Value -isnot [long]) {
        throw "$Suitability must be an integer from 0 through 10."
    }
    if ($Value -lt 0 -or $Value -gt 10) {
        throw "$Suitability is $Value; the supported configuration range is 0 through 10."
    }
    $RowPatch["WorkSuitability_$Suitability"] = [int]$Value
}

$PackageName = [string]$Config.packageName
$DistRoot = Join-Path $PSScriptRoot 'dist'
$OfficialRoot = Join-Path $DistRoot "$PackageName-OfficialServer"
$OfficialPackage = Join-Path $OfficialRoot $PackageName
$ManualRoot = Join-Path $DistRoot "$PackageName-Manual"
$OfficialRawRoot = Join-Path $OfficialPackage 'PalSchema\raw'
$ManualRawRoot = Join-Path $ManualRoot "PalSchema\mods\$PackageName\raw"

$ResolvedDist = [System.IO.Path]::GetFullPath($DistRoot)
$ResolvedProject = [System.IO.Path]::GetFullPath($PSScriptRoot)
if (-not $ResolvedDist.StartsWith($ResolvedProject, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Refusing to clean a dist directory outside this project.'
}
if (Test-Path -LiteralPath $DistRoot) {
    Remove-Item -LiteralPath $DistRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $OfficialPackage, $ManualRoot | Out-Null

foreach ($TargetTable in $TargetTables) {
    $Rows = [ordered]@{}
    foreach ($TargetRow in @($Config.targets.$TargetTable)) {
        $Copy = [ordered]@{}
        foreach ($Property in $RowPatch.GetEnumerator()) {
            $Copy[$Property.Key] = $Property.Value
        }
        $Rows[[string]$TargetRow] = $Copy
    }
    $RawPatch = [ordered]@{}
    $RawPatch[$TargetTable] = $Rows
    $RawJson = $RawPatch | ConvertTo-Json -Depth 8
    Write-Utf8NoBom -Path (Join-Path $OfficialRawRoot "$TargetTable.json") -Content ($RawJson + [Environment]::NewLine)
    Write-Utf8NoBom -Path (Join-Path $ManualRawRoot "$TargetTable.json") -Content ($RawJson + [Environment]::NewLine)
}

$InstallRules = @(
    [ordered]@{
        Type = 'PalSchema'
        Targets = @('./PalSchema/')
    },
    [ordered]@{
        Type = 'PalSchema'
        IsServer = $true
        Targets = @('./PalSchema/')
    }
)
$Info = [ordered]@{
    ModName = [string]$Config.modName
    PackageName = $PackageName
    Version = [string]$Config.version
    DebugMode = [bool]$Config.debugMode
    Author = [string]$Config.author
    Dependencies = @('UE4SS', 'PalSchema')
    Tags = @('PalSchema', 'Gameplay')
    InstallRule = $InstallRules
}
$InfoJson = $Info | ConvertTo-Json -Depth 8
Write-Utf8NoBom -Path (Join-Path $OfficialPackage 'Info.json') -Content ($InfoJson + [Environment]::NewLine)

$OfficialNoteCn = @"
佐伊／GrassBoss 全工作适应性 - 官方专用服务器包

1. 停止 Windows 专用服务器并备份世界存档。
2. 将 '$PackageName' 文件夹复制到 <PalServer>\Mods\Workshop\。
3. 在 <PalServer>\Mods\PalModSettings.ini 的 [PalModSettings] 段启用：
   bGlobalEnableMod=True
   ActiveModList=UE4SS
   ActiveModList=PalSchema
   ActiveModList=$PackageName
4. 启动服务器。官方加载器会将数据部署到
   Mods\NativeMods\UE4SS\Mods\PalSchema\mods\$PackageName。

依赖：兼容 Palworld 1.0.x 的 Windows 专用服务器、UE4SS 和 PalSchema。
完整说明、禁用方法与故障排查请查看项目 README.md。
"@
$OfficialNoteEn = @"
Zoe / GrassBoss All Work Suitability - official dedicated-server package

1. Stop the Windows dedicated server and back up the world save.
2. Copy the '$PackageName' folder into <PalServer>\Mods\Workshop\.
3. In the [PalModSettings] section of <PalServer>\Mods\PalModSettings.ini enable:
   bGlobalEnableMod=True
   ActiveModList=UE4SS
   ActiveModList=PalSchema
   ActiveModList=$PackageName
4. Start the server. The official loader deploys the data under
   Mods\NativeMods\UE4SS\Mods\PalSchema\mods\$PackageName.

Requires a compatible Palworld 1.0.x Windows dedicated server, UE4SS, and PalSchema.
See the repository README.md for full instructions, removal, and troubleshooting.
"@
Write-Utf8NoBom -Path (Join-Path $OfficialPackage 'README_INSTALL_CN.txt') -Content $OfficialNoteCn
Write-Utf8NoBom -Path (Join-Path $OfficialPackage 'README_INSTALL_EN.txt') -Content $OfficialNoteEn
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'LICENSE') -Destination (Join-Path $OfficialPackage 'LICENSE') -Force

$ManualNoteCn = @"
佐伊／GrassBoss 全工作适应性 - 手动 UE4SS/PalSchema 包

将压缩包中的 'PalSchema' 文件夹合并到已经安装 PalSchema 的 UE4SS Mods
目录。最终文件应位于：

<UE4SS Mods>\PalSchema\mods\$PackageName\raw\DT_PalMonsterParameter.json
<UE4SS Mods>\PalSchema\mods\$PackageName\raw\DT_PalHumanParameter.json

安装或删除后都要重启服务器。完整说明请查看项目 README.md。
"@
$ManualNoteEn = @"
Zoe / GrassBoss All Work Suitability - manual UE4SS/PalSchema package

Merge the included 'PalSchema' folder into the UE4SS Mods directory that
already contains PalSchema. The resulting files must be under:

<UE4SS Mods>\PalSchema\mods\$PackageName\raw\DT_PalMonsterParameter.json
<UE4SS Mods>\PalSchema\mods\$PackageName\raw\DT_PalHumanParameter.json

Restart the server after installing or removing the package. See the repository
README.md for complete instructions.
"@
Write-Utf8NoBom -Path (Join-Path $ManualRoot 'README_INSTALL_CN.txt') -Content $ManualNoteCn
Write-Utf8NoBom -Path (Join-Path $ManualRoot 'README_INSTALL_EN.txt') -Content $ManualNoteEn
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'LICENSE') -Destination (Join-Path $ManualRoot 'LICENSE') -Force

$OfficialZip = Join-Path $DistRoot "$PackageName-OfficialServer.zip"
$ManualZip = Join-Path $DistRoot "$PackageName-Manual.zip"
$SourceZip = Join-Path $DistRoot 'ZoeAllWorkSuitability-Source.zip'
Compress-Archive -LiteralPath $OfficialPackage -DestinationPath $OfficialZip -CompressionLevel Optimal
Compress-Archive -LiteralPath (Join-Path $ManualRoot 'PalSchema'), (Join-Path $ManualRoot 'README_INSTALL_CN.txt'), (Join-Path $ManualRoot 'README_INSTALL_EN.txt'), (Join-Path $ManualRoot 'LICENSE') -DestinationPath $ManualZip -CompressionLevel Optimal
$SourceItems = @(
    (Join-Path $PSScriptRoot '.gitignore'),
    (Join-Path $PSScriptRoot 'config.json'),
    (Join-Path $PSScriptRoot 'build.ps1'),
    (Join-Path $PSScriptRoot 'validate.ps1'),
    (Join-Path $PSScriptRoot 'install.ps1'),
    (Join-Path $PSScriptRoot 'README.md'),
    (Join-Path $PSScriptRoot 'README_EN.md'),
    (Join-Path $PSScriptRoot 'CHANGELOG.md'),
    (Join-Path $PSScriptRoot 'PRIVACY.md'),
    (Join-Path $PSScriptRoot 'SECURITY.md'),
    (Join-Path $PSScriptRoot 'LICENSE'),
    (Join-Path $PSScriptRoot 'docs'),
    (Join-Path $PSScriptRoot '.github')
)
Compress-Archive -LiteralPath $SourceItems -DestinationPath $SourceZip -CompressionLevel Optimal

$ChecksumLines = foreach ($ArchivePath in @($OfficialZip, $ManualZip, $SourceZip)) {
    $Hash = Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256
    "$($Hash.Hash)  $([System.IO.Path]::GetFileName($ArchivePath))"
}
Write-Utf8NoBom -Path (Join-Path $DistRoot 'SHA256SUMS.txt') -Content (($ChecksumLines -join [Environment]::NewLine) + [Environment]::NewLine)

Write-Host "Built: $OfficialZip"
Write-Host "Built: $ManualZip"
Write-Host "Built: $SourceZip"
foreach ($TargetTable in $TargetTables) {
    Write-Host "$TargetTable rows: $(@($Config.targets.$TargetTable) -join ', ')"
}
Write-Host "Fields per row: $($Suitabilities.Count)"
