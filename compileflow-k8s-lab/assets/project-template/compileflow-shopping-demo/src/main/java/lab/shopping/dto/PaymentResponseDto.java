package lab.shopping.dto;

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
    private Integer amountCents;
    private String status;
    private String requestId;
    private String serviceInstance;
    private String traceId;
}
