# new-api API 调用指南

## 目录

1. [概述](#1-概述)
2. [认证方式](#2-认证方式)
3. [模型列表](#3-模型列表)
4. [聊天补全 (Chat Completions)](#4-聊天补全-chat-completions)
5. [文本补全 (Completions)](#5-文本补全-completions)
6. [Embedding 嵌入](#6-embedding-嵌入)
7. [图片生成](#7-图片生成)
8. [语音识别与合成 (Audio)](#8-语音识别与合成-audio)
9. [Claude Messages API](#9-claude-messages-api)
10. [Gemini API](#10-gemini-api)
11. [OpenAI Responses API](#11-openai-responses-api)
12. [Rerank 重排序](#12-rerank-重排序)
13. [Moderation 内容审核](#13-moderation-内容审核)
14. [Realtime API (WebSocket)](#14-realtime-api-websocket)
15. [视频生成](#15-视频生成)
16. [Midjourney](#16-midjourney)
17. [Suno 音乐生成](#17-suno-音乐生成)
18. [流式传输 (Streaming)](#18-流式传输-streaming)
19. [Dashboard 兼容 API](#19-dashboard-兼容-api)
20. [高级功能](#20-高级功能)
21. [错误处理](#21-错误处理)

---

## 1. 概述

**new-api** 是一个 AI API 网关/代理系统，它将 40+ 上游 AI 提供商（OpenAI、Claude、Gemini、Azure、百度、阿里、DeepSeek 等）聚合在统一的 API 后面。您无需直接对接各家厂商的不同接口，只需使用 OpenAI 兼容格式（或其他标准格式）调用本系统即可。

### 基础 URL

所有 API 请求的基础 URL 为：

```
http://47.103.129.229:3000
```

### 快速开始

```bash
# 最简单的聊天调用
curl http://47.103.129.229:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

---

## 2. 认证方式

### 2.1 获取 API Key

登录管理后台后，在"令牌"页面创建 API Key。令牌支持三种权限范围：
- **只读 (ReadOnly)**：仅能查询用量和日志
- **所有 (All)**：可调用所有 API
- **自定义 (Custom)**：只允许访问指定模型

### 2.2 使用 API Key

在请求头中通过 `Authorization` 字段传递：

```
Authorization: Bearer sk-xxxxxx
```

### 2.3 与其他系统集成

本系统兼容 OpenAI 的 SDK，可以直接使用：

```python
import openai
openai.api_base = "http://47.103.129.229:3000/v1"
openai.api_key = "sk-xxxxxx"

# 聊天
response = openai.ChatCompletion.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "Hello"}]
)
```

```javascript
import OpenAI from 'openai';

const client = new OpenAI({
  baseURL: 'http://47.103.129.229:3000/v1',
  apiKey: 'sk-xxxxxx',
});

const response = await client.chat.completions.create({
  model: 'gpt-4o',
  messages: [{ role: 'user', content: 'Hello' }],
});
```

---

## 3. 模型列表

### 3.1 查询可用模型

```bash
curl http://47.103.129.229:3000/v1/models \
  -H "Authorization: Bearer sk-xxxxxx"
```

响应示例（OpenAI 格式）：

```json
{
  "object": "list",
  "data": [
    {
      "id": "gpt-4o",
      "object": "model",
      "created": 1700000000,
      "owned_by": "openai"
    },
    {
      "id": "claude-3-5-sonnet-20241022",
      "object": "model",
      "created": 1700000000,
      "owned_by": "anthropic"
    }
  ]
}
```

### 3.2 查询单个模型

```bash
curl http://47.103.129.229:3000/v1/models/gpt-4o \
  -H "Authorization: Bearer sk-xxxxxx"
```

### 3.3 Gemini 格式模型列表

```bash
curl http://47.103.129.229:3000/v1beta/models \
  -H "Authorization: Bearer sk-xxxxxx"
```

### 3.4 管理面板查看价格

```bash
curl http://47.103.129.229:3000/api/pricing
```

返回所有可用模型的定价信息。

---

## 4. 聊天补全 (Chat Completions)

这是最核心的 API，兼容 OpenAI 的聊天补全接口。

### 4.1 基本调用

```bash
curl http://47.103.129.229:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "model": "gpt-4o",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "What is the capital of France?"}
    ]
  }'
```

响应：

```json
{
  "id": "chatcmpl-xxx",
  "object": "chat.completion",
  "created": 1700000000,
  "model": "gpt-4o",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "The capital of France is Paris."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 20,
    "completion_tokens": 7,
    "total_tokens": 27
  }
}
```

### 4.2 流式调用 (Stream)

```bash
curl http://47.103.129.229:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Count from 1 to 5."}],
    "stream": true
  }'
```

### 4.3 多轮对话

```bash
curl http://47.103.129.229:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "model": "gpt-4o",
    "messages": [
      {"role": "user", "content": "What is AI?"},
      {"role": "assistant", "content": "AI stands for Artificial Intelligence."},
      {"role": "user", "content": "Can you elaborate more?"}
    ]
  }'
```

### 4.4 多模态输入（图片理解）

```bash
curl http://47.103.129.229:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "model": "gpt-4o",
    "messages": [
      {
        "role": "user",
        "content": [
          {"type": "text", "text": "What is in this image?"},
          {
            "type": "image_url",
            "image_url": {
              "url": "https://example.com/image.jpg"
            }
          }
        ]
      }
    ],
    "max_tokens": 300
  }'
```

### 4.5 参数说明

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `model` | string | 是 | 模型名称 |
| `messages` | array | 是 | 消息列表 |
| `stream` | boolean | 否 | 是否流式输出，默认 false |
| `max_tokens` | integer | 否 | 最大生成 token 数 |
| `temperature` | number | 否 | 采样温度，0-2，默认 1 |
| `top_p` | number | 否 | 核采样，0-1，默认 1 |
| `n` | integer | 否 | 生成几个回复，默认 1 |
| `stop` | string/array | 否 | 停止词 |
| `presence_penalty` | number | 否 | 话题重复惩罚，-2 到 2 |
| `frequency_penalty` | number | 否 | 频率惩罚，-2 到 2 |
| `logit_bias` | map | 否 | token 偏置 |
| `user` | string | 否 | 用户标识 |
| `seed` | integer | 否 | 随机种子，用于可复现结果 |
| `tools` | array | 否 | 工具调用（函数调用）定义 |
| `tool_choice` | string/object | 否 | 工具选择策略 |

---

## 5. 文本补全 (Completions)

传统的文本补全接口（非聊天格式）。

```bash
curl http://47.103.129.229:3000/v1/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "model": "gpt-3.5-turbo-instruct",
    "prompt": "Once upon a time,",
    "max_tokens": 100,
    "temperature": 0.8
  }'
```

---

## 6. Embedding 嵌入

将文本转换为向量表示。

### 6.1 单文本嵌入

```bash
curl http://47.103.129.229:3000/v1/embeddings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "model": "text-embedding-3-small",
    "input": "The quick brown fox jumps over the lazy dog"
  }'
```

### 6.2 批量文本嵌入

```bash
curl http://47.103.129.229:3000/v1/embeddings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "model": "text-embedding-3-small",
    "input": [
      "First text to embed",
      "Second text to embed",
      "Third text to embed"
    ]
  }'
```

参数说明：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `model` | string | 是 | 嵌入模型名称 |
| `input` | string/array | 是 | 输入文本（字符串或字符串数组） |
| `encoding_format` | string | 否 | 返回格式，`float` 或 `base64` |
| `dimensions` | integer | 否 | 输出维度（部分模型支持） |
| `user` | string | 否 | 用户标识 |

---

## 7. 图片生成

### 7.1 DALL-E / 文生图

```bash
curl http://47.103.129.229:3000/v1/images/generations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "model": "dall-e-3",
    "prompt": "A cute cat wearing a hat, digital art",
    "n": 1,
    "size": "1024x1024",
    "quality": "standard"
  }'
```

参数说明：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `model` | string | 是 | 模型名称 |
| `prompt` | string | 是 | 图片描述 |
| `n` | integer | 否 | 生成图片数量，默认 1 |
| `size` | string | 否 | 尺寸：`256x256`, `512x512`, `1024x1024` 等 |
| `quality` | string | 否 | 质量：`standard` 或 `hd` |
| `style` | string | 否 | 风格：`vivid` 或 `natural` |
| `response_format` | string | 否 | 返回格式：`url` 或 `b64_json` |

### 7.2 图片编辑

```bash
curl http://47.103.129.229:3000/v1/images/edits \
  -H "Authorization: Bearer sk-xxxxxx" \
  -F "image=@/path/to/image.png" \
  -F "mask=@/path/to/mask.png" \
  -F "prompt=Replace the object with a flower" \
  -F "n=1" \
  -F "size=1024x1024"
```

---

## 8. 语音识别与合成 (Audio)

### 8.1 语音转文字 (Transcription)

```bash
curl http://47.103.129.229:3000/v1/audio/transcriptions \
  -H "Authorization: Bearer sk-xxxxxx" \
  -F "file=@/path/to/audio.mp3" \
  -F "model=whisper-1" \
  -F "language=zh"
```

### 8.2 语音翻译 (Translation)

```bash
curl http://47.103.129.229:3000/v1/audio/translations \
  -H "Authorization: Bearer sk-xxxxxx" \
  -F "file=@/path/to/audio.mp3" \
  -F "model=whisper-1"
```

### 8.3 文字转语音 (TTS)

```bash
curl http://47.103.129.229:3000/v1/audio/speech \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "model": "tts-1",
    "input": "Hello, welcome to our service!",
    "voice": "alloy",
    "response_format": "mp3",
    "speed": 1.0
  }' \
  --output speech.mp3
```

参数说明：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `model` | string | 是 | TTS 模型名称 |
| `input` | string | 是 | 要合成的文字 |
| `voice` | string | 是 | 音色：`alloy`, `echo`, `fable`, `onyx`, `nova`, `shimmer` |
| `response_format` | string | 否 | 输出格式：`mp3`, `opus`, `aac`, `flac`, `wav`, `pcm` |
| `speed` | number | 否 | 语速：0.25 到 4.0 |

---

## 9. Claude Messages API

兼容 Anthropic Claude 的消息 API。

```bash
curl http://47.103.129.229:3000/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "model": "claude-3-5-sonnet-20241022",
    "max_tokens": 1024,
    "messages": [
      {"role": "user", "content": "Hello, Claude!"}
    ]
  }'
```

Claude API 特有参数：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `model` | string | 是 | Anthropic 模型名称 |
| `messages` | array | 是 | 消息列表（role 可以是 user/assistant）|
| `max_tokens` | integer | 是 | 最大生成 token 数 |
| `system` | string/array | 否 | System prompt |
| `stream` | boolean | 否 | 是否流式 |
| `temperature` | number | 否 | 采样温度 |
| `top_p` | number | 否 | 核采样 |
| `top_k` | integer | 否 | top-k 采样 |
| `stop_sequences` | array | 否 | 停止序列 |
| `metadata` | object | 否 | 用户标识等元数据 |

---

## 10. Gemini API

支持 Google Gemini 的原生 API。

### 10.1 文本生成

```bash
curl http://47.103.129.229:3000/v1beta/models/gemini-2.0-flash:generateContent \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "contents": [
      {
        "role": "user",
        "parts": [{"text": "Explain quantum computing"}]
      }
    ],
    "generationConfig": {
      "temperature": 0.7,
      "maxOutputTokens": 2048
    }
  }'
```

### 10.2 流式生成

```bash
curl http://47.103.129.229:3000/v1beta/models/gemini-2.0-flash:streamGenerateContent \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "contents": [
      {
        "role": "user",
        "parts": [{"text": "Tell me a story"}]
      }
    ]
  }'
```

### 10.3 Gemini 多模态

```bash
curl http://47.103.129.229:3000/v1beta/models/gemini-2.0-flash:generateContent \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "contents": [
      {
        "role": "user",
        "parts": [
          {"text": "What is in this photo?"},
          {
            "inlineData": {
              "mimeType": "image/jpeg",
              "data": "/9j/4AAQ..."  // base64 encoded image
            }
          }
        ]
      }
    ]
  }'
