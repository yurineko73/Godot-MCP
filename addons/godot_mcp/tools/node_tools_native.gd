# node_tools_native.gd - Node Tools原生实现

@tool
class_name NodeToolsNative
extends RefCounted

var _editor_interface: EditorInterface = null

func initialize(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface

func register_tools(server_core: RefCounted) -> void:
	_register_create_node(server_core)
	_register_delete_node(server_core)
	_register_update_node_property(server_core)
	_register_get_node_properties(server_core)
	_register_list_nodes(server_core)
	_register_get_scene_tree(server_core)

func _register_create_node(server_core: RefCounted) -> void:
	server_core.register_tool(
		"create_node",
		"Create a new node in the Godot scene tree. Returns the node path and type.",
		{
			"type": "object",
			"properties": {
				"parent_path": {
					"type": "string",
					"description": "Path to the parent node where the new node will be created (e.g. '/root', '/root/MainScene')"
				},
				"node_type": {
					"type": "string",
					"description": "Type of node to create (e.g. 'Node2D', 'Sprite2D', 'CharacterBody2D')"
				},
				"node_name": {
					"type": "string",
					"description": "Name for the new node"
				}
			},
			"required": ["parent_path", "node_type", "node_name"]
		},
		Callable(self, "_tool_create_node"),
		{
			"type": "object",
			"properties": {
				"status": {"type": "string"},
				"node_path": {"type": "string"},
				"node_type": {"type": "string"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false}
	)

func _resolve_node_path(node_path: String) -> Node:
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return null
	
	if node_path == "/root" or node_path.is_empty():
		return scene_root
	
	var relative: String = node_path.trim_prefix("/root/")
	var parts: PackedStringArray = relative.split("/")
	
	if parts.size() > 0 and parts[0] == scene_root.name:
		if parts.size() == 1:
			return scene_root
		var sub_path: String = "/".join(parts.slice(1))
		return scene_root.get_node_or_null(sub_path)
	
	return scene_root.get_node_or_null(relative)

func _tool_create_node(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var node_type: String = params.get("node_type", "Node")
	var node_name: String = params.get("node_name", "NewNode")
	
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	
	var parent: Node = _resolve_node_path(parent_path)
	if not parent:
		if parent_path == "/root" or parent_path.is_empty():
			parent = _get_user_scene_root()
	
	if not parent:
		return {"error": "Parent node not found: " + parent_path}
	
	if not ClassDB.class_exists(node_type):
		return {"error": "Invalid node type: " + node_type}
	
	var node: Node = ClassDB.instantiate(node_type)
	node.name = node_name
	parent.add_child(node)
	
	var scene_root: Node = _get_user_scene_root()
	if scene_root:
		node.owner = scene_root
	
	editor_interface.mark_scene_as_unsaved()
	
	var friendly_path: String = "/root/" + scene_root.name if scene_root else "/root"
	var node_friendly: String = str(node.get_path())
	if scene_root:
		var root_full: String = str(scene_root.get_path())
		if node_friendly.begins_with(root_full):
			node_friendly = "/root/" + scene_root.name + node_friendly.substr(root_full.length())
	
	return {
		"status": "success",
		"node_path": node_friendly,
		"node_type": node.get_class()
	}

func _register_delete_node(server_core: RefCounted) -> void:
	server_core.register_tool(
		"delete_node",
		"Delete a node from the Godot scene tree. This operation is destructive and cannot be undone.",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Path to the node to delete (e.g. '/root/MainScene/Player')"
				}
			},
			"required": ["node_path"]
		},
		Callable(self, "_tool_delete_node"),
		{
			"type": "object",
			"properties": {
				"status": {"type": "string"},
				"deleted_node": {"type": "string"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": true, "idempotentHint": false, "openWorldHint": false}
	)

func _tool_delete_node(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	
	var node_to_delete: Node = _resolve_node_path(node_path)
	
	if not node_to_delete:
		return {"error": "Node not found: " + node_path}
	
	var deleted_node_name: String = node_to_delete.name
	var parent: Node = node_to_delete.get_parent()
	if parent:
		parent.remove_child(node_to_delete)
	
	node_to_delete.queue_free()
	editor_interface.mark_scene_as_unsaved()
	
	return {
		"status": "success",
		"deleted_node": deleted_node_name
	}

func _register_update_node_property(server_core: RefCounted) -> void:
	server_core.register_tool(
		"update_node_property",
		"Update a property of a specific node. Supports common property types with automatic type conversion.",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Path to the target node (e.g. '/root/MainScene/Player')"
				},
				"property_name": {
					"type": "string",
					"description": "Name of the property to update (e.g. 'position', 'visible', 'modulate')"
				},
				"property_value": {
					"description": "New value for the property. Type conversion is handled automatically."
				}
			},
			"required": ["node_path", "property_name", "property_value"]
		},
		Callable(self, "_tool_update_node_property"),
		{
			"type": "object",
			"properties": {
				"status": {"type": "string"},
				"node_path": {"type": "string"},
				"property_name": {"type": "string"},
				"old_value": {"type": "string"},
				"new_value": {"type": "string"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false}
	)

func _tool_update_node_property(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var property_name: String = params.get("property_name", "")
	var property_value: Variant = params.get("property_value", null)
	
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	if property_name.is_empty():
		return {"error": "Missing required parameter: property_name"}
	if property_value == null:
		return {"error": "Missing required parameter: property_value"}
	
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	
	var target_node: Node = _resolve_node_path(node_path)
	
	if not target_node:
		return {"error": "Node not found: " + node_path}
	
	if not property_name in target_node:
		return {"error": "Property '" + property_name + "' not found on node " + node_path}
	
	var old_value: Variant = target_node.get(property_name)
	var actual_value: Variant = property_value
	if property_value is String:
		var parsed: Variant = JSON.parse_string(property_value)
		if parsed != null:
			actual_value = parsed
	var converted_value: Variant = _convert_value_for_property(target_node, property_name, actual_value)
	
	var undo_redo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()
	if undo_redo:
		undo_redo.create_action("Update Property: " + property_name)
		undo_redo.add_do_property(target_node, property_name, converted_value)
		undo_redo.add_undo_property(target_node, property_name, old_value)
		undo_redo.commit_action()
	else:
		target_node.set(property_name, converted_value)
	
	var new_value: Variant = target_node.get(property_name)
	
	editor_interface.mark_scene_as_unsaved()
	
	return {
		"status": "success",
		"node_path": node_path,
		"property_name": property_name,
		"old_value": str(old_value),
		"new_value": str(new_value)
	}

func _register_get_node_properties(server_core: RefCounted) -> void:
	server_core.register_tool(
		"get_node_properties",
		"Get all properties of a specific node in the scene tree.",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Path to the node (e.g. '/root/MainScene/Player')"
				}
			},
			"required": ["node_path"]
		},
		Callable(self, "_tool_get_node_properties"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"node_type": {"type": "string"},
				"properties": {"type": "object"}
			}
		},
		{"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false}
	)

func _tool_get_node_properties(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	
	var target_node: Node = _resolve_node_path(node_path)
	
	if not target_node:
		return {"error": "Node not found: " + node_path}
	
	var properties: Dictionary = {}
	var property_list: Array = target_node.get_property_list()
	
	for property_dict in property_list:
		var prop_name: String = property_dict.get("name", "")
		if prop_name.begins_with("__"):
			continue
		var usage_flags: int = property_dict.get("usage", 0)
		if usage_flags & 128 or usage_flags & 64 or usage_flags & 256:
			continue
		var value = target_node.get(prop_name)
		properties[prop_name] = _serialize_value(value)
	
	return {
		"node_path": node_path,
		"node_type": target_node.get_class(),
		"properties": properties
	}

func _register_list_nodes(server_core: RefCounted) -> void:
	server_core.register_tool(
		"list_nodes",
		"List all nodes in the current scene or under a specific parent node.",
		{
			"type": "object",
			"properties": {
				"parent_path": {
					"type": "string",
					"description": "Optional path to the parent node. If not provided, lists all nodes in the scene."
				},
				"recursive": {
					"type": "boolean",
					"description": "Whether to list nodes recursively. Default is true."
				}
			}
		},
		Callable(self, "_tool_list_nodes"),
		{
			"type": "object",
			"properties": {
				"nodes": {"type": "array", "items": {"type": "string"}},
				"count": {"type": "integer"}
			}
		},
		{"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false}
	)

func _tool_list_nodes(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var recursive: bool = params.get("recursive", true)
	
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}
	
	var start_node: Node = _get_user_scene_root()
	if not start_node:
		return {"error": "No scene is currently open"}
	
	if not parent_path.is_empty() and parent_path != "/root":
		start_node = _resolve_node_path(parent_path)
		if not start_node:
			return {"error": "Parent node not found: " + parent_path}
	
	var nodes_list: Array[String] = []
	_collect_nodes(start_node, "", recursive, nodes_list, scene_root)
	
	return {
		"nodes": nodes_list,
		"count": nodes_list.size()
	}

func _register_get_scene_tree(server_core: RefCounted) -> void:
	server_core.register_tool(
		"get_scene_tree",
		"Get the complete scene tree hierarchy starting from the scene root. Returns full tree structure with node types.",
		{
			"type": "object",
			"properties": {
				"max_depth": {
					"type": "integer",
					"description": "Maximum depth to traverse. -1 means no limit."
				}
			}
		},
		Callable(self, "_tool_get_scene_tree"),
		{
			"type": "object",
			"properties": {
				"scene_name": {"type": "string"},
				"tree": {"type": "object"},
				"total_nodes": {"type": "integer"}
			}
		},
		{"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false}
	)

func _tool_get_scene_tree(params: Dictionary) -> Dictionary:
	var max_depth: int = params.get("max_depth", -1)
	
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}
	
	var tree: Dictionary = _build_scene_tree_node(scene_root, 0, max_depth, scene_root)
	var total_nodes: int = _count_all_nodes(scene_root)
	
	return {
		"scene_name": scene_root.name,
		"tree": tree,
		"total_nodes": total_nodes
	}

func _get_editor_interface() -> EditorInterface:
	if _editor_interface:
		return _editor_interface
	if Engine.has_meta("GodotMCPPlugin"):
		var plugin = Engine.get_meta("GodotMCPPlugin")
		if plugin and plugin.has_method("get_editor_interface"):
			return plugin.get_editor_interface()
	return null

func _get_user_scene_root() -> Node:
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return null
	
	var scene_root: Node = editor_interface.get_edited_scene_root()
	if scene_root and not scene_root.name.begins_with("@") and scene_root.get_class() != "PanelContainer":
		return scene_root
	
	var open_scenes: Array = editor_interface.get_open_scenes()
	for scene in open_scenes:
		if scene and not scene.name.begins_with("@") and scene.get_class() != "PanelContainer":
			return scene
	
	return scene_root

static func _make_friendly_path(node: Node, scene_root: Node) -> String:
	if not scene_root:
		return str(node.get_path())
	if node == scene_root:
		return "/root/" + scene_root.name
	var node_path: String = str(node.get_path())
	var root_path: String = str(scene_root.get_path())
	if node_path.begins_with(root_path + "/"):
		return "/root/" + scene_root.name + node_path.substr(root_path.length())
	return node_path

static func _collect_nodes(node: Node, path: String, recursive: bool, result: Array[String], scene_root: Node = null) -> void:
	var node_path: String = _make_friendly_path(node, scene_root)
	result.append(node_path)
	if recursive:
		for child_index in range(node.get_child_count()):
			var child: Node = node.get_child(child_index)
			_collect_nodes(child, node_path, recursive, result, scene_root)

func _convert_value_for_property(node: Node, property_name: String, value: Variant) -> Variant:
	if value == null:
		return value
	
	var property_type: int = TYPE_NIL
	for prop in node.get_property_list():
		if prop["name"] == property_name:
			property_type = prop["type"]
			break
	
	if property_type == TYPE_NIL:
		return value
	
	match property_type:
		TYPE_VECTOR2:
			if value is Dictionary:
				return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
			if value is String:
				var parts: PackedStringArray = value.replace("(", "").replace(")", "").replace(" ", "").split(",")
				if parts.size() >= 2:
					return Vector2(float(parts[0]), float(parts[1]))
		TYPE_VECTOR2I:
			if value is Dictionary:
				return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
			if value is String:
				var parts: PackedStringArray = value.replace("(", "").replace(")", "").replace(" ", "").split(",")
				if parts.size() >= 2:
					return Vector2i(int(parts[0]), int(parts[1]))
		TYPE_VECTOR3:
			if value is Dictionary:
				return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
			if value is String:
				var parts: PackedStringArray = value.replace("(", "").replace(")", "").replace(" ", "").split(",")
				if parts.size() >= 3:
					return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
		TYPE_VECTOR3I:
			if value is Dictionary:
				return Vector3i(int(value.get("x", 0)), int(value.get("y", 0)), int(value.get("z", 0)))
			if value is String:
				var parts: PackedStringArray = value.replace("(", "").replace(")", "").replace(" ", "").split(",")
				if parts.size() >= 3:
					return Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
		TYPE_COLOR:
			if value is Dictionary:
				return Color(float(value.get("r", 0.0)), float(value.get("g", 0.0)), float(value.get("b", 0.0)), float(value.get("a", 1.0)))
			if value is String:
				if value.begins_with("#"):
					return Color(value)
				return Color(value)
		TYPE_BOOL:
			if value is String:
				return value.to_lower() == "true"
			if value is int or value is float:
				return value != 0
		TYPE_INT:
			if value is String:
				return int(value)
			if value is float:
				return int(value)
		TYPE_FLOAT:
			if value is String:
				return float(value)
			if value is int:
				return float(value)
		TYPE_RECT2:
			if value is Dictionary:
				return Rect2(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("w", 0.0)), float(value.get("h", 0.0)))
		TYPE_TRANSFORM2D:
			if value is Dictionary:
				var t: Transform2D = Transform2D()
				if value.has("rotation"):
					t = t.rotated(float(value["rotation"]))
				if value.has("origin"):
					var origin: Dictionary = value["origin"]
					t.origin = Vector2(float(origin.get("x", 0.0)), float(origin.get("y", 0.0)))
				return t
	
	return value

static func _serialize_value(value: Variant) -> Variant:
	if value == null:
		return null
	match typeof(value):
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_VECTOR2:
			return {"x": value.x, "y": value.y}
		TYPE_VECTOR3:
			return {"x": value.x, "y": value.y, "z": value.z}
		TYPE_VECTOR4:
			return {"x": value.x, "y": value.y, "z": value.z, "w": value.w}
		TYPE_COLOR:
			return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_ARRAY:
			var result: Array = []
			for item in value:
				result.append(_serialize_value(item))
			return result
		TYPE_DICTIONARY:
			var result: Dictionary = {}
			for key in value:
				result[str(key)] = _serialize_value(value[key])
			return result
		_:
			return str(value)

static func _build_scene_tree_node(node: Node, current_depth: int, max_depth: int, scene_root: Node = null) -> Dictionary:
	var node_info: Dictionary = {
		"name": node.name,
		"type": node.get_class(),
		"path": _make_friendly_path(node, scene_root),
		"child_count": node.get_child_count()
	}
	
	var important_props: Array[String] = ["visible", "position", "rotation", "scale", "modulate"]
	var properties: Dictionary = {}
	for prop_name in important_props:
		if prop_name in node:
			properties[prop_name] = _serialize_value(node.get(prop_name))
	if properties.size() > 0:
		node_info["properties"] = properties
	
	if max_depth >= 0 and current_depth >= max_depth:
		if node.get_child_count() > 0:
			node_info["children_truncated"] = true
		return node_info
	
	if node.get_child_count() > 0:
		var children: Array[Dictionary] = []
		for child_index in range(node.get_child_count()):
			var child: Node = node.get_child(child_index)
			var child_info: Dictionary = _build_scene_tree_node(child, current_depth + 1, max_depth, scene_root)
			children.append(child_info)
		node_info["children"] = children
	
	return node_info

static func _count_all_nodes(node: Node) -> int:
	var count: int = 1
	for child_index in range(node.get_child_count()):
		var child: Node = node.get_child(child_index)
		count += _count_all_nodes(child)
	return count
