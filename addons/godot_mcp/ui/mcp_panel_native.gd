# mcp_panel_native.gd
# MCP服务器配置面板 - 允许用户在编辑器底部控制MCP服务器
# 版本: 1.0
# 作者: AI Assistant
# 日期: 2026-05-01

@tool
extends PanelContainer

# 引用
var _plugin: EditorPlugin = null
var _server_core: RefCounted = null

# UI元素
var _status_label: Label = null
var _start_button: Button = null
var _stop_button: Button = null
var _auto_start_check: CheckBox = null
var _log_level_option: OptionButton = null
var _security_level_option: OptionButton = null
var _log_text_edit: TextEdit = null
var _tools_list_container: VBoxContainer = null

# ============================================================================
# 生命周期方法
# ============================================================================

func _ready() -> void:
	print("[MCP Panel] Panel ready")
	_create_ui()

func _exit_tree() -> void:
	print("[MCP Panel] Panel exiting tree")

# ============================================================================
# 初始化
# ============================================================================

## 设置插件引用
func set_plugin(plugin: EditorPlugin) -> void:
	_plugin = plugin
	print("[MCP Panel] Plugin reference set")
	
	# 获取服务器核心引用
	if _plugin and _plugin.has_method("get_native_server"):
		_server_core = _plugin.get_native_server()
	
	# 更新UI状态
	_update_ui_state()

## 设置服务器核心引用
func set_server_core(server_core: RefCounted) -> void:
	_server_core = server_core
	print("[MCP Panel] Server core reference set")
	
	# 更新UI状态
	_update_ui_state()

# ============================================================================
# UI创建
# ============================================================================

## 创建UI元素
func _create_ui() -> void:
	print("[MCP Panel] Creating UI...")
	
	# 设置面板属性
	custom_minimum_size = Vector2(200, 100)
	
	# 创建垂直布局
	var vbox: VBoxContainer = VBoxContainer.new()
	add_child(vbox)
	
	# 标题
	var title_label: Label = Label.new()
	title_label.text = "Godot Native MCP Server"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title_label)
	
	# 状态标签
	_status_label = Label.new()
	_status_label.text = "Status: Unknown"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status_label)
	
	# 分隔符
	vbox.add_child(HSeparator.new())
	
	# 按钮行
	var button_hbox: HBoxContainer = HBoxContainer.new()
	vbox.add_child(button_hbox)
	
	# 启动按钮
	_start_button = Button.new()
	_start_button.text = "Start Server"
	_start_button.pressed.connect(_on_start_pressed)
	button_hbox.add_child(_start_button)
	
	# 停止按钮
	_stop_button = Button.new()
	_stop_button.text = "Stop Server"
	_stop_button.pressed.connect(_on_stop_pressed)
	button_hbox.add_child(_stop_button)
	
	# 分隔符
	vbox.add_child(HSeparator.new())
	
	# 自动启动选项
	_auto_start_check = CheckBox.new()
	_auto_start_check.text = "Auto Start"
	_auto_start_check.toggled.connect(_on_auto_start_toggled)
	vbox.add_child(_auto_start_check)
	
	# 日志级别选项
	var log_hbox: HBoxContainer = HBoxContainer.new()
	vbox.add_child(log_hbox)
	
	var log_label: Label = Label.new()
	log_label.text = "Log Level:"
	log_hbox.add_child(log_label)
	
	_log_level_option = OptionButton.new()
	_log_level_option.add_item("ERROR", 0)
	_log_level_option.add_item("WARN", 1)
	_log_level_option.add_item("INFO", 2)
	_log_level_option.add_item("DEBUG", 3)
	_log_level_option.item_selected.connect(_on_log_level_selected)
	log_hbox.add_child(_log_level_option)
	
	# 安全级别选项
	var security_hbox: HBoxContainer = HBoxContainer.new()
	vbox.add_child(security_hbox)
	
	var security_label: Label = Label.new()
	security_label.text = "Security:"
	security_hbox.add_child(security_label)
	
	_security_level_option = OptionButton.new()
	_security_level_option.add_item("PERMISSIVE", 0)
	_security_level_option.add_item("STRICT", 1)
	_security_level_option.item_selected.connect(_on_security_level_selected)
	security_hbox.add_child(_security_level_option)
	
	# 分隔符
	vbox.add_child(HSeparator.new())
	
	# 日志查看器标题
	var log_title: Label = Label.new()
	log_title.text = "Server Log:"
	vbox.add_child(log_title)
	
	# 日志查看器
	_log_text_edit = TextEdit.new()
	_log_text_edit.editable = false
	_log_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_log_text_edit.custom_minimum_size = Vector2(200, 150)
	vbox.add_child(_log_text_edit)
	
	# 清空日志按钮
	var clear_log_button: Button = Button.new()
	clear_log_button.text = "Clear Log"
	clear_log_button.pressed.connect(_on_clear_log_pressed)
	vbox.add_child(clear_log_button)
	
	# 分隔符
	vbox.add_child(HSeparator.new())
	
	# 工具管理标题
	var tools_title: Label = Label.new()
	tools_title.text = "Tool Management:"
	vbox.add_child(tools_title)
	
	# 工具列表容器
	_tools_list_container = VBoxContainer.new()
	vbox.add_child(_tools_list_container)
	
	# 初始状态
	_update_ui_state()
	_refresh_tools_list()
	
	print("[MCP Panel] UI created successfully")