```

---

## 11. OpenAI Responses API

支持 OpenAI 新的 Responses API。

```bash
curl http://47.103.129.229:3000/v1/responses \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "model": "gpt-4o",
    "input": "What is the meaning of life?",
    "temperature": 0.7,
    "max_output_tokens": 500
  }'
```

Responses 压缩：

```bash
curl http://47.103.129.229:3000/v1/responses/compact \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "model": "gpt-4o",
    "input": "Hello",
    "previous_response_id": "resp_xxxxxx"
  }'
```

---

## 12. Rerank 重排序

对文档进行相关性重排序（主要用于 RAG 场景）。

```bash
curl http://47.103.129.229:3000/v1/rerank \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "model": "jina-reranker-v2-base-multilingual",
    "query": "What is artificial intelligence?",
    "documents": [
      "AI is the simulation of human intelligence in machines.",
      "Paris is the capital of France.",
      "Machine learning is a subset of AI."
    ],
    "top_n": 3
  }'
```

---

## 13. Moderation 内容审核

```bash
curl http://47.103.129.229:3000/v1/moderations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "model": "text-moderation-latest",
    "input": "I want to harm someone"
  }'
```

---

## 14. Realtime API (WebSocket)

OpenAI Realtime API 通过 WebSocket 连接。

```bash
# 使用 wscat 工具
wscat -c "ws://47.103.129.229:3000/v1/realtime?model=gpt-4o-realtime-preview-2024-10-01" \
  -H "Authorization: Bearer sk-xxxxxx"
