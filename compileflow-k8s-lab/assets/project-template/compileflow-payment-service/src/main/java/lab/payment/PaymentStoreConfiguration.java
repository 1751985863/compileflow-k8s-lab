package lab.payment;

import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import lab.payment.dto.PaymentRecordDto;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
class PaymentStoreConfiguration {

    @Bean
    @ConditionalOnProperty(name = "payment.database.enabled", havingValue = "false", matchIfMissing = true)
    PaymentStore inMemoryPaymentStore() {
        return new PaymentStore() {
            private final ConcurrentHashMap<String, PaymentRecordDto> records = new ConcurrentHashMap<>();

            @Override
            public PaymentRecordDto savePaid(String paymentId, String orderId, int amountCents,
                                             String requestId, String serviceInstance, String traceId) {
                return records.computeIfAbsent(orderId, ignored -> PaymentRecordDto.builder()
                        .paymentId(paymentId)
                        .orderId(orderId)
                        .amountCents(amountCents)
                        .status("PAID")
                        .requestId(requestId)
                        .serviceInstance(serviceInstance)
                        .traceId(traceId)
                        .build());
            }

            @Override
            public Optional<PaymentRecordDto> findByOrderId(String orderId) {
                return Optional.ofNullable(records.get(orderId));
            }
        };
    }
}
