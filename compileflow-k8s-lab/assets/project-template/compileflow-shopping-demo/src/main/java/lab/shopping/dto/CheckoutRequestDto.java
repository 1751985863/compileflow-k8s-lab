package lab.shopping.dto;

import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
public class CheckoutRequestDto {
    private String sku;
    private Integer quantity;
}
