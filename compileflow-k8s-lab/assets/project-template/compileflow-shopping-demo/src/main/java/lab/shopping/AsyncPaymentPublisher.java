package lab.shopping;

import java.nio.charset.StandardCharsets;
import lab.shopping.dto.PublishedMessageDto;
import org.apache.rocketmq.client.producer.DefaultMQProducer;
import org.apache.rocketmq.client.producer.SendResult;
import org.apache.rocketmq.common.message.Message;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(name = "rocketmq.enabled", havingValue = "true")
class AsyncPaymentPublisher {
    private final DefaultMQProducer producer;
    private final String topic;

    AsyncPaymentPublisher(DefaultMQProducer producer,
                          @Value("${rocketmq.payment-topic}") String topic) {
        this.producer = producer;
        this.topic = topic;
    }

    PublishedMessageDto publish(String orderId, int amountCents, String requestId,
                                String shoppingTraceId) throws Exception {
        Message message = new Message(topic, "PAY", orderId,
                orderId.getBytes(StandardCharsets.UTF_8));
        message.putUserProperty("amountCents", Integer.toString(amountCents));
        message.putUserProperty("requestId", requestId == null ? "" : requestId);
        message.putUserProperty("shoppingTraceId", shoppingTraceId == null ? "" : shoppingTraceId);

        // 这里等待的是 MQ 持久化确认，不等待支付完成。支付仍由消费者异步执行。
        SendResult result = producer.send(message, 5_000);
        return PublishedMessageDto.builder()
                .messageId(result.getMsgId())
                .sendStatus(result.getSendStatus().name())
                .build();
    }
}
