@tool
class_name MCPDebugCommands
extends MCPBaseCommandProcessor

func process_command(client_id: int, command_type: String, params: Dictionary, command_id: String) -> bool:
    match command_type:
        "read_logs":
            _read_logs(client_id, params, command_id)
            return true
    return false

func _read_logs(client_id: int, params: Dictionary, command_id: String) -> void:
    var source: String = params.get("source", "editor")
    var types: Array = params.get("type", [])  # Expected: array of strings like ["Error", "Warning"]
    var count: int = params.get("count", 10)
    var offset: int = params.get("offset", 0)
    var order: String = params.get("order", "desc")
    
    # Validate source
    if source != "editor" and source != "runtime":
        _send_error(client_id, "Invalid source: %s (must be 'editor' or 'runtime')" % source, command_id)
        return
    
    if source == "editor":
        _read_editor_logs(client_id, types, count, offset, order, command_id)
    else:
        _read_runtime_logs(client_id, types, count, offset, order, command_id)

func _read_editor_logs(client_id: int, types: Array, count: int, offset: int, order: String, command_id: String) -> void:
    var plugin = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
    if not plugin:
        _send_error(client_id, "GodotMCPPlugin not found in Engine metadata", command_id)
        return
    
    if not plugin.has_method("get_editor_log_entries"):
        _send_error(client_id, "Editor log capture is not available on the active plugin", command_id)
        return
    
    var all_entries: Array = plugin.get_editor_log_entries()
    var total_count := all_entries.size()
    if total_count == 0:
        _send_success(client_id, {"logs": [], "total_count": 0, "source": "editor"}, command_id)
        return
    
    var logs = []
    var collected = 0
    var filter_enabled = types.size() > 0
    
    if order == "desc":
        var start_idx = total_count - offset - 1
        for i in range(start_idx, -1, -1):
            if collected >= count:
                break
            var entry: Dictionary = all_entries[i]
            var msg_type = str(entry.get("type", "General"))
            if filter_enabled and not types.has(msg_type):
                continue
            logs.append({
                "index": entry.get("index", i),
                "type": msg_type,
                "message": str(entry.get("message", ""))
            })
            collected += 1
    else:
        var start_idx = offset
        for i in range(start_idx, total_count):
            if collected >= count:
                break
            var entry: Dictionary = all_entries[i]
            var msg_type = str(entry.get("type", "General"))
            if filter_enabled and not types.has(msg_type):
                continue
            logs.append({
                "index": entry.get("index", i),
                "type": msg_type,
                "message": str(entry.get("message", ""))
            })
            collected += 1
    
    _send_success(client_id, {
        "logs": logs,
        "total_count": total_count,
        "source": "editor"
    }, command_id)

func _read_runtime_logs(client_id: int, types: Array, count: int, offset: int, order: String, command_id: String) -> void:
    var log_path = "user://logs/godot.log"
    if not FileAccess.file_exists(log_path):
        _send_error(client_id, "Runtime log file not found: %s" % log_path, command_id)
        return
    
    var file = FileAccess.open(log_path, FileAccess.READ)
    if not file:
        _send_error(client_id, "Failed to open runtime log file: %s" % log_path, command_id)
        return
    
    var all_lines = []
    while not file.eof_reached():
        var line = file.get_line()
        if not line.is_empty():
            all_lines.append(line)
    file.close()
    
    var total_count = all_lines.size()
    if total_count == 0:
        _send_success(client_id, {"logs": [], "total_count": 0, "source": "runtime"}, command_id)
        return
    
    # For runtime logs, type is always "info"
    var filter_enabled = types.size() > 0
    if filter_enabled and not types.has("info"):
        # User requested types that don't include "info", so no logs will match
        _send_success(client_id, {"logs": [], "total_count": total_count, "source": "runtime"}, command_id)
        return
    
    var logs = []
    var collected = 0
    
    if order == "desc":
        var start_idx = total_count - offset - 1
        for i in range(start_idx, -1, -1):
            if collected >= count:
                break
            logs.append({
                "index": i,
                "type": "info",
                "message": all_lines[i]
            })
            collected += 1
    else:
        var start_idx = offset
        for i in range(start_idx, total_count):
            if collected >= count:
                break
            logs.append({
                "index": i,
                "type": "info",
                "message": all_lines[i]
            })
            collected += 1
    
    _send_success(client_id, {
        "logs": logs,
        "total_count": total_count,
        "source": "runtime"
    }, command_id)