```

连接后发送 JSON 消息（详见 OpenAI Realtime API 文档）。

---

## 15. 视频生成

### 15.1 OpenAI 兼容视频接口

```bash
# 创建视频生成任务
curl http://47.103.129.229:3000/v1/video/generations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "model": "sora-2",
    "prompt": "A cat walking on a sunny beach"
  }'

# 查询任务状态
curl http://47.103.129.229:3000/v1/video/generations/:task_id \
  -H "Authorization: Bearer sk-xxxxxx"
```

### 15.2 Kling 视频生成

```bash
# 文生视频
curl http://47.103.129.229:3000/kling/v1/videos/text2video \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "model": "kling-1.6",
    "prompt": "A dog running in the park"
  }'

# 图生视频
curl http://47.103.129.229:3000/kling/v1/videos/image2video \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "model": "kling-1.6",
    "image": "https://example.com/input.jpg",
    "prompt": "Make this image animate"
  }'
```

### 15.3 即梦 (Jimeng) 视频

```bash
curl http://47.103.129.229:3000/jimeng/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "model": "jimeng-2.0",
    "prompt": "A cinematic shot of mountains"
  }'
```

---

## 16. Midjourney

### 16.1 文生图

```bash
curl http://47.103.129.229:3000/mj/submit/imagine \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "prompt": "A beautiful landscape, digital art --ar 16:9",
    "notify_hook": "https://your-server.com/callback"
  }'
