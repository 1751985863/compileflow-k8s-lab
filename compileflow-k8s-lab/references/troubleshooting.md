# 故障诊断顺序

出现问题时按层检查，避免直接反复重装。

## 1. 主机层

运行 `scripts/preflight.ps1`，确认 Docker Engine、Java 17 和所有命令可用。再检查端口占用：28080、28761、28090、25601、22800、23000、29090、24466。

## 2. Kind 和 Kubernetes

```powershell
kind get clusters
kubectl config current-context
kubectl get pods -A -o wide
kubectl get events -n compileflow-lab --sort-by=.lastTimestamp
```

上下文必须是 `kind-compileflow-k8s`。不要在上下文不明确时执行删除或 apply。

## 3. 业务与注册中心

```powershell
kubectl get deploy -n compileflow-lab
kubectl logs -n compileflow-lab -l app=compileflow-shopping-demo --tail=200 --prefix
kubectl logs -n compileflow-lab -l app=compileflow-payment-service --tail=200 --prefix
```

Eureka 需要看到 Gateway 3、Shopping 4、Payment 4、Workbench 3 个 UP 实例。滚动更新后要等待旧 IP 从注册表和网关缓存消失。

## 4. 数据和消息

- PXC：`kubectl get pxc payment-pxc -n compileflow-lab` 必须为 ready，PXC Pod 应为 3 个。
- RocketMQ：2 个 NameServer 和 2 个 Broker 都应 Running；异步接口先返回 `PAYMENT_PENDING`，随后查询应为 `PAID`。
- MyBatis-Plus：支付 Pod 日志应出现 MyBatis-Plus 初始化且 Hikari 连接为 MySQL，不应退回内存 Store。

## 5. 可观测性

- 没有 Kibana 日志：检查 Filebeat → Kafka → Logstash → Elasticsearch 每一段，而不是只重启 Kibana。
- Grafana k6 无数据：k6 必须在 K8s Job 中运行并向 Prometheus Remote Write 输出；本机直接运行不会自动进入集群 Prometheus。
- SkyWalking 链路不贯通：确认各镜像含 Agent、服务名不同、OAP 地址为集群 Service，并检查 OpenFeign/HTTP/RocketMQ 插件覆盖范围。

## 6. 固定终止条件

同一故障连续三次仍无进展时，保存 `kubectl get pods/events`、相关 Pod 日志、部署脚本输出和主机资源信息，再向用户报告具体阻塞点；不要无限重试或删除持久卷。

