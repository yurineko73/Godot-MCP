# Godot-MCP HTTP 模式 UI 和工具修改计划

## 日期
2026-05-02（初版） / 2026-05-02（深度分析更新）

## 背景
用户要求查看增加 HTTP 模式后，UI 面板以及工具相关脚本场景是否需要修改。

---

## 当前状态分析

### ✅ 已完成的 HTTP 模式实现
1. **核心传输层** (`addons/godot_mcp/native_mcp/`)
   - `mcp_server_core.gd` - 支持 `TRANSPORT_HTTP` 和 `TRANSPORT_STDIO`
   - `mcp_http_server.gd` - HTTP 服务器实现（支持 Streamable HTTP）
   - `mcp_stdio_server.gd` - stdio 传输实现
   - `mcp_auth_manager.gd` - HTTP 模式认证管理

2. **主插件脚本** (`addons/godot_mcp/mcp_server_native.gd`)
   - `transport_mode` 属性 ("stdio" 或 "http")
   - `http_port` 属性 (默认 9080)
   - `auth_enabled` 和 `auth_token` 属性
   - `sse_enabled`, `allow_remote`, `cors_origin` 属性

### ❌ 需要修改的部分

#### 1. UI 面板 (`addons/godot_mcp/ui/mcp_panel_native.gd`)
**问题**: 当前 UI 面板只显示基本设置，不显示 HTTP 模式相关配置

**需要添加**:
- 传输模式选择 (stdio/http)
- HTTP 端口配置
- 认证开关和 token 输入
- SSE 开关
- 远程访问开关
- CORS 设置

#### 2. UI 场景 (`addons/godot_mcp/ui/mcp_panel_native.tscn`)
**问题**: 场景文件需要与脚本同步更新

**需要添加**:
- 传输模式 OptionButton
- HTTP 端口 SpinBox
- 认证相关控件
- SSE/远程访问 CheckBox
- 连接状态显示（特别是 HTTP 模式的 URL 和 SSE 连接数）

#### 3. 主插件属性暴露 (`addons/godot_mcp/mcp_server_native.gd`)
**问题**: `_get_property_list()` 方法只暴露了部分属性到 Godot Inspector

**需要添加**:
- 将 HTTP 相关属性添加到 property list
- 或者确保 UI 面板可以正确读取这些属性

#### 4. 工具脚本 (`addons/godot_mcp/tools/*_tools_native.gd`)
**分析**: 工具脚本通过 `_native_server.register_tool()` 注册工具
**结论**: **注册模式和返回格式与 HTTP 模式兼容**，但存在并发安全问题需要修复（详见下方深度分析）

---

## 深度分析：UI 面板现状与升级方案

### 当前 UI 面板详细分析

#### mcp_panel_native.gd（当前活跃面板）

**现有 UI 元素**:

| 元素 | 变量名 | 说明 |
|------|--------|------|
| 标题标签 | 临时变量 | 显示 "Godot Native MCP Server" |
| 状态标签 | `_status_label` | 显示 "Running"/"Stopped"，颜色随状态变化 |
| 启动按钮 | `_start_button` | 调用 `_plugin.start_server()` |
| 停止按钮 | `_stop_button` | 调用 `_plugin.stop_server()` |
| 自动启动复选框 | `_auto_start_check` | 绑定 `_plugin.auto_start` |
| 日志级别下拉 | `_log_level_option` | ERROR/WARN/INFO/DEBUG |
| 安全级别下拉 | `_security_level_option` | PERMISSIVE/STRICT |
| 日志查看器 | `_log_text_edit` | 只读 TextEdit，显示服务器日志 |
| 清空日志按钮 | 临时变量 | 清空日志文本 |
| 工具管理列表 | `_tools_list_container` | 动态生成每个工具的 CheckBox + 描述 |

**与插件的连接方式**:
- 插件通过 `_bottom_panel.set_plugin(self)` 和 `_bottom_panel.set_server_core(_native_server)` 传递引用
- 面板通过 `_plugin.start_server()` / `_plugin.stop_server()` 控制服务器
- 面板通过 `_plugin.auto_start` / `_plugin.log_level` / `_plugin.security_level` 读写配置
- **所有 UI 元素均由脚本动态创建，.tscn 场景文件仅包含根节点**

