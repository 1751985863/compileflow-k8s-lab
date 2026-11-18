package lab.payment;

import lab.payment.mapper.PaymentMapper;
import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

@Configuration
@ConditionalOnProperty(name = "payment.database.enabled", havingValue = "true")
@MapperScan("lab.payment.mapper")
class PaymentDatabaseConfiguration {

    @Bean
    @Primary
    PaymentStore mybatisPlusPaymentStore(PaymentMapper paymentMapper) {
        return new MybatisPlusPaymentStore(paymentMapper);
    }
}
