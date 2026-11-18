package lab.shopping;

import java.util.Map;
import lab.shopping.dto.WorkbenchExecutionDto;
import feign.FeignException;
import feign.RetryableException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

@Component
class WorkbenchClient {
    private static final Logger log = LoggerFactory.getLogger(WorkbenchClient.class);
    private final WorkbenchFeignClient client;
    private final String version;

    WorkbenchClient(WorkbenchFeignClient client,
                    @Value("${shopping.flow-version}") String version) {
        this.client = client;
        this.version = version;
    }

    WorkbenchExecutionDto execute(int subtotalCents) {
        // Workbench 按明确版本执行。同一个版本可以反复使用。
        Map<String, Object> payload = Map.of(
                "params", Map.of("subtotalCents", subtotalCents),
                "routing", Map.of("version", version));
        WorkbenchExecutionDto execution;
        try {
            log.info("calling workbench processCode=demo.shopping.checkout flowVersion={}", version);
            execution = client.execute(currentRequestId(), payload);
        } catch (RetryableException failure) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Workbench Server 连接失败或超时", failure);
        } catch (FeignException failure) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Workbench Server 请求失败，请核对流程版本", failure);
        }
        if (execution == null || !execution.isSuccess() || execution.getResult() == null
                || execution.getResult().getDiscountCents() == null
                || execution.getResult().getPayableCents() == null
                || execution.getRouting() == null || execution.getRouting().getEffectiveVersion() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "购物流程执行失败，请查看 Workbench 执行日志");
        }
        log.info("workbench completed traceId={} effectiveVersion={}",
                execution.getTraceId(), execution.getRouting().getEffectiveVersion());
        return execution;
    }

    private String currentRequestId() {
        String requestId = MDC.get("requestId");
        return requestId == null ? "unknown" : requestId;
    }
}