#### mcp_panel.gd / mcp_panel.tscn（旧版 WebSocket 面板）

**状态**: 为旧版 WebSocket 服务器设计，与 `mcp_server_native.gd` **完全不兼容**
- 使用 `websocket_server.start_server()` / `get_port()` 等 API
- 连接 `client_connected` / `client_disconnected` / `command_received` 信号
- **不应在新架构中使用**

### 插件 HTTP 属性暴露情况

| 属性 | 类型 | 默认值 | @export | _get_property_list | Inspector Hint |
|------|------|--------|---------|-------------------|----------------|
| `transport_mode` | String | `"stdio"` | ✅ | ❌ | 无（纯文本输入） |
| `http_port` | int | `9080` | ✅ | ❌ | 无（无范围限制） |
| `auth_enabled` | bool | `false` | ✅ | ❌ | 无 |
| `auth_token` | String | `""` | ✅ | ❌ | 无（明文显示） |
| `sse_enabled` | bool | `true` | ✅ | ❌ | 无 |
| `allow_remote` | bool | `false` | ✅ | ❌ | 无 |
| `cors_origin` | String | `"*"` | ✅ | ❌ | 无 |
| `auto_start` | bool | `false` | ✅ | ✅ | TYPE_BOOL |
| `log_level` | int | `2` | ✅ | ✅ | ENUM: ERROR,WARN,INFO,DEBUG |
| `security_level` | int | `1` | ✅ | ✅ | ENUM: PERMISSIVE,STRICT |
| `rate_limit` | int | `100` | ✅ | ✅ | RANGE: 10-1000 |

**关键发现**: 7 个 HTTP 相关属性虽然标记为 `@export`，但未在 `_get_property_list()` 中列出，导致：
- 不在 "MCP Settings" 分类下
- 缺少合适的 hint（`transport_mode` 应为 ENUM，`http_port` 应为 RANGE，`auth_token` 应有密码遮罩）

### 发现的代码 Bug

#### Bug 1: `set_sse_enabled()` 方法不存在
**位置**: `mcp_server_native.gd:145`
```gdscript
_native_server.set_sse_enabled(sse_enabled)
```
`MCPServerCore` 中**没有定义此方法**，SSE 配置实际上不会生效。

#### Bug 2: `set_remote_config()` 方法在 MCPServerCore 中不存在
**位置**: `mcp_server_native.gd:150`
```gdscript
_native_server.set_remote_config(allow_remote, cors_origin)
```
此方法只存在于 `McpHttpServer` 而非 `MCPServerCore`，远程访问配置不会生效。

#### Bug 3: 面板状态更新依赖 `await` 而非信号
面板的启动/停止回调使用 `await get_tree().process_frame` 延迟更新 UI，而非直接连接 `server_started` / `server_stopped` 信号，可能导致状态更新不直观。

---

## 深度分析：工具脚本 HTTP 模式兼容性

### 兼容性总览

| 工具文件 | 传输耦合 | EditorInterface 依赖 | 线程安全 | 并发风险 | 综合评级 |
|---|---|---|---|---|---|
| node_tools_native.gd | 无 | 重度 | 有竞态 | 中等 | **中等风险** |
| script_tools_native.gd | 无 | 无(static) | 基本安全 | 低 | **低风险** |
| scene_tools_native.gd | 无 | 重度 | 有竞态 | 高 | **高风险** |
| editor_tools_native.gd | 无 | 极度 | 有竞态 | 高 | **高风险** |
| debug_tools_native.gd | 无 | 轻度 | **有bug** | 高 | **高风险** |
| project_tools_native.gd | 无 | 无(static) | 安全 | 低 | **低风险** |
| resource_tools_native.gd | 无 | 重度 | 基本安全 | 低 | **中等风险** |
| 命令脚本(6个) | **强耦合WebSocket** | 重度 | 不适用 | 不适用 | **不兼容** |

### 严重问题（必须修复）

#### 1. `_log_buffer` 竞态条件 — debug_tools_native.gd
**位置**: `debug_tools_native.gd:8-42`
- `_log_buffer` 数组在信号回调 `_on_log_message` 中写入，在 `_tool_get_editor_logs` 中读取
- **无任何锁保护**，HTTP 模式下并发请求可能导致数组损坏
- **修复方案**: 使用 `Mutex` 保护 `_log_buffer` 的读写操作

