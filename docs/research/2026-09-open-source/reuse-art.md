# 美术复用评审（D）

核验日：2026-09-10。首版受众暂定为 Godot/独立游戏贡献者和 AI/美术协作者。本轮只研究，不下载、安装、导入或付费。当前已有约 114 MB 的自制市场 GLB、约 34 MB 的可编辑 Blend、程序纹理和占位人物；目标是尽快让首条街的居民可读，绝不重做全城。现有 MarketCraftV5 应继续作为场景基线。

## 结论矩阵

| 方案 | 现在有限试验 | 保留现有 | 触发条件出现再加 | 不采用 |
|---|---|---|---|---|
| Quaternius Platformer Game Kit（官方包页） | 只取一个角色，验证 Idle/Walk/交流姿态和 Godot GLB 导入 | 市场建筑、碰撞和材质 | 验收通过且人物比例能融入市场，再替换一个占位居民 | 不整包并入，不扩角色阵容 |
| Kenney UI Pack、Interface Sounds | 仅做事件提示按钮和交互点击/确认声 | 现有街道 UI 逻辑与离线提示 | 首版需要公开演示反馈且能保持字体/色板一致时加入 | 不拿 City Kit 重做市场 |
| Poly Haven Fine Grained Wood（1K/2K） | 仅试木台面或井边一张小 PBR 材质 | 现有自制纹理仍是默认 | 近景材质验收通过、包内许可证随文件复核后再加 | 不把 4K/8K 贴图整库带入 |
| Blender 原生 glTF 2.0 | 建一个最小“动作命名—导出—Godot播放”试件 | 当前 Blender 建模脚本和 GLB | 试件能冷开、动作不漂移且可回退时固化流程 | 不引入额外转换器或平行引擎 |
| Mixamo（热门否决） | 无 | — | 只有能取得可再分发的明确条款并通过贡献者复核才重新审查 | 首版不采用 |

## 逐项证据与接入边界

