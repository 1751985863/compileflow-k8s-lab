# CompileFlow K8s Lab

一套可迁移、可验证的 CompileFlow 微服务 Kubernetes 学习实验，同时也是一个可供 Codex 使用的 Skill。

项目完整保留购物、支付、流程编排、服务注册、网关、消息队列、数据库集群、日志、链路追踪、指标监控和压测环境。换到另一台 Windows 电脑后，可以让 Codex 按固定步骤检查环境、恢复源码、部署集群并完成端到端验证，减少重复对话和手工排错。

## 架构概览

```text
客户端
  │
  ▼
Nginx 总入口 ×1
  │
  ▼
Spring Cloud Gateway ×3
  │
  ▼
Shopping Service ×4
  ├── CompileFlow Workbench Server ×3
  │     └── PostgreSQL
  │
  ├── Payment Service ×4 ── MyBatis-Plus ── PXC MySQL ×3
  │
  └── RocketMQ
        ├── NameServer ×2
        ├── Broker ×2
        └── Payment Service 异步消费

公共能力：
  Eureka / Redis Cluster / SkyWalking / ELK / Prometheus / Grafana / Headlamp / k6
```

## 包含内容

### 项目代码

- `compileflow-shopping-demo`：购物结算、CompileFlow 调用、同步支付、异步支付消息生产。
- `compileflow-payment-service`：支付接口、RocketMQ 消费、MyBatis-Plus、PXC 持久化。
- `compileflow-cluster-gateway`：统一路由和 Redis 分布式令牌桶限流。
- `compileflow-eureka-server`：Spring Cloud Eureka 注册中心。
- `assets/compileflow-upstream`：固定提交的 CompileFlow 源码快照，用于构建 Workbench Server。

### 中间件与运维工具

| 分类 | 组件 | 实验拓扑 |
|---|---|---|
| 容器编排 | Kind + Kubernetes | 单节点本地学习集群 |
| 入口 | Nginx | 1 个实例 |
| 网关 | Spring Cloud Gateway | 3 个 Pod |
| 注册中心 | Eureka | 1 个实例 |
| 限流 | Redis Cluster | 3 主 3 从 |
| 流程编排 | CompileFlow Workbench Server | 3 个 Pod |
| 消息队列 | RocketMQ | 2 NameServer、2 Broker |
| 支付数据库 | Percona XtraDB Cluster | 3 PXC、1 HAProxy |
| 流程数据库 | PostgreSQL | 1 个 StatefulSet |
| 日志平台 | Filebeat、Kafka、Logstash、Elasticsearch、Kibana | 完整日志链路 |
| 链路追踪 | SkyWalking | 2 OAP、2 UI |
| 指标监控 | Prometheus、kube-state-metrics、Grafana | K8s 与 k6 指标 |
| 集群界面 | Headlamp | 独立 Docker 容器 |
| 压测 | k6 | Kubernetes Job |

## 运行要求

- Windows 10 或 Windows 11
- PowerShell 7，命令为 `pwsh`
- Docker Desktop，使用 Linux 容器且 Docker Engine 已启动
- JDK 17
- Maven
- Git
- kubectl
- Kind
- 建议至少 16 GB 内存、35 GB 可用磁盘；完整运行建议 24 GB 内存

> 请统一使用 PowerShell 7。Windows PowerShell 5 可能错误解析项目中的 UTF-8 中文脚本。

## 在 Codex 中安装 Skill

下载或克隆仓库后，在仓库根目录执行：

```powershell
pwsh -ExecutionPolicy Bypass -File .\scripts\install-skill.ps1
```

重启 Codex，然后输入：

```text
使用 $compileflow-k8s-lab 在这台电脑上检查环境并复刻完整实验集群
```

## 手动恢复实验项目

### 1. 检查电脑环境

```powershell
pwsh -ExecutionPolicy Bypass -File .\scripts\preflight.ps1
```

脚本会检查 Docker、Git、Java 17、Maven、kubectl、Kind、PowerShell 7、内存和磁盘空间。

### 2. 恢复源码

```powershell
pwsh -ExecutionPolicy Bypass -File .\scripts\restore-lab.ps1 `
  -Destination 'D:\labs\compileflow-k8s-lab'