```

### 16.2 图生图 (Blend)

```bash
curl http://47.103.129.229:3000/mj/submit/blend \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "base64Array": [
      "data:image/png;base64,xxx",
      "data:image/png;base64,yyy"
    ],
    "dimensions": {
      "width": 1024,
      "height": 1024
    }
  }'
```

### 16.3 图片放大 (Upscale)

```bash
curl http://47.103.129.229:3000/mj/submit/change \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "action": "UPSCALE",
    "taskId": "xxx-task-id",
    "index": 1
  }'
```

### 16.4 图片变体 (Variation)

```bash
curl http://47.103.129.229:3000/mj/submit/change \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "action": "VARIATION",
    "taskId": "xxx-task-id",
    "index": 2
  }'
```

### 16.5 查询任务

```bash
# 查询单个任务
curl http://47.103.129.229:3000/mj/task/:id/fetch \
  -H "Authorization: Bearer sk-xxxxxx"

# 查询多个任务（按条件）
curl http://47.103.129.229:3000/mj/task/list-by-condition \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "ids": ["id1", "id2"]
  }'
```

### 16.6 图片 Seed 提取

```bash
curl http://47.103.129.229:3000/mj/image-seed \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "imageUrl": "https://example.com/image.png"
  }'
```

### 16.7 换脸

```bash
curl http://47.103.129.229:3000/mj/insight-face/swap \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "sourceBase64": "data:image/png;base64,xxx",
    "targetBase64": "data:image/png;base64,yyy"
  }'
```

---

## 17. Suno 音乐生成

### 17.1 生成音乐

```bash
curl http://47.103.129.229:3000/suno/submit/music \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "prompt": "A cheerful pop song about summer",
    "style": "pop",
    "title": "Summer Day",
    "custom": false,
    "instrumental": false
  }'
```

### 17.2 查询音乐任务

```bash
# 按 ID 查询
curl http://47.103.129.229:3000/suno/fetch/:id \
  -H "Authorization: Bearer sk-xxxxxx"

