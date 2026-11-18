FROM apache/skywalking-java-agent:9.8.0-java17 AS skywalking-agent
FROM compileflow-workbench-server:local-2.0.0
USER root
WORKDIR /app
COPY --from=skywalking-agent /skywalking/agent /skywalking/agent
RUN cp /skywalking/agent/optional-plugins/apm-springmvc-annotation-6.x-plugin-*.jar /skywalking/agent/plugins/ \
    && chown -R compileflow:compileflow /skywalking
COPY --chown=compileflow:compileflow target/compileflow-shopping-demo-1.0-SNAPSHOT.jar /app/app.jar
USER compileflow
EXPOSE 8080
