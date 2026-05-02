# Godot Native MCP 贡献指南

## 简介

感谢你对 Godot Native MCP 项目的关注！本文档将指导你如何参与项目贡献。

---

## 如何贡献

### 1. 报告 Bug

**使用 GitHub Issues**：
1. 访问项目 GitHub 页面
2. 点击「Issues」标签
3. 点击「New Issue」按钮
4. 选择「Bug Report」模板
5. 填写基本信息：
   - **问题描述**：清晰描述遇到的问题
   - **复现步骤**：详细列出复现步骤
   - **预期行为**：你期望的正确行为
   - **实际行为**：实际发生的情况
   - **环境信息**：Godot 版本、操作系统、插件版本
   - **日志**：相关的错误日志或截图

**示例**：
```
问题：调用 create_node 工具时返回 "Parent node not found" 错误

复现步骤：
1. 打开 Godot Editor
2. 打开场景 "main.tscn"
3. 在 Claude Desktop 中发送请求："在 /root/Main 下创建 Player 节点"
4. 收到错误响应

预期行为：成功创建 Player 节点
实际行为：返回 "Parent node not found" 错误

环境信息：
- Godot 版本：4.3.stable
- 操作系统：Windows 11
- 插件版本：1.0

日志：
[MCP Plugin][ERROR] Parent node not found: /root/Main
```

---

### 2. 提出新功能建议

**使用 GitHub Issues**：
1. 访问项目 GitHub 页面
2. 点击「Issues」标签
3. 点击「New Issue」按钮
4. 选择「Feature Request」模板
5. 填写基本信息：
   - **功能描述**：详细描述建议的功能
   - **使用场景**：为什么需要这个功能？
   - **实现思路**：你设想的实现方式（可选）
   - **替代方案**：其他可行的方案（可选）

**示例**：
```
功能描述：添加场景缩略图生成工具

使用场景：
在 AI 辅助游戏开发时，经常需要查看场景的预览图。目前只能获取场景结构（节点树），无法直观看到场景内容。如果能生成场景缩略图，将大大提升开发体验。

实现思路：
1. 添加一个新工具 `generate_scene_thumbnail`
2. 使用 Godot 的 `Viewport` 和 `get_texture()` 渲染场景
3. 将渲染结果保存为 PNG 图片
4. 返回图片路径或 Base64 编码的图片数据

替代方案：
- 使用 `get_scene_structure` 工具获取场景结构，然后在 AI 端生成示意图（但效果不佳）
```

---

### 3. 提交代码贡献

#### 步骤 1：Fork 项目

1. 访问项目 GitHub 页面
2. 点击右上角「Fork」按钮
3. 等待 Fork 完成

#### 步骤 2：克隆你的 Fork

```bash
git clone https://github.com/你的用户名/Godot-MCP.git
cd Godot-MCP
```

#### 步骤 3：创建分支

```bash
git checkout -b feature/你的功能名
# 或者
git checkout -b fix/你要修复的Bug名
```

#### 步骤 4：进行更改

**代码规范**：
- **GDScript**：
  - 使用 snake_case 命名变量、方法
  - 使用 PascalCase 命名类
  - 添加类型提示：`var player: Player`
  - 遵循 Godot 官方风格指南

- **提交信息**：
  - 使用英文或中文，保持清晰简洁
  - 格式：`类型: 简要描述`
  - 类型：`feat`（新功能）、`fix`（修复）、`docs`（文档）、`refactor`（重构）

**示例提交信息**：
```
feat: 添加 generate_scene_thumbnail 工具

- 实现场景缩略图生成功能
- 添加对应的 MCP 工具注册
- 更新工具参考手册
```

#### 步骤 5：测试更改

**必需测试**：
1. **单元测试**：运行现有测试用例
2. **手动测试**：在 Godot Editor 中测试你的更改
3. **集成测试**：配置 Claude Desktop 测试 MCP 工具

**测试清单**：
- [ ] 所有单元测试通过
- [ ] 新功能/修复正常工作
- [ ] 没有引入新的 Bug
- [ ] 文档已更新（如果需要）

#### 步骤 6：提交更改

```bash
git add .
git commit -m "feat: 添加 generate_scene_thumbnail 工具"
```

#### 步骤 7：推送到你的 Fork

```bash
git push origin feature/你的功能名
```

#### 步骤 8：创建 Pull Request

1. 访问你的 Fork 页面
2. 点击「Compare & pull request」按钮
3. 填写 PR 描述：
   - **标题**：简洁描述你的更改
   - **描述**：详细说明更改内容、原因、测试方法
   - **关联 Issue**：如果有相关的 Issue，添加链接
4. 点击「Create pull request」

---

## 代码规范

### GDScript 风格指南

#### 命名约定