# 批量查询
curl http://47.103.129.229:3000/suno/fetch \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "ids": ["id1", "id2"]
  }'
```

---

## 18. 流式传输 (Streaming)

### 18.1 Chat Completions 流式

```bash
curl http://47.103.129.229:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Tell me a long story"}],
    "stream": true
  }'
```

流式响应每行以 `data: ` 开头，格式如下：

```
data: {"id":"chatcmpl-xxx","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"content":"Once"},"finish_reason":null}]}

data: {"id":"chatcmpl-xxx","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"content":" upon"},"finish_reason":null}]}

...

data: [DONE]
```

### 18.2 流式选项

支持 `stream_options` 参数，可以在流式结束时返回用量统计：

```json
{
  "model": "gpt-4o",
  "messages": [{"role": "user", "content": "Hello"}],
  "stream": true,
  "stream_options": {
    "include_usage": true
  }
}
```

### 18.3 Claude 流式

```bash
curl http://47.103.129.229:3000/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "model": "claude-3-5-sonnet-20241022",
    "max_tokens": 1024,
    "stream": true,
    "messages": [{"role": "user", "content": "Tell me a story"}]
  }'
```

### 18.4 各语言 SDK 流式调用

Python:

```python
import openai
openai.api_base = "http://47.103.129.229:3000/v1"
openai.api_key = "sk-xxxxxx"

response = openai.ChatCompletion.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "Count to 10"}],
    stream=True
)

for chunk in response:
    if chunk.choices[0].delta.get("content"):
        print(chunk.choices[0].delta.content, end="")
```

JavaScript:

```javascript
import OpenAI from 'openai';

const client = new OpenAI({
  baseURL: 'http://47.103.129.229:3000/v1',
  apiKey: 'sk-xxxxxx',
});

const stream = await client.chat.completions.create({
  model: 'gpt-4o',
  messages: [{ role: 'user', content: 'Count to 10' }],
  stream: true,
});

for await (const chunk of stream) {
  process.stdout.write(chunk.choices[0]?.delta?.content || '');
}
```

---

## 19. Dashboard 兼容 API

兼容 OpenAI 的用量查询接口。

### 19.1 查询订阅信息

```bash
# 多个 path 均可访问
curl http://47.103.129.229:3000/dashboard/billing/subscription \
  -H "Authorization: Bearer sk-xxxxxx"

curl http://47.103.129.229:3000/v1/dashboard/billing/subscription \
  -H "Authorization: Bearer sk-xxxxxx"
```

### 19.2 查询用量

```bash
curl "http://47.103.129.229:3000/dashboard/billing/usage?start_date=2025-01-01&end_date=2025-01-31" \
  -H "Authorization: Bearer sk-xxxxxx"
```

---

## 20. 高级功能

### 20.1 模型映射

如果管理员配置了模型映射，您请求的模型名会被自动映射。例如配置 `{"gpt-4": "claude-3-5-sonnet-20241022"}` 后，请求 `gpt-4` 会实际使用 Claude 模型。

### 20.2 令牌模型限制

您创建的 API 令牌可以限制为只能访问特定的模型列表。超过限制会返回 403 错误。

### 20.3 分组系统

- **用户分组**：`default`、`vip` 等
- **渠道分组**：渠道可以归属不同分组
- **匹配规则**：用户只能使用其分组对应的渠道

### 20.4 Playground 测试

管理面板中可以使用 Playground 快速测试：

```bash
curl http://47.103.129.229:3000/pg/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### 20.5 查询令牌用量

```bash
curl http://47.103.129.229:3000/api/usage/token/ \
  -H "Authorization: Bearer sk-xxxxxx"
```

### 20.6 查询自身日志

```bash
curl http://47.103.129.229:3000/api/log/self \
  -H "Authorization: Bearer sk-xxxxxx"

# 搜索日志
curl "http://47.103.129.229:3000/api/log/self/search?keyword=test&page=1" \
  -H "Authorization: Bearer sk-xxxxxx"
```

---

## 21. 错误处理

### 21.1 HTTP 状态码说明

| 状态码 | 含义 | 说明 |
|--------|------|------|
| 200 | 成功 | 请求成功完成 |
| 400 | 请求错误 | 请求参数有误 |
| 401 | 未认证 | API Key 缺失或无效 |
| 403 | 无权限 | API Key 无权限访问该模型 |
| 429 | 频率限制 | 请求过于频繁，请稍后重试 |
| 500 | 服务端错误 | 上游服务出错或内部异常 |
| 502 | 上游错误 | 上游 AI 提供商返回错误 |

