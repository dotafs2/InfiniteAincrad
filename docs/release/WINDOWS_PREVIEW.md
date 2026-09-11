# 构建 Windows 技术预览

P1 的第一个交付对象是现有井边事件的离线 Windows x64 包。玩家解压后启动 EXE，
开发者才需要以下工具。真实模型、原 13 人世界与社区采用情况分别验收。

## 固定基线

- [官方 Godot 4.7.2 .NET Windows 编辑器和 .NET 导出模板](https://godotengine.org/download/archive/4.7.2-stable/)。
  `--version` 必须为 `4.7.2.stable.mono.official.ed1daf0bf`；普通非 .NET 编辑器不适用。
- 本机与 CI 的已选构建 SDK 为 .NET `9.0.200`；项目目标 `net8.0`，随包运行时固定 `8.0.31`。
  版本依据 [Microsoft .NET 8 发布元数据](https://builds.dotnet.microsoft.com/dotnet/release-metadata/8.0/releases.json)，查询于 2026-09-10。
- Python 3.11+、Git 和 Git LFS；OGA 上游版本与源码哈希见 `third_party/opengameagent.lock.json`。
- 由维护者下载工具时，先对照 Godot 官方发布的 `SHA512-SUMS.txt`；本机已验证的值见下。

| 官方文件 | SHA512 |
|---|---|
| `Godot_v4.7.2-stable_mono_win64.zip` | `79229fd112b0c9cbeab82363a4ef7be18ea70f1caf86bf912789335b136fbe7e01db0053a33461438c5da1c680c17bbb10040bd09bedc51221cd4423d0367757` |
| `Godot_v4.7.2-stable_mono_export_templates.tpz` | `bb5c41d72370ed743660361f6228006f808ab04ca33abdc545d740b044f3fe057f32ae8cb7873a1bc86ddcd82ae683b9f6dfdfe4179852f2c0f1acde2ff6bd5a` |

模板安装到 Godot 的标准导出模板目录。若编辑器旁有 `_sc_`，使用便携目录
`editor_data/export_templates/4.7.2.stable.mono/`，保留 `version.txt` 和 Windows 模板文件。
CI 使用固定 SHA 的 [setup-godot Action](https://github.com/chickensoft-games/setup-godot/tree/46198e5e97e81c09d8001962fdf4ed8c215bcb50) 安装工具和模板；工作流不发布包。

## 一条构建命令

```powershell
git lfs pull
git lfs fsck
./Build-WindowsPreview.ps1 -Godot C:/Tools/Godot/Godot_v4.7.2-stable_mono_win64_console.exe
```

也可用 `GODOT_EXE` 或 PATH 中的 `godot`。默认输出到新的 `exports/windows-<UTC时间>/`。
`-Output <新目录>` 适合指定验收批次；如果目录已存在则拒绝覆盖。缓存只写入忽略目录 `tmp/`。
不在脚本中硬编码代理；有网络代理需求时由开发者进程环境配置。

构建先从当前源码复制一份不含缓存的快照并记录逐文件哈希、检查 59 个上游文件。
所有编译和 Godot 导出都在此快照内运行，避免 ExportRelease 恢复操作改写工作区的上游锁文件。
随后依次恢复锁定 NuGet 依赖、编译 C#、导入市场、执行现有五组规则/知识/OGA/恢复检查、
执行独立进程写入与恢复、导出并检查 EXE/PCK/.NET 运行时，再附带告知文本和 SHA256 清单。
Godot 有时会在导出失败时返回退出码 0，因此同时检查错误日志和运行时文件是否真正存在。
GLB 导入采用嵌入纹理，避免把临时解包 PNG 当作新的美术源；UID 和导入参数纳入版本控制。

最后将 ZIP 解压到含空格的新路径，清除模型配置环境，以不含 Godot/dotnet 的 PATH
和无全局 .NET 的查找配置运行发布 EXE。离线帮助事件通过后再启动新进程，要求恢复不改变存档字节。
这些是同一主机上的隔离测试，**不是一台没有安装运行库的新机器，也不是外部测试者验收**。
CI 使用 headless 模式，不生成画面；图形模式截图需另行核验。

对同一份解压后的包做图形复核：

```powershell
python tools/verify_windows_preview.py --package "C:/Preview/InfiniteAincrad-0.0.1-preview-win-x64" --output "exports/my-rendered-check" --rendered
```

验证器使用实际时间和帧率上限。不要用 `--fixed-fps` 加速这个包含物理到达与异步 C# 决策的场景；
此前这会让渲染帧中的计时先于物理和异步工作推进，造成误超时。

成功时会写 `validation.json`，失败时只留下相应过程日志与部分产物，不声称可发布。
每个长进程记录 PID、命令、超时和退出状态；只终止本次任务自己启动的进程。
构建不读取或发送私人存档，不使用付费模型，不上传 GitHub release。

## 外部验收记录

授权范围通过后，邀请三位首次接触的测试者独立解压运行。维护者不代操作。
每人记录：机器/显卡、启动用时、是否理解 E 的帮助效果、是否观察到水量变化、
是否在 15 分钟内关闭重启并认出原有结果、出现的问题和自己的描述。
三人均能启动、至少两人理解并完成干预及恢复后，P1 才通过外部验收。
未完成的测试保留失败原因，不改写成成功。

公开前另需完成 [授权范围确认](RIGHTS_REVIEW.md)。本地产物先供维护者审阅；
P2 的附近询问/拒绝、P3 的三人/两种真实模型连续性和 P5 的实际外部贡献各自保留独立证据。
