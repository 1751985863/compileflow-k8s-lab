package lab.payment;

import java.util.Optional;
import lab.payment.dto.PaymentRecordDto;

interface PaymentStore {
    PaymentRecordDto savePaid(String paymentId, String orderId, int amountCents,
                              String requestId, String serviceInstance, String traceId);

    Optional<PaymentRecordDto> findByOrderId(String orderId);
}
