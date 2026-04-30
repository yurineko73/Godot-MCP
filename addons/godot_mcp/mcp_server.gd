@tool
extends EditorPlugin

const MCP_PANEL_TITLE := "MCP Server"
const SHOW_PANEL_MENU_ITEM := "Show MCP Panel"
const TOOLBAR_BUTTON_TEXT := "MCP"

var tcp_server := TCPServer.new()
var port := 9080
var handshake_timeout := 3000 # ms
var debug_mode := true
var log_detailed := true  # Enable detailed logging
var command_handler = null  # Command handler reference
var mcp_panel: Control = null  # Bottom panel instance
var mcp_panel_button: Button = null  # Bottom panel tab button
var toolbar_button: Button = null  # Main toolbar shortcut button
var tool_menu_registered := false

signal client_connected(id)
signal client_disconnected(id)
signal command_received(client_id, command)

var editor_logger = null

class MCPEditorLogger extends Logger:
	const MAX_ENTRIES := 2000
	
	var _entries: Array[Dictionary] = []
	var _next_index := 0
	var _mutex := Mutex.new()
	
	func _strip_ansi_sequences(message: String) -> String:
		var ansi_regex := RegEx.new()
		ansi_regex.compile("(?:\\x1b)?\\[[0-9;]*m")
		return ansi_regex.sub(message, "", true)
	
	func _strip_control_characters(message: String) -> String:
		var control_regex := RegEx.new()
		control_regex.compile("[\\x00-\\x08\\x0B-\\x1F\\x7F]")
		return control_regex.sub(message, "", true)
	
	func _normalize_message(message: String) -> String:
		var sanitized := _strip_ansi_sequences(message)
		sanitized = _strip_control_characters(sanitized)
		return sanitized.strip_edges()
	
	func _is_transport_noise(message: String) -> bool:
		if message.begins_with("[Client "):
			return true
		return (
			message.begins_with("Sending response to client ")
			or message.begins_with("Processing command: ")
			or message.begins_with("Executing script... ready func")
			or message.begins_with("result_data: ")
		)
	
	func _append_entry(entry_type: String, message: String) -> void:
		var normalized_message := _normalize_message(message)
		if normalized_message.is_empty() or _is_transport_noise(normalized_message):
			return
		
		_mutex.lock()
		_entries.append({
			"index": _next_index,
			"type": entry_type,
			"message": normalized_message,
		})
		_next_index += 1
		if _entries.size() > MAX_ENTRIES:
			_entries.remove_at(0)
		_mutex.unlock()
	
	func _log_message(message: String, error: bool) -> void:
		var normalized_message := _normalize_message(message)
		if error:
			if normalized_message.begins_with("WARNING: "):
				_append_entry("Warning", normalized_message.trim_prefix("WARNING: "))
				return
			if normalized_message.begins_with("SCRIPT ERROR: "):
				_append_entry("Script", normalized_message.trim_prefix("SCRIPT ERROR: "))
				return
			if normalized_message.begins_with("ERROR: "):
				_append_entry("Error", normalized_message.trim_prefix("ERROR: "))
				return
		_append_entry("Error" if error else "General", normalized_message)
	
	func _classify_error_entry(error_type: int, function: String, file: String) -> String:
		match error_type:
			Logger.ERROR_TYPE_WARNING:
				return "Warning"
			Logger.ERROR_TYPE_SCRIPT:
				return "Script"
			Logger.ERROR_TYPE_ERROR, Logger.ERROR_TYPE_SHADER:
				return "Error"
		if function == "push_warning":
			return "Warning"
		if file.begins_with("gdscript://") or file.ends_with(".gd"):
			return "Script"
		return "Error"
	
	func _extract_error_message(function: String, file: String, line: int, code: String, rationale: String) -> String:
		var message := _normalize_message(rationale)
		if message.is_empty():
			message = _normalize_message(code)
		if not message.is_empty():
			return message
		if function == "push_warning":
			return "Warning emitted"
		if function == "push_error":
			return "Error emitted"
		return "%s (%s:%d)" % [function, file, line]
	
	func _log_error(
		function: String,
		file: String,
		line: int,
		code: String,
		rationale: String,
		editor_notify: bool,
		error_type: int,
		script_backtraces
	) -> void:
		var entry_type := _classify_error_entry(error_type, function, file)
		var message := _extract_error_message(function, file, line, code, rationale)
		_append_entry(entry_type, message)
	
	func get_entries() -> Array[Dictionary]:
		_mutex.lock()
		var copy: Array[Dictionary] = _entries.duplicate(true)
		_mutex.unlock()
		return copy

class WebSocketClient:
	var tcp: StreamPeerTCP
	var id: int
	var ws: WebSocketPeer
	var state: int = -1 # -1: handshaking, 0: connected, 1: error/closed
	var handshake_time: int
	var last_poll_time: int
	
	func _init(p_tcp: StreamPeerTCP, p_id: int):
		tcp = p_tcp
		id = p_id
		handshake_time = Time.get_ticks_msec()
	
	func upgrade_to_websocket() -> bool:
		ws = WebSocketPeer.new()
		var err = ws.accept_stream(tcp)
		return err == OK

