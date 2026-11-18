$ErrorActionPreference = 'Stop'

$expectedContext = 'kind-compileflow-k8s'
$actualContext = kubectl config current-context
if ($LASTEXITCODE -ne 0 -or $actualContext -ne $expectedContext) {
    throw "Current kubectl context must be $expectedContext, found $actualContext."
}

kubectl apply -f (Join-Path $PSScriptRoot 'rbac.yaml')
if ($LASTEXITCODE -ne 0) { throw 'Could not create the read-only Headlamp account.' }

$token = ''
for ($attempt = 1; $attempt -le 12; $attempt++) {
    $token = kubectl get secret headlamp-viewer-token -n kube-system `
        -o jsonpath='{.data.token}' 2>$null
    if ($token) { break }
    Start-Sleep -Seconds 1
}
if (-not $token) { throw 'The Headlamp service account token was not generated.' }

$caData = kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'
if (-not $caData) { throw 'Could not read the kind cluster CA certificate.' }

$tokenText = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($token))
$kubeconfig = @"
apiVersion: v1
kind: Config
clusters:
  - name: compileflow-k8s
    cluster:
      server: https://compileflow-k8s-control-plane:6443
      certificate-authority-data: $caData
contexts:
  - name: compileflow-k8s
    context:
      cluster: compileflow-k8s
      user: headlamp-viewer
      namespace: compileflow-lab
current-context: compileflow-k8s
users:
  - name: headlamp-viewer
    user:
      token: $tokenText
"@

# 这是运行时凭据文件，已被 .gitignore 排除，不会进入镜像。
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'kubeconfig'), $kubeconfig, [Text.UTF8Encoding]::new($false))

docker compose -f (Join-Path $PSScriptRoot 'compose.yaml') up -d
if ($LASTEXITCODE -ne 0) { throw 'Could not start the Headlamp container.' }

$ready = $false
for ($attempt = 1; $attempt -le 30; $attempt++) {
    try {
        $response = Invoke-WebRequest -UseBasicParsing 'http://127.0.0.1:24466/' -TimeoutSec 2
        if ($response.StatusCode -eq 200) {
            $ready = $true
            break
        }
    } catch {
        Start-Sleep -Seconds 2
    }
}
if (-not $ready) {
    docker logs compileflow-k8s-headlamp --tail=100
    throw 'Headlamp did not become ready.'
}

Write-Host 'Headlamp is ready: http://127.0.0.1:24466'
Write-Host 'It uses a read-only Kubernetes account and opens the compileflow-lab namespace by default.'