| 元素 | 约定 | 示例 |
|------|------|------|
| 变量 | `snake_case` | `player_health`, `node_count` |
| 函数/方法 | `snake_case()` | `get_node_info()`, `create_scene()` |
| 类 | `PascalCase` | `NodeToolsNative`, `MCPServerCore` |
| 常量 | `ALL_CAPS` | `MAX_NODE_COUNT`, `DEFAULT_PORT` |
| 信号 | `snake_case` | `server_started`, `tool_executed` |

#### 注释规范

```gdscript
# 单行注释：解释复杂逻辑

# ============================================================================
# 区块分隔符：用于分隔不同功能的代码块
# ============================================================================

# 函数注释：说明函数功能、参数、返回值
## 计算节点总数
func count_nodes(node: Node) -> int:
	# 递归计算节点数
	var count: int = 1
	for child in node.get_children():
		count += count_nodes(child)
	return count

# 类注释：说明类职责、用法
# NodeToolsNative - 节点操作工具
# 提供节点创建、删除、修改等功能
class_name NodeToolsNative
```

#### 文件结构

```
文件头注释：
# 文件名
# 简要描述
# 版本
# 作者
# 日期

extends 继承类

# ============================================================================
# 信号定义
# ============================================================================

# ============================================================================
# 导出变量
# ============================================================================

# ============================================================================
# 内部变量
# ============================================================================

# ============================================================================
# 生命周期方法
# ============================================================================

# ============================================================================
# 公共方法
# ============================================================================

# ============================================================================
# 私有方法
# ============================================================================
```

---

## 添加新工具步骤

### 1. 创建工具函数

在对应的工具文件中添加新函数（如 `tools/node_tools_native.gd`）：

```gdscript
static func _tool_generate_thumbnail(params: Dictionary) -> Dictionary:
	"""生成场景缩略图"""
	
	# 验证参数
	if not params.has("scene_path"):
		return {"error": "Missing required parameter: scene_path"}
	
	var scene_path: String = params["scene_path"]
	
	# 验证路径
	var validation := PathValidator.validate_file_path(scene_path, [".tscn"])
	if not validation.valid:
		return {"error": validation.error}
	
	# 实现功能
	# ...
	
	return {
		"status": "success",
		"thumbnail_path": "res://thumbnails/scene.png"
	}
```

### 2. 注册工具

在 `register_tools()` 函数中注册新工具：

```gdscript
static func register_tools(server_core: RefCounted) -> void:
	# ... 其他工具注册 ...
	
	# 注册 generate_thumbnail 工具
	server_core.register_tool(
		"generate_thumbnail",
		"Generate a thumbnail image for a scene",
		{
			"type": "object",
			"properties": {
				"scene_path": {"type": "string", "description": "Path to the scene file"}
			},
			"required": ["scene_path"]
		},
		Callable(self, "_tool_generate_thumbnail")
	)
```

### 3. 更新文档

- 在 `docs/tools-reference-native.md` 中添加新工具的说明
- 在 `docs/quickstart-native.md` 中添加使用示例（可选）
- 更新 `README.md`（如果新工具很重要）

### 4. 添加测试

在 `tests/` 目录中添加对应的测试用例：

```gdscript
# tests/test_node_tools.gd
func test_generate_thumbnail() -> void:
	var result: Dictionary = NodeToolsNative._tool_generate_thumbnail({
		"scene_path": "res://scenes/main.tscn"
	})
	
	assert(result["status"] == "success")
	assert(result.has("thumbnail_path"))
```

---

## 社区规范

### 行为准则

- **尊重他人**：使用友好、专业的语言交流
- **接受反馈**：欢迎建设性的批评和建议
- **保持耐心**：理解和实现需求需要时间
- **帮助他人**：如果你有经验，欢迎帮助新手

### 语言要求

- **代码**：使用英文（变量名、函数名、注释）
- **文档**：使用中文或英文（根据目标用户选择）
- **提交信息**：使用英文或中文，保持一致性

---

## 获取帮助

如果你在贡献过程中遇到任何问题，可以：

1. **查看现有文档**：
   - `docs/quickstart-native.md`（快速开始）
   - `docs/architecture-native.md`（架构文档）
   - `docs/tools-reference-native.md`（工具参考）

2. **搜索已有 Issues**：
   - 访问项目 GitHub 页面
   - 在搜索框中输入关键词

3. **创建新 Issue**：
   - 选择「Question」标签
   - 详细描述你的问题

4. **加入社区**（如果有）：
   - Discord 服务器
   - 论坛
   - 聊天群组

---

## 致谢

感谢所有贡献者的付出！你们的帮助让这个项目变得更好。

**贡献者列表**（按贡献时间排序）：
- 你的名字（如果你贡献了）

---

**文档版本**：1.0  
**最后更新**：2026-05-01
