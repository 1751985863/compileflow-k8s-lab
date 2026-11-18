param([switch]$SkipBuild)

$ErrorActionPreference = 'Stop'
$ClusterName = 'compileflow-k8s'
$Namespace = 'compileflow-lab'
$LabRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$ClusterDocker = Resolve-Path (Join-Path $PSScriptRoot '..\cluster-docker')
$EnvFile = Resolve-Path (Join-Path $LabRoot '.lab.env')

if (-not $SkipBuild) {
    & (Join-Path $ClusterDocker 'build.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Java modules build failed.' }

    docker compose --env-file $EnvFile -f (Join-Path $ClusterDocker 'compose.yaml') build `
        eureka gateway workbench-1 shopping-1 payment-1
    if ($LASTEXITCODE -ne 0) { throw 'Docker image build failed.' }
}

$infraImages = @(
    'postgres:18.6-alpine3.24',
    'busybox:1.37.0',
    'redis:7.4.2-alpine',
    'nginx:1.28.0-alpine',
    'apache/rocketmq:5.3.2',
    'percona/percona-xtradb-cluster-operator:1.20.0',
    'percona/percona-xtradb-cluster:8.4.8-8.1',
    'percona/haproxy:2.8.18-1',
    'docker.elastic.co/elasticsearch/elasticsearch:8.19.15',
    'apache/kafka:3.9.1',
    'docker.elastic.co/beats/filebeat:8.19.15',
    'docker.elastic.co/logstash/logstash:8.19.15',
    'docker.elastic.co/kibana/kibana:8.19.15',
    'apache/skywalking-oap-server:10.4.0-java17',
    'apache/skywalking-ui:10.4.0-java17'
)
foreach ($image in $infraImages) {
    docker image inspect $image *> $null
    if ($LASTEXITCODE -ne 0) {
        docker pull $image
        if ($LASTEXITCODE -ne 0) { throw "Could not pull $image" }
    }
}

$clusters = @(kind get clusters 2>$null)
if ($clusters -notcontains $ClusterName) {
    kind create cluster --config (Join-Path $PSScriptRoot 'kind-config.yaml')
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the kind cluster.' }
}

kubectl config use-context "kind-$ClusterName" | Out-Null

$images = @(
    'compileflow-eureka-server:cluster',
    'compileflow-cluster-gateway:cluster',
    'compileflow-workbench-server:eureka-2.0.0',
    'compileflow-shopping-demo:cluster',
    'compileflow-payment-service:cluster'
) + $infraImages

kind load docker-image --name $ClusterName @images
if ($LASTEXITCODE -ne 0) { throw 'Could not load images into kind.' }

kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -
if ($LASTEXITCODE -ne 0) { throw 'Could not create the application namespace.' }

# PXC 是自定义 Kubernetes 资源，必须先安装官方 Operator 1.20.0 和 CRD。
$pxcOperatorBundle = 'https://raw.githubusercontent.com/percona/percona-xtradb-cluster-operator/v1.20.0/deploy/bundle.yaml'
kubectl apply --server-side -f $pxcOperatorBundle -n $Namespace
if ($LASTEXITCODE -ne 0) { throw 'Percona PXC Operator could not be installed.' }
kubectl rollout status deployment/percona-xtradb-cluster-operator -n $Namespace --timeout=300s

kubectl delete job redis-cluster-init -n $Namespace --ignore-not-found --wait=true | Out-Null
kubectl delete job rocketmq-topic-init -n $Namespace --ignore-not-found --wait=true | Out-Null
kubectl delete job payment-pxc-schema-init -n $Namespace --ignore-not-found --wait=true | Out-Null
kubectl apply -k $PSScriptRoot
if ($LASTEXITCODE -ne 0) { throw 'Kubernetes manifests could not be applied.' }

kubectl rollout status statefulset/postgres -n $Namespace --timeout=300s
kubectl rollout status statefulset/elasticsearch -n $Namespace --timeout=600s
kubectl rollout status statefulset/redis-cluster -n $Namespace --timeout=600s
kubectl wait --for=condition=complete job/redis-cluster-init -n $Namespace --timeout=300s
kubectl rollout status deployment/rocketmq-nameserver -n $Namespace --timeout=300s
kubectl rollout status statefulset/rocketmq-broker -n $Namespace --timeout=600s
kubectl wait --for=condition=complete job/rocketmq-topic-init -n $Namespace --timeout=300s

$pxcReady = $false
for ($attempt = 1; $attempt -le 120; $attempt++) {
    $pxcState = kubectl get pxc payment-pxc -n $Namespace -o jsonpath='{.status.state}' 2>$null
    if ($pxcState -eq 'ready') {
        $pxcReady = $true
        break
    }
    if (($attempt % 12) -eq 0) { Write-Host "Waiting for PXC cluster: state=$pxcState" }
    Start-Sleep -Seconds 5
}
if (-not $pxcReady) {
    kubectl get pods -n $Namespace -l app.kubernetes.io/instance=payment-pxc -o wide
    throw 'The three-node PXC cluster did not become ready.'
}
kubectl wait --for=condition=complete job/payment-pxc-schema-init -n $Namespace --timeout=300s

kubectl rollout status statefulset/kafka -n $Namespace --timeout=600s
kubectl rollout status daemonset/filebeat -n $Namespace --timeout=600s
kubectl rollout status deployment/logstash -n $Namespace --timeout=600s
kubectl rollout status deployment/kibana -n $Namespace --timeout=600s
kubectl rollout status deployment/skywalking-oap -n $Namespace --timeout=600s
kubectl rollout status deployment/skywalking-ui -n $Namespace --timeout=300s
kubectl rollout status deployment/eureka -n $Namespace --timeout=300s
kubectl rollout status deployment/compileflow-workbench-server -n $Namespace --timeout=600s
kubectl rollout status deployment/compileflow-payment-service -n $Namespace --timeout=300s
kubectl rollout status deployment/compileflow-cluster-gateway -n $Namespace --timeout=300s
kubectl rollout status deployment/nginx-entry -n $Namespace --timeout=300s
kubectl rollout status deployment/compileflow-shopping-demo -n $Namespace --timeout=300s

# 新建 kind 集群通过 NodePort 映射访问 Kibana；旧集群没有该映射时自动启动端口转发。
try {
    Invoke-RestMethod -Uri 'http://127.0.0.1:25601/api/status' -TimeoutSec 3 | Out-Null
} catch {
    & (Join-Path $PSScriptRoot 'logging\start-kibana.ps1')
}
& (Join-Path $PSScriptRoot 'logging\setup-kibana.ps1')

$publishScript = Resolve-Path (Join-Path $PSScriptRoot '..\publish.ps1')
$published = $null
for ($attempt = 1; $attempt -le 12; $attempt++) {
    try {
        $published = & $publishScript -WorkbenchUrl 'http://127.0.0.1:28080'
        if ($published.version) { break }
    } catch {
        if ($attempt -eq 12) { throw }
        Start-Sleep -Seconds 5
    }
}
if (-not $published.version) { throw 'The shopping flow was not published.' }

$version = $published.version
kubectl set env deployment/compileflow-shopping-demo -n $Namespace "SHOPPING_FLOW_VERSION=$version"
kubectl rollout status deployment/compileflow-shopping-demo -n $Namespace --timeout=300s

# Eureka 客户端与网关都有本地缓存。滚动发布后等待注册表中的 IP 与当前 Pod 完全一致，
# 避免第一次请求仍然被路由到刚刚退出的旧 Pod。
$registryReady = $false
for ($attempt = 1; $attempt -le 24; $attempt++) {
    try {
        $registry = Invoke-RestMethod -Uri 'http://127.0.0.1:28761/eureka/apps/COMPILEFLOW-SHOPPING-DEMO' `
            -Headers @{Accept='application/json'}
        $registeredIps = @($registry.application.instance | Where-Object status -eq 'UP' |
            ForEach-Object ipAddr | Sort-Object -Unique)
        $podIps = @(kubectl get pods -n $Namespace -l app=compileflow-shopping-demo `
            -o jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}' | Where-Object { $_ } | Sort-Object -Unique)
        if ($registeredIps.Count -eq 4 -and
            (Compare-Object $registeredIps $podIps).Count -eq 0) {
            $registryReady = $true
            break
        }
    } catch {
        # Eureka 可能正在刷新注册表，下一轮继续检查。
    }
    Start-Sleep -Seconds 5
}
if (-not $registryReady) { throw 'Eureka did not converge to the four current shopping Pods.' }

# 再留出一次网关注册表缓存刷新周期。
Start-Sleep -Seconds 15

Write-Host "Kubernetes deployment is ready. Flow version: $version"
Write-Host 'Nginx entry: http://127.0.0.1:28080'
Write-Host 'Eureka:      http://127.0.0.1:28761'
Write-Host 'SkyWalking:  http://127.0.0.1:28090'
Write-Host 'Kibana:      http://127.0.0.1:25601'
Write-Host 'OAP status:  http://127.0.0.1:22800/status/cluster/nodes'
Write-Host 'Run .\verify.ps1 to verify the cluster and trace.'
