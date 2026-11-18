package lab.payment.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import java.time.LocalDateTime;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("payment_record")
public class PaymentEntity {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String paymentId;
    private String orderId;
    private Integer amountCents;
    private String status;
    private String requestId;
    private String serviceInstance;
    private String traceId;
    private LocalDateTime createdAt;
}
