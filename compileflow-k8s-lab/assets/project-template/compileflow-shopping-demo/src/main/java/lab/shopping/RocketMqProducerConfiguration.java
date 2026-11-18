package lab.shopping;

import org.apache.rocketmq.client.exception.MQClientException;
import org.apache.rocketmq.client.producer.DefaultMQProducer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConditionalOnProperty(name = "rocketmq.enabled", havingValue = "true")
class RocketMqProducerConfiguration {

    @Bean(destroyMethod = "shutdown")
    DefaultMQProducer paymentProducer(
            @Value("${rocketmq.name-server}") String nameServer,
            @Value("${INSTANCE_ID:shopping-local}") String instanceId) throws MQClientException {
        DefaultMQProducer producer = new DefaultMQProducer("shopping-payment-producer");
        producer.setNamesrvAddr(nameServer);
        producer.setInstanceName(instanceId);
        producer.setSendMsgTimeout(5_000);
        producer.setRetryTimesWhenSendFailed(2);
        producer.start();
        return producer;
    }
}