**1. Quaternius Platformer Game Kit（优先人物包）。** 官方页列出 112 个模型、FBX/OBJ/Blend/glTF，明确“角色含 18 个动画”，并标 Creative Commons Zero；页面还称个人和商业项目可用：[官方包页](https://quaternius.com/packs/ultimateplatformer.html)。这是真正免费的资产包，不是开源代码库；下载仍须把 ZIP 内 LICENSE 和所选文件哈希写进 `PROVENANCE.md`，当前只能称“页面声明 CC0”，不能预先替包内每个文件背书。一个角色可望省掉占位人物网格、基础骨骼、待机/移动制作；交流动作是否包含可读手势必须以包内动作清单实查，不能由“18 个动画”推断。接入验收：GLB 在 Godot 4.7.2 导入无缺材质；身高、脚底和碰撞盒与现有井边尺度匹配；Idle/Walk 循环不滑步；至少一个 Wave/Point/Look 类动作（若没有，则保留程序化转身和气泡）；冷启动、存档及 Luna/Mira 的知识逻辑不变。假设估算为 0.5–1.5 个工作日，未实测。失败就删除试件并继续占位人物，退出成本小。可另看其 [RPG Character Pack](https://quaternius.com/packs/rpgcharacters.html)：6 个 rigged/animated/textured 角色，FBX/OBJ/Blend/glTF、CC0，但首轮不同时引入两套人物风格。

Quaternius 的 [Universal Animation Library](https://quaternius.itch.io/universal-animation-library) 是补充而非首选人物包：页面写明 120+ 通用人形动作、8 方向移动、emote、Root Motion 开关、Godot 可用和 CC0；Standard 15 MB 免费，Pro/Source（含 Blend）分别要求 9.99/14.99 美元。它只有动画库，需另有兼容骨骼，且根运动会改变移动权威；故只在首个角色包缺交流动作且最小试件证明可重定向时再加。

**2. Kenney。** [UI Pack](https://kenney.nl/assets/ui-pack) 是 430 个 2D 文件，官方标 CC0，含 button/panel/slider；[Interface Sounds](https://kenney.nl/assets/interface-sounds) 是 100 个音频文件，亦标 CC0。它们是免费资产（可捐赠，不是开源程序），格式和压缩方式应在下载包内复核。可节省手工按钮边框、状态反馈和点击声制作，但 UI 的扁平鲜艳风格可能冲淡市集的低多边形材质。验收需在 1280×720 与窗口缩放下无裁切，提示仍能表达“居民请求/玩家帮助/拒绝”，音频导入不改离线判定；假设 0.25–0.5 日。退出方案是删除资源，恢复现有文字面板。Kenney City Kit 虽热门，和自制市场比例、材质及所有权记录冲突，故不扩城。

**3. Poly Haven。** 以 [Fine Grained Wood](https://polyhaven.com/a/fine_grained_wood) 为具体小试件：页面给出 1K–8K、AO/rough/metal、diffuse、DX/GL normal、ZIP/Blend/glTF，并明确 CC0。其 [FAQ](https://docs.polyhaven.com/en/faq) 解释所有资产均 CC0，可商用、可随产品分发，但不得冒称作者或重新许可，建议保留来源链接。木纹可节省一次近景 PBR 贴图制作，却与现有程序化、手绘化市场风格有写实冲突；只取 1K/2K 的木台面，不改建筑主材。验收需检查色彩空间、法线方向、Godot Forward+ 性能、许可证文件和源链接；假设 0.5 日，未实测。若太写实或包体增加，删除材质并回退现有纹理。Poly Haven 的 Brick Pavement/Red Brick 也为 CC0，但 4K/8K 体积与首版收益不成比例，延后。

**4. Blender 原生方法。** Blender 官方 [glTF 2.0 手册](https://docs.blender.org/manual/en/dev/addons/scene_gltf2.html)说明 `.glb/.gltf` 的导入导出、动作/NLA 和骨骼/形态键；动作模式下只有当前 Action 或已 stash 到 NLA 的 Action 才会导出，物体变换、pose bones、shape keys 才是稳定支持范围。它不是资产来源或“开源素材”，而是当前 Blend→GLB 的可复现工具链。接入验收：动作名称固定、无双根骨、米制比例正确、嵌入纹理可重载、Godot 动画树可播放，且保留原 Blend 作为退出源；假设 0.5–1 日。失败时直接使用原 GLB/占位体，不添加第三方转换器。

**维护与依赖的共同门槛。** 贡献者能重做比“今天下载成功”更重要：来源页、下载日期、压缩包哈希、包内许可证、导入设置和删减清单必须同行记录。Quaternius 的网页和 itch 下载由作者维护，但本项目不能依赖 Patreon、Discord 或在线服务才能运行；选定 GLB、动作清单和许可证固定后，Godot 打开工程应不访问外网。Kenney 与 Poly Haven 页面会更新，版本不固定时不能把后来新增文件当作当前授权证据；每次换包都要重查。Blender 版本变化会影响 NLA 合并行为，升级需重跑动作和冷启动检查。复用能省搜集、切片和部分手工绘制，但不能把假设工时写成已验证收益。

**热门选择的否决：Mixamo。** Adobe FAQ称其角色和动画可免费、免版税用于个人、商业和非营利游戏，并且服务只支持二足人形；但它是在线服务与 Adobe ID 依赖，不是 CC0 开源资产库，页面没有给本项目所需的“源文件、修改后文件及打包分发”审计清单：[Adobe FAQ](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html)。因此不能从“免费”推论可随仓库再分发，也不能用它替 Quaternius 的明确 CC0；除非未来取得逐文件许可证据、可离线保存和贡献者复核，否则不采用。

## 第一轮判断与重审条件

我的票是：有限试验 Quaternius Platformer 单角色；保留现有街道和人物逻辑；Kenney UI/Interface Sounds 与 Poly Haven 木材只做小范围可逆试件；Blender glTF 流程作为验收工具；不引入 Mixamo、City Kit 或大批新环境。判断可被以下证据推翻：人物包缺少可读交流动作或比例破坏镜头可读性；Godot 导入出现骨骼/材质/根运动错误；包内许可证与官方页面不一致；或任何资源使保存、知识隔离、首街性能回归。满足任一条件就回退占位艺术并把触发记录在后续评审中。

这份建议刻意把“风格完整”放在“资产数量”之前：居民脸部、轮廓、动作节奏和井边交互距离先过关，市场仍以已有作者资产维持统一视觉。任何新增文件都必须能单独移除，不得成为世界连续性或存档格式的隐性依赖。

## 交叉质询回应（第二轮）

**给 E 的导航问题。** 我不能声称已测得市场尺度，因此以下是一次可证伪的假设试件，不改世界规则：按现有成人占位体先设胶囊半径 0.32 m、高 1.80 m，NavigationAgent3D 半径 0.34 m、高 1.80 m，井边到达阈值 0.60 m；实际导入角色若包围盒不同，必须以 Blender/Godot 实测身高同比缩放，不能悄悄改事件半径。行走面只来自市场地面和 22 个现有碰撞代理，导航网格向障碍收缩至少代理半径，坡度先限 35°、可跨台阶先限 0.20 m；每个路径段应在网格内，并以胶囊 sweep 检查与墙体无交，起点、终点和井边截图及断言固定。导航拥有位置，根运动关闭或仅取骨骼姿态；若动画 GLB 带 root translation，导入时清除/忽略位移，避免动画把人物推穿墙。验收是绕障到达、全程无碰撞、冷启动位置一致；失败即回退占位体和直线 fixture，不改变存档或消息规则。

**给根代理的回应与改变。** 我接受“消息/分发优先”的反对理由，撤回本轮即时 Poly Haven 木材试验；它不比邻居消息和可分发包更重要。木材只保留为“单角色一次试验通过、消息路径验收后，且镜头确实暴露近景材质缺口”才触发的候选，仍限一张 1K/2K 可删材质。Kenney UI/音效也只在不阻塞消息验收的微型提示试件中保留；不得并行扩充环境。

**许可证表述修正。** Poly Haven 的 CC0 意味着可复制、修改、分发和商用；“不得重新许可”不应写成禁止对衍生作品设条款。准确说法是：不能冒称原作者，也不能把原公共领域素材本身变成他人不得自由使用的专有权；项目可对自己的新增组合/代码另行授权，但必须保留来源说明并随包复核许可证。今后以包内文本和官方 FAQ 双重核验。
