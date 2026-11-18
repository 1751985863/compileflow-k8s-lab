package lab.payment.dto;

import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
public class PaymentRequestDto {
    private String orderId;
    private Integer amountCents;
}
