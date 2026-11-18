# 架构与固定拓扑

本参考用于确认复刻范围和修改拓扑时的连锁影响。

## 请求链路

```text
客户端 :28080
  → Nginx 总入口 ×1
  → Spring Cloud Gateway ×3
  → Shopping Service ×4
      → Workbench Server ×3（CompileFlow 执行）
      → Payment Service ×4（同步 OpenFeign）
      → RocketMQ（异步支付）
            → Payment Service 消费
            → MyBatis-Plus
            → PXC MySQL ×3 + HAProxy ×1
```

## 基础设施和运维组件

| 类别 | 组件 | 拓扑/作用 |
|---|---|---|
| 服务发现 | Eureka | 1 节点，注册网关、购物、支付、Workbench |
| 网关 | Spring Cloud Gateway | 3 Pod |
| 限流 | Redis Cluster | 3 主 3 从，网关令牌桶 |
| 流程平台 | CompileFlow Workbench Server | 3 Pod，PostgreSQL 持久化 |
| 消息 | RocketMQ | 2 NameServer、2 Broker |
| 支付数据库 | Percona XtraDB Cluster | 3 PXC、1 HAProxy、Operator 管理 |
| 日志 | Filebeat → Kafka → Logstash → Elasticsearch → Kibana | K8s 日志采集、缓冲、检索 |
| 追踪 | SkyWalking | 2 OAP、2 UI，Elasticsearch 存储 |
| 指标 | Prometheus + kube-state-metrics + Grafana | 集群和 k6 指标 |
| 集群 UI | Headlamp | Docker 独立运行，运行时生成只读 kubeconfig |
| 压测 | k6 | Kubernetes Job，参数由 PowerShell 脚本更新 |

## 项目代码

- `compileflow-shopping-demo`：同步/异步结算、Workbench 调用、RocketMQ 生产者。
- `compileflow-payment-service`：同步支付接口、RocketMQ 消费者、MyBatis-Plus + PXC。
- `compileflow-cluster-gateway`：Eureka 路由、Redis 分布式令牌桶。
- `compileflow-eureka-server`：注册中心。
- `vendor/compileflow`：从 Skill 内置快照恢复的官方 CompileFlow 源码，用于构建 Workbench Server。

不要把 Workbench Web 页面与 Workbench Server 混为一谈：当前实验部署的是 Server；流程发布通过后端 API 和项目内 `publish.ps1` 完成。

