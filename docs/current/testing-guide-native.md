# MCP原生实现测试指南

## 测试概述
本文档提供Godot-MCP原生实现的测试步骤，帮助验证所有功能是否正常工作。

## 测试准备
1. 打开Godot编辑器
2. 确保`addons/godot_mcp`插件已启用
3. 打开MCP面板（底部面板）

## 功能测试

### 1. MCP服务器控制测试
- [ ] 在MCP面板中点击"启动服务器"按钮
- [ ] 验证服务器状态显示为"运行中"
- [ ] 验证日志输出显示"MCP服务器已启动"
- [ ] 点击"停止服务器"按钮
- [ ] 验证服务器状态显示为"已停止"

### 2. 工具调用测试
使用MCP客户端（如Claude Desktop）连接后，测试以下工具：

#### 场景工具
- [ ] `get_scene_list` - 获取项目中的所有场景
- [ ] `get_current_scene` - 获取当前打开的场景
- [ ] `open_scene` - 打开指定场景
- [ ] `create_scene` - 创建新场景
- [ ] `save_scene` - 保存当前场景
- [ ] `get_scene_tree` - 获取场景树结构

#### 节点工具
- [ ] `get_node_tree` - 获取节点树
- [ ] `create_node` - 创建新节点
- [ ] `delete_node` - 删除节点
- [ ] `update_node_property` - 更新节点属性
- [ ] `get_node_properties` - 获取节点属性

#### 脚本工具
- [ ] `get_script_list` - 获取所有脚本
- [ ] `get_current_script` - 获取当前打开的脚本
- [ ] `create_script` - 创建新脚本
- [ ] `update_script` - 更新脚本内容
- [ ] `get_script_content` - 获取脚本内容

#### 项目工具
- [ ] `get_project_info` - 获取项目信息
- [ ] `get_project_settings` - 获取项目设置
- [ ] `update_project_setting` - 更新项目设置

#### 编辑器工具
- [ ] `get_editor_info` - 获取编辑器信息
- [ ] `get_selected_nodes` - 获取选中的节点
- [ ] `open_editor_screen` - 打开指定编辑器屏幕

#### 调试工具
- [ ] `get_editor_logs` - 获取编辑器日志
- [ ] `clear_editor_logs` - 清除编辑器日志
- [ ] `run_project` - 运行项目
- [ ] `stop_project` - 停止项目运行

### 3. 资源读取测试
使用MCP客户端读取以下资源：

- [ ] `godot://scene/list` - 场景列表
- [ ] `godot://scene/current` - 当前场景
- [ ] `godot://script/list` - 脚本列表
- [ ] `godot://script/current` - 当前脚本（需先打开一个脚本）
- [ ] `godot://project/info` - 项目信息
- [ ] `godot://project/settings` - 项目设置
- [ ] `godot://editor/state` - 编辑器状态

### 4. UI面板测试
- [ ] 验证MCP面板正确显示在底部面板
- [ ] 验证服务器状态正确显示
- [ ] 验证日志查看器能正确显示日志
- [ ] 验证工具列表能正确显示和切换
- [ ] 验证设置面板能正确保存设置

### 5. 路径验证测试
- [ ] 尝试访问非法路径（如`res://../etc/passwd`）
- [ ] 验证系统拒绝访问并返回错误
- [ ] 尝试访问允许的路径（如`res://default.tscn`）
- [ ] 验证系统允许访问

### 6. 性能测试
- [ ] 测试大量节点场景的加载速度
- [ ] 测试大文件的读取速度
- [ ] 测试并发工具调用的处理能力

## 自动化测试
如果需要自动化测试，可以创建以下GDScript测试文件：

### 测试文件结构
```
addons/godot_mcp/tests/
  - test_mcp_server_core.gd
  - test_resource_tools.gd
  - test_scene_tools.gd
  - test_script_tools.gd
  - test_path_validator.gd
```

### 运行测试
1. 在Godot编辑器中打开脚本编辑器
2. 加载测试脚本
3. 运行测试脚本

## 常见问题排查

### 问题：MCP服务器无法启动
- 检查端口9080是否被占用
- 检查Godot编辑器是否以管理员权限运行
- 查看日志输出获取详细错误信息

### 问题：工具调用失败
- 检查MCP客户端配置是否正确
- 检查工具参数是否符合要求
- 查看Godot编辑器输出获取详细错误信息

### 问题：资源读取失败
- 检查资源URI是否正确
- 检查是否有打开的场景或脚本
- 查看Godot编辑器输出获取详细错误信息

## 测试检查清单
完成所有测试后，使用此清单确认功能完整性：

### 核心功能
- [ ] MCP服务器能正常启动和停止
- [ ] 所有30个工具都能正常调用
- [ ] 所有7个资源都能正常读取
- [ ] UI面板所有功能都正常工作

### 安全功能
- [ ] 路径验证能正确阻止非法路径
- [ ] 所有文件操作都经过路径验证

### 性能要求
- [ ] 场景加载时间 < 1秒（100个节点内）
- [ ] 工具调用响应时间 < 500毫秒
- [ ] 资源读取时间 < 200毫秒

## 下一步
完成测试后：
1. 修复发现的所有问题
2. 清理冗余文件（旧版MCP实现）
3. 更新文档和README
4. 准备发布新版本
