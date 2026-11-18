# Kubernetes + SkyWalking 双节点 OAP 集群实验

这套部署和原来的 Docker Compose 环境并存，使用独立端口，不会停止原容器。

```text
宿主机 :28080
  → kind NodePort
  → Nginx 系统总入口
  → Gateway × 3
      → Redis Cluster × 6（3 主 3 从）共享令牌桶
  → shopping-service × 4
      → OpenFeign → Workbench × 3 → PostgreSQL
      → OpenFeign → payment-service × 4
      → RocketMQ NameServer × 2 + Broker × 2
          → payment-service × 4 竞争消费
          → PXC MySQL × 3 （HAProxy 入口）

所有 Java Agent
  → skywalking-oap Service
  → OAP × 2（Kubernetes Coordinator）
  → Elasticsearch

SkyWalking UI × 2
  → skywalking-oap Service
```

## 为什么这才是 OAP 集群

只把 Deployment 的副本数改成 2 还不够。本实验同时设置：

- `SW_CLUSTER=kubernetes`；
- `SW_CLUSTER_K8S_NAMESPACE`；
- `SW_CLUSTER_K8S_LABEL=app=skywalking-oap`；
- 通过 Downward API 把 Pod UID 注入 `SKYWALKING_COLLECTOR_UID`；
- ServiceAccount、ClusterRole 和 ClusterRoleBinding，允许 OAP 观察 Pod；
- 两个 OAP 共享 Elasticsearch；
- Agent 只连接 `skywalking-oap:11800`，由 Service 分配节点；
- PodDisruptionBudget 保证维护时至少保留一个 OAP。

## 首次部署

启动 Docker Desktop，在本目录执行：

```powershell
.\deploy.ps1
```

脚本会自动：

1. 编译并构建业务镜像；
2. 创建 `compileflow-k8s` kind 集群；
3. 将本地镜像加载到 kind；
4. 部署 PostgreSQL、Elasticsearch、Eureka、Nginx、Redis Cluster、RocketMQ 和所有服务；
5. 安装 Percona PXC Operator 1.20.0，创建 3 节点 MySQL 集群；
6. 部署 2 个 OAP、2 个 SkyWalking UI；
7. 自动发布 `checkout.bpm`，再把新版本号更新到购物 Deployment；
8. 等待所有 Deployment 就绪。

已构建镜像时可以跳过 Java/Docker 构建：

```powershell
.\deploy.ps1 -SkipBuild
```

## 地址

| 功能 | Kubernetes 地址 |
| --- | --- |
| Nginx 系统总入口 | http://127.0.0.1:28080 |
| SkyWalking UI | http://127.0.0.1:28090 |
| Eureka | http://127.0.0.1:28761 |
| OAP HTTP/GraphQL | http://127.0.0.1:22800 |
| OAP gRPC | 127.0.0.1:21800 |

原 Docker Compose 版本仍使用 18080、18090、18761，不会冲突。

## Nginx、Gateway 与 Redis 限流

外部请求不再直接暴露 Gateway，而是按下列链路进入：

```text
客户端 → Nginx → Kubernetes Service → 3 个 Gateway Pod → 业务服务
                                  ↓
                         Redis Cluster 共享令牌
```

限流键是客户端 IP，3 个 Gateway 共用同一个 Redis 令牌桶，所以扩容 Gateway
不会导致限流额度被重复计算。默认参数是：

- `replenishRate=200`：每秒补充 200 个令牌；
- `burstCapacity=400`：令牌桶最多积累 400 个令牌；
- 每个请求消耗 1 个令牌，无令牌时返回 HTTP `429 Too Many Requests`。

查看关键组件：

```powershell
kubectl get pods -n compileflow-lab -l app=compileflow-cluster-gateway
kubectl get pods -n compileflow-lab -l app=redis-cluster
kubectl get pods -n compileflow-lab -l app=nginx-entry
kubectl exec -n compileflow-lab redis-cluster-0 -- redis-cli cluster info
```

## RocketMQ 异步支付 + PXC MySQL

异步链路与原有同步 OpenFeign 链路并存，方便对比：

```text
POST /api/checkout/async
  → 购物服务计价并生成 orderId
  → 投递 shopping-payment-requests 消息
  → 立即返回 PAYMENT_PENDING

RocketMQ Broker
  → 4 个支付 Pod 使用 shopping-payment-consumer 消费组竞争消费
  → 通过 payment-pxc-haproxy:3306 写入 PXC
  → GET /api/payments/orders/{orderId} 查询结果
```

发送异步订单：

```powershell
$order = Invoke-RestMethod -Method Post `
  -Uri 'http://127.0.0.1:28080/api/checkout/async' `
  -ContentType 'application/json' `
  -Body '{"sku":"BOOK","quantity":2}'
$order

Invoke-RestMethod `
  -Uri "http://127.0.0.1:28080/api/payments/orders/$($order.orderId)"
```

