# Jev 本地部署说明（Windows）

当前部署的是 `githubnext/localjev`：它把本地模型包装成 Jev 的 `POST /v1/systemone` 接口。官方 Jev 权重仍是闭源远程服务，无法直接下载；本方案完全本地运行，但概率来自本地模型生成与校准，不等同官方 Jev 的原始 logits。针对 Ollama，适配层会调用原生 `/api/chat` 并关闭 Qwen3 思考通道。

## 启动

1. 双击仓库根目录的 `StartOllama.cmd`（保持窗口运行）。
2. 首次需要模型时，双击仓库根目录的 `PullJevModel.cmd`；它会下载约 5.2 GB 的 `qwen3:8b`。也可以在 PowerShell 执行：

   ```powershell
   & "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe" pull qwen3:8b
   ```

3. 双击 `StartLocalJev.cmd`。8B 模型允许一次处理多个问题，脚本已将分组上限调高。
4. 健康检查：`http://127.0.0.1:8080/ready`。

`qwen3:8b` 是本机 GPU 友好的本地模型；它仍然是 Jev 风格的结构化判断，不是官方 Jev 权重。

## 给 NPC 选择模型

`POST /v1/route` 只判断这次思考应该交给哪类模型，不直接调用云模型，也不
写世界存档。普通短回合可以交给本地 `qwen3:8b`；对话升级到 `cloud_social`；
故事关键任务升级到 `cloud_story_critical`；不可逆、稀缺资源或多方事务直接
交给 `gm_review`。置信度低于 0.75 的普通路由会回退到 `cloud_social`。

```powershell
$route = @{
  state = @{ resident = "Rowan"; action = "walk_to_known_place" }
  task_type = "resident_turn"
  requires_dialogue = $false
  irreversible = $false
  scarce_resource = $false
  story_critical = $false
  multi_party = $false
} | ConvertTo-Json -Depth 8
Invoke-RestMethod http://127.0.0.1:8080/v1/route -Method Post `
  -ContentType 'application/json' -Headers @{Authorization='Bearer local-dev-key'} -Body $route
```

返回的 `selected_model` 是路由建议。InfiniteAincrad 接入时仍需由宿主的
provider multiplexer 执行它，并把 `router_model`、路由、置信度、最终模型和
回退原因写入该回合 receipt；LocalJev 不得直接改变 Kimi/GM 账本。

## API 示例

```powershell
$body = @{
  model = "jev-latest"
  state = "我连续两次被扣款，需要退款。"
  questions = @{
    intent = @{ type = "choice"; instructions = "这是什么类型的问题？"; criteria = @{ billing = "账单或扣款"; bug = "技术故障"; other = "其他" } }
    urgent = @{ type = "noul"; instructions = "是否需要立即人工处理？" }
    sentiment = @{ type = "score"; instructions = "用户有多生气？"; criteria = @("平静", "不满", "非常生气") }
  }
} | ConvertTo-Json -Depth 8
Invoke-RestMethod http://127.0.0.1:8080/v1/systemone -Method Post -ContentType 'application/json' -Headers @{Authorization='Bearer local-dev-key'} -Body $body
```
