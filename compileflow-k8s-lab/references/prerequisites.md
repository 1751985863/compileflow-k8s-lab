# 新电脑前置条件

在复制或部署前读取本参考。

## 必需软件

- Windows 10/11，PowerShell 7 (`pwsh`)。
- Docker Desktop，Linux 容器模式，Docker Engine 已启动。
- JDK 17，并确保 `java -version` 首行是 17。
- Maven、Git、kubectl、Kind。
- 建议至少 16 GB 内存、35 GB 可用磁盘；完整集群更推荐 24 GB 内存。

先执行：

```powershell
pwsh -ExecutionPolicy Bypass -File .\scripts\preflight.ps1
```

不要复用旧机器的 kubeconfig、Headlamp Token、`.env` 或 PXC Secret。Skill 只携带声明式配置；运行时凭据必须在新电脑重新生成。

## 固定版本和来源

- Java 17。
- CompileFlow Git 提交：`c2831832745e893f0dbe22b1e94810625372a356`。
- Spring Boot 4.1.1、Spring Cloud 2025.1.4。
- MyBatis-Plus 3.5.18.1。
- 其他镜像版本以项目模板的 YAML 和 `deploy.ps1` 为准，不要在复刻时随意改成 `latest`。

Grafana、Prometheus、Headlamp 和 k6 的现有模板仍有少数 `latest` 标签；要求严格可重现时，应先把它们解析并固定为镜像 digest，再部署。

