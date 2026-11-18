package lab.shopping.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class WorkbenchExecutionDto {
    private boolean success;
    private WorkbenchResultDto result;
    private WorkbenchRoutingDto routing;
    private String traceId;
}
