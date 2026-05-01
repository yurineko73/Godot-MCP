---
name: 嵌入式 MCP 面板
overview: 把现有独立 `Window` 式 MCP 控制面板改成 Godot 编辑器内的底部面板，并补一个稳定的 `Tools` 菜单入口，顺手消除“关闭后无法再次打开”的生命周期问题。实现会尽量复用现有 `mcp_panel.tscn/.gd`，主要调整 `EditorPlugin` 的挂载与清理方式。
todos:
  - id: refactor-plugin-ui-lifecycle
    content: 梳理 `mcp_server.gd` 中窗口式 UI 的创建、显示、关闭和清理路径，替换为单实例底部面板生命周期
    status: completed
  - id: register-bottom-panel-and-menu
    content: 将面板注册到 Godot 底部面板，并使用 `Tools` 菜单官方入口显示/聚焦该面板
    status: completed
  - id: validate-panel-behavior
    content: 复核 `mcp_panel.gd` 在非 `Window` 宿主下的行为，并定义验证清单覆盖 reopen/cleanup/server-controls
    status: completed
isProject: false
---

# 将 MCP 窗口改为 Godot 编辑器底部面板

## 目标
- 用 Godot 编辑器内嵌面板替换当前独立浮窗。
- 在 `Tools` 菜单增加稳定入口，用于显示/聚焦 MCP 面板。
- 修复当前“窗口关闭后无法再打开”的 UI 生命周期问题。

## 现状与关键证据
- 当前插件在 [f:\gitProjects\Godot-MCP\addons\godot_mcp\mcp_server.gd](f:\gitProjects\Godot-MCP\addons\godot_mcp\mcp_server.gd) 里通过 `Window.new()` 创建浮窗，并在 `_create_floating_panel()` 中执行 `popup_centered()`。
- 关闭路径是 `_on_window_close_requested()` -> `queue_free()` -> `mcp_window = null`。这套设计本身就依赖窗口节点的释放时机，容易出现“引用已清掉，但旧窗口还没真正从树上移除”的 reopen 问题。
- 现有“菜单入口”不是 `EditorPlugin` 官方菜单接口，而是直接尝试操作编辑器内部 `View` 菜单节点，耦合较高，稳定性差。
- 面板内容本身已经被拆到 [f:\gitProjects\Godot-MCP\addons\godot_mcp\ui\mcp_panel.gd](f:\gitProjects\Godot-MCP\addons\godot_mcp\ui\mcp_panel.gd) 和 `mcp_panel.tscn`，说明 UI 逻辑可以直接复用，只需要改挂载方式。

## API 依据
基于 Godot `EditorPlugin` 文档，适合本需求的模式是：
- `add_control_to_bottom_panel(control, title)`：把面板挂到底部区域。
- `remove_control_from_bottom_panel(control)`：插件退出时清理。
- `add_tool_menu_item(name, callable)`：给 `Tools` 菜单增加官方入口。
- `_make_visible(visible)`：在插件启停时同步显示状态。

说明：Context7 文档里提到新版本文档对底部面板 API 有弃用提示，但当前迁移目标仍可先落在 `add_control_to_bottom_panel()`，因为它与现有结构最贴合、改动最小。实现时把“面板注册”收口到单一函数，后续若要切到 `add_dock(...DOCK_SLOT_BOTTOM)`，改动面会很小。

## 实施方案
### 1. 改造 `mcp_server.gd` 的 UI 挂载方式
在 [f:\gitProjects\Godot-MCP\addons\godot_mcp\mcp_server.gd](f:\gitProjects\Godot-MCP\addons\godot_mcp\mcp_server.gd) 中：
- 删除或停用 `mcp_window: Window` 相关状态。
- 新增持久化的面板引用，例如 `mcp_panel: Control` 与底部面板返回的按钮引用。
- 在 `_enter_tree()` 中实例化 `res://addons/godot_mcp/ui/mcp_panel.tscn`，执行 `set_server(self)`，再注册到底部面板。
- 不再在启动时创建浮窗；改为让面板成为编辑器 UI 的一部分。

### 2. 用官方 `Tools` 菜单替代手工拼接 `View` 菜单
仍在 [f:\gitProjects\Godot-MCP\addons\godot_mcp\mcp_server.gd](f:\gitProjects\Godot-MCP\addons\godot_mcp\mcp_server.gd) 中：
- 去掉 `_add_menu_item()` 里对 `/root/EditorNode/menu_bar/View` 的直接访问。
- 改为使用 `add_tool_menu_item("Show MCP Panel", ...)` 注册菜单动作。
- 菜单动作职责只做“显示/聚焦底部面板”，不再负责重新创建 UI 节点。

### 3. 重写显示/隐藏与清理生命周期
在 [f:\gitProjects\Godot-MCP\addons\godot_mcp\mcp_server.gd](f:\gitProjects\Godot-MCP\addons\godot_mcp\mcp_server.gd) 中统一处理：
- `_make_visible(visible)`：插件启用/禁用时同步面板可见性。
- `_exit_tree()`：
  - `remove_tool_menu_item(...)`
  - `remove_control_from_bottom_panel(mcp_panel)`
  - `mcp_panel.queue_free()`
- 这样 UI 节点只有一份，且由插件生命周期统一托管，彻底消除“窗口关闭后重建失败”的路径。

### 4. 复核 `mcp_panel.gd` 对宿主类型的假设
检查并必要时微调 [f:\gitProjects\Godot-MCP\addons\godot_mcp\ui\mcp_panel.gd](f:\gitProjects\Godot-MCP\addons\godot_mcp\ui\mcp_panel.gd)：
- 确认它只依赖 `set_server()`、按钮回调和标签更新，不依赖 `Window` 专属行为。
- 如果需要隐藏/显示日志区域或按钮状态，保持逻辑都在 `Control` 层完成，不再依赖窗口关闭事件。

## 实现后预期结构
```mermaid
flowchart TD
    A[EditorPlugin _enter_tree] --> B[实例化 mcp_panel.tscn]
    B --> C[panel.set_server(self)]
    C --> D[add_control_to_bottom_panel]
    A --> E[add_tool_menu_item Show MCP Panel]
    E --> F[聚焦/显示底部 MCP 面板]
    G[_exit_tree] --> H[remove_tool_menu_item]
    G --> I[remove_control_from_bottom_panel]
    I --> J[queue_free panel]
```

## 需要验证的点
- 启用插件后，MCP 面板默认出现在底部面板区域。
- 点击 `Tools -> Show MCP Panel` 能稳定显示或聚焦面板。
- 关闭/隐藏底部面板后，仍可通过 `Tools` 菜单再次打开。
- 服务器启动/停止、端口修改、连接计数、日志输出仍正常工作。
- 禁用插件后，菜单项和底部面板都能被干净移除，没有残留节点或重复注册。

## 风险与取舍
- 如果你的 Godot 目标版本已经切到文档里更推荐的新面板 API，后续可能要把底部挂载从 `add_control_to_bottom_panel()` 换成新的 dock 方式；这不会影响 `mcp_panel.gd`，只影响插件注册层。
- 如果你希望“菜单动作”是严格的 toggle，而不是“显示/聚焦”，需要额外确认 Godot 当前版本对底部面板按钮/显示状态的可控程度；默认我会按“显示/聚焦”实现，行为更稳。