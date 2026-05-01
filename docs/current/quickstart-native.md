# Godot Native MCP 快速开始指南

## 简介

Godot Native MCP 是将 Model Context Protocol (MCP) 直接集成到 Godot 引擎的原生实现。与之前的 Node.js 中介架构不同，原生实现：

- ✅ **零外部依赖**：仅需 Godot 引擎
- ✅ **更低延迟**：消除 Node.js 中介层，响应速度提升 30%+
- ✅ **更小资源占用**：内存占用从 150MB 降至 <5MB
- ✅ **更高安全性**：直接调用 Godot API，无命令注入风险
- ✅ **更易维护**：仅 GDScript，代码统一

## 系统要求

- **Godot 引擎**：4.0 或更高版本
- **操作系统**：Windows、macOS 或 Linux
- **AI 客户端**：Claude Desktop 或其他支持 MCP 的客户端

## 安装步骤

### 1. 下载或克隆项目

```bash
git clone https://github.com/你的用户名/Godot-MCP.git
cd Godot-MCP
```

### 2. 打开 Godot 项目

1. 启动 Godot Editor
2. 点击「导入」按钮
3. 浏览到 `Godot-MCP` 文件夹
4. 点击「导入并编辑」

### 3. 启用插件

1. 在 Godot Editor 中，点击「项目」→「项目设置」
2. 选择「插件」标签页
3. 找到「Godot Native MCP Server」插件
4. 将状态从「停用」改为「启用」

### 4. 配置插件

启用插件后，你会在编辑器底部看到「MCP Server」面板：

1. **启动服务器**：点击「Start Server」按钮
2. **自动启动**：勾选「Auto Start」以便在编辑器启动时自动启动 MCP 服务器
3. **日志级别**：选择日志详细程度（ERROR、WARN、INFO、DEBUG）
4. **安全级别**：选择安全级别（PERMISSIVE、STRICT）

## 配置 Claude Desktop

### 1. 打开 Claude Desktop 配置文件

- **Windows**：`%APPDATA%\Claude\claude_desktop_config.json`
- **macOS**：`~/Library/Application Support/Claude/claude_desktop_config.json`
- **Linux**：`~/.config/Claude/claude_desktop_config.json`

### 2. 添加 MCP 服务器配置

将以下配置添加到 `mcpServers` 对象中：

```json
{
  "mcpServers": {
    "godot-mcp-native": {
      "command": "C:\\Program Files\\Godot\\Godot_v4.x-stable_console_win64.exe",
      "args": ["--headless", "--editor", "--path", "F:\\gitProjects\\Godot-MCP", "--", "--mcp-server"],
      "env": {}
    }
  }
}
```

**参数说明**：
- `--headless`：无头模式运行，不显示编辑器窗口，确保 stdin/stdout 正确连接
- `--editor`：强制以编辑器模式启动，加载 EditorPlugin 和编辑器接口
- `--path`：指定 Godot-MCP 项目路径
- `--`：分隔 Godot 引擎参数和用户自定义参数
- `--mcp-server`：用户自定义参数，插件检测到此参数后自动启动 MCP 服务器

**⚠️ 重要：Windows 必须使用 console 版本！**

在 Windows 上，MCP 通过 stdin/stdout 管道通信。普通的 `Godot_v4.x-stable_win64.exe` 是 GUI 子系统程序，**stdout 不会连接到父进程的管道**，导致 MCP 客户端收不到响应。

**必须使用 `Godot_v4.x-stable_console_win64.exe`**（文件名中包含 `console`），这是控制台子系统版本，stdout 会正确连接到管道。

| 平台 | 正确的可执行文件 | 错误的可执行文件 |
|------|-----------------|-----------------|
| Windows | `Godot_v4.x-stable_console_win64.exe` | ~~`Godot_v4.x-stable_win64.exe`~~ |
| Linux | `Godot_v4.x-stable_linux.x86_64` | N/A |
| macOS | `Godot_v4.x-stable_macos.universal` | N/A |

### 3. 重启 Claude Desktop

保存配置文件后，重启 Claude Desktop 使配置生效。

## 第一个工具调用示例

配置完成后，你可以在 Claude Desktop 中测试 MCP 工具：

### 示例 1：获取项目信息

**用户输入**：
```
请使用 godot-mcp-native 工具获取当前 Godot 项目的信息
```

**Claude 响应**：
Claude 会调用 `get_project_info` 工具，返回项目名称、版本、作者等信息。

### 示例 2：列出场景文件

**用户输入**：
```
请列出当前 Godot 项目中的所有场景文件
```

**Claude 响应**：
Claude 会调用 `list_project_scenes` 工具，返回所有 `.tscn` 文件的路径列表。

### 示例 3：创建新节点

**用户输入**：
```
请在当前场景的根节点下创建一个名为 "Player" 的 CharacterBody2D 节点
```

**Claude 响应**：
Claude 会调用 `create_node` 工具，在场景中创建新节点。

## 验证安装

要验证安装是否成功，可以检查以下几点：

1. **Godot Editor**：底部面板应该显示「MCP Server」标签页，且状态为「Running」
2. **Claude Desktop**：在设置中应该能看到 `godot-mcp-native` 服务器，且状态为「Connected」
3. **日志**：在 Godot Editor 的输出窗口中，应该能看到 MCP 服务器的日志消息

## 常见问题

### 1. Claude Desktop 无法连接到 MCP 服务器

**可能原因**：
- Godot 可执行文件路径不正确
- 项目路径不正确
- `--mcp-server` 参数未放在 `--` 之后
- 缺少 `--editor` 参数导致插件未加载

**解决方案**：
- 检查 `claude_desktop_config.json` 中的路径配置
- 确保 Godot 项目路径正确且包含 `project.godot` 文件
- 确保 `--mcp-server` 放在 `--` 之后（如 `-- --mcp-server`）
- 添加 `--editor` 参数确保编辑器模式启动
- 检查 Claude Desktop 的 MCP 日志（通常在 `%APPDATA%\Claude\logs\` 目录）

### 2. 工具调用失败

**可能原因**：
- 路径验证失败（安全级别过高）
- 编辑器接口未正确获取
- 工具未正确注册

**解决方案**：
- 降低安全级别（设置为 PERMISSIVE）
- 检查 Godot Editor 输出窗口中的错误信息
- 确保插件已正确启用

### 3. 性能问题

**可能原因**：
- 项目过大，工具执行时间过长
- 日志级别过低（DEBUG），导致大量日志输出

**解决方案**：
- 提高日志级别（设置为 INFO 或 WARN）
- 优化项目结构，减少不必要的文件和节点

## 下一步

- 阅读《迁移指南》了解从 Node.js 版迁移的详细步骤
- 阅读《工具参考手册》了解所有可用工具的详细说明
- 阅读《架构文档》了解原生实现的详细架构设计

## 获取帮助

如果你遇到任何问题，可以：

- 查看 Godot Editor 输出窗口中的日志消息
- 在 GitHub 上提交 Issue
- 加入项目 Discord 社区（如果有）

---

**文档版本**：1.0  
**最后更新**：2026-05-01