```

恢复过程会：

1. 复制四个 Spring 项目及全部 Kubernetes 配置；
2. 恢复内置的 CompileFlow 固定源码快照；
3. 生成当前电脑专用的随机数据库密码；
4. 不复用原电脑的 kubeconfig、Token、Secret、日志或持久化数据。

目标目录非空时脚本会停止，避免覆盖已有代码。只有明确确认覆盖时才使用 `-Force`。

### 3. 部署核心集群

```powershell
Set-Location 'D:\labs\compileflow-k8s-lab\compileflow-shopping-demo\k8s-cluster'
pwsh -ExecutionPolicy Bypass -File .\deploy.ps1
```

部署脚本会完成 Java 构建、Docker 镜像构建、Kind 集群创建、镜像导入、Operator 和中间件部署、流程发布以及服务滚动更新。

### 4. 端到端验证

```powershell
pwsh -ExecutionPolicy Bypass -File .\verify.ps1
```

验证通过需要同时满足：

- Gateway 3 个实例、Shopping 4 个实例、Payment 4 个实例、Workbench 3 个实例均在 Eureka 中为 `UP`；
- 同步结算返回 `PAID`；
- SkyWalking 链路贯穿 Gateway、Shopping、Workbench 和 Payment；
- 异步结算先返回 `PAYMENT_PENDING` 和 `SEND_OK`；
- RocketMQ 消费后支付状态变为 `PAID`；
- 支付记录通过 MyBatis-Plus 写入 PXC；
- PXC 为 3 个数据库 Pod，RocketMQ 为 2 个 NameServer 和 2 个 Broker。

## 启动可观测性和管理界面

```powershell
# Prometheus + Grafana
pwsh -ExecutionPolicy Bypass -File .\monitoring\start.ps1

# Headlamp
pwsh -ExecutionPolicy Bypass -File .\headlamp-docker\start.ps1
```

## 运行 k6 压测

```powershell
Set-Location .\load-test

pwsh -ExecutionPolicy Bypass -File .\run.ps1 `
  -Rate 500 `
  -Duration 30s `
  -PreAllocatedVUs 500 `
  -MaxVUs 1000
```

建议先以较低 RPS 做冒烟测试，再逐步提高压力，不要直接用极高并发判断系统上限。

## 本地访问地址

| 地址 | 用途 |
|---|---|
| `http://127.0.0.1:28080` | Nginx 总入口和业务 API |
| `http://127.0.0.1:28761` | Eureka |
| `http://127.0.0.1:28090` | SkyWalking UI |
| `http://127.0.0.1:25601` | Kibana |
| `http://127.0.0.1:22800` | SkyWalking OAP 状态与 GraphQL |
| `http://127.0.0.1:23000` | Grafana |
| `http://127.0.0.1:29090` | Prometheus |
| `http://127.0.0.1:24466` | Headlamp |

## Skill 目录结构

```text
compileflow-k8s-lab/
├── SKILL.md                       # Codex 的核心执行规则
├── README.md                      # GitHub 项目说明
├── agents/openai.yaml             # Skill 展示和调用配置
├── scripts/
│   ├── install-skill.ps1          # 安装到 Codex
│   ├── preflight.ps1              # 环境检查
│   ├── restore-lab.ps1            # 恢复项目
│   └── audit-bundle.ps1           # 迁移包审计
├── references/
│   ├── architecture.md            # 架构与固定拓扑
│   ├── prerequisites.md           # 新电脑要求
│   ├── operations.md              # 部署与日常操作
│   └── troubleshooting.md         # 分层故障诊断
└── assets/
    ├── project-template/          # 完整实验项目模板
    └── compileflow-upstream/      # 固定 CompileFlow 源码快照
```

## 安全说明

仓库不应提交以下运行时文件：

- `.lab.env`
- Headlamp 生成的 `kubeconfig`
- ServiceAccount Token
- Kubernetes 运行时 Secret
- PXC/PostgreSQL 持久卷数据
- `target`、日志和压测结果

打包或发布前执行：

```powershell
pwsh -ExecutionPolicy Bypass -File .\scripts\audit-bundle.ps1
```

## 重要说明

- 这是单节点 Kind 学习实验。虽然 PXC、RocketMQ 和服务均采用多副本，但它不能抵御整台宿主机或 Kind 节点故障。
- 生产环境需要多工作节点、持久卷、备份恢复、正式证书、Secret 管理、资源配额和严格的安全策略。
- CompileFlow 源码固定为提交 `c2831832745e893f0dbe22b1e94810625372a356`，避免不同版本造成构建或接口差异。
- 修改组件版本或拓扑后，应同时更新 `SKILL.md`、`references`、部署清单和验证脚本。

## License

本仓库中的实验代码可根据仓库后续选择的许可证发布；`assets/compileflow-upstream` 来源于 Alibaba CompileFlow，请同时遵守其原始开源许可证与版权声明。

