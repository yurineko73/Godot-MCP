# Godot MCP 迁移指南

## 简介

本指南将帮助你从 **Node.js + FastMCP 中介架构** 迁移到 **Godot 原生 MCP 实现**。

### 为什么要迁移？

| 对比维度 | Node.js 版（旧） | 原生实现（新） |
|---------|------------------|----------------|
| **环境依赖** | 需要 Node.js + npm | 仅需 Godot 引擎 |
| **通信延迟** | AI → Node.js → Godot（~100ms） | AI → Godot（~70ms） |
| **内存占用** | 150MB+ | <5MB |
| **安全性** | 存在命令注入风险 | 直接 API 调用，更安全 |
| **代码维护** | TypeScript + GDScript | 仅 GDScript |

---

## 迁移前准备

### 1. 备份当前项目

```bash
# 备份整个项目目录
cp -r Godot-MCP Godot-MCP-backup

# 或者只备份关键配置文件
cp Godot-MCP/claude_desktop_config.json Godot-MCP/claude_desktop_config.json.backup
```

### 2. 确认 Godot 版本

原生实现需要 **Godot 4.0 或更高版本**。

在 Godot Editor 中查看：  
「帮助」→「关于 Godot」→ 确认版本号

### 3. 记录当前配置

记录你当前的 MCP 服务器配置，包括：
- 工具启用/禁用状态
- 自定义设置
- 工作流习惯

---

## 迁移步骤

### 步骤 1：更新 Godot-MCP 项目

```bash
cd Godot-MCP
git pull origin main  # 或下载最新 Release
```

### 步骤 2：启用原生插件

1. 打开 Godot Editor
2. 点击「项目」→「项目设置」
3. 选择「插件」标签页
4. **禁用** 旧版 `godot-mcp` 插件（如果存在）
5. **启用** `Godot Native MCP Server` 插件

### 步骤 3：配置原生插件

启用插件后，底部会出现「MCP Server」面板：

1. **日志级别**：设置为 `INFO`（默认）
2. **安全级别**：设置为 `STRICT`（默认，更安全）
3. **速率限制**：保持默认 `100`（每秒请求数）
4. 点击「Start Server」按钮

### 步骤 4：更新 Claude Desktop 配置

#### 旧配置（Node.js 版）

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "node",
      "args": ["PATH_TO_PROJECT/server/dist/index.js"],
      "env": {"MCP_TRANSPORT": "stdio"}
    }
  }
}
```

#### 新配置（原生实现）

**Windows 示例**：
```json
{
  "mcpServers": {
    "godot-mcp-native": {
      "command": "C:\\Program Files\\Godot\\Godot_v4.3-stable_mono_win64.exe",
      "args": ["--path", "F:\\gitProjects\\Godot-MCP", "--headless"],
      "env": {}
    }
  }
}
```

**macOS/Linux 示例**：
```json
{
  "mcpServers": {
    "godot-mcp-native": {
      "command": "/Applications/Godot.app/Contents/MacOS/Godot",
      "args": ["--path", "/path/to/Godot-MCP", "--headless"],
      "env": {}
    }
  }
}
```

#### 参数说明

| 参数 | 说明 |
|-----|------|
| `--path` | Godot-MCP 项目路径 |
| `--headless` | 以无界面模式运行（推荐） |
| `--editor` | 以编辑器模式运行（调试用） |

### 步骤 5：重启 Claude Desktop

1. 保存 `claude_desktop_config.json`
2. 完全退出 Claude Desktop（包括系统托盘图标）
3. 重新启动 Claude Desktop
4. 在设置中确认 `godot-mcp-native` 服务器状态为「Connected」

---

## 功能对比

### 工具支持情况

| 工具名称 | Node.js 版 | 原生实现 | 备注 |
|---------|-----------|----------|------|
| `create_node` | ✅ | ✅ | |
| `delete_node` | ✅ | ✅ | |
| `update_node_property` | ✅ | ✅ | |
| `get_node_properties` | ✅ | ✅ | |
| `list_nodes` | ✅ | ✅ | |
| `get_scene_tree` | ❌ | ✅ | 新增 |
| `list_project_scripts` | ✅ | ✅ | |
| `read_script` | ✅ | ✅ | |
| `create_script` | ✅ | ✅ | |
| `modify_script` | ✅ | ✅ | |
| `analyze_script` | ✅ | ✅ | |
| `create_scene` | ✅ | ✅ | |
| `save_scene` | ✅ | ✅ | |
| `open_scene` | ✅ | ✅ | |
| `get_current_scene` | ✅ | ✅ | |
| `get_scene_structure` | ✅ | ✅ | |
| `list_project_scenes` | ✅ | ✅ | |
| `get_editor_state` | ✅ | ✅ | |
| `run_project` | ✅ | ✅ | |
| `stop_project` | ✅ | ✅ | |
| `get_selected_nodes` | ✅ | ✅ | |
| `set_editor_setting` | ❌ | ✅ | 新增 |
| `get_editor_logs` | ✅ | ✅ | |
| `execute_script` | ❌ | ✅ | 新增 |
| `get_performance_metrics` | ❌ | ✅ | 新增 |
| `debug_print` | ❌ | ✅ | 新增 |
| `get_project_info` | ✅ | ✅ | |
| `get_project_settings` | ✅ | ✅ | |
| `list_project_resources` | ✅ | ✅ | |
| `create_resource` | ✅ | ✅ | |

### 资源支持情况

| 资源 URI | Node.js 版 | 原生实现 | 备注 |
|---------|-----------|----------|------|
| `godot://scene/list` | ✅ | ✅ | |
| `godot://scene/current` | ✅ | ✅ | |
| `godot://script/list` | ✅ | ✅ | |
| `godot://script/current` | ✅ | ✅ | |
| `godot://project/info` | ✅ | ✅ | |
| `godot://project/settings` | ✅ | ✅ | |
| `godot://editor/state` | ✅ | ✅ | |

