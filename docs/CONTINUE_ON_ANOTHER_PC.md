# 换电脑继续：2026-09-11

**本机续作更新：** 已同步 `main` 的 `e3ab07b`。代码/美术已到，原镇 seq37 完整源档和 seq44 Godot 副本没有随 Git 到达；本机只找到 seq3，用户确认尚未私下同步。下文“已找到原档”指上一台电脑的事实，不能拿两人水井私有包或新的三人交易测试档替代原世界。

本轮交易代码和真实 Kimi 验证见 [新报告](validation/town_trade_2026-09-11.md)。新的独立验证链末端为本机 `C:/InfiniteAincrad/tmp/town-contracts-20260911/live-ledger/continuation.sqlite3` 及同名 `.guard.json`，世界在该批目录的 `live/world.json`，之前失败/复核记录仍保留。12 次新增请求估算 0.1717833 元，加旧验证负债 0.0141471 元，共 0.1859304 元；仍为同一 2 元授权链。下文 0.0141471 元和旧包只作为历史，不再是最新余额。跨电脑另行私下传递这些文件及请求记录，不传密钥、临时 endpoint 令牌，不从旧包恢复新额度。

正式仓库是 `dotafs2/InfiniteAincrad`，默认分支 `main`。请先读 `AGENTS.md`、`docs/STATUS.md`；唯一执行路线仍是 Godot 中持续存在的 AI 居民世界。旧项目保留历史，不从旧王国/双引擎路线重新开始。

本次同步包括原镇三名居民的独立 Godot 迁移验证、生活与社交边界代码、人物动作细节、Windows 技术预览构建工具、研究结论和精选验收画面。当前第一版目标是恢复原 Kimi 城镇能力后达到5–10名活跃居民；井边包仍只是内部技术预览。完整长期目标、当前分工和下一步分别以 `AGENTS.md`、`ROADMAP.md`、`docs/STATUS.md` 为准。

上传前本机迁移测试6/6通过，C#工程构建0警告、0错误。已有Godot实机和冷恢复证据见 `docs/validation/town_life_2026-09-10.md`，不是本次上传重新进行的付费运行。

## 获取完整代码和美术

需要 Git LFS、Godot 4.7.2 .NET、.NET SDK 8或更新版本。API密钥不是离线启动条件。

```powershell
git lfs install
git clone https://github.com/dotafs2/InfiniteAincrad.git
cd InfiniteAincrad
git lfs pull
git lfs fsck
./Run-Street.ps1 -Godot C:/Tools/Godot/Godot.exe
```

已有克隆则先保存本机改动，执行 `git pull --ff-only` 和 `git lfs pull`。不要用 GitHub 的源码ZIP代替LFS拉取；大模型文件在Git中显示为指针是正常的，必须取得实际内容。

主美术：`game/assets/market/StartingTown_Market_CraftV5.glb`（114,210,064字节），SHA256 `2e680ec8814a6aa7f4d09c74ad20fb859b5ccae5e3ef161f51d70e9c40f1b67d`。GLB无外部图片/缓冲文件依赖。可编辑源：`Art/ReferenceScenes/MarketCraftV5/StartingTown_Market_CraftV5.blend`，34,246,266字节；源贴图和制作脚本一并收录。临时人物的模型代码在 `game/spatial/trial_resident.gd`。正式项目运行不依赖旧桐人角色资源。

## 续接同一个世界

Git只包含源码、美术和脱敏证据，不包含运行存档、密钥或费用数据库。离开旧电脑前，另行带走本次生成的私有文件：

`C:\InfiniteAincrad\Transfer\InfiniteAincrad-private-state-2026-09-10.zip`

将它解压到仓库之外的私人目录，用包内 `SHA256.json` 核对。里面的 `world.json` 是已真实运行的两名测试居民的最新世界，不能拿默认新fixture代替它。

```powershell
./Run-Street.ps1 -Godot C:/Tools/Godot/Godot.exe -SavePath C:/Private/InfiniteAincrad-private-state-2026-09-10/world.json -Visitor
```

上述旧私有包启动恢复两人的事实与Mira已经保存的选择，不追加付费调用。它仍是明确的两人fixture，不是旧13人主世界的恢复。另一路原镇迁移已使用序号37的完整源档检查点验证保留13个身份，独立副本离线推进到44；按 [迁移说明](MIGRATION.md) 准备私有副本，再使用 `./Run-Street.ps1 -Town -SavePath <迁移输出/world.json>`。该检查点不等于旧项目此刻的最新存档，也不等于完成社会迁移。

## Kimi与费用

同一验证额度累计花费0.0141471元，总额2元。包内 `ledgers/validation-latest/visitor.sqlite3` 和同名 `.guard.json` 是当前验证链末端。前两个验证账本的费用已经结转，不能把三个账本的累计数再相加。旧城市账本是另一段历史，旧夜间主账本仍缺失、跨机器费用仍未核实；不清零或从账户余额重建100元预算。

```powershell
python tools/kimi/inspect_ledger.py C:/Private/InfiniteAincrad-private-state-2026-09-10/ledgers/validation-latest/visitor.sqlite3
```

此命令不初始化、不调用模型。预算/网关/图像传输的Python实现已随项目迁入 `tools/kimi/`，不再需要旧UE目录才能读取这些实现。旧网关的直接命令行入口已禁用；后续运行应显式加载已核验账本和私有配置，不能删除已耗尽的尝试记录获得更多请求。API密钥和临时网关令牌未打包；新电脑需从自己的密钥管理位置配置。不要把旧运行配置中的过期截止或本机绝对路径直接当作新授权。

## 最新进度与唯一下一项

已完成真实Kimi提出水桶需求、玩家帮助入口安装、真实取水/饮水、独立恢复；第二人Mira自己走到井边观察，得知有桶无水并选择等待，没有拿到Luna的私有经历。Mira没有返回结构化 `need`，不要替她补写需求。

原镇三人的进食、休息和采浆果现已在独立副本验证，新增动作来自离线规则；Windows预览也已有构建与验收工具。下一项按最新路线推进居民交流、修理/劳动/交换和有意义的玩家介入，先解决食物供给再激活更多原居民。完整迁移、5–10人生活、真实第二模型续接和最终人物美术仍未完成；不要直接共享居民私有记忆或把离线规则称为Kimi自主决定。

旧电脑的小时续作已暂停，避免两个电脑同时写同一世界。连续开发的旧预算、用量与进度记录随私有包保留；迁机不是重置历史费用或恢复过期自动任务。下一台电脑先读记录、核实范围后再启动工作。
