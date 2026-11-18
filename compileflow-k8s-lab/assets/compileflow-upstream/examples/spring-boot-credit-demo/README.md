# CompileFlow 用信审批示例

运行时，流程引擎读取 `credit-approval.bpm`。

```text
用户校验 → 是否需要风控 → 风控推送或直接跳过 → 合同签订 → APPROVED
```

业务节点放在 `CreditOperations` 中。流程顺序、条件分支和节点连接放在 BPM 文件中，因此新增节点或调整连线时不需要把一个 Service 方法越写越长。

运行命令

```powershell
cd <Skill 恢复目录>\vendor\compileflow
$env:JAVA_HOME = 'D:\Program Files\JetBrains\IntelliJ IDEA 2026.3\jbr'
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
.\mvnw.cmd install -pl compileflow-spring-boot-starter-tbbpm -am -DskipTests
.\mvnw.cmd -f examples\spring-boot-credit-demo\pom.xml spring-boot:run
```