---

## 常见问题

### 1. 迁移后工具调用失败

**可能原因**：
- 路径验证失败（安全级别过高）
- Godot 项目路径不正确
- 插件未正确启用

**解决方案**：
1. 检查 Godot Editor 输出窗口中的错误信息
2. 临时将安全级别设置为 `PERMISSIVE`
3. 确认项目路径配置正确

### 2. Claude Desktop 无法连接

**可能原因**：
- Godot 可执行文件路径不正确
- `--path` 参数路径不正确
- 端口被占用（如果使用 WebSocket 模式）

**解决方案**：
1. 检查 `claude_desktop_config.json` 中的路径
2. 手动运行 Godot 命令测试：
   ```bash
   "C:\Program Files\Godot\Godot_v4.3-stable_mono_win64.exe" --path "F:\gitProjects\Godot-MCP" --headless
   ```
3. 查看 Godot 输出日志

### 3. 性能下降

**可能原因**：
- 日志级别过低（DEBUG），导致大量输出
- 项目过大，工具执行时间长

**解决方案**：
1. 将日志级别设置为 `INFO` 或 `WARN`
2. 优化项目结构，减少不必要的文件
3. 使用 `.gdignore` 文件排除不需要扫描的目录

### 4. 旧版功能缺失

**可能原因**：
- 某些工具尚未迁移
- 行为略有变化

**解决方案**：
1. 查看上面的「功能对比」表格，确认工具是否已迁移
2. 阅读《工具参考手册》了解新工具的用法
3. 在 GitHub 上提交 Feature Request

---

## 回滚方案

如果迁移后出现问题，可以回滚到 Node.js 版：

### 步骤 1：禁用原生插件

1. 打开 Godot Editor
2. 点击「项目」→「项目设置」
3. 选择「插件」标签页
4. **禁用** `Godot Native MCP Server` 插件

### 步骤 2：恢复 Claude Desktop 配置

将 `claude_desktop_config.json` 恢复为旧配置：

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "node",
      "args": ["PATH_TO_PROJECT/server/dist/index.js"],
      "env": {"MCP_TRANSPORT": "stdio"}
    }
  }
}
```

### 步骤 3：重启 Claude Desktop

1. 完全退出 Claude Desktop
2. 重新启动 Claude Desktop
3. 确认 `godot-mcp` 服务器状态为「Connected」

---

## 最佳实践

### 1. 逐步迁移

不要一次性迁移所有项目，建议：
1. 先在一个测试项目中试用原生实现
2. 确认稳定后，再迁移主项目
3. 保留旧版配置作为备份

### 2. 安全配置

- **开发环境**：使用 `PERMISSIVE` 安全级别，方便调试
- **生产环境**：使用 `STRICT` 安全级别，防止意外操作

### 3. 日志管理

- **开发阶段**：使用 `DEBUG` 日志级别，查看详细日志
- **日常使用**：使用 `INFO` 或 `WARN` 日志级别，减少输出

### 4. 性能优化

- 对于大型项目，使用 `.gdignore` 文件排除不需要扫描的目录
- 定期清理项目中的临时文件和未使用的资源
- 使用 `rate_limit` 参数限制请求频率，防止过载

---

## 获取帮助

如果你在迁移过程中遇到任何问题，可以：

1. 查看 Godot Editor 输出窗口中的日志
2. 查看 Claude Desktop 的开发者工具（如果有错误信息）
3. 在 GitHub 上提交 Issue，描述你的问题和错误信息
4. 加入项目 Discord 社区（如果有），寻求帮助

---

## 附录：配置对比

### Node.js 版完整配置

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "node",
      "args": ["/path/to/Godot-MCP/server/dist/index.js"],
      "env": {
        "MCP_TRANSPORT": "stdio",
        "GODOT_WEBSOCKET_PORT": "9080"
      }
    }
  }
}
```

### 原生实现完整配置

```json
{
  "mcpServers": {
    "godot-mcp-native": {
      "command": "/path/to/godot-binary",
      "args": [
        "--path", "/path/to/Godot-MCP",
        "--headless"
      ],
      "env": {}
    }
  }
}
```

---

**文档版本**：1.0  
**最后更新**：2026-05-01
