import http from 'k6/http';
import { check } from 'k6';

export const options = {
  scenarios: {
    checkout_100_rps: {
      executor: 'constant-arrival-rate',
      rate: 100,
      timeUnit: '1s',
      duration: '30s',
      preAllocatedVUs: 50,
      maxVUs: 200,
    },
  },
};

export default function () {
  const response = http.post(
    'http://127.0.0.1:28080/api/checkout',
    JSON.stringify({
      sku: 'BOOK',
      quantity: 1,
    }),
    {
      headers: {
        'Content-Type': 'application/json',
        'X-Request-Id': `k6-${__VU}-${__ITER}-${Date.now()}`,
      },
    },
  );

  check(response, {
    '状态码为 200': (r) => r.status === 200,
    '支付成功': (r) => r.json('paymentStatus') === 'PAID',
  });
}