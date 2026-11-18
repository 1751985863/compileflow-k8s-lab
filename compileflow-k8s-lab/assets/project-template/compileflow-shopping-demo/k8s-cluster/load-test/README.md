# k6 购物链路压测

k6 作为临时 Kubernetes Job 运行在 `compileflow-lab` 命名空间，通过集群内部
Service 压测以下完整链路：

```text
k6 → Gateway → shopping × 4 → Workbench × 3 → payment × 4
```

## 安全基线

```powershell
cd "<项目目录>\compileflow-shopping-demo\k8s-cluster\load-test"
.\run.ps1
```

脚本先发送 20 次预热请求，让各实例完成 CompileFlow 首次动态编译；随后默认每秒
5 个正式请求，持续 30 秒。预热数据不会计入正式请求的延迟和错误率门槛。测试必须
同时满足：

- HTTP 错误率低于 1%；
- 99% 以上的业务断言成功；
- P95 响应时间低于 2 秒；
- 没有因为虚拟用户不足而丢弃请求。

## 逐步加压

不要直接在单节点 kind 上使用很高的并发，建议逐级运行：

```powershell
# 10 RPS，持续 1 分钟
.\run.ps1 -Rate 10 -Duration 1m -PreAllocatedVUs 20 -MaxVUs 100

# 30 RPS，持续 1 分钟
.\run.ps1 -Rate 30 -Duration 1m -PreAllocatedVUs 50 -MaxVUs 200
```

`Rate` 是每秒启动的请求数，不等同于同时在线的线程数。每次运行会先删除上一次
同名 Job，不会影响业务 Deployment。

## 查看结果

脚本会实时打印平均值、P90、P95、错误率和断言结果。也可以运行：

```powershell
kubectl logs -n compileflow-lab job/k6-shopping-load-test
kubectl get job,pod -n compileflow-lab -l app=k6-shopping-load-test
```

在 Headlamp 中进入 `compileflow-lab → Workloads → Jobs`，也能看到
`k6-shopping-load-test` 及其日志。压测请求仍会进入 SkyWalking，可以同时观察调用链、
服务响应时间和错误。

如果 Pod 的 `LAST_REASON` 显示 `OOMKilled`，说明失败来自容器内存边界，而不是接口
响应时间。这个实验已经为 Workbench 的 JVM 堆预留额外的 Agent、元空间和线程栈
空间；继续提高压力前仍应同时观察 Pod 重启次数。

