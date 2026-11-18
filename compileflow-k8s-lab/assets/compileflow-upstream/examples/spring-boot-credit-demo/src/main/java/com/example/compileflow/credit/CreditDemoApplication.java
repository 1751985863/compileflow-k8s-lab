package com.example.compileflow.credit;

import com.alibaba.compileflow.engine.ProcessDefinition;
import com.alibaba.compileflow.engine.ProcessEngine;
import com.alibaba.compileflow.engine.ProcessModelType;
import com.alibaba.compileflow.engine.ProcessResult;
import java.util.HashMap;
import java.util.Map;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

@SpringBootApplication
public class CreditDemoApplication {
    public static void main(String[] args) {
        SpringApplication.run(CreditDemoApplication.class, args);
    }

    @Bean
    CommandLineRunner run(ProcessEngine processEngine) {
        return args -> {
            // Java 只负责加载并执行流程定义。节点顺序和条件在 credit-approval.bpm 中。
            ProcessDefinition definition = ProcessDefinition.classpath(
                    ProcessModelType.TBBPM, "demo.credit.approval", "flows/credit-approval.bpm");

            Map<String, Object> input = new HashMap<>();
            input.put("userId", "U10086");
            input.put("amount", 20_000);
            input.put("needRisk", true);

            ProcessResult<Map<String, Object>> execution = processEngine.execute(definition, input);
            Map<String, Object> output = execution.orElseThrow();
            System.out.println("流程结束 result=" + output.get("result"));
        };
    }
}
