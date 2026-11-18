/*
 * Copyright 2020-present the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.alibaba.compileflow.workbench.server;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/** Adds a request id and the Workbench instance id to every request log. */
@Component
public class RequestTraceFilter extends OncePerRequestFilter {

    private static final Logger LOGGER = LoggerFactory.getLogger(RequestTraceFilter.class);
    private static final String REQUEST_ID_HEADER = "X-Request-Id";
    private final String instanceId;

    public RequestTraceFilter(@Value("${eureka.instance.instance-id:${HOSTNAME:local}}") String instanceId) {
        this.instanceId = instanceId;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        String requestId = request.getHeader(REQUEST_ID_HEADER);
        if (requestId == null || requestId.isBlank()) {
            requestId = UUID.randomUUID().toString();
        }
        response.setHeader(REQUEST_ID_HEADER, requestId);
        response.setHeader("X-Workbench-Instance", instanceId);
        long startedAt = System.currentTimeMillis();
        MDC.put("requestId", requestId);
        try {
            LOGGER.info("workbench request started requestId={} instance={} method={} path={}", requestId, instanceId,
                    request.getMethod(), request.getRequestURI());
            filterChain.doFilter(request, response);
            LOGGER.info("workbench request completed requestId={} instance={} status={} durationMs={}", requestId,
                    instanceId, response.getStatus(), System.currentTimeMillis() - startedAt);
        } finally {
            MDC.remove("requestId");
        }
    }
}
