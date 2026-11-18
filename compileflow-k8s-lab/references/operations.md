# 复刻与日常操作

## 0. 在新电脑安装 Skill

解压压缩包后，在解压出的 Skill 根目录执行：

```powershell
pwsh -ExecutionPolicy Bypass -File .\scripts\install-skill.ps1
```

重启 Codex 后可使用 `$compileflow-k8s-lab`。若目标位置已经存在，脚本默认停止；检查确认后才能显式使用 `-Force` 更新。

## 1. 恢复源码

在 Skill 根目录执行：

```powershell
pwsh -ExecutionPolicy Bypass -File .\scripts\restore-lab.ps1 `
  -Destination 'D:\labs\compileflow-k8s-lab'
```

脚本会复制实验源码和 Skill 内置的固定 CompileFlow 源码快照，并创建本机专用 `.lab.env`，因此恢复源码不依赖 GitHub。目标目录非空时默认停止；只有用户明确允许覆盖时才加 `-Force`。

## 2. 部署核心集群

```powershell
Set-Location 'D:\labs\compileflow-k8s-lab\compileflow-shopping-demo\k8s-cluster'
pwsh -ExecutionPolicy Bypass -File .\deploy.ps1
pwsh -ExecutionPolicy Bypass -File .\verify.ps1
```

不要用 Windows PowerShell 5 执行 UTF-8 中文脚本，统一使用 `pwsh`。

## 3. 启动监控与 Headlamp

```powershell
pwsh -ExecutionPolicy Bypass -File .\monitoring\start.ps1
pwsh -ExecutionPolicy Bypass -File .\headlamp-docker\start.ps1
```

## 4. 运行压测

```powershell
Set-Location .\load-test
pwsh -ExecutionPolicy Bypass -File .\run.ps1 `
  -Rate 500 -Duration 30s -PreAllocatedVUs 500 -MaxVUs 1000
```

压测前先用低速率冒烟，再逐级提升；不要一开始就用极高并发判断系统上限。

## 5. 访问地址

| 地址 | 用途 |
|---|---|
| `http://127.0.0.1:28080` | Nginx 总入口/API |
| `http://127.0.0.1:28761` | Eureka |
| `http://127.0.0.1:28090` | SkyWalking UI |
| `http://127.0.0.1:25601` | Kibana |
| `http://127.0.0.1:22800` | SkyWalking OAP 状态/GraphQL |
| `http://127.0.0.1:23000` | Grafana（启动 monitoring 后） |
| `http://127.0.0.1:29090` | Prometheus（启动 monitoring 后） |
| `http://127.0.0.1:24466` | Headlamp（启动后） |

## 6. 停止

核心集群用 `k8s-cluster/stop.ps1`。监控和 Headlamp 分别使用各自目录的停止脚本。删除 Kind 集群会删除集群内部数据，执行前必须确认用户确实要重建。

