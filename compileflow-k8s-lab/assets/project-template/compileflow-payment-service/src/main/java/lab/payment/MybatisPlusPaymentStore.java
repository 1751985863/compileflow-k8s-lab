package lab.payment;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import java.util.Optional;
import lab.payment.dto.PaymentRecordDto;
import lab.payment.entity.PaymentEntity;
import lab.payment.mapper.PaymentMapper;
import org.springframework.dao.DuplicateKeyException;

final class MybatisPlusPaymentStore implements PaymentStore {
    private final PaymentMapper paymentMapper;

    MybatisPlusPaymentStore(PaymentMapper paymentMapper) {
        this.paymentMapper = paymentMapper;
    }

    @Override
    public PaymentRecordDto savePaid(String paymentId, String orderId, int amountCents,
                                     String requestId, String serviceInstance, String traceId) {
        PaymentEntity entity = PaymentEntity.builder()
                .paymentId(paymentId)
                .orderId(orderId)
                .amountCents(amountCents)
                .status("PAID")
                .requestId(requestId)
                .serviceInstance(serviceInstance)
                .traceId(traceId)
                .build();
        try {
            paymentMapper.insert(entity);
        } catch (DuplicateKeyException ignored) {
            // RocketMQ 至少一次投递可能产生重复消息，order_id 唯一键负责最终幂等。
        }
        return findByOrderId(orderId).orElseThrow();
    }

    @Override
    public Optional<PaymentRecordDto> findByOrderId(String orderId) {
        PaymentEntity entity = paymentMapper.selectOne(Wrappers.<PaymentEntity>lambdaQuery()
                .eq(PaymentEntity::getOrderId, orderId));
        return Optional.ofNullable(entity).map(MybatisPlusPaymentStore::toDto);
    }

    private static PaymentRecordDto toDto(PaymentEntity entity) {
        return PaymentRecordDto.builder()
                .paymentId(entity.getPaymentId())
                .orderId(entity.getOrderId())
                .amountCents(entity.getAmountCents())
                .status(entity.getStatus())
                .requestId(entity.getRequestId())
                .serviceInstance(entity.getServiceInstance())
                .traceId(entity.getTraceId())
                .build();
    }
}