var clients := {}
var next_client_id := 1

func _enter_tree():
	# Store plugin instance for EditorInterface access
	Engine.set_meta("GodotMCPPlugin", self)
	editor_logger = MCPEditorLogger.new()
	OS.add_logger(editor_logger)
	
	print("\n=== MCP SERVER STARTING ===")
	
	# Initialize the command handler
	print("Creating command handler...")
	command_handler = preload("res://addons/godot_mcp/command_handler.gd").new()
	command_handler.name = "CommandHandler"
	add_child(command_handler)
	
	# Connect signals
	print("Connecting command handler signals...")
	self.connect("command_received", Callable(command_handler, "_handle_command"))
	
	# Start WebSocket server
	var err = start_server()
	if err != OK:
		printerr("Failed to start server: ", err)
	
	_create_bottom_panel()
	_create_toolbar_button()
	add_tool_menu_item(SHOW_PANEL_MENU_ITEM, Callable(self, "_show_mcp_panel"))
	tool_menu_registered = true
	_show_mcp_panel()
	
	print("=== MCP SERVER INITIALIZED ===\n")

func _exit_tree():
	if editor_logger:
		OS.remove_logger(editor_logger)
		editor_logger = null
	
	# Remove plugin instance from Engine metadata
	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")
	
	if tool_menu_registered:
		remove_tool_menu_item(SHOW_PANEL_MENU_ITEM)
		tool_menu_registered = false
	
	if toolbar_button and is_instance_valid(toolbar_button):
		remove_control_from_container(CONTAINER_TOOLBAR, toolbar_button)
		toolbar_button.queue_free()
		toolbar_button = null
	
	if mcp_panel and is_instance_valid(mcp_panel):
		remove_control_from_bottom_panel(mcp_panel)
		mcp_panel.queue_free()
		mcp_panel = null
		mcp_panel_button = null
	
	stop_server()
	clients.clear()
	
	print("=== MCP SERVER SHUTDOWN ===")

func _create_bottom_panel():
	if mcp_panel and is_instance_valid(mcp_panel):
		return
	
	mcp_panel = load("res://addons/godot_mcp/ui/mcp_panel.tscn").instantiate()
	mcp_panel.set_server(self)
	mcp_panel_button = add_control_to_bottom_panel(mcp_panel, MCP_PANEL_TITLE)
	if mcp_panel_button and is_instance_valid(mcp_panel_button):
		mcp_panel_button.visible = true

func _create_toolbar_button():
	if toolbar_button and is_instance_valid(toolbar_button):
		return
	
	toolbar_button = Button.new()
	toolbar_button.text = TOOLBAR_BUTTON_TEXT
	toolbar_button.tooltip_text = SHOW_PANEL_MENU_ITEM
	toolbar_button.pressed.connect(_show_mcp_panel)
	add_control_to_container(CONTAINER_TOOLBAR, toolbar_button)

func _show_mcp_panel():
	if not (mcp_panel and is_instance_valid(mcp_panel)):
		return
	
	if mcp_panel_button and is_instance_valid(mcp_panel_button):
		mcp_panel_button.visible = true
	
	make_bottom_panel_item_visible(mcp_panel)

func _make_visible(visible):
	if not (mcp_panel and is_instance_valid(mcp_panel)):
		return
	
	if mcp_panel_button and is_instance_valid(mcp_panel_button):
		mcp_panel_button.visible = visible
	
	if visible:
		_show_mcp_panel()
	else:
		hide_bottom_panel()

func get_editor_log_entries() -> Array[Dictionary]:
	if editor_logger == null:
		return []
	return editor_logger.get_entries()

func _log(client_id, message):
	if log_detailed:
		print("[Client ", client_id, "] ", message)