### 21.2 错误响应格式

```json
{
  "error": {
    "message": "当前分组上游负载已饱和，请稍后再试",
    "type": "api_error",
    "param": null,
    "code": "insufficient_quota"
  }
}
```

### 21.3 常见错误及处理

| 错误信息 | 可能原因 | 处理方式 |
|----------|----------|----------|
| `insufficient_quota` | 额度不足 | 充值或联系管理员 |
| `当前分组上游负载已饱和` | 渠道不可用 | 稍后重试 |
| `model not found` | 模型不存在或未配置 | 检查模型名称 |
| `invalid_api_key` | API Key 无效 | 检查 API Key |
| `rate limit exceeded` | 触发限流 | 降低请求频率 |
| `stream timeout` | 流式请求超时 | 增大超时设置或减少生成量 |

---

## 附录

### A. 常用 curl 请求模板

```bash
# Chat Completions
curl http://47.103.129.229:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{"model": "gpt-4o", "messages": [{"role": "user", "content": "Hello"}]}'

# 流式 Chat
curl -N http://47.103.129.229:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{"model": "gpt-4o", "messages": [{"role": "user", "content": "Hello"}], "stream": true}'

# Embeddings
curl -N http://47.103.129.229:3000/v1/embeddings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{"model": "text-embedding-3-small", "input": "Hello world"}'

# 图片生成
curl http://47.103.129.229:3000/v1/images/generations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxx" \
  -d '{"model": "dall-e-3", "prompt": "A cat", "n": 1, "size": "1024x1024"}'
```

### B. 各语言 SDK 调用示例

Python:

```python
import openai

openai.api_base = "http://47.103.129.229:3000/v1"
openai.api_key = "sk-xxxxxx"

# 聊天
response = openai.ChatCompletion.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "Hello"}]
)
print(response.choices[0].message.content)

# Embeddings
response = openai.Embedding.create(
    model="text-embedding-3-small",
    input="Hello world"
)
print(response.data[0].embedding)

# 图片生成
response = openai.Image.create(
    model="dall-e-3",
    prompt="A cute cat",
    n=1,
    size="1024x1024"
)
print(response.data[0].url)
```

JavaScript:

```javascript
import OpenAI from 'openai';

const client = new OpenAI({
  baseURL: 'http://47.103.129.229:3000/v1',
  apiKey: 'sk-xxxxxx',
});

// 聊天
const chatResponse = await client.chat.completions.create({
  model: 'gpt-4o',
  messages: [{ role: 'user', content: 'Hello' }],
});
console.log(chatResponse.choices[0].message.content);

// Embeddings
const embResponse = await client.embeddings.create({
  model: 'text-embedding-3-small',
  input: 'Hello world',
});
console.log(embResponse.data[0].embedding);

// 图片生成
const imgResponse = await client.images.generate({
  model: 'dall-e-3',
  prompt: 'A cute cat',
  n: 1,
  size: '1024x1024',
});
console.log(imgResponse.data[0].url);
```

### C. 支持的主要模型示例

| 模型名称 | 类型 | 说明 |
|----------|------|------|
| `gpt-4o` / `gpt-4o-mini` | Chat | OpenAI 最新模型 |
| `claude-3-5-sonnet-20241022` | Chat | Anthropic Claude |
| `claude-3-opus-20240229` | Chat | Anthropic Claude Opus |
| `deepseek-chat` / `deepseek-reasoner` | Chat | DeepSeek |
| `gemini-2.0-flash` / `gemini-2.5-pro` | Chat | Google Gemini |
| `qwen-max` / `qwen-plus` | Chat | 阿里通义千问 |
| `glm-4-plus` | Chat | 智谱 GLM |
| `ERNIE-4.0` | Chat | 百度文心 |
| `text-embedding-3-small` / `text-embedding-3-large` | Embedding | OpenAI 嵌入 |
| `dall-e-3` | Image | OpenAI 图片生成 |
| `whisper-1` | Audio | 语音转文字 |
| `tts-1` / `tts-1-hd` | Audio | 文字转语音 |

实际可用模型以系统管理员配置为准，可通过 [查询模型列表](#31-查询可用模型) 接口获取。
