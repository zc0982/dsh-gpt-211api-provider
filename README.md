# DSH GPT 211API Provider

DeepSeek Harness 的 GPT 211API Provider 配置插件，为 GPT-5.6 Sol、Terra、Luna 提供完整的可选思考等级，并显式按 OpenAI-compatible `reasoning_effort` 字段发送选择结果。

## 功能

- 注册 `gpt-211api` Provider，接口为 `https://www.211api.com/v1`。
- 提供 GPT-5.6 Sol、GPT-5.6 Terra、GPT-5.6 Luna。
- 每个推理模型提供 `off`、`low`、`medium`、`high`、`xhigh`、`max` 六档选择。
- 保留 Codex Auto Review 与 GPT Image 2 模型入口。
- 将新会话默认模型设为 GPT-5.6 Sol，默认思考等级设为 `high`。
- 复用 DSH 内置的 `@deepseek-ai/dsh-llm-pi-ai`，不复制协议、凭据或流式处理实现。

## 要求

- DeepSeek Harness `0.1.0-rc.7` 或更高版本。
- Node.js `^22.19.0` 或 `>=24.0.0`。
- 一个有效的 211API API Key。

## 安装

从 GitHub 安装指定版本：

```bash
dsh plugin --profile web add -w github:zc0982/dsh-gpt-211api-provider#v0.1.0
```

也可以下载 GitHub Release 中的 `.tgz` 后安装：

```bash
dsh plugin --profile web add -w ./zc0982-dsh-gpt-211api-provider-0.1.0.tgz
```

安装后刷新已运行的 GUI，或重新启动 DSH。

## 配置凭据

插件只保存凭据引用，不包含或提交 API Key。把密钥保存为 `GPT_211API_API_KEY`：

- 推荐：在 Web GUI 的“设置 → 模型”中为 GPT 211API 填写 API Key。
- 或在启动 DSH 前导出环境变量：

```bash
export GPT_211API_API_KEY='your-api-key'
```

## 思考等级映射

| GUI 选项 | Wire 值 |
| --- | --- |
| `off` | 不发送 `reasoning_effort` |
| `low` | `low` |
| `medium` | `medium` |
| `high` | `high` |
| `xhigh` | `xhigh` |
| `max` | `max` |

Provider 配置显式设置 `supportsReasoningEffort: true`，避免自定义域名依赖 URL 猜测。

## 覆盖配置

Bundle 层只提供默认配置。用户仍可通过 `$DSH_HOME/settings.yaml` 中的 `llm-pi-ai` section 或 Web GUI 模型设置覆盖 Provider、模型和端点。DSH 的 profile/home patch 层也可以覆盖本插件写入的 `llm-pi-ai` 与 `agent-default-model` 行。

## 卸载

```bash
dsh plugin --profile web remove -w @zc0982/dsh-gpt-211api-provider
```

## 开发

```bash
DSH_CHECKOUT=/path/to/deepseek-harness npm run build
npm pack
```

## License

MIT
