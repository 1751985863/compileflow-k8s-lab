package lab.shopping.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class WorkbenchResultDto {
    private Integer discountCents;
    private Integer payableCents;
}
