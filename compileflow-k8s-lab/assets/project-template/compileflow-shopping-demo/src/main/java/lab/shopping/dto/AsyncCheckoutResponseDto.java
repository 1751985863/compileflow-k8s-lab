package lab.shopping.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AsyncCheckoutResponseDto {
    private String sku;
    private int quantity;
    private int subtotalCents;
    private int discountCents;
    private int payableCents;
    private String traceId;
    private String flowVersion;
    private String requestId;
    private String serviceInstance;
    private String orderId;
    private String paymentStatus;
    private String messageId;
    private String mqSendStatus;
    private String skywalkingTraceId;
}
