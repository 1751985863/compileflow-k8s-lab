package lab.payment;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.UUID;
import lab.payment.dto.PaymentRecordDto;
import org.apache.rocketmq.client.consumer.DefaultMQPushConsumer;
import org.apache.rocketmq.client.consumer.listener.ConsumeConcurrentlyContext;
import org.apache.rocketmq.client.consumer.listener.ConsumeConcurrentlyStatus;
import org.apache.rocketmq.client.consumer.listener.MessageListenerConcurrently;
import org.apache.rocketmq.client.exception.MQClientException;
import org.apache.rocketmq.common.consumer.ConsumeFromWhere;
import org.apache.rocketmq.common.message.MessageExt;
import org.apache.skywalking.apm.toolkit.trace.TraceContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConditionalOnProperty(name = "rocketmq.enabled", havingValue = "true")
class RocketMqPaymentConsumerConfiguration {
    private static final Logger log = LoggerFactory.getLogger(RocketMqPaymentConsumerConfiguration.class);

    @Bean(destroyMethod = "shutdown")
    DefaultMQPushConsumer paymentConsumer(
            PaymentStore paymentStore,
            @Value("${rocketmq.name-server}") String nameServer,
            @Value("${rocketmq.payment-topic}") String topic,
            @Value("${INSTANCE_ID:payment-local}") String instanceId) throws MQClientException {
        DefaultMQPushConsumer consumer = new DefaultMQPushConsumer("shopping-payment-consumer");
        consumer.setNamesrvAddr(nameServer);
        consumer.setInstanceName(instanceId);
        consumer.setConsumeFromWhere(ConsumeFromWhere.CONSUME_FROM_FIRST_OFFSET);
        consumer.setConsumeMessageBatchMaxSize(1);
        consumer.subscribe(topic, "PAY");
        consumer.registerMessageListener((MessageListenerConcurrently) (messages, context) ->
                consume(messages, context, paymentStore, instanceId));
        consumer.start();
        return consumer;
    }

    private ConsumeConcurrentlyStatus consume(List<MessageExt> messages,
                                               ConsumeConcurrentlyContext context,
                                               PaymentStore paymentStore,
                                               String instanceId) {
        try {
            for (MessageExt message : messages) {
                String orderId = new String(message.getBody(), StandardCharsets.UTF_8);
                int amountCents = Integer.parseInt(message.getUserProperty("amountCents"));
                String requestId = message.getUserProperty("requestId");
                String traceId = TraceContext.traceId();
                if (traceId == null || traceId.isBlank() || "N/A".equals(traceId)) {
                    // Agent 版本无法自动继承 RocketMQ 上下文时，仍保留生产者 TraceId 供日志检索。
                    traceId = message.getUserProperty("shoppingTraceId");
                }
                String paymentId = "PAY-" + UUID.randomUUID().toString()
                        .substring(0, 8).toUpperCase();
                PaymentRecordDto record = paymentStore.savePaid(paymentId, orderId, amountCents,
                        requestId, instanceId, traceId);
                log.info("async payment consumed orderId={} paymentId={} messageId={} amountCents={}",
                        record.getOrderId(), record.getPaymentId(), message.getMsgId(), record.getAmountCents());
            }
            return ConsumeConcurrentlyStatus.CONSUME_SUCCESS;
        } catch (Exception failure) {
            log.error("async payment consume failed queue={}", context.getMessageQueue(), failure);
            return ConsumeConcurrentlyStatus.RECONSUME_LATER;
        }
    }
}
