package lab.payment;

import jakarta.servlet.http.HttpServletRequest;
import java.util.UUID;
import lab.payment.dto.PaymentRecordDto;
import lab.payment.dto.PaymentRequestDto;
import lab.payment.dto.PaymentResponseDto;
import org.apache.skywalking.apm.toolkit.trace.TraceContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/payments")
class PaymentController {
    private static final Logger log = LoggerFactory.getLogger(PaymentController.class);
    private final PaymentStore paymentStore;

    PaymentController(PaymentStore paymentStore) {
        this.paymentStore = paymentStore;
    }

    @PostMapping
    PaymentResponseDto pay(@RequestBody PaymentRequestDto request, HttpServletRequest servletRequest) {
        if (request.getOrderId() == null || request.getOrderId().isBlank()
                || request.getAmountCents() == null || request.getAmountCents() < 1) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "订单号不能为空，支付金额必须大于 0");
        }
        String requestId = (String) servletRequest.getAttribute(RequestTraceFilter.REQUEST_ID_ATTRIBUTE);
        String instanceId = (String) servletRequest.getAttribute(RequestTraceFilter.INSTANCE_ID_ATTRIBUTE);
        String paymentId = "PAY-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        PaymentRecordDto payment = paymentStore.savePaid(paymentId, request.getOrderId(),
                request.getAmountCents(), requestId, instanceId, TraceContext.traceId());
        log.info("payment accepted orderId={} paymentId={} amountCents={}",
                payment.getOrderId(), payment.getPaymentId(), payment.getAmountCents());
        return toResponse(payment);
    }

    @GetMapping("/orders/{orderId}")
    PaymentResponseDto findByOrderId(@PathVariable("orderId") String orderId) {
        return paymentStore.findByOrderId(orderId)
                .map(PaymentController::toResponse)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "支付记录尚未生成"));
    }

    private static PaymentResponseDto toResponse(PaymentRecordDto record) {
        return PaymentResponseDto.builder()
                .paymentId(record.getPaymentId())
                .orderId(record.getOrderId())
                .amountCents(record.getAmountCents())
                .status(record.getStatus())
                .requestId(record.getRequestId())
                .serviceInstance(record.getServiceInstance())
                .traceId(record.getTraceId())
                .build();
    }
}
