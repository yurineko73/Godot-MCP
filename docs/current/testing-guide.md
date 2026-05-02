# 测试指南

本指南详细说明 Godot-MCP 项目的测试策略、测试工具和最佳实践。

## 目录

1. [测试概述](#测试概述)
2. [单元测试](#单元测试)
3. [集成测试](#集成测试)
4. [性能测试](#性能测试)
5. [端到端测试](#端到端测试)
6. [测试覆盖率](#测试覆盖率)
7. [持续集成](#持续集成)
8. [测试最佳实践](#测试最佳实践)

---

## 测试概述

### 测试金字塔

```
           __
          /  \
         / E2E \   端到端测试（少量，关键路径）
        /______\
       /        \
      / Integration\ 集成测试（中量，API 级别）
     /__________\
    /            \
   /   Unit Tests   \  单元测试（大量，函数级别）
  /________________\
```

### 测试类型

| 测试类型 | 用途 | 工具 | 覆盖率目标 |
|----------|------|------|------------|
| 单元测试 | 测试单个函数/类 | Vitest, Godot | 80% |
| 集成测试 | 测试模块交互 | Python, curl | 关键路径 100% |
| 性能测试 | 测试系统性能 | GDScript | N/A |
| 端到端测试 | 测试完整流程 | Node.js | 核心功能 100% |

### 测试目录结构

```
test/
├── unit/                       # 单元测试
│   ├── tools/                  # 工具单元测试
│   │   ├── create_node.test.ts
│   │   └── delete_node.test.ts
│   └── utils/                 # 工具类单元测试
│       └── godot_connection.test.ts
├── integration/                # 集成测试
│   ├── stdio/
│   │   └── test_mcp_stdio.py
│   └── http/
│       └── test_mcp_http.py
├── performance/                # 性能测试
│   └── performance_test.gd
├── e2e/                       # 端到端测试
│   ├── test_mcp_client.js
│   └── test_mcp_client.ts
└── helpers/                   # 测试辅助工具
    ├── mcp_client.js
    └── godot_mock.gd
```

---

## 单元测试

### GDScript 单元测试

**工具**：Godot 内置测试框架

**示例测试** (`test/tools/test_create_node.gd`)：
```gdscript
extends SceneTree

const NodeToolsNative = preload("res://addons/godot_mcp/native_mcp/tools/node_tools_native.gd")

var _tool_instance: NodeToolsNative = null
var _pass_count: int = 0
var _fail_count: int = 0

func _ready() -> void:
	print("=== Running test: create_node ===")
	
	_tool_instance = NodeToolsNative.new()
	_tool_instance.initialize(get_editor_interface())
	
	# 运行测试用例
	_test_create_valid_node()
	_test_create_invalid_node_type()
	_test_create_invalid_parent_path()
	
	# 打印结果
	print("\n=== Test Results ===")
	print("Passed: " + str(_pass_count))
	print("Failed: " + str(_fail_count))
	
	if _fail_count == 0:
		print("✓ All tests passed")
	else:
		print("✗ Some tests failed")
	
	quit()

func _test_create_valid_node() -> void:
	print("\nTest: create valid node")
	
	var result: Dictionary = _tool_instance.create_node({
		"parent_path": "/root",
		"node_type": "Node2D",
		"node_name": "TestNode"
	})
	
	_assert_equal(result["status"], "success", "Node creation status")
	_assert_true(result.has("node_path"), "Has node_path")

func _test_create_invalid_node_type() -> void:
	print("\nTest: create invalid node type")
	
	var result: Dictionary = _tool_instance.create_node({
		"parent_path": "/root",
		"node_type": "InvalidType",
		"node_name": "Test"
	})
	
	_assert_equal(result["status"], "error", "Invalid node type status")
	_assert_true(result.has("message"), "Has error message")

func _test_create_invalid_parent_path() -> void:
	print("\nTest: create invalid parent path")
	
	var result: Dictionary = _tool_instance.create_node({
		"parent_path": "/non/existent",
		"node_type": "Node2D",
		"node_name": "Test"
	})
	
	_assert_equal(result["status"], "error", "Invalid parent path status")
	_assert_true(result.has("message"), "Has error message")

# 断言辅助函数
func _assert_equal(actual, expected: Variant, test_name: String) -> void:
	if actual == expected:
		_pass_count += 1
		print("  ✓ " + test_name)
	else:
		_fail_count += 1
		print("  ✗ " + test_name + ": expected " + str(expected) + ", got " + str(actual))

func _assert_true(condition: bool, test_name: String) -> void:
	if condition:
		_pass_count += 1
		print("  ✓ " + test_name)
	else:
		_fail_count += 1
		print("  ✗ " + test_name)
```

**运行测试**：
```bash
# 在 Godot Editor 中
# 1. 打开 test/tools/test_create_node.gd
# 2. 点击 "运行" 按钮

# 或使用命令行
"C:\Program Files\Godot\Godot.exe" --path "F:\gitProjects\Godot-MCP" --script "test/tools/test_create_node.gd"
```

---

## 集成测试

### HTTP 模式集成测试

**工具**：Python + `requests`

**示例测试** (`test/http/test_mcp_http.py`)：
```python
#!/usr/bin/env python3
"""测试 MCP 服务器的 HTTP 模式"""

import requests
import json

BASE_URL = "http://localhost:9080/mcp"
AUTH_TOKEN = "test-token-1234567890"

def test_tools_list():
    """测试 tools/list 端点"""
    response = requests.post(
        BASE_URL,
        json={
            "jsonrpc": "2.0",
            "method": "tools/list",
            "id": 1
        },
        headers={
            "Authorization": f"Bearer {AUTH_TOKEN}"
        }
    )
    
    assert response.status_code == 200, f"Unexpected status code: {response.status_code}"
    
    data = response.json()
    assert "result" in data, "Missing result in response"
    assert "tools" in data["result"], "Missing tools in result"
    assert len(data["result"]["tools"]) >= 42, "Not enough tools"
    
    print("✓ test_tools_list passed")

def test_unauthorized():
    """测试未授权请求"""
    response = requests.post(
        BASE_URL,
        json={
            "jsonrpc": "2.0",
            "method": "tools/list",
            "id": 1
        }
        # 不包含 Authorization 头
    )
    
    assert response.status_code == 401 or "error" in response.json(), "Should return 401 or error"
    
    print("✓ test_unauthorized passed")

def test_sse_endpoint():
    """测试 SSE 端点"""
    import sseclient
    
    response = requests.get(
        BASE_URL,
        headers={
            "Accept": "text/event-stream",
            "Authorization": f"Bearer {AUTH_TOKEN}"
        },
        stream=True
    )
    
    assert response.status_code == 200, "SSE connection failed"
    
    client = sseclient.SSEClient(response)
    for event in client.events():
        assert event.event == "connected", "Unexpected event"
        assert "session_id" in event.data, "Missing session_id"
        break  # 仅测试第一个事件
    
    print("✓ test_sse_endpoint passed")

if __name__ == "__main__":
    # 确保服务器正在运行
    test_tools_list()
    test_unauthorized()
    test_sse_endpoint()
    print("\n✓ All HTTP integration tests passed")
```

**运行测试**：
```bash
# 首先启动 HTTP 服务器
cd F:\gitProjects\Godot-MCP
"Godot.exe" --path . --mcp-server --http

# 然后运行测试
cd test/http
python test_mcp_http.py
```

---

## 性能测试

### Godot 性能测试

**示例** (`test/benchmark/performance_test.gd`)：
```gdscript
extends SceneTree

# 性能测试配置
const TEST_ITERATIONS: int = 100
const MAX_AVERAGE_TIME_MS: float = 10.0

func _ready() -> void:
	print("=== Godot-MCP Performance Tests ===")
	
	# 测试 1: create_node 性能
	_test_create_node_performance()
	
	# 测试 2: list_nodes 性能
	_test_list_nodes_performance()
	
	# 测试 3: get_node_properties 性能
	_test_get_node_properties_performance()
	
	print("\n✓ All performance tests passed")
	quit()

func _test_create_node_performance() -> void:
	print("\nTest: create_node performance")
	print("  Iterations: " + str(TEST_ITERATIONS))
	
	var tool_instance: NodeToolsNative = NodeToolsNative.new()
	tool_instance.initialize(get_editor_interface())
	
	var total_time: int = 0
	
	for i in range(TEST_ITERATIONS):
		var start_time: int = Time.get_ticks_msec()
		
		var result: Dictionary = tool_instance.create_node({
			"parent_path": "/root",
			"node_type": "Node2D",
			"node_name": "PerfTest" + str(i)
		})
		
		var elapsed: int = Time.get_ticks_msec() - start_time
		total_time += elapsed
		
		assert(result["status"] == "success", "Node creation failed")
	
	var avg_time: float = total_time / float(TEST_ITERATIONS)
	var min_time: int = 0  # TODO: 追踪最小值
	var max_time: int = 0  # TODO: 追踪最大值
	
	print("  Average time: " + str(avg_time) + "ms")
	print("  Total time: " + str(total_time) + "ms")
	
	assert(avg_time < MAX_AVERAGE_TIME_MS, "Performance degradation detected")
	print("  ✓ create_node performance")

func _test_list_nodes_performance() -> void:
	print("\nTest: list_nodes performance")
	# ... 类似实现

func _test_get_node_properties_performance() -> void:
	print("\nTest: get_node_properties performance")
	# ... 类似实现
```

**运行性能测试**：
```bash
"Godot.exe" --path "F:\gitProjects\Godot-MCP" --script "test/benchmark/performance_test.gd"
```

### 负载测试

**工具**：Python + `threading`

**示例** (`test/load/test_concurrent_requests.py`)：
```python
#!/usr/bin/env python3
"""并发负载测试"""

import threading
import requests
import time

BASE_URL = "http://localhost:9080/mcp"
AUTH_TOKEN = "test-token-1234567890"
NUM_THREADS = 10
NUM_REQUESTS_PER_THREAD = 100

def worker(thread_id: int):
    """工作线程函数"""
    results = {"success": 0, "fail": 0}
    
    for i in range(NUM_REQUESTS_PER_THREAD):
        try:
            response = requests.post(
                BASE_URL,
                json={
                    "jsonrpc": "2.0",
                    "method": "tools/list",
                    "id": thread_id * 1000 + i
                },
                headers={
                    "Authorization": f"Bearer {AUTH_TOKEN}"
                },
                timeout=5
            )
            
            if response.status_code == 200:
                results["success"] += 1
            else:
                results["fail"] += 1
        
        except Exception as e:
            results["fail"] += 1
    
    return results

def test_concurrent_requests():
    """测试并发请求"""
    threads = []
    results = []
    
    start_time = time.time()
    
    # 创建并启动线程
    for i in range(NUM_THREADS):
        thread = threading.Thread(target=worker, args=(i,))
        threads.append(thread)
        thread.start()
    
    # 等待所有线程完成
    for thread in threads:
        thread.join()
    
    elapsed = time.time() - start_time
    
    # 汇总结果
    total_success = 0
    total_fail = 0
    
    for result in results:
        total_success += result["success"]
        total_fail += result["fail"]
    
    total_requests = total_success + total_fail
    requests_per_second = total_requests / elapsed
    
    print(f"=== Concurrent Requests Test ===")
    print(f"Threads: {NUM_THREADS}")
    print(f"Requests per thread: {NUM_REQUESTS_PER_THREAD}")
    print(f"Total requests: {total_requests}")
    print(f"Success: {total_success}")
    print(f"Fail: {total_fail}")
    print(f"Elapsed time: {elapsed:.2f}s")
    print(f"Requests/second: {requests_per_second:.2f}")
    
    assert total_fail == 0, "Some requests failed"
    print("✓ Concurrent requests test passed")

if __name__ == "__main__":
    test_concurrent_requests()
```

---

## 测试覆盖率

### GDScript 覆盖率

Godot 没有内置的覆盖率工具，但可以使用以下方法：

**手动追踪**：
```gdscript
var _coverage: Dictionary = {}

func _track_coverage(function_name: String) -> void:
    if not _coverage.has(function_name):
        _coverage[function_name] = 0
    _coverage[function_name] += 1

func _get_coverage_report() -> String:
    var report: String = "Coverage Report:\n"
    for func_name in _coverage:
        report += "  " + func_name + ": " + str(_coverage[func_name]) + " calls\n"
    return report
```

**使用第三方工具**：
- [Gut](https://github.com/bitwes/Gut)：Godot 单元测试框架，包含覆盖率报告

---

## 持续集成

### GitHub Actions 配置

**示例** (`.github/workflows/test.yml`)：
```yaml
name: Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        node-version: [18.x, 20.x]
        godot-version: ["4.2", "4.3"]
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v3
        with:
          node-version: ${{ matrix.node-version }}
          cache: "npm"
      
      - name: Setup Godot ${{ matrix.godot-version }}
        uses: azure/godot-builds@v1
        with:
          version: ${{ matrix.godot-version }}
      
      - name: Install dependencies
        run: |
          cd server
          npm install
          npm run build
      
      - name: Run unit tests
        run: |
          cd server
          npm test
      
      - name: Run integration tests (stdio)
        run: |
          cd test/stdio
          python test_mcp_stdio.py
      
      - name: Run integration tests (http)
        run: |
          # 启动 Godot 服务器（后台）
          godot --path . --mcp-server --http &
          sleep 5
          
          # 运行测试
          cd test/http
          python test_mcp_http.py
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./server/coverage/coverage-final.json
```

---

## 测试最佳实践

### 1. 测试命名

**好的做法**：
```typescript
describe("createNode", () => {
  it("should create a new node when valid parameters are provided", () => {
    // ...
  });

  it("should return error when node type is invalid", () => {
    // ...
  });
});
```

**避免**：
```typescript
describe("createNode", () => {
  it("test1", () => {
    // ...
  });

  it("test2", () => {
    // ...
  });
});
```

### 2. 测试独立性

**好的做法**：
```typescript
beforeEach(() => {
  // 每个测试前重置状态
  mockGodot.reset();
});

it("should create node", () => {
  // 不依赖其他测试
});
```

**避免**：
```typescript
it("should create node", () => {
  // 依赖前一个测试创建的节点
});
```

### 3. Mock 外部依赖

**好的做法**：
```typescript
// 使用 Mock
const mockGodot = {
  createNode: vi.fn().mockReturnValue({ status: "success" }),
};

const result = await createNode(mockGodot, "/root", "Node2D", "Player");
expect(mockGodot.createNode).toHaveBeenCalled();
```

**避免**：
```typescript
// 依赖真实的 Godot 服务器
const realGodot = new GodotConnection();
const result = await createNode(realGodot, "/root", "Node2D", "Player");
```

### 4. 测试边界条件

**示例**：
```typescript
it("should handle empty string", () => {
  const result = await createNode(mockGodot, "", "Node2D", "Player");
  expect(result.status).toBe("error");
});

it("should handle null", () => {
  const result = await createNode(mockGodot, null, "Node2D", "Player");
  expect(result.status).toBe("error");
});

it("should handle very long node name", () => {
  const longName = "A".repeat(1000);
  const result = await createNode(mockGodot, "/root", "Node2D", longName);
  expect(result.status).toBe("error");
});
```

### 5. 测试错误信息

**示例**：
```typescript
it("should return descriptive error message", async () => {
  const result = await createNode(mockGodot, "/root", "InvalidType", "Test");
  
  expect(result.status).toBe("error");
  expect(result.message).toContain("Invalid node type");
  expect(result.message).toContain("InvalidType");
});
```

---

## 总结

测试是确保代码质量的关键环节。Godot-MCP 项目采用多层次的测试策略，包括单元测试、集成测试、性能测试和端到端测试。遵循本指南中的最佳实践，可以编写出高质量、可维护的测试代码。

如有任何问题或建议，欢迎在 GitHub Issues 中提出。

**Happy Testing！** 🧪
