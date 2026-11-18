package lab.payment.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PaymentResponseDto {
    private String paymentId;
    private String orderId;
    private int amountCents;
    private String status;
    private String requestId;
    private String serviceInstance;
    private String traceId;
}