func _process(_delta):
	if not tcp_server.is_listening():
		return
	
	# Poll for new connections
	if tcp_server.is_connection_available():
		var tcp = tcp_server.take_connection()
		var id = next_client_id
		next_client_id += 1
		
		var client = WebSocketClient.new(tcp, id)
		clients[id] = client
		
		print("[Client ", id, "] New TCP connection")
		
		# Try to upgrade immediately
		if client.upgrade_to_websocket():
			print("[Client ", id, "] WebSocket handshake started")
		else:
			print("[Client ", id, "] Failed to start WebSocket handshake")
			clients.erase(id)
	
	# Update clients
	var current_time = Time.get_ticks_msec()
	var ids_to_remove := []
	
	for id in clients:
		var client = clients[id]
		client.last_poll_time = current_time
		
		# Process client based on its state
		if client.state == -1: # Handshaking
			if client.ws != null:
				# Poll the WebSocket peer
				client.ws.poll()
				
				# Check WebSocket state
				var ws_state = client.ws.get_ready_state()
				if debug_mode:
					_log(id, "State: " + str(ws_state))
					
				if ws_state == WebSocketPeer.STATE_OPEN:
					print("[Client ", id, "] WebSocket handshake completed")
					client.state = 0
					
					# Emit connected signal
					emit_signal("client_connected", id)
					
					# Send welcome message
					var msg = JSON.stringify({
						"type": "welcome",
						"message": "Welcome to Godot MCP WebSocket Server"
					})
					client.ws.send_text(msg)
					
				elif ws_state != WebSocketPeer.STATE_CONNECTING:
					print("[Client ", id, "] WebSocket handshake failed, state: ", ws_state)
					ids_to_remove.append(id)
				
				# Check for handshake timeout
				elif current_time - client.handshake_time > handshake_timeout:
					print("[Client ", id, "] WebSocket handshake timed out")
					ids_to_remove.append(id)
			else:
				# If TCP is still connected, try upgrading
				if client.tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
					if client.upgrade_to_websocket():
						print("[Client ", id, "] WebSocket handshake started")
					else:
						print("[Client ", id, "] Failed to start WebSocket handshake")
						ids_to_remove.append(id)
				else:
					print("[Client ", id, "] TCP disconnected during handshake")
					ids_to_remove.append(id)
		
		elif client.state == 0: # Connected
			# Poll the WebSocket
			client.ws.poll()
			
			# Check state
			var ws_state = client.ws.get_ready_state()
			if ws_state != WebSocketPeer.STATE_OPEN:
				print("[Client ", id, "] WebSocket connection closed, state: ", ws_state)
				emit_signal("client_disconnected", id)
				ids_to_remove.append(id)
				continue
			
			# Process messages
			while client.ws.get_available_packet_count() > 0:
				var packet = client.ws.get_packet()
				var text = packet.get_string_from_utf8()
				
				print("[Client ", id, "] RECEIVED RAW DATA: ", text)
				
				# Parse as JSON
				var json = JSON.new()
				var parse_result = json.parse(text)
				_log(id, "JSON parse result: " + str(parse_result))
				
				if parse_result == OK:
					var data = json.get_data()
					_log(id, "Parsed JSON: " + str(data))
					
					# Handle JSON-RPC protocol
					if data.has("jsonrpc") and data.get("jsonrpc") == "2.0":
						# Handle ping method
						if data.has("method") and data.get("method") == "ping":
							print("[Client ", id, "] Received PING with id: ", data.get("id"))
							var response = {
								"jsonrpc": "2.0",
								"id": data.get("id"),
								"result": null  # FastMCP expects null result for pings
							}
							var response_text = JSON.stringify(response)
							var send_result = client.ws.send_text(response_text)
							print("[Client ", id, "] SENDING PING RESPONSE: ", response_text, " (result: ", send_result, ")")
						
						# Handle other MCP commands
						elif data.has("method"):
							var method_name = data.get("method")
							var params = data.get("params", {})
							var req_id = data.get("id")
							
							print("[Client ", id, "] Processing JSON-RPC method: ", method_name)
							
							# For now, just send a generic success response
							# TODO: Route these to command handler as well
							var response = {
								"jsonrpc": "2.0",
								"id": req_id,
								"result": {
									"status": "success",
									"message": "Command processed"
								}
							}
							
							var response_text = JSON.stringify(response)
							var send_result = client.ws.send_text(response_text)
							print("[Client ", id, "] SENT RESPONSE: ", response_text, " (result: ", send_result, ")")
					
					# Handle legacy command format - This is what Claude Code uses
					elif data.has("type"):
						var cmd_type = data.get("type")
						var params = data.get("params", {})
						var cmd_id = data.get("commandId", "")
						
						print("[Client ", id, "] Processing command: ", cmd_type)
						
						# Route command to command handler via signal
						# The command handler will handle the response via send_response
						emit_signal("command_received", id, data)
				else:
					print("[Client ", id, "] Failed to parse JSON: ", json.get_error_message())
	
	# Remove clients that need to be removed
	for id in ids_to_remove:
		clients.erase(id)

# Function for command handler to send responses back to clients
func send_response(client_id: int, response: Dictionary) -> int:
	if not clients.has(client_id):
		print("Error: Client %d not found" % client_id)
		return ERR_DOES_NOT_EXIST
	
	var client = clients[client_id]
	var json_text = JSON.stringify(response)
	
	print("Sending response to client %d: %s" % [client_id, json_text])
	
	if client.ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		print("Error: Client %d connection not open" % client_id)
		return ERR_UNAVAILABLE
	
	var result = client.ws.send_text(json_text)
	if result != OK:
		print("Error sending response to client %d: %d" % [client_id, result])
	
	return result

func is_server_active() -> bool:
	return tcp_server.is_listening()

func start_server() -> int:
	if is_server_active():
		return ERR_ALREADY_IN_USE
	var err = tcp_server.listen(port)
	if err == OK:
		print("MCP WebSocket server started on port ", port)
		set_process(true)
		return OK
	else:
		printerr("Failed to listen on port ", port, " error: ", err)
		return err

func stop_server() -> void:
	if is_server_active():
		tcp_server.stop()
		clients.clear()
		set_process(false)
		print("MCP WebSocket server stopped")

func set_port(new_port: int) -> void:
	if is_server_active():
		push_error("Cannot change port while server is active")
		return
	port = new_port

func get_client_count() -> int:
	return clients.size()
		
func get_port() -> int:
	return port
