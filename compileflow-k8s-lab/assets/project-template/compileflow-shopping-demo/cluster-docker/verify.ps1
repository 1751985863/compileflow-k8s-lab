$ErrorActionPreference = 'Stop'

Write-Host '1. Eureka 注册情况'
$registry = Invoke-RestMethod -Uri 'http://127.0.0.1:18761/eureka/apps' -Headers @{ Accept = 'application/json' }
$registry.applications.application | ForEach-Object {
    [pscustomobject]@{
        Service = $_.name
        Instances = @($_.instance).Count
        Status = (@($_.instance) | ForEach-Object status) -join ','
    }
} | Format-Table -AutoSize

Write-Host '2. 连续发送 8 个请求，观察购物和支付节点轮询'
1..8 | ForEach-Object {
    $requestId = "cluster-study-$($_)"
    $response = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:18080/api/checkout' `
        -Headers @{ 'X-Request-Id' = $requestId } -ContentType 'application/json' `
        -Body '{"sku":"BOOK","quantity":2}'
    [pscustomobject]@{
        RequestId = $response.requestId
        ShoppingNode = $response.serviceInstance
        PaymentNode = $response.paymentInstance
        PaymentId = $response.paymentId
        FlowTraceId = $response.traceId
        SkyWalkingTraceId = $response.skywalkingTraceId
        PayableCents = $response.payableCents
    }
} | Format-Table -AutoSize

Write-Host '3. 到 Kibana 查询：message : "cluster-study-1"；到 SkyWalking 查询返回的 SkyWalkingTraceId'
