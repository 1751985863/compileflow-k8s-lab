import http from 'k6/http';
import { check } from 'k6';

// 每秒启动 100 次结算请求，持续 5 秒，理论总量约 500 次。
export const options = {
  scenarios: {
    checkout_100_rps: {
      executor: 'constant-arrival-rate',
      rate: 1000,
      timeUnit: '1s',
      duration: '5s',
      preAllocatedVUs: 50,
      maxVUs: 200,
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<1000'],
    checks: ['rate>0.99'],
  },
};

export default function () {
  const requestId = `k6-studio-100rps-${__VU}-${__ITER}-${Date.now()}`;
  const response = http.post(
    'http://127.0.0.1:28080/api/checkout',
    JSON.stringify({ sku: 'BOOK', quantity: 1 }),
    {
      headers: {
        'Content-Type': 'application/json',
        'X-Request-Id': requestId,
      },
      tags: {
        test_name: 'checkout-100rps-5s',
      },
    },
  );

  check(response, {
    'HTTP 状态码是 200': (r) => r.status === 200,
    '支付状态是 PAID': (r) => r.json('paymentStatus') === 'PAID',
  });
}
