# tools 说明

这个文件夹放的是**通用烧录脚本**，解决这块 DAPLink「红灯一直闪、烧不进去」的问题。

## 里面有什么

- `flash.ps1`：一键烧录脚本。
  - 自动从工程的 `Makefile` 里读取 `TARGET`，找到 `build\<TARGET>.elf`，所以换工程不用改脚本；
  - 内置 `cmsis-dap quirk enable`，绕开 DAPLink 固件（FW 0254）的应答错位；
  - 失败会自动等待 8 秒重试，最多 5 次。

## 怎么用

### 方式一：放到某个工程里（推荐）

1. 把整个 `tools` 文件夹复制到工程根目录（和 `Makefile` 同级）。
2. 在该工程的 `.vscode\tasks.json` 里加一个任务：

```json
{
    "label": "flash (DAPLink)",
    "type": "shell",
    "command": "powershell",
    "args": [
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "${workspaceFolder}\\tools\\flash.ps1"
    ],
    "options": { "cwd": "${workspaceFolder}" },
    "dependsOn": ["build task"],
    "problemMatcher": []
}
```

3. VSCode 里 `Ctrl+Shift+P` → `Tasks: Run Task` → `flash (DAPLink)`。

### 方式二：直接命令行

在工程根目录执行：

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\flash.ps1
```

## 成功标志

日志里出现：

```
** Programming Finished **
** Verified OK **
** Resetting Target **
```

`Verified OK` = 固件已经写进芯片，断电重启也会继续运行。

## 失败怎么办

| 日志 | 原因 | 处理 |
|---|---|---|
| `CMSIS-DAP command mismatch` | 探针应答错位 | 脚本会自动重试；仍失败就拔插 DAPLink |
| `unable to find a matching CMSIS-DAP device` | 探针没插 / 没识别 | 检查 USB 线，直插主机口 |
| `Error: open failed` | 探针被别的软件占用 | 关掉其他调试软件再试 |

> 注意：`flash.ps1` 必须保存为 **UTF-8 带 BOM**，否则 Windows PowerShell 读中文会乱码甚至报语法错误。
