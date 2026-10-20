# 技术依据与路线选择

数据结构最后人工核对日期：2026-09-01。上游安装与版本说明最后核对日期：2026-10-20。

## 1.0.x 数据结构

`PalCharacterParameterDatabaseRow` 使用的怪物参数表和人形参数表都包含以下 13 个整数字段：

```text
WorkSuitability_EmitFlame
WorkSuitability_Watering
WorkSuitability_Seeding
WorkSuitability_GenerateElectricity
WorkSuitability_Handcraft
WorkSuitability_Collection
WorkSuitability_Deforest
WorkSuitability_Mining
WorkSuitability_OilExtraction
WorkSuitability_ProductMedicine
WorkSuitability_Cool
WorkSuitability_Transport
WorkSuitability_MonsterFarm
```

1.0.x 的佐伊与暴电熊对应 `DT_PalMonsterParameter` 中的 `GYM_ElecPanda`、`GYM_ElecPanda_2` 和 `GYM_ElecPanda_Otomo`。三行均为 `IsPal=true`、`Tribe=ElecPanda`，并使用 `BPClass=GYM_ElecPanda`。

`GrassBoss` 是 `DT_PalHumanParameter` 行：`IsPal=false`、`Tribe=Human`、`BPClass=NPC_GrassBoss`，原生只有 `WorkSuitability_Handcraft=3`。它的 `DT_WazaMasterLevel` 记录为 `GrassBoss001 -> Weapon_Use, Level=1`，因此本项目只改工作适应性，不改持枪战斗技能。

## 为什么不能只改单只帕鲁存档

单只帕鲁的 `GotWorkSuitabilityAddRankList` 表达已有工种的额外等级。物种基础字段为 0 时，仅写额外等级可能被现行计算或校验忽略。本项目修改物种/角色静态表，从基础数据中加入目标工种。

## 为什么不是整表 PAK

整表 `.uasset`/PAK 覆盖也能修改这些数值，但会覆盖完整 DataTable：

- 容易与其他修改同表的 MOD 冲突。
- 每次游戏更新后都需要从当前 cooked 资产重新制作。
- 需要游戏资产、对应 Unreal Editor/Modding Kit 和 cook/package 工具链。

PalSchema 以 JSON 在运行时修改指定行和字段，修改面更小，也不需要在仓库中分发游戏资产。

## 为什么不优先写 Lua 反射脚本

UE4SS Lua 可以在运行时寻找 DataTable 并写字段，但需要处理对象加载时序、反射 API 和热重载行为。PalSchema 已封装 DataTable 加载与逐字段合并，更适合这个只有“目标行 + 13 个整数”的补丁。本项目的 PowerShell 只用于离线构建和安装，不在服务器运行轮询脚本。

## 版本边界

- 本包采用 PalSchema `raw` DataTable 补丁格式，并提供带 `IsServer=true` 的官方服务器安装规则。
- Pocketpair 的专用服务器 MOD 指南截至 2026-10-20 标记为 1.0.4，仍只声明 Windows 专用服务器支持服务端 MOD。
- 截至 2026-10-20，PalSchema 0.6.71 的发布说明要求与 Okaetsu UE4SS 2281fa31 配套；升级依赖时必须重新阅读对应 Release Notes，不应混用版本。
- 1.0、1.0.2 和 1.0.3 的这些目标行和字段在核对时未见变化；任何后续更新仍应先检查 PalSchema/UE4SS 日志并在备份存档上验证。
- Windows 专用服务器是本项目的测试目标；Linux 原生或 Wine 环境不在已验证范围。
- 游戏、UE4SS 和 PalSchema 都可能改变兼容性。不要在没有备份的唯一存档上首次测试。
