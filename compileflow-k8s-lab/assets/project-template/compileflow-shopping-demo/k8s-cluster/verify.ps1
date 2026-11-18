$ErrorActionPreference = 'Stop'
$Namespace = 'compileflow-lab'

Write-Host '1. Kubernetes 工作负载'
kubectl get pods -n $Namespace -o wide

Write-Host '2. SkyWalking OAP 集群成员'
$nodes = Invoke-RestMethod 'http://127.0.0.1:22800/status/cluster/nodes'
$nodes.nodes | Format-Table host,port,self -AutoSize
if (@($nodes.nodes).Count -lt 2) {
    throw "SkyWalking OAP cluster expected 2 nodes, found $(@($nodes.nodes).Count)."
}

Write-Host '3. Eureka 注册实例'
$registry = Invoke-RestMethod -Uri 'http://127.0.0.1:28761/eureka/apps' -Headers @{Accept='application/json'}
$registry.applications.application | ForEach-Object {
    [pscustomobject]@{
        Service = $_.name
        Instances = @($_.instance).Count
        Status = (@($_.instance) | ForEach-Object status) -join ','
    }
} | Sort-Object Service | Format-Table -AutoSize

$expectedInstances = @{
    'COMPILEFLOW-CLUSTER-GATEWAY' = 3
    'COMPILEFLOW-PAYMENT-SERVICE' = 4
    'COMPILEFLOW-SHOPPING-DEMO' = 4
    'COMPILEFLOW-WORKBENCH-SERVER' = 3
}
foreach ($service in $expectedInstances.Keys) {
    $application = $registry.applications.application | Where-Object name -eq $service
    $actual = @($application.instance | Where-Object status -eq 'UP').Count
    if ($actual -ne $expectedInstances[$service]) {
        throw "$service expected $($expectedInstances[$service]) UP instances, found $actual."
    }
}

Write-Host '4. 发送购物支付请求'
$requestId = 'k8s-study-' + [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
$response = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:28080/api/checkout' `
    -Headers @{'X-Request-Id'=$requestId} -ContentType 'application/json' `
    -Body '{"sku":"BOOK","quantity":2}'
$response | Select-Object requestId,serviceInstance,paymentInstance,paymentStatus,traceId,skywalkingTraceId |
    Format-List

if ($response.paymentStatus -ne 'PAID' -or -not $response.skywalkingTraceId) {
    throw 'Checkout, payment, or SkyWalking trace verification failed.'
}

Write-Host '5. RocketMQ 异步支付与 PXC 落库'
$pxcState = kubectl get pxc payment-pxc -n $Namespace -o jsonpath='{.status.state}'
if ($pxcState -ne 'ready') { throw "PXC expected ready, found $pxcState." }

$nameServers = @(kubectl get pods -n $Namespace -l app=rocketmq-nameserver `
    -o jsonpath='{range .items[?(@.status.phase=="Running")]}{.metadata.name}{"\n"}{end}' | Where-Object { $_ })
$brokers = @(kubectl get pods -n $Namespace -l app=rocketmq-broker `
    -o jsonpath='{range .items[?(@.status.phase=="Running")]}{.metadata.name}{"\n"}{end}' | Where-Object { $_ })
if ($nameServers.Count -ne 2 -or $brokers.Count -ne 2) {
    throw "RocketMQ expected 2 NameServers and 2 Brokers, found $($nameServers.Count) and $($brokers.Count)."
}

$asyncRequestId = 'k8s-async-' + [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
$asyncResponse = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:28080/api/checkout/async' `
    -Headers @{'X-Request-Id'=$asyncRequestId} -ContentType 'application/json' `
    -Body '{"sku":"PEN","quantity":2}'
if ($asyncResponse.paymentStatus -ne 'PAYMENT_PENDING' -or $asyncResponse.mqSendStatus -ne 'SEND_OK') {
    throw 'The shopping service did not publish the asynchronous payment message.'
}

$storedPayment = $null
for ($attempt = 1; $attempt -le 30; $attempt++) {
    try {
        $storedPayment = Invoke-RestMethod `
            -Uri "http://127.0.0.1:28080/api/payments/orders/$($asyncResponse.orderId)"
        break
    } catch {
        Start-Sleep -Seconds 1
    }
}
if (-not $storedPayment -or $storedPayment.status -ne 'PAID') {
    throw 'The payment consumer did not persist the message to PXC.'
}
$asyncResponse | Select-Object orderId,messageId,mqSendStatus,paymentStatus | Format-List
$storedPayment | Select-Object paymentId,orderId,amountCents,status,serviceInstance,traceId | Format-List

$traceQuery = 'query { queryTrace(traceId:"' + $response.skywalkingTraceId + '") { spans { serviceCode component type endpointName refs { parentSegmentId } } } }'
$body = @{query=$traceQuery} | ConvertTo-Json -Compress
$services = @()
for ($attempt = 1; $attempt -le 12; $attempt++) {
    Start-Sleep -Seconds 5
    $trace = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:22800/graphql' `
        -ContentType 'application/json' -Body $body
    $services = @($trace.data.queryTrace.spans.serviceCode | Sort-Object -Unique)
    if (@('compileflow-gateway','shopping-service','workbench-server','payment-service') |
            Where-Object { $_ -notin $services }) {
        Write-Host "Waiting for the complete trace ($attempt/12)..."
        continue
    }
    break
}
Write-Host "SkyWalking services: $($services -join ' -> ')"
if (@('compileflow-gateway','shopping-service','workbench-server','payment-service') |
        Where-Object { $_ -notin $services }) {
    throw 'The SkyWalking trace does not contain all four services.'
}

Write-Host 'Kubernetes + SkyWalking + RocketMQ + PXC verification passed.'
