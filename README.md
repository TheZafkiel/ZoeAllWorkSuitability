# 佐伊／GrassBoss 全工作适应性 MOD

[English](README_EN.md) · 版本 1.1.0 · 面向 Palworld 1.0.x Windows 专用服务器

这是一个基于 UE4SS + PalSchema 的小型数据补丁。它将佐伊相关角色及 `GrassBoss` 人形 NPC 的 13 项基础工作适应性设为可配置等级，默认全部为 10。它修改物种/角色 DataTable，不依赖单只帕鲁的 `GotWorkSuitabilityAddRankList`，所以能添加原本为 0 的工作类型。

本项目是非官方社区 MOD，与 Pocketpair 无关联。首次安装前请备份世界存档。

## 默认目标

| DataTable | 内部行名 | 说明 |
| --- | --- | --- |
| `DT_PalMonsterParameter` | `GYM_ElecPanda` | 佐伊与暴电熊塔主版本 |
| `DT_PalMonsterParameter` | `GYM_ElecPanda_2` | 第二套/高难度参数版本 |
| `DT_PalMonsterParameter` | `GYM_ElecPanda_Otomo` | 可同行/伙伴版本 |
| `DT_PalHumanParameter` | `GrassBoss` | 人形 NPC 佐伊 |

默认修改 13 项：生火、浇水、播种、发电、手工作业、采集、伐木、采矿、采油、制药、冷却、搬运、牧场。目标行和每项等级都可在 [`config.json`](config.json) 中修改。

## 要求

