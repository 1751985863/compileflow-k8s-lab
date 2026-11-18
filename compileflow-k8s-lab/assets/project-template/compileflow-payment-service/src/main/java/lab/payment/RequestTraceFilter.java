package lab.payment;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.UUID;
import org.slf4j.MDC;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
class RequestTraceFilter extends OncePerRequestFilter {
    static final String REQUEST_ID_ATTRIBUTE = RequestTraceFilter.class.getName() + ".requestId";
    static final String INSTANCE_ID_ATTRIBUTE = RequestTraceFilter.class.getName() + ".instanceId";
    private static final String REQUEST_ID_HEADER = "X-Request-Id";
    private final String instanceId;

    RequestTraceFilter(@Value("${INSTANCE_ID:local}") String instanceId) {
        this.instanceId = instanceId;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String requestId = request.getHeader(REQUEST_ID_HEADER);
        if (requestId == null || requestId.isBlank()) {
            requestId = UUID.randomUUID().toString();
        }
        request.setAttribute(REQUEST_ID_ATTRIBUTE, requestId);
        request.setAttribute(INSTANCE_ID_ATTRIBUTE, instanceId);
        response.setHeader(REQUEST_ID_HEADER, requestId);
        response.setHeader("X-Payment-Instance", instanceId);
        try (MDC.MDCCloseable ignored = MDC.putCloseable("requestId", requestId)) {
            filterChain.doFilter(request, response);
        }
    }
}
