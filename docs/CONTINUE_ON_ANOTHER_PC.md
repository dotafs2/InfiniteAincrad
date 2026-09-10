# 换电脑继续：2026-09-10

正式仓库是 `dotafs2/InfiniteAincrad`，默认分支 `main`。请先读 `AGENTS.md`、`docs/STATUS.md`；唯一执行路线仍是 Godot 中持续存在的 AI 居民世界。旧项目保留历史，不从旧王国/双引擎路线重新开始。

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

上述启动恢复两人的事实与Mira已经保存的选择，不追加付费调用。它仍是明确的两人fixture，不是旧13人主世界的恢复；旧主世界的最新完整源档尚未核实。

## Kimi与费用

同一验证额度累计花费0.0141471元，总额2元。包内 `ledgers/validation-latest/visitor.sqlite3` 和同名 `.guard.json` 是当前验证链末端。前两个验证账本的费用已经结转，不能把三个账本的累计数再相加。旧城市账本是另一段历史，旧夜间主账本仍缺失、跨机器费用仍未核实；不清零或从账户余额重建100元预算。

```powershell
python tools/kimi/inspect_ledger.py C:/Private/InfiniteAincrad-private-state-2026-09-10/ledgers/validation-latest/visitor.sqlite3
```

此命令不初始化、不调用模型。预算/网关/图像传输的Python实现已随项目迁入 `tools/kimi/`，不再需要旧UE目录才能读取这些实现。旧网关的直接命令行入口已禁用；后续运行应显式加载已核验账本和私有配置，不能删除已耗尽的尝试记录获得更多请求。API密钥和临时网关令牌未打包；新电脑需从自己的密钥管理位置配置。不要把旧运行配置中的过期截止或本机绝对路径直接当作新授权。

## 最新进度与唯一下一项

已完成真实Kimi提出水桶需求、玩家帮助入口安装、真实取水/饮水、独立恢复；第二人Mira自己走到井边观察，得知有桶无水并选择等待，没有拿到Luna的私有经历。Mira没有返回结构化 `need`，不要替她补写需求。

下一项只做附近居民之间可拒绝的询问/求助：消息来源、接收范围、个人知识、回复和保存续接。不要扩地图、堆美术、换Web框架或直接共享记忆。仍缺少实际NPC摄像头、三人生活事件、自主兑现新功能和可分发构建。

旧电脑的小时续作已暂停，避免两个电脑同时写同一世界。连续开发的旧预算、用量与进度记录随私有包保留；迁机不是重置历史费用或恢复过期自动任务。下一台电脑先读记录、核实范围后再启动工作。
