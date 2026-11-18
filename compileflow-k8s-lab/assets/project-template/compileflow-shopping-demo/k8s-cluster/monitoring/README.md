# Prometheus + Grafana 监控实验

组件全部运行在 Kubernetes：

```text
k6 --remote-write--> Prometheus <--scrape-- cAdvisor / kube-state-metrics
                              |
                              v
                           Grafana
```

启动：

```powershell
cd "<项目目录>\compileflow-shopping-demo\k8s-cluster\monitoring"
.\start.ps1
```

地址：

- Grafana：<http://127.0.0.1:23000>，账号密码均为 `admin`；
- Prometheus：<http://127.0.0.1:29090>；
- 预置仪表盘：`CompileFlow 实验 / CompileFlow · k6 与 K8s 监控`。

Grafana 展示 k6 的 RPS、P95、HTTP 错误率、业务断言成功率，以及
`compileflow-lab` 中各 Pod 的 CPU、内存和容器重启次数。

运行压测后产生 k6 指标：

```powershell
cd ..\load-test
.\run.ps1
```

Prometheus 数据在本 kind 节点保留 7 天。Pod 重建不会丢失；删除整个 kind 集群会删除
这些实验数据。`access` 下的两个轻量 Docker 容器只负责把没有预留到宿主机的 NodePort
映射到本机，不保存指标。

