# CompileFlow 购物 + 支付微服务集群实验

这个实验把一次结算请求拆成四段，并让同一个 SkyWalking `trace-id` 贯穿所有服务：

```text
客户端
  → Gateway
  → shopping-service（4 个节点）
      → OpenFeign + Eureka → Workbench Server（3 个节点）→ PostgreSQL
      → OpenFeign + Eureka → payment-service（4 个节点）

所有 Java 服务 → SkyWalking OAP → Elasticsearch → SkyWalking UI
所有容器日志   → Filebeat → Kafka → Logstash → Elasticsearch → Kibana
```

Gateway 不保存购物节点地址。购物、支付和 Workbench 都注册到 Eureka；外部请求由 Gateway 选择购物节点，购物服务内部则通过 `@FeignClient(name=...)` 和 Eureka 直接选择 Workbench、支付节点，不再绕回 Gateway。支付接口是学习用的模拟实现：生成支付流水号并直接返回 `PAID`，不连接真实支付渠道。

OpenFeign 不是另一种传输协议，它底层依然发送 HTTP。它解决的是手写 URL、序列化和调用模板的问题，并通过 Eureka 服务名完成服务发现与客户端负载均衡。

## 一次启动

先启动 Docker Desktop，在本目录执行：

```powershell
.\build.ps1
.\start.ps1
```

`build.ps1` 会编译 Eureka、Gateway、购物、支付和 Workbench。`start.ps1` 会重建集群，但保留原来的 PostgreSQL 与 Elasticsearch 数据卷。

| 页面/接口 | 地址 | 用途 |
| --- | --- | --- |
| Eureka | http://127.0.0.1:18761 | 查看购物 4 节点、支付 4 节点、Workbench 3 节点 |
| Gateway | http://127.0.0.1:18080 | 所有业务请求的统一入口 |
| Workbench 网页 | http://127.0.0.1:5173 | 编辑、发布购物流程 |
| SkyWalking | http://127.0.0.1:18090 | 查看跨服务拓扑、耗时和调用链 |
| Kibana | http://127.0.0.1:15601 | 按 request-id 或 trace-id 查询原始日志 |

## 实验一：观察购物调用支付

在 IDEA 打开 `requests.http`，执行第一个请求，或者运行：

```powershell
$response = Invoke-RestMethod -Method Post `
  -Uri 'http://127.0.0.1:18080/api/checkout' `
  -Headers @{ 'X-Request-Id' = 'shopping-pay-001' } `
  -ContentType 'application/json' `
  -Body '{"sku":"BOOK","quantity":2}'
$response | ConvertTo-Json
```

响应示例：

```json
{
  "payableCents": 11000,
  "requestId": "shopping-pay-001",
  "serviceInstance": "shopping-2",
  "orderId": "ORDER-316F60A3",
  "paymentId": "PAY-B43762C7",
  "paymentStatus": "PAID",
  "paymentInstance": "payment-1",
  "traceId": "d121bdf328b6416480476f18b7de6845",
  "skywalkingTraceId": "b3774fe...17948846984920001"
}
```

几个编号不要混淆：

- `requestId`：我们自己定义的业务请求编号，适合在 Kibana 查日志；
- `traceId`：Workbench 的一次流程执行记录编号；
- `skywalkingTraceId`：SkyWalking 自动生成的跨服务链路编号；
- `serviceInstance`、`paymentInstance`：本次实际命中的购物、支付节点。

## 实验二：验证两个四节点集群

```powershell
.\verify.ps1
```

Eureka 应显示：

- `COMPILEFLOW-SHOPPING-DEMO`：4 个 `UP`；
- `COMPILEFLOW-PAYMENT-SERVICE`：4 个 `UP`；
- `COMPILEFLOW-WORKBENCH-SERVER`：3 个 `UP`；
- `COMPILEFLOW-CLUSTER-GATEWAY`：1 个 `UP`。

脚本连续发送 8 个请求。`ShoppingNode` 会在 `shopping-1..4` 之间轮询，`PaymentNode` 会在 `payment-1..4` 之间轮询。

## 实验三：在 SkyWalking 看完整链路

1. 打开 http://127.0.0.1:18090；
2. 进入 **Trace**；
3. 时间范围选择最近 15 分钟；
4. 用响应中的 `skywalkingTraceId` 搜索；
5. 打开结果，观察 `Gateway → shopping → Workbench` 和 `shopping → payment`。两条内部调用的组件应显示为 `Feign`。

同一个 trace-id 也会被写进日志，格式类似：

```text
traceId=TID:b3774fe... requestId=shopping-pay-001
```

本实验设置 `SW_AGENT_SAMPLE=-1`，即全量采样，便于每次练习都能看到。生产系统通常使用采样策略控制存储量。

## 实验四：在 Kibana 串起四类日志

打开 Kibana Discover，选择 `CompileFlow Logs`，搜索：

```text
message : "shopping-pay-001"
```

建议只展示：

```text
service.name
service.instance.id
message
```

能依次看到：

1. `compileflow-gateway` 接收 `/api/checkout`；
2. `shopping-service` 计算金额；
3. OpenFeign 从 Eureka 选择某个 `workbench-server`；
4. 购物服务发起支付；
5. OpenFeign 从 Eureka 选择某个 `payment-service`；
6. 支付返回 `PAID`，购物返回最终响应。

也可以直接用 SkyWalking trace-id 搜索：

```text
message : "响应中的 skywalkingTraceId"
```

## 实验五：模拟支付节点故障

```powershell
docker stop compileflow-cluster-lab-payment-2-1
```

等待约 15 秒后再次执行 `verify.ps1`，支付仍可完成，但只会命中另外三个支付节点。恢复：

```powershell
docker start compileflow-cluster-lab-payment-2-1
```

## 常用命令

```powershell
# 查看所有容器
docker compose --env-file ..\..\compileflow-credit-service\workbench-docker\.env ps

# 查看指定节点日志
docker compose --env-file ..\..\compileflow-credit-service\workbench-docker\.env logs --tail 100 shopping-1
docker compose --env-file ..\..\compileflow-credit-service\workbench-docker\.env logs --tail 100 payment-1
docker compose --env-file ..\..\compileflow-credit-service\workbench-docker\.env logs --tail 100 skywalking-oap

# 停止集群，保留数据
.\stop.ps1

# 再次启动
.\start.ps1
```

这是学习环境：Eureka 和 Gateway 仍是单节点。生产环境还需要让注册中心、网关、OAP 和 Elasticsearch 自身高可用，并根据流量设置采样率和数据保留周期。
