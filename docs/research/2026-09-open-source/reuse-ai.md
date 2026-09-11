# AI 复用研究评审（F）

核验日：2026-09-10。范围是现有 Godot 4 .NET 街道和已锁定的 OpenGameAgent（OGA）`0.3.0-alpha.4`、commit `b1a9f149d7cfd9e6659fd6aeb2ed4cfc275d0f84`；本轮只研究，不安装候选、不运行付费模型。仓库当前边界很清楚：`resident_view → IModelProvider → decision → world_kernel`，模型只有提议权；`OgaResidentNode` 一轮、512 输出 token、单并发，`resident_brain.gd` 对请求/超时/取消做闸门，世界事实和个人记忆仍在 world_kernel。这个边界应保留。

## 结论与候选矩阵

| 方案 | 判断 | 许可证、成本与门槛 | 兼容/退出 |
|---|---|---|---|
| OGA 固定提交 | **保留** | 框架 MIT；上游明确仍是 pre-1.0，API 可变，分发须带版权与许可。服务代码许可不等于模型许可；模型权重另按其卡片核验。当前接入已验证 C# Godot 主线程、结构化请求和取消，继续锁 SHA。 | 只依赖 `IModelProvider`、官方 Node；升级前做同一存档回放。删除 provider/runtime 引用即可，世界存档不变。上游 README 的维护强度和 alpha 状态不足以承诺稳定性，故不追 main。 |
| Ollama 本地 provider | **现在有限试验** | Ollama 服务代码 MIT，API 支持 JSON Schema；模型可显示自己的 license，但下载的 GGUF/权重仍逐模型审查，不能因 API “兼容”推断行为、价格或权重许可。安装是独立本地服务并需下载模型；RAM/VRAM、首 token、tokens/s 随模型、量化、上下文和硬件变化，本仓库没有数据。 | 可做 `IModelProvider` HTTP 适配器，固定 `format` schema、超时、模型摘要和 provenance。实验失败只回到 fixture/网关；不把 Ollama 作为生产依赖。云端 Ollama 当前不支持 structured outputs，须使用本地路径。 |
| llama.cpp server | **现在有限试验** | llama.cpp MIT；`llama-server` 支持 OpenAI 兼容与 JSON schema/grammar。构建可选 CPU、Metal、CUDA、HIP、Vulkan 等后端，量化降低内存但改变质量/速度。GGUF 权重来源和基座许可另审；项目本身不替权重背书。编译、后端选择和模型文件管理是额外门槛，延迟必须实测。 | 相同 `IModelProvider` 可对接 localhost HTTP，schema 是明确边界；适合作为第二本地实现，退出只停进程并删适配器。与 Ollama 二选一先测一款同模型、同量化、同上下文；不要同时引入。 |
| LiteLLM/新 agent 框架 | **延后** | LiteLLM MIT，目标是 100+ 厂商统一、重试、路由、计费、代理；这会另加 Python 服务、配置、日志/密钥和故障面。“OpenAI 兼容”只说明线协议，不保证结构化输出、停止语义、模型行为、费用或权重许可一致。 | 现有 `BudgetGatewayProvider` 已有本地绑定、账本、未知结果熔断和字段投影；LiteLLM 会重复这些职责，不能证明节省时间。只有出现多供应商路由或团队级配额需求，才做隔离代理 PoC；当前否决接入主运行时。 |
| AI Town/Generative Agents 与向量库/GraphRAG | **概念借鉴；运行时与基础设施否决/延后** | AI Town 是 MIT，但运行依赖 React/Convex 云后端；不能搬进单引擎 Godot。论文的 observation、planning、reflection、memory stream 是可借鉴概念，不是可直接复用的持久事实实现。Microsoft GraphRAG 也是 MIT，但官方警告索引昂贵，流水线要 LLM 抽取实体/关系、社区总结和向量写入。对两名 fixture、有限个人视图和短经历，这会增加迁移、隐私分区、重建与回滚工作。 | 保留“每人只看自己的观察/经历”“未来可做受控回忆检索”两个接口思想；当前直接读取 world_kernel 中该居民已有的个人观察与经历，明确没有已实现的词法/向量检索。只有经历规模、跨事件查询和测量结果证明直接读取不足，才试可重建本地索引；GraphRAG/Convex 后端现在不进主树。 |

**最小栈：** Godot 世界规则与存档 + 已锁定 OGA runtime + 一个严格的 `IModelProvider`（fixture 或受控网关）；可复用接口仅是 `StreamAsync(ModelRequest, CancellationToken) → ModelStreamEvent`、`resident_brain.propose(view, turn) → {ok, decision, provenance, code}`，以及 world_kernel 的 `submit_resident_decision`。Provider 不得写世界、生成代码、安装能力或替居民执行；失败/超时只能返回失败并让居民按显式规则等待，不能伪装成自主 wait。结构化 JSON 通过 schema 后仍由世界校验动作、资源、权限和版本。

建议的最小判别试验不需要新框架：选一个不含隐私的 fixture 保存，固定同一小模型和量化，分别启动 Ollama 与 llama.cpp；输入完全相同的个人观察，收集首 token、完整响应、schema 拒绝率、超时率、峰值内存和启动耗时，随后关掉服务做冷恢复。通过条件是两者都能在硬上限内给出合法提议，世界拒绝越权字段，回放后的事实字节一致；否则保留当前 fixture/网关。没有固定机器和模型 SHA，就不能把任何延迟、免费或“轻量”结论写成产品承诺。

