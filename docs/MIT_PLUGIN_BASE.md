# MIT 基础库与当前接入

2026-09-10。继续 InfiniteAincrad 的 Godot 3D 街道，不迁回网页，也不替换世界存档。此前调研中优先的 NPC 框架确实是 OpenGameAgent；本次已实际编译并接入。

| 基础 | 用途与取舍 | 本轮状态 |
| --- | --- | --- |
| [OpenGameAgent](https://github.com/EricSun0218/OpenGameAgent) | 原生 C# agent runtime：模型接口、每角色执行、循环限制、会话、Godot 主线程信号和取消。适合现有 Godot .NET | 已使用真实上游 runtime 和官方 Godot Node；本轮提供者是离线测试策略 |
| [a16z AI Town](https://github.com/a16z-infra/ai-town) | NPC 社交、对话和记忆的参考实现，但整套运行依赖浏览器与 Convex | MIT 已核对；没有搬入网页或另建后端 |
| [Beehave](https://github.com/bitbrain/beehave) | Godot GDScript 行为树，适合以后把走路、等待、搬运组织为可复用执行节点 | MIT 已核对，尚未集成；需要更复杂行动时优先试它 |
| Godot 自带节点 | NavigationAgent3D、物理、场景、Resource 和信号应优先复用 | 本轮继续复用引擎场景、物理和信号；尚未增加寻路系统 |

许可证：[OGA 固定版本 MIT](https://github.com/EricSun0218/OpenGameAgent/blob/b1a9f149d7cfd9e6659fd6aeb2ed4cfc275d0f84/LICENSE)、[AI Town MIT](https://github.com/a16z-infra/ai-town/blob/main/LICENSE)、[Beehave MIT](https://github.com/bitbrain/beehave/blob/godot-4.x/LICENSE)。这不替代本项目自身的许可证选择，也不覆盖第三方美术。

## 真正复用的代码

固定上游 commit `b1a9f149d7cfd9e6659fd6aeb2ed4cfc275d0f84`，版本 `0.3.0-alpha.4`。它仍是 alpha，后续升级应有针对当前存档的兼容验证。

`third_party/OpenGameAgent/` 保留五个最小依赖项目：Runtime、Kernel、Attachments、Client、Runtime.Protocol。官方 Godot `OpenGameAgentNode.cs` 在 `game/addons/open_game_agent/runtime/`，原版权和 MIT 文本一并保留。没有导入服务器、Web UI、Unity、UE 或源码中的测试集合。Client/Protocol 是官方 Godot Node 的编译依赖，本轮不启动远程服务。

`third_party/opengameagent.lock.json` 记录来源、固定 commit 与 59 个原样源码文件的 SHA256。上游源码共约 1.03 MB，没有修改上游文件；程序集由本地构建产生，bin/obj/.godot 不上传。NuGet 依赖另外由各 `packages.lock.json` 固定。

## 接口与当前边界

```text
world_kernel.resident_view()  →  resident_brain.propose(view, turn)
                            →  官方 OpenGameAgent runtime / provider
                            →  decision + command_id + 可信来源
                            →  world_kernel.submit_resident_decision()
                            →  校验、执行、事实与存档  →  3D 表现
```

- `game/agents/resident_brain.json` 选择 adapter 脚本并控制 enabled；修改后重启加载。禁用模块暂停居民思考，不删除存档。它不是任意代码热安装器。
- `resident_brain.gd` 是场景依赖的接口：提议没有写世界权限；处理超时、单请求并发和错误。每次实例最多 12 次离线请求，每次最多 10 秒。
- `OgaResidentNode.cs` 配置官方 runtime：最多一轮模型推理、512 输出 token、一个并发居民、有限消息历史，不向 NPC 注册 GM 或开发工具。
- 当前 `ObservationFixtureProvider` 是明确标记的测试策略，通过真正的 `IModelProvider` 接口运行。不是大模型、自主故事或 Kimi。它沿用已有取水 fixture 来测接线。
- 更换模型实现沿用上游 provider 接口；新 `BudgetGatewayProvider` 已适配现有Kimi预算网关的非流式协议并通过隔离HTTP/图形验证。它不直连Kimi或初始化余额；真实Kimi验收仍等待最新累计账本核实。详见 [网关接入报告](validation/budget_gateway_2026-09-10.md)。
- 人物经历与资源仍由 Godot 世界保存；本轮 OGA 会话只是内存中的推理上下文，不成为第二份世界事实或长期记忆数据库。替换 runtime 后以同一居民观察和经历续接。
- 动作、GM 审核和安装仍是现有取水能力 fixture。目前只支持 wait / draw_water / drink_water，不能声称所有功能已通用插件化或 GM 已能自己开发插件。

## 如何继续扩展

每轮只兑现一个可见模块：先把真实模型和费用门控接到现有接口，再把行动执行接到现成 Godot 行为树。只有新的实际需求出现，才新增世界能力与相应验证；经济、交易、产权和存档语义由世界规则负责，不能交给模型任意重写。

引擎、NPC 推理、行动执行、GM 能力安装分别有清晰职责。可插拔意味着接口与状态归属稳定，不要求把每个函数包装成插件，也不意味着安装未经验证的生成代码。

## 本地运行与验证

需要 Godot **4.7.2 .NET** 和 .NET SDK 8 或更新版本。第一次克隆还需 Git LFS 拉取已有市场 GLB。`./Run-Street.ps1 -Godot <Godot.exe>` 会先执行 .NET 构建；已有程序集可传 `-SkipBuild`。

```powershell
dotnet build game/InfiniteAincrad.csproj --disable-build-servers
# 以下命令从 game/ 运行，Godot 使用 .NET 版本
Godot.exe --headless --path . --script res://tests/oga_acceptance.gd
Godot.exe --headless --path . --script res://tests/decision_boundary_acceptance.gd
```

构建及接入验证结果见 [本轮报告](validation/oga_integration_2026-09-10.md)。所有测试都只操作隔离 fixture；没有迁移或改写原维护世界。