#### 2. `open_scene` 与节点操作的并发冲突 — scene_tools_native.gd
**位置**: `scene_tools_native.gd:287-322`
- `open_scene` 会关闭当前场景，如果同时有其他工具在操作当前场景的节点，会导致节点引用失效
- **修复方案**: 实现请求队列或操作锁，确保场景切换操作独占执行

#### 3. `run_project`/`stop_project` 的状态冲突 — editor_tools_native.gd
**位置**: `editor_tools_native.gd:164-229`
- 运行/停止项目改变编辑器全局状态，与所有其他操作不兼容
- **修复方案**: 添加状态检查，在项目运行时拒绝场景/节点操作请求

### 中等问题（建议修复）

#### 4. `execute_script` 的并发执行风险 — debug_tools_native.gd
- 两个并发 `execute_script` 调用可能操作相同的 Godot 对象
- **修复方案**: 添加执行锁，确保同一时刻只有一个脚本在执行

#### 5. 文件操作的原子性 — script_tools_native.gd / project_tools_native.gd
- `modify_script` 的"读取-修改-写入"不是原子的
- `create_script` 的"检查存在-创建"存在 TOCTOU 竞态
- **修复方案**: 主线程串行执行使实际风险较低，建议添加文件锁或操作去重

### 低优先级问题（可后续优化）

#### 6. HTTP 模式下"当前选择"语义不清
- `get_selected_nodes` 和 `get_editor_state` 返回编辑器本地用户的选择状态
- HTTP 远程客户端无法控制选择，返回值可能不符合预期
- **建议**: 在文档中明确说明，或添加"远程选择"机制

#### 7. `resource_tools_native.gd` 的 `_base_control` 未使用
- `ResourceToolsNative` 需要 `Control` 类型的 `base_control`，但实际未被使用
- **建议**: 移除以减少不必要的依赖

#### 8. 命令脚本系统与 HTTP 模式不兼容
- `commands/` 目录下的脚本全部基于 WebSocket 架构
- 使用 `client_id: int` 标识客户端，这是 WebSocket 连接的概念
- **建议**: 命令系统是遗留代码，不需要为 HTTP 模式更新，但应确保不会与 native 工具系统同时运行导致冲突

---

## 修改计划

### 阶段 1: 修复已知 Bug（前置条件）

#### 1.1 修复 MCPServerCore 缺失方法
**文件**: `addons/godot_mcp/native_mcp/mcp_server_core.gd`

**任务**:
1. 添加 `set_sse_enabled(enabled: bool)` 方法，转发到 HTTP 传输层
2. 添加 `set_remote_config(allow_remote: bool, cors_origin: String)` 方法，转发到 HTTP 传输层

#### 1.2 修复工具并发安全问题
**文件**: `addons/godot_mcp/tools/debug_tools_native.gd`

**任务**:
1. 为 `_log_buffer` 添加 `Mutex` 保护
2. 为 `execute_script` 添加执行锁

### 阶段 2: 更新 UI 面板脚本
**文件**: `addons/godot_mcp/ui/mcp_panel_native.gd`

**任务**:
1. 添加传输模式选择 UI
   - 创建 OptionButton 用于选择 "stdio" 或 "http"
   - 连接信号到插件端的 `transport_mode` 属性
   - 切换时显示/隐藏 HTTP 配置区域

2. 添加 HTTP 配置 UI (根据传输模式显示/隐藏)
   - HTTP 端口 SpinBox (1024-65535)
   - 认证 CheckBox + Token LineEdit（密码遮罩）
   - SSE CheckBox
   - 远程访问 CheckBox
   - CORS LineEdit

3. 添加连接状态显示
   - 显示当前传输模式
   - 如果是 HTTP 模式，显示访问 URL (e.g., `http://localhost:9080/mcp`)
   - 显示活跃 HTTP 连接数
   - 显示 SSE 会话数

4. 更新 `_update_ui_state()` 方法
   - 根据 `_server_core` 的状态更新所有控件
   - 根据传输模式启用/禁用相关控件
   - 服务器运行时禁止修改传输模式

5. 添加速率限制 SpinBox

### 阶段 3: 更新主插件属性暴露
**文件**: `addons/godot_mcp/mcp_server_native.gd`

