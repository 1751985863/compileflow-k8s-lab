# K8s 日志实验

日志链路：`K8s Pod → Filebeat → Kafka → Logstash → Elasticsearch → Kibana`。

## 打开 Kibana

现有 kind 集群需要启动本机端口转发：

```powershell
.\start-kibana.ps1
.\setup-kibana.ps1
```

打开 <http://127.0.0.1:25601/app/discover>，选择 `CompileFlow Logs`，时间范围选择最近 15 分钟。

压测脚本会写入 `X-Request-Id: k6-...`，在 Discover 中搜索：

```text
message : k6-*
```

建议显示 `@timestamp`、`kubernetes.pod.name`、`kubernetes.container.name` 和 `message`。

Grafana 用来查看 QPS、P95 和失败率；Kibana 用来查看压测请求产生的业务日志；SkyWalking 用来查看跨服务链路。
