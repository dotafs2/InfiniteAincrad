InfiniteAincrad 0.0.1 技术预览 — Windows x64

完整解压文件夹，双击 InfiniteAincrad.exe。保留旁边的 PCK 和 data 文件夹。
无需 Godot 编辑器、.NET SDK、Python 或 API 密钥。

WASD 移动；点击窗口控制视角，Esc 释放鼠标；F8 显示诊断。
跟随居民到井边，等待她提出请求。靠近井边按 E 提供绳子和水桶。
观察取水、喝水及水量变化，关闭窗口，再次启动检查同一事件的结果。
你也可以不提供帮助，居民会保留尚未满足的请求。

存档位置：
%APPDATA%\Godot\app_userdata\InfiniteAincrad - Starting Town Street\technical-preview\world.json
保留这个文件即可继续。关闭游戏后再备份；损坏文件会报错，不会自动重置。
预览使用单独的存档位置。不要同时打开两个窗口写同一存档。

本包使用明确标注的离线规则示例。人物是临时几何体；默认事件展示 Luna。
这次预览没有联网模型决策。已有的两人真实模型验证另见源仓库证据。
当前验证以 Windows x64 为目标；显卡需要支持 Vulkan。
如果默认渲染无法启动，可在本目录终端运行：
  .\InfiniteAincrad.exe --rendering-method gl_compatibility
兼容渲染路径仍需你的机器验证。错误日志位于存档目录上一层的 logs 中。

反馈时说明 Windows/显卡型号、启动是否成功、卡在哪一步、重启后发生了什么。
不要发送密钥或私人存档。build-info.json 与 SHA256.json 标识这一份构建。

项目：https://github.com/dotafs2/InfiniteAincrad
本地产物用于预发布审阅。原创代码、美术和文档的通用再分发授权仍在确认。
第三方组件的现有许可证见 licenses 与 THIRD_PARTY_NOTICES.md。
