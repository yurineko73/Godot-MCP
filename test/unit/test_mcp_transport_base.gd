extends "res://addons/gut/test.gd"

var _transport_base: RefCounted = null

func before_each():
	_transport_base = load("res://addons/godot_mcp/native_mcp/mcp_transport_base.gd").new()

func after_each():
	_transport_base = null

func test_has_message_received_signal():
	assert_true(_transport_base.has_signal("message_received"), "Should have message_received signal")

func test_has_server_error_signal():
	assert_true(_transport_base.has_signal("server_error"), "Should have server_error signal")

func test_has_server_started_signal():
	assert_true(_transport_base.has_signal("server_started"), "Should have server_started signal")

func test_has_server_stopped_signal():
	assert_true(_transport_base.has_signal("server_stopped"), "Should have server_stopped signal")

func test_base_start_is_virtual():
	assert_true(_transport_base.has_method("start"), "Should have start method")
	assert_true(_transport_base.has_method("stop"), "Should have stop method")
	assert_true(_transport_base.has_method("is_running"), "Should have is_running method")
	assert_true(_transport_base.has_method("set_port"), "Should have set_port method")
	assert_true(_transport_base.has_method("set_auth_manager"), "Should have set_auth_manager method")
	assert_true(_transport_base.has_method("send_response"), "Should have send_response method")

func test_http_server_extends_transport_base():
	var http_server: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_http_server.gd").new()
	assert_true(http_server.has_signal("message_received"), "HTTP server should inherit message_received signal")
	assert_true(http_server.has_signal("server_started"), "HTTP server should inherit server_started signal")
	assert_true(http_server.has_signal("server_stopped"), "HTTP server should inherit server_stopped signal")

func test_stdio_server_extends_transport_base():
	var stdio_server: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_stdio_server.gd").new()
	assert_true(stdio_server.has_signal("message_received"), "Stdio server should inherit message_received signal")
	assert_true(stdio_server.has_signal("server_started"), "Stdio server should inherit server_started signal")
	assert_true(stdio_server.has_signal("server_stopped"), "Stdio server should inherit server_stopped signal")

func test_http_server_implements_start():
	var http_server: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_http_server.gd").new()
	assert_true(http_server.has_method("start"), "HTTP server should implement start")
	assert_true(http_server.has_method("stop"), "HTTP server should implement stop")
	assert_true(http_server.has_method("is_running"), "HTTP server should implement is_running")
	assert_true(http_server.has_method("send_response"), "HTTP server should implement send_response")

func test_stdio_server_implements_start():
	var stdio_server: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_stdio_server.gd").new()
	assert_true(stdio_server.has_method("start"), "Stdio server should implement start")
	assert_true(stdio_server.has_method("stop"), "Stdio server should implement stop")
	assert_true(stdio_server.has_method("is_running"), "Stdio server should implement is_running")
