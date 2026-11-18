package lab.shopping;

import java.util.Map;
import lab.shopping.dto.WorkbenchExecutionDto;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;

/**
 * name 是 Eureka 中的服务名。OpenFeign 会通过负载均衡选择一个 Workbench 节点，
 * 不需要在购物服务中保存具体 IP 和端口。
 */
@FeignClient(name = "compileflow-workbench-server")
interface WorkbenchFeignClient {
    @PostMapping("/api/processes/demo.shopping.checkout/execute")
    WorkbenchExecutionDto execute(
            @RequestHeader("X-Request-Id") String requestId,
            @RequestBody Map<String, Object> payload);
}