**牌照边界：** MIT 只覆盖上述服务/框架代码。Ollama/llama.cpp 的模型下载地址、基座、微调、量化文件可能分别是 Apache、社区条款或非商业条款；每个候选模型必须保存来源、SHA、license URL 和分发限制。不要把模型内含的 system prompt、服务计费或“兼容”宣传当成授权。

一个容易被忽略的反证是：最热门的 GraphRAG 反而会增加当前工时。它先把短经历变成实体、关系、社区和嵌入，再在查询时组装上下文；每一步都可能引入模型费用、陈旧索引、跨居民泄漏和无法解释的回滚。现有两名居民的关键验收恰恰是“只看自己的观察”，因此更大的召回系统会先扩大错误面，而不是缩短交付。OGA 上游 README 还展示了远超本锁定 alpha 提交的扩展能力；这证明项目在演进，也证明直接追随 main 会扩大升级面，不能算免费维护。

## 证据、退出与验证

真实模型切换证明的是 provider 协议和边界：同一保存、同一 `resident_view`、同一 action schema，记录模型/权重 SHA、provenance、请求/响应耗时、token/账本、被世界接受的命令及保存后事实；至少 fixture→真实 A→真实 B，各自新操作号。它不能单独证明记忆正确、居民人格连续或更快。离线回放只重放已记录观察和决策，证明世界提交、拒绝、持久化、隔离和冷启动可重复；不能证明模型质量、真实延迟、费用或提供者可用性。付费验证必须另行核对授权 scope、截止时间、原始账本和未知结果账；本轮不运行，不能用 API 失败或超时补写居民决定。

## 给 Godot/产品组的尖锐问题

1. 如果本周只允许一条可见街道事件，哪条事实证明“换模型仍是同一居民”，而不是又一段漂亮对白？
2. 谁拥有 wait 的语义：模型拒绝、超时、断网和世界规则不允许，是否分别出现在存档与 UI，而不是都叫“居民选择等待”？
3. 你们愿意先给出同一模型/量化在 Ollama 与 llama.cpp 的首 token、完成时间、结构化失败率和每居民硬上限，还是承认“本地免费”目前只是口号？
4. 产品是否接受每条跨居民消息带来源、接收者和时间戳，并由接收者决定拒绝/等待？若不能，为什么要上 AI Town 的社交运行时？
5. 在引入向量/GraphRAG 前，哪一个可重放测试会证明当前 world_kernel 的个人视图检索已经失败？

## 一手来源（最多 10 页）

1. [OpenGameAgent README 与 MIT/alpha 说明](https://github.com/EricSun0218/OpenGameAgent/blob/main/README.md)；[本项目固定提交](https://github.com/EricSun0218/OpenGameAgent/tree/b1a9f149d7cfd9e6659fd6aeb2ed4cfc275d0f84)。
2. [Ollama API：JSON Schema structured outputs 与 model license 字段](https://github.com/ollama/ollama/blob/main/docs/api.md)；[Ollama structured outputs（云端限制）](https://github.com/ollama/ollama/blob/main/docs/capabilities/structured-outputs.mdx)。
3. [llama.cpp README：后端、量化与 OpenAI-compatible server](https://github.com/ggml-org/llama.cpp/blob/master/README.md)；[server schema/grammar](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/server-schema.cpp)。
4. [LiteLLM README：代理、路由、计费与 100+ provider](https://github.com/BerriAI/litellm/blob/main/README.md)。
5. [AI Town README/架构与 Convex 依赖](https://github.com/a16z-infra/ai-town/blob/main/README.md)。
6. [Generative Agents 原论文](https://arxiv.org/abs/2304.03442)。
7. [Microsoft GraphRAG README 的成本警告与项目定位](https://github.com/microsoft/graphrag/blob/main/README.md)。

本文件是 F 的独立研究意见，不替代六人后续逐票投票；投票应以本矩阵和可复现实验证据为输入。

## 第二轮交叉辩论：质询、回应与修正

对 E 的质询，我同意“只含可听/可见来源”不能靠 prompt 保证。消息事件应先由 world_kernel 按发送者、接收者、距离、视线/声场、时间和原文建立接收记录，再投影给接收者；模型永远不能补造“听见”。冷恢复验收应使用独立 actor_id 和私有视图哈希，断言 Mira 的输入、请求日志和存档不含 Luna 的观察/经历；共享世界事实也必须标注来源，不能因同街道而进入个人记忆。

对 B，我改变措辞：无密钥预览不应被本地模型挡住。fixture provider 应继续作为默认、可下载、离线的预览路径；本地模型是可选开发增强，不是首发前置。对根代理的反对，我接受：同权重换 Ollama/llama.cpp 只证明传输与服务替换，不能证明模型替换。因此唯一首选本地路线是先做 Ollama 的可选 `IModelProvider` 试件；只有它在结构化输出、取消、冷启动或目标硬件上失败，才触发 llama.cpp 试验，且届时选择另一实际模型，单独记录模型/权重许可与行为差异，不做双 runtime 同时基准。

我也修正对 AI Town 的表述：其官方说明确实提供本地 Docker 与 Ollama 路径，不能说只能用 Convex 云；但本地仍携带 Convex/PixiJS 等完整运行栈，与本项目单 Godot、世界事实归属和存档目标不同，所以仍只借鉴社交投影概念。最后，超时、断网、取消或 provider 失败一律进入系统暂停/错误，保留最后有效决定；除非另有显式世界规则，不能生成或伪装居民 `wait`。这条修正优先于本文前文任何含糊措辞。本轮不投最终票。
