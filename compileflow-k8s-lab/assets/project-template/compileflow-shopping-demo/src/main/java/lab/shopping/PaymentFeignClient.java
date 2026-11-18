package lab.shopping;

import java.util.Map;
import lab.shopping.dto.PaymentResponseDto;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;

/**
 * 只声明支付接口，不写服务地址。OpenFeign 根据 Eureka 服务名查找 payment-1..4。
 */
@FeignClient(name = "compileflow-payment-service")
interface PaymentFeignClient {
    @PostMapping("/api/payments")
    PaymentResponseDto pay(
            @RequestHeader("X-Request-Id") String requestId,
            @RequestBody Map<String, Object> payload);
}
