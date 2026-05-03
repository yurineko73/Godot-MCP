# UI 面板增强计划 - 主屏幕插件改造

## 日期
2026-05-03

## 背景
当前 MCP 面板以底部停靠面板（EditorDock + DOCK_SLOT_BOTTOM）形式存在，空间狭小，所有功能（配置、日志、工具管理）堆叠在一个垂直布局中，信息密度过高。用户希望将面板提升到编辑器主屏幕级别（与 2D、3D、Script 同级），并使用页签分离不同功能区。

---

## 当前状态分析

### 现有架构

1. **插件入口** (`addons/godot_mcp/mcp_server_native.gd`)
   - 继承 `EditorPlugin`，但未覆写 `_has_main_screen()`
   - 使用 `EditorDock` + `add_dock()` 创建底部面板
   - `_create_ui_panel()` (L744-771): 加载场景 → 实例化 → 创建 EditorDock → `add_dock()`
   - `_exit_tree()` (L191-208): `remove_dock()` 清理
   - 信号回调 (L777-814): 通过 `_bottom_panel` 引用更新面板

2. **面板脚本** (`addons/godot_mcp/ui/mcp_panel_native.gd`, 451行)
   - 继承 `PanelContainer`
   - `_create_ui()` 程序化构建所有 UI（单列 VBoxContainer）
   - 包含：标题、状态、传输设置、HTTP配置、启动/停止按钮、自动启动、日志级别、安全级别、速率限制、Server Log、Tool Management
   - 所有内容堆叠在一个垂直布局中，空间利用率低

3. **面板场景** (`addons/godot_mcp/ui/mcp_panel_native.tscn`)
   - 极简：仅 PanelContainer + script 引用
   - `custom_minimum_size = Vector2(200, 100)`

### 问题

- 底部面板空间狭小（高度受限），不适合展示日志和工具列表
- 所有功能挤在一个面板中，信息密度过高
- 无法充分利用编辑器中央区域的大面积空间
- 日志区域和工具列表在底部面板中显示空间严重不足

---

## 目标架构

### 主屏幕插件

面板将出现在编辑器顶部选择栏中，与 2D、3D、Script、Game、AssetLib 同级：

```
[2D] [3D] [Script] [MCP] [Game] [AssetLib]
┌──────────────────────────────────────────┐
│  ┌─────────┬─────────────┬──────────────┐│
│  │Settings │ Server Log  │ Tool Manager ││
│  └─────────┴─────────────┴──────────────┘│
│                                          │
│  [当前选中页签的内容]                      │
│                                          │
└──────────────────────────────────────────┘
```

### 3 个页签内容

| 页签 | 内容 | 来源 |
|------|------|------|
| **Settings** | 传输模式、HTTP配置、认证、SSE/CORS、启动/停止按钮、自动启动、日志级别、安全级别、速率限制、连接信息 | 现有面板上半部分 |
| **Server Log** | 日志文本区域 + 清除按钮 | 现有 `_log_text_edit` + `clear_log_button` |
| **Tool Manager** | 工具列表（CheckBox + 描述）+ 刷新按钮 | 现有 `_tools_list_container` |

---

## 实现方案

### 核心 API 参考

#### 1. 主屏幕插件 API（EditorPlugin 虚方法）

来源: [Godot 官方文档 - Making main screen plugins](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/making_main_screen_plugins.html)

```gdscript
# 必须覆写，返回 true 声明为主屏幕插件
func _has_main_screen() -> bool:
    return true

# 当用户切换到/离开此主屏幕时调用
func _make_visible(visible: bool) -> void:
    _main_panel.visible = visible

# 主屏幕选择按钮上显示的名称
func _get_plugin_name() -> String:
    return "MCP"

# 主屏幕选择按钮上显示的图标
func _get_plugin_icon() -> Texture2D:
    return EditorInterface.get_editor_theme().get_icon("Network", "EditorIcons")
```

**关键点**:
- 面板必须作为 `EditorInterface.get_editor_main_screen()` 的子节点添加
- 创建后必须立即隐藏（`hide()` 或 `_make_visible(false)`），否则会遮挡 2D/3D 视图
- 当用户选择 MCP 工作区时，其他主屏幕插件自动隐藏
- `_get_plugin_icon()` 必须返回有效的 `Texture2D`

