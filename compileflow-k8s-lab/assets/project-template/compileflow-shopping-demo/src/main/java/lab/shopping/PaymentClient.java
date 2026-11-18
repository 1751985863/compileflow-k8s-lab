package lab.shopping;

import java.util.Map;
import lab.shopping.dto.PaymentResponseDto;
import feign.FeignException;
import feign.RetryableException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

@Component
class PaymentClient {
    private static final Logger log = LoggerFactory.getLogger(PaymentClient.class);
    private final PaymentFeignClient client;

    PaymentClient(PaymentFeignClient client) {
        this.client = client;
    }

    PaymentResponseDto pay(String orderId, int amountCents) {
        try {
            log.info("calling payment orderId={} amountCents={}", orderId, amountCents);
            Map<String, Object> payload = Map.of("orderId", orderId, "amountCents", amountCents);
            PaymentResponseDto payment = client.pay(currentRequestId(), payload);
            if (payment == null || payment.getPaymentId() == null || !"PAID".equals(payment.getStatus())) {
                throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "支付服务返回异常");
            }
            log.info("payment completed paymentId={} paymentNode={} status={}",
                    payment.getPaymentId(), payment.getServiceInstance(), payment.getStatus());
            return payment;
        } catch (RetryableException failure) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "支付服务连接失败或超时", failure);
        } catch (FeignException failure) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "支付服务请求失败", failure);
        }
    }

    private String currentRequestId() {
        String requestId = MDC.get("requestId");
        return requestId == null ? "unknown" : requestId;
    }
}
