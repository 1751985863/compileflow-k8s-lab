package com.example.compileflow.credit;

import org.springframework.stereotype.Service;

/** 流程节点调用的真实业务能力。这里仍然只专注各自的业务。 */
@Service("creditOperations")
public class CreditOperations {
    public void validateUser(String userId) {
        if (userId == null || userId.trim().isEmpty()) {
            throw new IllegalArgumentException("用户不存在");
        }
        System.out.println("业务节点 用户校验通过 userId=" + userId);
    }

    public void pushRisk(String userId, Integer amount) {
        System.out.println("业务节点 推送风控 userId=" + userId + ", amount=" + amount);
    }

    public void signContract(String userId, Integer amount) {
        System.out.println("业务节点 签订合同 userId=" + userId + ", amount=" + amount);
    }
}
