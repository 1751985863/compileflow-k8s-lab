---
name: compileflow-k8s-lab
description: Restore, deploy, verify, operate, or troubleshoot the portable CompileFlow shopping/payment Kubernetes lab on a Windows computer, including its Spring services, middleware clusters, logging, tracing, monitoring, Headlamp, and k6 setup. Use for reproducing this specific lab; do not route unrelated Kubernetes projects here.
---

# CompileFlow K8s Lab

Use the bundled project snapshot and deterministic scripts as the source of truth. The target outcome is a working local Kind cluster with the same services, replica counts, middleware topology, ports, and verification behavior as the original lab.

## Route the task

- For a new computer or fresh copy, read [references/prerequisites.md](references/prerequisites.md), then [references/operations.md](references/operations.md).
- For topology, dependencies, replica counts, or architectural changes, read [references/architecture.md](references/architecture.md).
- For failures, read [references/troubleshooting.md](references/troubleshooting.md) and diagnose in its layer order.
- Run `scripts/audit-bundle.ps1` before transferring or publishing an updated Skill bundle.

## Restore rules

1. Run `scripts/preflight.ps1` before copying or deploying anything.
2. Use `scripts/restore-lab.ps1` to create a project from `assets/project-template`; do not reconstruct the project from memory.
3. The restore script copies the bundled Alibaba CompileFlow source snapshot from pinned commit `c2831832745e893f0dbe22b1e94810625372a356`. Preserve that snapshot for a 1:1 reproduction unless the user explicitly requests an upgrade.
4. Use PowerShell 7 (`pwsh`) for all included scripts. Windows PowerShell 5 can misread the UTF-8 Chinese scripts.
5. Never copy `.lab.env`, generated Headlamp `kubeconfig`, service-account tokens, PXC runtime secrets, persistent volumes, or log files from another computer. Generate them locally.
6. If the destination is nonempty, inspect it and preserve user changes. Do not use `-Force` without explicit authorization to overwrite.

## Deployment invariants

- Active kubectl context must be `kind-compileflow-k8s` before apply, rollout, exec, or delete operations.
- Build Java with JDK 17.
- Keep the declared image versions, service names, namespace `compileflow-lab`, and host ports unless the user requests a change.
- Deploy the Percona Operator/CRD before the PXC custom resource, wait for PXC `ready`, then run the schema Job before starting payment traffic.
- Publish the CompileFlow shopping definition after Workbench is ready, inject the returned version into Shopping, and wait for Eureka and gateway caches to converge.
- Treat RocketMQ delivery as at-least-once; preserve the unique `order_id` constraint and idempotent payment write.
- Payment persistence in K8s must use MyBatis-Plus and PXC. The in-memory Store is only the local fallback when `PAYMENT_DATABASE_ENABLED=false`.

## Verification

After deployment, run the bundled `k8s-cluster/verify.ps1`. Completion requires all of these observable results:

- Eureka: Gateway 3, Shopping 4, Payment 4, Workbench 3, all UP.
- Synchronous checkout returns `PAID` and a SkyWalking trace crossing gateway, shopping, Workbench, and payment.
- Asynchronous checkout returns `PAYMENT_PENDING` plus `SEND_OK`, then becomes `PAID` after RocketMQ consumption and PXC persistence.
- PXC reports ready with 3 database Pods; RocketMQ has 2 NameServers and 2 Brokers.
- No application Pod is crash-looping or repeatedly restarting.

Only report successful reproduction after these checks pass. If monitoring, Headlamp, or load testing was requested, verify those separately using their included scripts and UIs.

## Updating the bundle

When the user asks to capture later project changes, update only the corresponding files under `assets/project-template`, update the relevant reference if topology or operations changed, run `scripts/audit-bundle.ps1`, run Maven packaging for all four modules, and validate the Skill. Do not add build outputs or live credentials to the bundle.

