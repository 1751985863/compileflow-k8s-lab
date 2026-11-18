# Docker 日志采集实验

集群模式下 Filebeat 还会自动发现 `compileflow-cluster-lab` 中的 Gateway、Eureka、4 个购物节点和 3 个 Workbench 节点，并写入相同的 `compileflow-logs-*` 索引。按一次请求查询的方法见 [集群实验教程](../cluster-docker/README.md)。

```text
Workbench Server 的 Docker 标准输出 ─┐
                                    ├→ Filebeat → Kafka → Logstash → Elasticsearch → Kibana
购物服务的 Spring Boot 日志文件 ─────┘
```

Filebeat 根据 `compileflow-workbench-lab-server-*` 容器名自动发现 Workbench Server，读取 Docker 的 json-file 日志。购物服务仍可在 IDEA 运行，Filebeat 通过只读挂载读取它的日志文件。采集链路无需修改 Java 或 BPM。文件日志的 `@timestamp` 为 Filebeat 采集时间，Workbench 容器日志使用 Docker 记录的时间。

## 启动与查看

在本目录打开 PowerShell。

```powershell
docker compose up -d --wait
docker compose ps
.\setup-kibana.ps1
```

Kibana 初始化可能稍晚于容器启动。如果脚本返回 503，等 [Kibana 状态](http://127.0.0.1:15601/api/status) 就绪后再次执行。
打开 [Kibana Discover](http://127.0.0.1:15601/app/discover)，选 `CompileFlow Logs`，时间范围设为最近 15 分钟。

```text
service.name : "workbench-server"
service.name : "shopping-service" and message : "checkout"
```

每次输入上面其中一条 KQL。Workbench 日志包含 JVM 输出和流程运行时日志。脚本中的 println 也能被采集。Workbench「运维 → 日志」展示的是 PostgreSQL 里的执行记录，可继续通过它核对执行 ID 和版本。

## 采集 IDEA 中的购物服务日志

购物模块的 `application.yml` 已配置文件日志和接口路径日志。IDEA 以 `spring-interview-lab` 根目录运行 `ShoppingApplication` 时，直接写入本目录下的 `logs/shopping.log`。
从其他工作目录启动时，可以用下面的 **Program argument** 指定同一个文件路径。

```text
--logging.file.name=D:/校招/yoga电脑/spring-interview-lab/compileflow-shopping-demo/logging-docker/logs/shopping.log
```

执行上一层的 `requests.http`，买两本书，期望应付 110 元。回到 Discover 查询购物日志。现有日志如果没有关联 ID，集中收集后也仍需通过时间、服务名或原有字段筛选。

## 逐段排查

| 环节 | 检查方式 |
| --- | --- |
| 原始日志 | `docker logs --tail 30 compileflow-workbench-lab-server-1`，或读 `logs/shopping.log` |
| Filebeat | `docker compose logs --tail 50 filebeat` |
| Kafka Topic | `docker compose exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 --describe --topic compileflow-logs` |
| Logstash | `docker compose logs --tail 50 logstash` |
| ES 索引 | [索引列表](http://127.0.0.1:19200/_cat/indices/compileflow-logs-*) |
| Kibana | 检查数据视图和时间范围 |

这是本机实验配置。Kibana 15601 和 Elasticsearch 19200 只绑定回环地址，Kafka 留在 Compose 网络内。Filebeat 挂载 Docker socket 做容器发现，即使是只读挂载，Docker API 权限仍然敏感。Kafka 日志保留 72 小时，ES 索引按日期建立，未配置自动删除。

执行 `docker compose stop` 停止采集，保留 Kafka、ES 和采集进度的数据卷。
