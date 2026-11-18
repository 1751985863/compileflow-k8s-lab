package lab.shopping;

import jakarta.servlet.http.HttpServletRequest;
import java.util.Map;
import java.util.UUID;
import lab.shopping.dto.AsyncCheckoutResponseDto;
import lab.shopping.dto.CheckoutRequestDto;
import lab.shopping.dto.CheckoutResponseDto;
import org.apache.skywalking.apm.toolkit.trace.TraceContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/checkout")
class CheckoutController {
    private static final Logger log = LoggerFactory.getLogger(CheckoutController.class);
    private static final Map<String, Integer> PRICES = Map.of("BOOK", 6_000, "PEN", 1_500);
    private final WorkbenchClient workbench;
    private final PaymentClient paymentClient;
    private final ObjectProvider<AsyncPaymentPublisher> asyncPaymentPublisher;

    CheckoutController(WorkbenchClient workbench, PaymentClient paymentClient,
                       ObjectProvider<AsyncPaymentPublisher> asyncPaymentPublisher) {
        this.workbench = workbench;
        this.paymentClient = paymentClient;
        this.asyncPaymentPublisher = asyncPaymentPublisher;
    }

    @PostMapping("/async")
    AsyncCheckoutResponseDto asyncCheckout(@RequestBody CheckoutRequestDto request,
                                           HttpServletRequest servletRequest) {
        validate(request);
        int subtotal = PRICES.get(request.getSku()) * request.getQuantity();
        String requestId = (String) servletRequest.getAttribute(RequestTraceFilter.REQUEST_ID_ATTRIBUTE);
        String instanceId = (String) servletRequest.getAttribute(RequestTraceFilter.INSTANCE_ID_ATTRIBUTE);
        var execution = workbench.execute(subtotal);
        var result = execution.getResult();
        String orderId = "ORDER-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        AsyncPaymentPublisher publisher = asyncPaymentPublisher.getIfAvailable();
        if (publisher == null) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "RocketMQ 异步支付未启用");
        }
        try {
            var published = publisher.publish(orderId, result.getPayableCents(), requestId,
                    TraceContext.traceId());
            log.info("async payment published orderId={} messageId={} payableCents={}",
                    orderId, published.getMessageId(), result.getPayableCents());
            return AsyncCheckoutResponseDto.builder()
                    .sku(request.getSku())
                    .quantity(request.getQuantity())
                    .subtotalCents(subtotal)
                    .discountCents(result.getDiscountCents())
                    .payableCents(result.getPayableCents())
                    .traceId(execution.getTraceId())
                    .flowVersion(execution.getRouting().getEffectiveVersion())
                    .requestId(requestId)
                    .serviceInstance(instanceId)
                    .orderId(orderId)
                    .paymentStatus("PAYMENT_PENDING")
                    .messageId(published.getMessageId())
                    .mqSendStatus(published.getSendStatus())
                    .skywalkingTraceId(TraceContext.traceId())
                    .build();
        } catch (Exception failure) {
            log.error("async payment publish failed orderId={}", orderId, failure);
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "支付消息投递失败", failure);
        }
    }

    private static void validate(CheckoutRequestDto request) {
        if (request.getSku() == null || !PRICES.containsKey(request.getSku())
                || request.getQuantity() == null || request.getQuantity() < 1 || request.getQuantity() > 99) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "商品必须为 BOOK 或 PEN，数量必须为 1 到 99");
        }
    }

    @PostMapping
    CheckoutResponseDto checkout(@RequestBody CheckoutRequestDto request, HttpServletRequest servletRequest) {
        validate(request);
        // 由商品目录定价，外部请求只提供 SKU 和数量。
        int subtotal = PRICES.get(request.getSku()) * request.getQuantity();
        String requestId = (String) servletRequest.getAttribute(RequestTraceFilter.REQUEST_ID_ATTRIBUTE);
        String instanceId = (String) servletRequest.getAttribute(RequestTraceFilter.INSTANCE_ID_ATTRIBUTE);
        log.info("checkout started sku={} quantity={} subtotalCents={}",
                request.getSku(), request.getQuantity(), subtotal);
        var execution = workbench.execute(subtotal);
        var result = execution.getResult();
        String orderId = "ORDER-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        var payment = paymentClient.pay(orderId, result.getPayableCents());
        log.info("checkout completed traceId={} flowVersion={} payableCents={}",
                execution.getTraceId(), execution.getRouting().getEffectiveVersion(), result.getPayableCents());
        return CheckoutResponseDto.builder()
                .sku(request.getSku())
                .quantity(request.getQuantity())
                .subtotalCents(subtotal)
                .discountCents(result.getDiscountCents())
                .payableCents(result.getPayableCents())
                .traceId(execution.getTraceId())
                .flowVersion(execution.getRouting().getEffectiveVersion())
                .requestId(requestId)
                .serviceInstance(instanceId)
                .orderId(orderId)
                .paymentId(payment.getPaymentId())
                .paymentStatus(payment.getStatus())
                .paymentInstance(payment.getServiceInstance())
                .skywalkingTraceId(TraceContext.traceId())
                .build();
    }
}
