# 2026-09-18 真实参与和移动证据

核对时间：2026-09-17T22:22:45.147983+00:00。运行仍在继续，以下是已达成的检查点，不是 09:00 最终报告。

十位居民均有真实 Kimi 已结算决定，均在正式续跑中发生实际身体位移。位移取相对 seq166 初始位置的最大已观测值，不是累计步行里程；返回原位不会抹掉此前证据。

| 居民 | 身份 | 今晚已结算决定 | 最大已观测位移（米） | 位移见证 |
| --- | --- | ---: | ---: | --- |
| 阿岚 | shared:well-keeper | 17 | 52.15 | gm-source-seq214-installed.json |
| 白枝 | shared:baker | 22 | 42.85 | movement-all10-seq335.json |
| 石青 | shared:smith | 17 | 14.02 | gm-source-seq201.json |
| 木生 | shared:carpenter | 21 | 17.53 | movement-all10-seq335.json |
| 灯姐 | shared:innkeeper | 14 | 34.77 | gm-source-seq173.json |
| 草见 | shared:herder | 24 | 46.36 | checkpoint-0401.json |
| 叶禾 | shared:gardener | 23 | 5.30 | movement-all10-seq335.json |
| 细娘 | shared:weaver | 12 | 23.19 | movement-all10-seq335.json |
| 渡白 | shared:fisher | 25 | 26.70 | gm-source-seq243.json |
| 枚青 | shared:healer | 10 | 45.17 | movement-all10-seq335.json |

最后一位织工的自然决策 `turn:shared:weaver:0:31` 选择 `life:eat_ration`，真实模型操作 `e7328f30-5e92-4909-9aea-ca08766a0e82` 已结算。她走回住处并完成事件 333，下一次决定选择休息。没有修改身体位置或冷却，也没有在 life12 注入访客提问。life10 曾有一次明确标记的自动访客提问，应与这次自然到期决定分开理解。

证据存档：`D:\lucidgloves\InfiniteAincrad\tmp\overnight-20260918\delivery-live\movement-all10-seq335.json`。SHA-256：`59b98070cbcdfc393e18f47924d99f7dc2f55c99dda662f493e6da241583d35c`。

完整验收收据：`D:\lucidgloves\InfiniteAincrad\private\overnight-20260918\ten-resident-movement-acceptance.json`。

公共烤炉闭环：事件 293 铁匠亲自发现 → 297 首次烤好 → 304 食用 → 314 再次烤好。seq321 的四份初始面粉对应剩余二份、持有一个面包、已吃一个。收据：`D:\lucidgloves\InfiniteAincrad\private\overnight-20260918\baking-full-lifecycle-seq321.json`。

十位 GM 的真实观察和维护记录显示在游戏 G 面板；它是最近工作记录，不表示十位 GM 正在同时调用模型。07:30 使用当时重新冻结的 seq417 回访原十个持久会话，九位成功返回，一位 GM01 已发送后超时，结果/费用未知且未重试。此前十位各有成功参与证据；不能把最新一轮写成十位全部成功。

07:30 源快照 SHA-256：`962159a93b73dfa5ec8e16e0d631b828ba5c6b346289f0a0d46ac89bfb74bcef`。原回执：`D:\lucidgloves\InfiniteAincrad\tmp\overnight-20260918\sol-gm\private\night-delivery\evidence\seq417-refresh\receipts.json`，SHA-256：`3413432fead33ea1456a935c627d57544ff31f91006fd48fc1d6398ec79bf55f`。九位成功调用的实测 usage delta 为 input 6,077,606、cached input 5,423,104、output 100,914，其中 reasoning output 83,086；这些是 token 计数，不是供应商费用账单。

七个 GM 问题来源归并为一个口粮交接能力。原生建议中的 2.2 米范围及面包归因转移由主协调缩小为 1.5 米、仅普通口粮，不能声称完整实现原 GM 设计。交付提交 `8c023ac`，未知状态界面修正 `a12c464`；离线守恒/冷恢复通过，正式自然采用仍待后续证据。

这些证据证明本轮参与、走动和一次扩展能力采用；长期稳定、无限扩展、所有职业能力和所有交易承诺履约均未据此证明。

## 最终存档 seq450

最终冷恢复：完整 state equal，10 个身份，源文件不变，0 API。life20：16 次请求全部 settled、无新增 unknown、无未排空请求。life19 为正常等待且 0 请求，不计作模型验收通过。

| 居民 | 今夜已结算模型请求 | 已证明最大位移（米） | 最终饱食度 |
| --- | ---: | ---: | ---: |
| 阿岚 | 26 | 52.15 | 49 |
| 白枝 | 30 | 42.85 | 69 |
| 石青 | 23 | 14.02 | 70 |
| 木生 | 32 | 17.53 | 95 |
| 灯姐 | 24 | 34.77 | 86 |
| 草见 | 58 | 46.36 | 39 |
| 叶禾 | 56 | 5.30 | 69 |
| 细娘 | 23 | 23.19 | 65 |
| 渡白 | 30 | 26.70 | 34 |
| 枚青 | 15 | 45.17 | 49 |

草见真实采集事件447 → 进食449，饱食度恢复到39；仅补充通用准确规则，未强制动作。口粮赠予实现尚无自然采用事件。最终费用与 SHA、冷恢复及入口审计见 `private/overnight-20260918/final-acceptance-receipt.json`（位于主仓的私有证据目录）。
