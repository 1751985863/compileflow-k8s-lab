# Headlamp Docker 控制台

Headlamp 作为独立 Docker 容器运行，通过 kind 的 Docker 网络访问
`compileflow-k8s`。它不会部署到 Kubernetes 内，也不会占用业务 Pod。

## 启动

```powershell
cd "<项目目录>\compileflow-shopping-demo\k8s-cluster\headlamp-docker"
.\start.ps1
```

浏览器打开：<http://127.0.0.1:24466>

默认上下文是 `compileflow-k8s`，默认命名空间是 `compileflow-lab`。

本实验给 Headlamp 绑定 Kubernetes 内置的 `view` 角色，并补充 Node、命名空间、
存储和 RBAC 等集群级资源的只读权限。因此可以查看 Pod、Deployment、Service、
Node、事件和日志，但不能读取 Secret、删除 Pod、扩缩容或修改配置。这比在网页中
直接保存集群管理员凭据更适合日常检查。

## 停止

```powershell
.\stop.ps1
```

容器设置了 `restart: unless-stopped`：Docker Desktop 重启后会自动恢复；手动执行
`stop.ps1` 后不会自动启动。Kubernetes 集群删除并重建后，需要重新运行 `start.ps1`
生成新凭据。