# ============================================================================
# UI更新
# ============================================================================

## 更新UI状态
func _update_ui_state() -> void:
	if not _status_label:
		return
	
	# 获取服务器状态
	var is_running: bool = false
	if _server_core and _server_core.has_method("is_running"):
		is_running = _server_core.is_running()
	
	# 更新状态标签
	if is_running:
		_status_label.text = "Status: Running"
		_status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		_status_label.text = "Status: Stopped"
		_status_label.add_theme_color_override("font_color", Color.RED)
	
	# 更新按钮状态
	if _start_button:
		_start_button.disabled = is_running
	if _stop_button:
		_stop_button.disabled = not is_running
	
	# 更新选项状态
	if _plugin:
		if _auto_start_check:
			_auto_start_check.button_pressed = _plugin.auto_start
		
		if _log_level_option:
			_log_level_option.select(_plugin.log_level)
		
		if _security_level_option:
			_security_level_option.select(_plugin.security_level)

# ============================================================================
# 按钮回调
# ============================================================================

## 启动按钮按下
func _on_start_pressed() -> void:
	print("[MCP Panel] Start button pressed")
	
	if not _plugin:
		printerr("[MCP Panel] Plugin reference not set")
		return
	
	_plugin.start_server()
	
	# 延迟更新UI状态
	await get_tree().process_frame
	_update_ui_state()

## 停止按钮按下
func _on_stop_pressed() -> void:
	print("[MCP Panel] Stop button pressed")
	
	if not _plugin:
		printerr("[MCP Panel] Plugin reference not set")
		return
	
	_plugin.stop_server()
	
	# 延迟更新UI状态
	await get_tree().process_frame
	_update_ui_state()

# ============================================================================
# 选项回调
# ============================================================================

## 自动启动选项切换
func _on_auto_start_toggled(button_pressed: bool) -> void:
	print("[MCP Panel] Auto start toggled: " + str(button_pressed))
	
	if _plugin:
		_plugin.auto_start = button_pressed

## 日志级别选项选择
func _on_log_level_selected(index: int) -> void:
	print("[MCP Panel] Log level selected: " + str(index))
	
	if _plugin:
		_plugin.log_level = index

## 安全级别选项选择
func _on_security_level_selected(index: int) -> void:
	print("[MCP Panel] Security level selected: " + str(index))
	
	if _plugin:
		_plugin.security_level = index

## 清空日志按钮按下
func _on_clear_log_pressed() -> void:
	print("[MCP Panel] Clear log button pressed")
	
	if _log_text_edit:
		_log_text_edit.text = ""

## 刷新工具列表
func _refresh_tools_list() -> void:
	print("[MCP Panel] Refreshing tools list")
	
	if not _tools_list_container:
		return
	
	# 清空现有列表
	for child in _tools_list_container.get_children():
		child.queue_free()
	
	# 获取工具列表
	var tools: Array = []
	if _server_core and _server_core.has_method("get_registered_tools"):
		tools = _server_core.get_registered_tools()
	
	# 添加工具开关
	for tool_info in tools:
		var tool_hbox: HBoxContainer = HBoxContainer.new()
		_tools_list_container.add_child(tool_hbox)
		
		var tool_check: CheckBox = CheckBox.new()
		tool_check.text = tool_info.get("name", "Unknown")
		tool_check.button_pressed = tool_info.get("enabled", true)
		tool_check.toggled.connect(_on_tool_toggled.bind(tool_info.get("name", "")))
		tool_hbox.add_child(tool_check)
		
		var desc_label: Label = Label.new()
		desc_label.text = tool_info.get("description", "")
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		tool_hbox.add_child(desc_label)

## 工具启用/禁用切换
func _on_tool_toggled(button_pressed: bool, tool_name: String) -> void:
	print("[MCP Panel] Tool toggled: " + tool_name + " = " + str(button_pressed))
	
	if _server_core and _server_core.has_method("set_tool_enabled"):
		_server_core.set_tool_enabled(tool_name, button_pressed)

## 更新日志显示
func update_log(message: String) -> void:
	if not _log_text_edit:
		return
	
	if Thread.is_main_thread():
		_append_log(message)
	else:
		call_deferred("_append_log", message)

func _append_log(message: String) -> void:
	if not _log_text_edit:
		return
	
	_log_text_edit.text += message + "\n"
	_log_text_edit.scroll_vertical = _log_text_edit.get_line_count()

# ============================================================================
# 公共API
# ============================================================================

## 刷新UI状态
func refresh() -> void:
	if Thread.is_main_thread():
		_update_ui_state()
	else:
		call_deferred("_update_ui_state")