- Palworld 1.0.x Windows 专用服务器。Pocketpair 的服务器 MOD 指南截至 2026-10-20 标记为 1.0.4，并仍只声明 Windows 专用服务器支持服务端 MOD。
- 推荐按当前上游明确配套使用 [PalSchema 0.6.71](https://github.com/Okaetsu/PalSchema/releases/tag/0.6.71) 与 [Okaetsu UE4SS 2281fa31](https://github.com/Okaetsu/RE-UE4SS/releases/tag/2281fa31)。
- 使用其他版本时，必须按对应 PalSchema Release Notes 匹配 UE4SS，不要把不同配套版本混用。本项目使用 PalSchema 的 `raw` DataTable 补丁格式。

不要同时安装两套 UE4SS。若服务器已通过 Palworld 官方 MOD 系统安装 UE4SS 和 PalSchema，优先使用官方服务器包。

## 下载包怎么选

GitHub Release 提供以下文件：

- `ZoeAllWorkLv10-OfficialServer.zip`：推荐；用于官方专用服务器 MOD 加载方式。
- `ZoeAllWorkLv10-Manual.zip`：已有手动 UE4SS/PalSchema 环境时使用。
- `ZoeAllWorkSuitability-Source.zip`：源码快照，不是直接安装包；先构建再使用安装脚本。
- `SHA256SUMS.txt`：用于核对下载文件完整性。

本项目不捆绑 UE4SS、PalSchema 或任何游戏资产。

## 安装：官方服务器包（推荐）

1. 停止专用服务器并备份世界存档。
2. 解压 `ZoeAllWorkLv10-OfficialServer.zip`。
3. 将解压得到的 `ZoeAllWorkLv10` 文件夹放到：

   ```text
   <PalServer>\Mods\Workshop\ZoeAllWorkLv10\Info.json
   ```

4. 确认 `<PalServer>\Mods\PalModSettings.ini` 的 `[PalModSettings]` 段包含：

   ```ini
   [PalModSettings]
   bGlobalEnableMod=True
   ActiveModList=UE4SS
   ActiveModList=PalSchema
   ActiveModList=ZoeAllWorkLv10
   ```

5. 启动服务器。官方加载器应将补丁部署到：

   ```text
   <PalServer>\Mods\NativeMods\UE4SS\Mods\PalSchema\mods\ZoeAllWorkLv10
   ```

## 安装：手动 UE4SS/PalSchema 包

停止服务器后，解压 `ZoeAllWorkLv10-Manual.zip`，将其中的 `PalSchema` 文件夹合并到 UE4SS 的 `Mods` 目录。最终应存在：

```text
<UE4SS Mods>\PalSchema\mods\ZoeAllWorkLv10\raw\DT_PalMonsterParameter.json
<UE4SS Mods>\PalSchema\mods\ZoeAllWorkLv10\raw\DT_PalHumanParameter.json
```

完成后重启服务器。

## 从源码构建和安装

Windows PowerShell 5.1 或 PowerShell 7 均可运行构建脚本：

```powershell
.\build.ps1
.\validate.ps1
```

构建会重新创建 `dist`、三个 ZIP 和 `SHA256SUMS.txt`。验证器会根据当前 `config.json` 检查目标表、目标行、13 个具体数值、官方与手动载荷的一致性，以及服务端安装规则。

从完整仓库源码安装时，还可以运行：

```powershell
.\install.ps1 -ServerRoot 'C:\Path\To\PalServer' -Mode Official
# 或
.\install.ps1 -ServerRoot 'C:\Path\To\PalServer' -Mode Manual
```

安装脚本不会停止服务器；检测到服务器正在运行时会退出。它会备份旧 MOD 目录和 `PalModSettings.ini`，然后干净替换本项目目录，避免旧 JSON 残留。

## 自定义

编辑 `config.json` 后重新构建并验证：

- `targets`：按 DataTable 分类的内部行名。怪物/伙伴行放在 `DT_PalMonsterParameter`，人形 NPC 行放在 `DT_PalHumanParameter`。
- `levels`：13 项工作适应性必须全部保留，每项为 0–10 的整数。
- `packageName`：只能包含英文字母和数字；改变后安装目录和 `ActiveModList` 名也会改变。
- `version`：发布新包时更新版本号。

## 验证是否生效

服务器完全启动后：

1. 查看 `UE4SS.log`，搜索 `PalSchema`、目标表名和目标行名，确认没有加载错误。
2. 重新生成/取出对应角色，并在基地实际分配不同工作。
3. 默认配置应看到 `DT_PalMonsterParameter` 的 3 行和 `DT_PalHumanParameter` 的 1 行被加载。

未安装本补丁的客户端可能仍按本地静态数据把新增工种显示为灰色或不显示，但服务器端的实际分配和工作行为仍可能已经生效。以服务器行为和日志为准；若要求客户端详情页同步显示，客户端也需要加载相同数据补丁。

## 已知边界

- `WorkSuitability_MonsterFarm=10` 只增加牧场适应性并与其他默认值保持一致；PalSchema 上游说明牧场等级高于 1 没有额外机制收益。实际产物还需要独立的 Ranch Action/掉落定义，本项目不会凭空生成物品，也不保证该机制能直接用于 `GrassBoss` 人形行。
- `GrassBoss` 的武器、攻击倍率和战斗招式不在修改范围内，避免破坏人形 NPC 的持枪 AI。
- 这是静态 DataTable 补丁，不向存档写入自定义结构。其他工具写入的单体强化值不由本项目清理。
- 游戏、UE4SS 或 PalSchema 更新后都可能需要重新验证兼容性。数据结构的最后人工核对日期为 2026-09-01。

## 禁用和回滚

先停止服务器。

- 官方包：从 `PalModSettings.ini` 移除或注释 `ActiveModList=ZoeAllWorkLv10`，并移走 `Mods\Workshop\ZoeAllWorkLv10`，然后重启。
- 手动包：移走 `PalSchema\mods\ZoeAllWorkLv10`，然后重启。
- 临时排查全部 MOD：使用官方 `-NoMods` 启动参数。

禁用后基础值恢复原版。安装脚本生成的 `.bak-时间戳` 备份可以用于恢复旧配置或旧包。

## 隐私与安全

源码和发布包不包含服务器日志、世界存档、Steam ID、IP、账号、密码、Token、Cookie 或机器专属路径。本项目没有遥测、联网、上传或凭据读取代码。安装脚本只读取指定服务器目录、复制本 MOD，并在修改前创建本地备份。详见 [`PRIVACY.md`](PRIVACY.md) 和 [`SECURITY.md`](SECURITY.md)。

## 官方与直接上游

- [Pocketpair 专用服务器 MOD 文档](https://docs.palworldgame.com/settings-and-operation/mod/)
- [Pocketpair PalworldModUploader](https://github.com/pocketpairjp/PalworldModUploader)
- [PalSchema](https://github.com/Okaetsu/PalSchema)
- [PalSchema 文档](https://okaetsu.github.io/PalSchema/)

PalSchema 文档站显示的文档版本不一定等于最新二进制版本；安装时以 GitHub Releases 和对应 Release Notes 为准。

## 社区交叉核对

- [palschema-hub 数据表参考](https://github.com/Booyaka101/palschema-hub)
- [Palworld Modding Kit SDK](https://github.com/localcc/PalworldModdingKit)

技术路线和字段依据见 [`docs/technical-basis.md`](docs/technical-basis.md)。