#### 2. 面板注册方式对比

```gdscript
# 旧方式（底部停靠）
var dock = EditorDock.new()
dock.title = "MCP Server"
dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM
dock.add_child(panel)
add_dock(dock)

# 新方式（主屏幕）
EditorInterface.get_editor_main_screen().add_child(panel)
panel.hide()  # 初始隐藏，非常重要！
```

#### 3. TabContainer 使用

来源: [Godot 官方文档 - TabContainer](https://docs.godotengine.org/en/stable/classes/class_tabcontainer.html)

```gdscript
var tab_container = TabContainer.new()

# TabContainer 为每个子 Control 自动创建一个页签
var settings_tab = VBoxContainer.new()
var log_tab = VBoxContainer.new()
var tools_tab = VBoxContainer.new()

tab_container.add_child(settings_tab)  # 自动创建 tab 0
tab_container.add_child(log_tab)       # 自动创建 tab 1
tab_container.add_child(tools_tab)     # 自动创建 tab 2

# 设置页签标题
tab_container.set_tab_title(0, "Settings")
tab_container.set_tab_title(1, "Server Log")
tab_container.set_tab_title(2, "Tool Manager")

# 设置页签图标（可选）
tab_container.set_tab_icon(0, icon_texture)

# 获取底层 TabBar 进行更细粒度控制
var tab_bar: TabBar = tab_container.get_tab_bar()
```

**TabContainer 特性**:
- 每个子 Control 自动对应一个页签
- 当前活动页签的子 Control 可见，其余隐藏
- `current_tab` 属性控制当前显示的页签
- `get_tab_bar()` 返回底层 TabBar，可进行更细粒度控制

---

## 文件修改清单

### 1. `mcp_server_native.gd` — 插件主类改造

| 位置 | 修改 | 说明 |
|------|------|------|
| L90-92 变量声明 | 删除 `_dock: EditorDock`，`_bottom_panel` → `_main_panel: Control` | 移除 EditorDock 依赖 |
| L101-189 `_enter_tree()` | `_create_ui_panel()` → `_create_main_screen_panel()` | 改用主屏幕注册方式 |
| L191-208 `_exit_tree()` | 删除 `remove_dock()`，改为 `get_editor_main_screen().remove_child()` + `queue_free()` | 主屏幕清理逻辑 |
| 新增方法 | `_has_main_screen()` → `true` | 声明为主屏幕插件 |
| 新增方法 | `_make_visible(visible: bool)` | 控制面板可见性 |
| 新增方法 | `_get_plugin_name()` → `"MCP"` | 主屏幕按钮名称 |
| 新增方法 | `_get_plugin_icon()` → 编辑器内置图标 | 主屏幕按钮图标 |
| L744-771 `_create_ui_panel()` | 重写为 `_create_main_screen_panel()` | 使用 `get_editor_main_screen().add_child()` + `hide()` |
| L777-814 信号回调 | `_bottom_panel` → `_main_panel` | 变量名更新 |

**`_create_main_screen_panel()` 实现要点**:
```gdscript
func _create_main_screen_panel() -> void:
    var panel_scene: PackedScene = load("res://addons/godot_mcp/ui/mcp_panel_native.tscn")
    if not panel_scene:
        _log_error("Failed to load MCP panel scene")
        return

    _main_panel = panel_scene.instantiate()
    if not _main_panel:
        _log_error("Failed to instantiate MCP panel")
        return

    EditorInterface.get_editor_main_screen().add_child(_main_panel)
    _make_visible(false)  # 初始隐藏

    if _main_panel.has_method("set_plugin"):
        _main_panel.set_plugin(self)
    if _native_server and _main_panel.has_method("set_server_core"):
        _main_panel.set_server_core(_native_server)
```

**`_exit_tree()` 修改要点**:
```gdscript
func _exit_tree() -> void:
    if _native_server and _native_server.is_running():
        _native_server.stop()

    if _main_panel:
        EditorInterface.get_editor_main_screen().remove_child(_main_panel)
        _main_panel.queue_free()
        _main_panel = null

    _native_server = null
```

### 2. `mcp_panel_native.gd` — 面板脚本重构

| 位置 | 修改 | 说明 |
|------|------|------|
| L8 基类 | `PanelContainer` → `VBoxContainer` | 主屏幕不需要 PanelContainer 边框 |
| L49-244 `_create_ui()` | 完全重写 | 创建 TabContainer + 3 个页签 + 顶部状态栏 |
| 新增 `_create_status_bar()` | 从 `_create_ui()` 提取 | 状态标签 + 连接信息 + 启动/停止按钮 |
| 新增 `_create_settings_tab()` | 从 `_create_ui()` 提取 | 传输模式、HTTP配置、认证、SSE/CORS、自动启动、日志级别、安全级别、速率限制 |
| 新增 `_create_log_tab()` | 从 `_create_ui()` 提取 | 日志 TextEdit + 清除按钮 |
| 新增 `_create_tools_tab()` | 从 `_create_ui()` 提取 | 刷新按钮 + ScrollContainer + 工具列表 |
| L246-324 `_update_ui_state()` | 逻辑不变，变量引用不变 | 所有成员变量名保持不变 |
| L402-426 `_refresh_tools_list()` | 逻辑不变 | 工具列表容器引用不变 |
| L432-444 `update_log()` | 逻辑不变 | 日志控件引用不变 |
| L446-450 `refresh()` | 逻辑不变 | 无需修改 |

**新 UI 布局结构**:
```
VBoxContainer (根节点, mcp_panel_native.gd)
├── HBoxContainer (顶部状态栏 - 始终可见)
│   ├── Label (_status_label, "Status: Stopped")
│   ├── Label (_connection_info_label, URL信息)
│   ├── Button (_start_button, "Start Server")
│   └── Button (_stop_button, "Stop Server")
└── TabContainer (页签容器, size_flags_vertical = SIZE_EXPAND_FILL)
    ├── VBoxContainer "Settings"
    │   ├── HBoxContainer (传输模式选择)
    │   ├── VBoxContainer (_http_config_container, HTTP配置区域)
    │   │   ├── HBoxContainer (端口)
    │   │   ├── HBoxContainer (认证开关 + Token)
    │   │   ├── CheckBox (_sse_enabled_check)
    │   │   ├── HBoxContainer (CORS源)
    │   │   └── CheckBox (_allow_remote_check)
    │   ├── CheckBox (_auto_start_check)
    │   ├── HBoxContainer (日志级别)
    │   ├── HBoxContainer (安全级别)
    │   └── HBoxContainer (速率限制)
    ├── VBoxContainer "Server Log"
    │   ├── TextEdit (_log_text_edit, size_flags_vertical = SIZE_EXPAND_FILL)
    │   └── Button (clear_log_button, "Clear Log")
    └── VBoxContainer "Tool Manager"
        ├── HBoxContainer (工具栏: 刷新按钮 + 工具数量标签)
        └── ScrollContainer (size_flags_vertical = SIZE_EXPAND_FILL)
            └── VBoxContainer (_tools_list_container)
```

**关键改进**:
- 顶部状态栏始终可见（不随页签切换隐藏），可随时查看服务器状态和启停
- Server Log 页签的 TextEdit 占据全部可用高度，日志展示空间大幅增加
- Tool Manager 页签使用 ScrollContainer 包裹，支持大量工具滚动浏览
- Settings 页签可水平布局某些配置项，充分利用主屏幕宽度

### 3. `mcp_panel_native.tscn` — 场景文件更新

| 修改 | 说明 |
|------|------|
| 根节点类型 `PanelContainer` → `VBoxContainer` | 主屏幕面板不需要 PanelContainer 边框 |
| 删除 `custom_minimum_size = Vector2(200, 100)` | 主屏幕自动填满，无需最小尺寸 |
| 保持脚本引用不变 | `script = ExtResource("1")` |

### 4. 无需修改的文件

- `plugin.cfg` — 插件注册方式不变
- 所有 `tools/*_tools_native.gd` — 工具逻辑与 UI 无关
- `native_mcp/mcp_server_core.gd` — 服务器核心逻辑与 UI 无关

---

## 实施步骤

### Step 1: 修改 `mcp_server_native.gd`
1. 替换变量声明：`_dock: EditorDock` + `_bottom_panel: Control` → `_main_panel: Control`
2. 添加 4 个虚方法覆写：`_has_main_screen()`、`_make_visible()`、`_get_plugin_name()`、`_get_plugin_icon()`
3. 重写 `_create_ui_panel()` → `_create_main_screen_panel()`，使用 `get_editor_main_screen().add_child()` + `_make_visible(false)`
4. 修改 `_exit_tree()` 清理逻辑：`remove_dock()` → `get_editor_main_screen().remove_child()` + `queue_free()`
5. 全局替换信号回调中的 `_bottom_panel` → `_main_panel`

### Step 2: 重构 `mcp_panel_native.gd`
1. 修改基类 `PanelContainer` → `VBoxContainer`
2. 重写 `_create_ui()`：创建顶部状态栏 + TabContainer + 3 个页签
3. 提取 `_create_status_bar()`：状态标签 + 连接信息 + 启动/停止按钮
4. 提取 `_create_settings_tab()`：传输模式、HTTP配置、认证、SSE/CORS、自动启动、日志级别、安全级别、速率限制
5. 提取 `_create_log_tab()`：日志 TextEdit + 清除按钮
6. 提取 `_create_tools_tab()`：刷新按钮 + ScrollContainer + 工具列表
7. 确保 `_update_ui_state()`、`refresh()`、`update_log()` 等方法正常工作
8. 为 Server Log 和 Tool Manager 页签设置 `size_flags_vertical = SIZE_EXPAND_FILL`

### Step 3: 更新 `mcp_panel_native.tscn`
1. 根节点类型改为 `VBoxContainer`
2. 删除 `custom_minimum_size`
3. 验证脚本引用正确

### Step 4: 测试验证
1. 重启 Godot 编辑器
2. 确认 "MCP" 出现在主屏幕选择栏中（与 2D、3D、Script 同级）
3. 点击 "MCP" 切换到 MCP 主屏幕
4. 测试 3 个页签（Settings / Server Log / Tool Manager）切换
5. 测试 Settings 页签所有配置功能（传输模式、端口、认证、SSE等）
6. 测试 Server Log 日志显示和清除
7. 测试 Tool Manager 工具列表和启用/禁用
8. 测试启动/停止服务器（顶部状态栏按钮）
9. 测试切换到其他主屏幕（2D/3D/Script）时面板正确隐藏
10. 测试从 MCP 主屏幕切换回来时面板正确显示

---

## 风险和注意事项

1. **主屏幕插件与底部面板不兼容**: 一个 EditorPlugin 不能同时是主屏幕插件和底部面板插件。切换后原有的 `add_dock()` 逻辑必须完全移除，不能保留两种注册方式。

2. **初始隐藏**: 主屏幕面板创建后必须调用 `hide()` 或 `_make_visible(false)`，否则会默认显示并遮挡 2D/3D 视图。这是 Godot 官方文档明确强调的。

3. **面板大小**: 主屏幕面板会自动填满编辑器中央区域，无需设置 `custom_minimum_size`。但 TabContainer 和其子页签需要正确设置 `size_flags_vertical = SIZE_EXPAND_FILL` 才能充分利用空间。

4. **图标选择**: `_get_plugin_icon()` 必须返回有效的 `Texture2D`。推荐使用 `EditorInterface.get_editor_theme().get_icon("Network", "EditorIcons")` 或其他内置图标。如果图标无效，按钮可能显示为空白。

5. **向后兼容**: 如果用户习惯底部面板，可以考虑未来添加配置选项让用户选择面板位置，但本次实施先完成主屏幕方案。

6. **`_make_visible(false)` 调用时机**: 在 `_enter_tree()` 中创建面板后立即调用 `_make_visible(false)` 确保初始不显示。Godot 官方示例推荐此做法。

7. **`_exit_tree()` 清理**: 必须先从 `get_editor_main_screen()` 移除子节点，再 `queue_free()`。直接 `queue_free()` 可能导致编辑器崩溃。

---

## 实施记录

### 已完成的修改

#### 文件修改清单（实际执行）

| 文件 | 修改内容 |
|------|----------|
| `mcp_server_native.gd` | `_dock: EditorDock` + `_bottom_panel` → `_main_panel: Control`；新增 `_has_main_screen()`、`_make_visible()`、`_get_plugin_name()`、`_get_plugin_icon()`；`_create_ui_panel()` → `_create_main_screen_panel()`；`_exit_tree()` 改用 `get_editor_main_screen().remove_child()`；信号回调 `_bottom_panel` → `_main_panel` |
| `mcp_panel_native.gd` | 基类 `PanelContainer` → `VBoxContainer`；重写 `_create_ui()` 为 TabContainer + 3 页签 + 顶部状态栏；新增 `_create_status_bar()`、`_create_settings_tab()`、`_create_log_tab()`、`_create_tools_tab()`、`_update_tools_count()`；`set_plugin()`/`set_server_core()` 中追加 `_refresh_tools_list()` 调用；`_refresh_tools_list()` 始终显示全部工具 + "Enabled: X / Y" 计数 |
| `mcp_panel_native.tscn` | 根节点 `PanelContainer` → `VBoxContainer`；删除 `custom_minimum_size` |
| `mcp_types.gd` | `MCPTool` 新增 `var enabled: bool = true` 字段 |
| `mcp_server_core.gd` | `set_tool_enabled()` 改为标志位控制（不再 `_tools.erase()`）；`get_registered_tools()` 返回真实 `tool.enabled` 状态；`_handle_tools_list()` 只返回启用的工具；`_handle_tool_call()` 新增禁用检查 |

#### 实施中遇到的问题及修复

**问题1: Server Log 内容框太扁 / Tool Manager 被压缩到最小**

- **根因**: 主屏幕插件的根 Control 缺少 `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)` 和 `size_flags_vertical = SIZE_EXPAND_FILL`。Godot 官方文档明确要求主屏幕插件必须设置 Full Rect 锚点布局，否则面板只会以最小尺寸显示。
- **修复**: 在 `_create_ui()` 中对根节点和 TabContainer 均设置 `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)` + `size_flags_vertical/horizontal = SIZE_EXPAND_FILL`。同时每个页签根节点、MarginContainer、content VBoxContainer 也都设置了 `SIZE_EXPAND_FILL`，确保容器链完整传递扩展行为。

**问题2: Tool Manager 页签不显示具体工具**

- **根因**: `_refresh_tools_list()` 在 `_ready()` 阶段调用，但此时 `_server_core` 还是 `null`（`set_plugin()`/`set_server_core()` 在实例化之后才调用），所以工具列表为空。
- **修复**: 在 `set_plugin()` 和 `set_server_core()` 中追加 `_refresh_tools_list()` 调用。

**问题3: 工具禁用后再刷新会从列表消失**

- **根因**: `set_tool_enabled(tool_name, false)` 直接 `_tools.erase(tool_name)` 删除工具，`get_registered_tools()` 自然找不到被禁用的工具。UI 刷新时列表只显示存在的工具，导致禁用的工具"消失"。
- **修复**:
  1. `MCPTool` 新增 `enabled: bool = true` 字段
  2. `set_tool_enabled()` 改为 `_tools[tool_name].enabled = enabled`（标志位控制，不删除）
  3. `get_registered_tools()` 返回真实的 `tool.enabled` 状态
  4. `_handle_tools_list()` 只返回 `tool.enabled == true` 的工具给 MCP 客户端
  5. `_handle_tool_call()` 新增禁用检查，调用被禁用的工具返回 `isError`
  6. UI 工具列表始终显示全部注册工具，checkbox 反映启用状态
  7. 计数显示从 `"Tools: N"` 改为 `"Enabled: X / Y"` 格式
  8. `_on_tool_toggled()` 切换后立即调用 `_update_tools_count()` 更新计数

---

## 预期效果

- MCP 面板与 2D、3D、Script 同级，一键切换，无需在底部面板中寻找
- 3 个页签清晰分离：配置、日志、工具管理，各司其职
- 充分利用编辑器中央大区域空间，日志和工具列表展示空间大幅增加
- 顶部状态栏始终可见，无需切换页签即可查看服务器状态和启停
- 整体用户体验更接近 Godot 原生编辑器风格