第一个返回的状态是 `PAYMENT_PENDING`，消费和落库完成后查询状态为 `PAID`。
数据库表对 `order_id` 建立唯一索引，因此 RocketMQ 重试不会产生重复支付记录。

支付服务的数据访问层使用 MyBatis-Plus，不再直接操作 JDBC：

```text
PaymentController / RocketMQ Consumer
  → PaymentStore
  → MybatisPlusPaymentStore
  → PaymentMapper（BaseMapper<PaymentEntity>）
  → PXC MySQL
```

`payment-pxc-schema-init` Job 负责首次创建 `payment_lab` 数据库和
`payment_record` 表；应用只通过 `BaseMapper.insert` 和 LambdaQuery 完成新增、查询。
本机默认关闭 PXC 存储并使用内存 Store；K8s 会设置
`PAYMENT_DATABASE_ENABLED=true`，自动切换到 MyBatis-Plus + PXC。

查看集群：

```powershell
kubectl get pods -n compileflow-lab -l app=rocketmq-nameserver
kubectl get pods -n compileflow-lab -l app=rocketmq-broker
kubectl get pxc payment-pxc -n compileflow-lab
kubectl get pods -n compileflow-lab -l app.kubernetes.io/instance=payment-pxc
```

Kind 只有一个 Kubernetes 节点，所以实验中关闭了 PXC Pod 的主机级反亲和性；
3 个 PXC 实例确实组成 Galera 集群，但不能防御整台 Kind 节点故障。生产环境应使用
至少 3 个 K8s 工作节点，并恢复 `kubernetes.io/hostname` 反亲和性。

## Headlamp 图形化检查

独立 Docker 版 Headlamp 位于 `headlamp-docker`，使用只读账号查看本集群：

```powershell
cd .\headlamp-docker
.\start.ps1
```

打开 <http://127.0.0.1:24466>。详细说明见 `headlamp-docker/README.md`。

## k6 压测

`load-test` 目录提供集群内部的购物支付链路压测。先运行安全基线：

```powershell
cd .\load-test
.\run.ps1
```

当前实验默认流量为每秒 500 个请求、持续 5 秒。流量会先通过 Nginx 和 Redis
令牌桶，因此超过限额时看到 `429` 是预期的保护行为。详细的加压参数和指标说明见
`load-test/README.md`。

## Prometheus + Grafana

`monitoring` 目录提供 K8s 与 k6 的可视化监控：

```powershell
cd .\monitoring
.\start.ps1
```

Grafana：<http://127.0.0.1:23000>（`admin / admin`）；Prometheus：
<http://127.0.0.1:29090>。详细说明见 `monitoring/README.md`。

## 验证

```powershell
.\verify.ps1
```

脚本会检查：

- Kubernetes Pod 是否运行；
- `/status/cluster/nodes` 是否返回 2 个 OAP 节点；
- Eureka 是否有 4 个购物、4 个支付、3 个 Workbench；
- checkout 是否返回 `PAID`；
- RocketMQ 2 个 NameServer、2 个 Broker 是否运行；
- PXC 3 节点是否为 `ready`；
- 异步 checkout 是否先返回 `PAYMENT_PENDING`，随后在 PXC 中变成 `PAID`；
- SkyWalking 的同一条 trace 是否包含 Gateway、购物、Workbench、支付。

单独查看 OAP 集群成员：

```powershell
Invoke-RestMethod http://127.0.0.1:22800/status/cluster/nodes |
  ConvertTo-Json -Depth 5
```

## 扩缩容实验

扩成 3 个 OAP：

```powershell
kubectl scale deployment/skywalking-oap -n compileflow-lab --replicas=3
kubectl rollout status deployment/skywalking-oap -n compileflow-lab
Invoke-RestMethod http://127.0.0.1:22800/status/cluster/nodes
```

恢复 2 个：

```powershell
kubectl scale deployment/skywalking-oap -n compileflow-lab --replicas=2
```

模拟一个 OAP Pod 故障：

```powershell
$pod = kubectl get pod -n compileflow-lab -l app=skywalking-oap `
  -o jsonpath='{.items[0].metadata.name}'
kubectl delete pod $pod -n compileflow-lab
```

Deployment 会自动补回一个 Pod，Service 在此期间继续把请求发送到可用 OAP。

## 日常排查

```powershell
kubectl get pods -n compileflow-lab -o wide
kubectl get deployments -n compileflow-lab
kubectl logs -n compileflow-lab deployment/skywalking-oap --tail=100
kubectl logs -n compileflow-lab deployment/compileflow-shopping-demo --tail=100
kubectl describe pod -n compileflow-lab <pod名称>
```

## 删除实验集群

```powershell
.\stop.ps1
```

该命令删除整个 kind 集群及其内部实验数据，不影响原来的 Docker Compose 环境。

这是单机学习环境：OAP 是真正的多副本协同集群，但两个 Pod 位于同一台 kind 节点上；生产环境应使用多个 Kubernetes 工作节点、持久化存储和多副本 Elasticsearch/BanyanDB。