**任务**:
1. 修改 `_get_property_list()` 方法
   - 添加 "Transport Settings" 分类
   - `transport_mode`: PROPERTY_HINT_ENUM, "stdio,http"
   - `http_port`: PROPERTY_HINT_RANGE, "1024,65535"
   - `auth_enabled`: TYPE_BOOL
   - `auth_token`: PROPERTY_HINT_PASSWORD
   - `sse_enabled`: TYPE_BOOL
   - `allow_remote`: TYPE_BOOL
   - `cors_origin`: PROPERTY_HINT_MULTILINE_TEXT

2. 确保 UI 面板可以直接访问这些属性
   - 当前 UI 面板通过 `set_plugin()` 获取插件引用
   - 可以通过插件引用直接访问这些属性

**建议**: 两种方法都实现，以便在 Inspector 和 UI 面板中都能配置

### 阶段 4: 添加工具并发保护
**文件**: `addons/godot_mcp/tools/*.gd`

**任务**:
1. 在 `MCPServerCore` 中添加操作队列机制
   - 确保修改编辑器状态的操作（`open_scene`、`run_project`、`stop_project`）串行执行
   - 读取操作可以并发执行

2. 或者在各工具中添加状态检查
   - `open_scene` 执行前检查是否有其他操作正在进行
   - `run_project` 执行前检查编辑器状态

### 阶段 5: 测试和调试
**任务**:
1. 测试 stdio 模式
   - 启动/停止服务器
   - 验证工具调用

2. 测试 HTTP 模式
   - 启动服务器
   - 使用 curl 或 Postman 发送 HTTP 请求
   - 测试 SSE 连接
   - 测试认证

3. 测试 UI 面板
   - 验证所有控件正常工作
   - 验证传输模式切换
   - 验证 HTTP 配置生效
   - 验证运行时禁止修改配置

4. 测试并发场景
   - 同时发送多个工具调用请求
   - 验证操作队列正常工作
   - 验证不会出现数据竞争

---

## UI 面板升级详细方案

### 布局结构

```
PanelContainer (MCPPanelNative)
└── MarginContainer
    └── VBoxContainer
        ├── 标题区: "Godot Native MCP Server"
        ├── 状态区: 状态标签 + 连接信息
        ├── HSeparator
        ├── 传输设置区 (VBoxContainer)
        │   ├── 传输模式: OptionButton [stdio / http]
        │   └── HTTP 配置区 (VBoxContainer, 根据模式显示/隐藏)
        │       ├── 端口: SpinBox [1024-65535]
        │       ├── 认证: CheckBox + Token LineEdit
        │       ├── SSE: CheckBox
        │       ├── 远程访问: CheckBox
        │       └── CORS 源: LineEdit
        ├── HSeparator
        ├── 服务器控制区
        │   ├── 启动/停止按钮
        │   └── 自动启动 CheckBox
        ├── HSeparator
        ├── 通用设置区
        │   ├── 日志级别: OptionButton
        │   ├── 安全级别: OptionButton
        │   └── 速率限制: SpinBox
        ├── HSeparator
        ├── 工具管理区
        │   └── 工具列表 (VBoxContainer, 动态生成)
        ├── HSeparator
        └── 日志区
            ├── 日志查看器 (TextEdit, 只读)
            └── 清空日志按钮
```

### 新增控件变量

```gdscript
var _transport_mode_option: OptionButton
var _http_config_container: VBoxContainer
var _http_port_spin: SpinBox
var _auth_enabled_check: CheckBox
var _auth_token_edit: LineEdit
var _sse_enabled_check: CheckBox
var _allow_remote_check: CheckBox
var _cors_origin_edit: LineEdit
var _rate_limit_spin: SpinBox
var _connection_info_label: Label
```

### 新增回调方法

```gdscript
func _on_transport_mode_selected(index: int) -> void
func _on_http_port_changed(value: float) -> void
func _on_auth_enabled_toggled(enabled: bool) -> void
func _on_auth_token_changed(text: String) -> void
func _on_sse_enabled_toggled(enabled: bool) -> void
func _on_allow_remote_toggled(enabled: bool) -> void
func _on_cors_origin_changed(text: String) -> void
func _on_rate_limit_changed(value: float) -> void
```

---

