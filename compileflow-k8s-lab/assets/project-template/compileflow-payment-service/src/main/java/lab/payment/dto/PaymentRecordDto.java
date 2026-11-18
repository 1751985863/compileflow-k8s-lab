package lab.payment.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PaymentRecordDto {
    private String paymentId;
    private String orderId;
    private int amountCents;
    private String status;
    private String requestId;
    private String serviceInstance;
    private String traceId;
}
