import { check } from "k6";
import { Writer } from "k6/x/kafka";

const brokers = ["my-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"];
const topic = "my-topic";

const writer = new Writer({
  brokers: brokers,
  topic: topic,
});

export const options = {
  vus: 10,
  duration: '30s',
};

function stringToBytes(str) {
  const bytes = [];
  for (let i = 0; i < str.length; i++) {
    bytes.push(str.charCodeAt(i));
  }
  return bytes;
}

// 100KB 크기의 페이로드 생성 (약 102,400 bytes)
function generate100KBPayload(vu, iter, timestamp) {
  const header = `VU${vu} iter${iter} ts${timestamp} `;
  const targetSize = 102400; // 100KB
  
  // 반복할 데이터 패턴 (더 현실적인 JSON 형태)
  const dataPattern = JSON.stringify({
    user_id: Math.floor(Math.random() * 10000),
    event_type: "user_action",
    metadata: {
      browser: "Chrome",
      os: "Linux",
      version: "1.0.0"
    },
    payload: "x".repeat(100) // 100자 더미 데이터
  });
  
  // 목표 크기에 도달할 때까지 반복
  let payload = header;
  while (payload.length < targetSize) {
    payload += dataPattern;
  }
  
  // 정확히 100KB로 자르기
  return payload.substring(0, targetSize);
}

export default function () {
  const message = generate100KBPayload(__VU, __ITER, Date.now());
  
  const messages = [{
    value: stringToBytes(message),
  }];

  const error = writer.produce({ messages: messages });
  check(error, {
    "is sent": (err) => err == undefined,
  });
}

export function teardown(data) {
  writer.close();
}