## 不需要修改的部分

### ✅ 工具脚本（注册模式和返回格式）
- `addons/godot_mcp/tools/script_tools_native.gd` - 低风险，无需修改
- `addons/godot_mcp/tools/project_tools_native.gd` - 低风险，无需修改

**原因**: 工具注册模式和返回格式与 HTTP 模式完全兼容，不需要修改注册逻辑或返回值格式。

### ✅ 核心传输层
- `addons/godot_mcp/native_mcp/mcp_transport_base.gd`
- `addons/godot_mcp/native_mcp/mcp_stdio_server.gd`
- `addons/godot_mcp/native_mcp/mcp_http_server.gd`
- `addons/godot_mcp/native_mcp/mcp_auth_manager.gd`
- `addons/godot_mcp/native_mcp/mcp_types.gd`
- `addons/godot_mcp/native_mcp/mcp_resource_manager.gd`

**原因**: 核心传输层已完成 HTTP 模式实现。

### ✅ 资源脚本
- `addons/godot_mcp/native_mcp/mcp_resource_manager.gd`

**原因**: 资源管理器与传输层无关。

---

## 文件修改清单

### 必须修改
1. ✅ `addons/godot_mcp/ui/mcp_panel_native.gd` - 添加 HTTP 模式 UI
2. ✅ `addons/godot_mcp/mcp_server_native.gd` - 暴露 HTTP 属性到 Inspector + 修复 Bug
3. ✅ `addons/godot_mcp/native_mcp/mcp_server_core.gd` - 添加 `set_sse_enabled()` / `set_remote_config()` 方法

### 建议修改（并发安全）
4. ⚠️ `addons/godot_mcp/tools/debug_tools_native.gd` - 修复 `_log_buffer` 竞态 + `execute_script` 锁
5. ⚠️ `addons/godot_mcp/tools/scene_tools_native.gd` - 添加 `open_scene` 操作保护
6. ⚠️ `addons/godot_mcp/tools/editor_tools_native.gd` - 添加 `run/stop_project` 状态检查

### 不需要修改
- ❌ `addons/godot_mcp/tools/script_tools_native.gd` - 低风险
- ❌ `addons/godot_mcp/tools/project_tools_native.gd` - 低风险
- ❌ `addons/godot_mcp/tools/resource_tools_native.gd` - 中等风险，可后续优化
- ❌ `addons/godot_mcp/commands/*.gd` - 旧 WebSocket 架构，与 HTTP 无关
- ❌ `addons/godot_mcp/native_mcp/mcp_*.gd` - 核心传输层（已完成）
- ❌ `addons/godot_mcp/ui/mcp_panel_native.tscn` - 场景仅含根节点，UI 由脚本动态创建

---

## 风险和建议

### 风险
1. **UI 复杂性增加** - HTTP 模式配置较多，可能使 UI 面板变得复杂
   - **建议**: 使用条件显示/隐藏，stdio 模式下隐藏 HTTP 配置区

2. **传输模式切换** - 切换传输模式需要重启服务器
   - **建议**: 在 UI 中明显提示用户需要重启，运行时禁止修改

3. **认证安全性** - Token 在 UI 中明文显示
   - **建议**: 使用 LineEdit 的 `secret` 属性实现密码遮罩，添加显示/隐藏按钮

4. **并发请求风险** - HTTP 模式支持多客户端同时连接，可能导致工具调用冲突
   - **建议**: 实现操作队列机制，确保修改编辑器状态的操作串行执行

5. **旧版面板残留** - `mcp_panel.gd` / `mcp_panel.tscn` 是旧版 WebSocket 面板
   - **建议**: 标记为废弃或删除，避免误用

### 建议
1. **分阶段实施** - 先修复 Bug 和基本 UI，再添加并发保护和高级功能
2. **保持向后兼容** - 确保 stdio 模式继续正常工作
3. **添加文档** - 更新 README 和使用说明
4. **添加操作队列** - 在 `MCPServerCore` 中实现请求序列化机制

---

## 下一步

等待用户确认后，可以开始实施：
1. 阶段 1: 修复已知 Bug（`set_sse_enabled`、`set_remote_config`、`_log_buffer` 竞态）
2. 阶段 2: 更新 UI 面板脚本
3. 阶段 3: 更新主插件属性暴露
