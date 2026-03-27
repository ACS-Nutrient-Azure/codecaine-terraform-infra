# AgentCore 커스텀 메트릭 계측 가이드

Grafana Business Overview 대시보드에 에이전트 데이터를 연결하려면 아래 메트릭을 코드에서 emit해야 합니다.
메트릭은 **boto3 → CloudWatch** 경로로 직접 전송됩니다.

> **AgentCore Runtime은 사이드카를 지원하지 않아 ADOT 대신 boto3 직접 전송 방식을 사용합니다.**
> IAM 권한(`cloudwatch:PutMetricData`)은 `agentcore/{agent}/iam.tf`에서 관리합니다.

---

## 메트릭 스키마

CloudWatch Namespace: **`CDCI/AgentCore`**

| 메트릭 이름 | 타입 | Dimensions | 설명 |
|---|---|---|---|
| `agent_invocation_total` | Counter | `agent_name`, `status` | 에이전트 호출 수 |
| `agent_token_input_total` | Counter | `agent_name`, `model_id` | 입력 토큰 수 |
| `agent_token_output_total` | Counter | `agent_name`, `model_id` | 출력 토큰 수 |
| `agent_latency_seconds` | Histogram | `agent_name` | 에이전트 응답 시간 |
| `tool_execution_total` | Counter | `agent_name`, `tool_name`, `status` | Step 실행 횟수 |
| `tool_execution_duration_seconds` | Histogram | `agent_name`, `tool_name` | Step 실행 시간 |
| `tool_approval_total` | Counter | `agent_name`, `tool_name`, `result` | Tool 승인/거절 횟수 (supervisor 패턴) |

**Dimension 값 규칙**

| Dimension | 허용 값 |
|---|---|
| `agent_name` | `analysis-agent`, `chatbot-agent`, `supervisor-agent`, `summary-agent` |
| `status` | `success`, `error` |
| `result` | `approved`, `rejected` |
| `model_id` | 실제 사용 모델 ID (예: `anthropic.claude-3-5-sonnet-20240620-v1:0`) |

---

## 설치

추가 패키지 불필요. `boto3`는 기본 포함됩니다.

---

## metrics.py

에이전트 레포에 `app/metrics.py`를 생성합니다.

```python
import logging
import boto3
from app.core.config import settings

logger = logging.getLogger(__name__)

NAMESPACE = "CDCI/AgentCore"
_cw = None


def _get_client():
    global _cw
    if _cw is None:
        _cw = boto3.client("cloudwatch", region_name=settings.AWS_REGION)
    return _cw


def _put(metric_name: str, value: float, dimensions: dict, unit: str = "Count"):
    try:
        _get_client().put_metric_data(
            Namespace=NAMESPACE,
            MetricData=[{
                "MetricName": metric_name,
                "Dimensions": [{"Name": k, "Value": v} for k, v in dimensions.items()],
                "Value": value,
                "Unit": unit,
            }]
        )
    except Exception as e:
        logger.warning(f"CloudWatch put_metric_data 실패: {e}")


class _Counter:
    def __init__(self, name: str):
        self.name = name

    def add(self, value: float, attributes: dict):
        _put(self.name, value, attributes, "Count")


class _Histogram:
    def __init__(self, name: str):
        self.name = name

    def record(self, value: float, attributes: dict):
        _put(self.name, value, attributes, "Seconds")


def init_metrics():
    """CloudWatch 클라이언트 초기화 (컨테이너 시작 시 1회 호출)"""
    _get_client()


agent_invocation_counter   = _Counter("agent_invocation_total")
agent_token_input_counter  = _Counter("agent_token_input_total")
agent_token_output_counter = _Counter("agent_token_output_total")
agent_latency_histogram    = _Histogram("agent_latency_seconds")
tool_execution_counter     = _Counter("tool_execution_total")
tool_duration_histogram    = _Histogram("tool_execution_duration_seconds")
tool_approval_counter      = _Counter("tool_approval_total")
```

---

## 계측 위치 및 코드

### 1. app/main.py — 초기화

```python
from app.metrics import init_metrics
init_metrics()

app = FastAPI(...)
```

### 2. 에이전트 진입점 (/invocations)

```python
import time
from app.metrics import agent_invocation_counter, agent_latency_histogram

AGENT_NAME = "chatbot-agent"  # 각 에이전트마다 변경

@router.post("/invocations")
async def invocations(req: ...):
    start = time.time()
    status = "success"
    try:
        return await agent.run(req)
    except ValueError as e:
        status = "error"
        raise HTTPException(status_code=422, detail=str(e))
    except Exception as e:
        status = "error"
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        agent_invocation_counter.add(1, {"agent_name": AGENT_NAME, "status": status})
        agent_latency_histogram.record(time.time() - start, {"agent_name": AGENT_NAME})
```

### 3. 내부 Step 실행 래핑

```python
import time
from app.metrics import tool_execution_counter, tool_duration_histogram

AGENT_NAME = "chatbot-agent"

def execute_step(tool_name: str, tool_fn, *args, **kwargs):
    start = time.time()
    status = "success"
    try:
        return tool_fn(*args, **kwargs)
    except Exception as e:
        status = "error"
        raise e
    finally:
        tool_execution_counter.add(1, {"agent_name": AGENT_NAME, "tool_name": tool_name, "status": status})
        tool_duration_histogram.record(time.time() - start, {"agent_name": AGENT_NAME, "tool_name": tool_name})

# 사용 예시
result = execute_step("step1_llm", self._call_llm, system=..., user=...)
result = execute_step("nutrient_calc", self._call_lambda, cognito_id=..., ...)
```

### 4. 토큰 카운터 — LLM 호출 내부

각 LLM provider별 응답 구조가 다릅니다.

```python
from app.metrics import agent_token_input_counter, agent_token_output_counter

# Bedrock (invoke_model)
body = json.loads(response["body"].read())
usage = body.get("usage", {})
agent_token_input_counter.add(usage.get("input_tokens", 0), {"agent_name": AGENT_NAME, "model_id": settings.BEDROCK_MODEL_ID})
agent_token_output_counter.add(usage.get("output_tokens", 0), {"agent_name": AGENT_NAME, "model_id": settings.BEDROCK_MODEL_ID})

# Anthropic SDK
agent_token_input_counter.add(message.usage.input_tokens, {"agent_name": AGENT_NAME, "model_id": settings.ANTHROPIC_MODEL_ID})
agent_token_output_counter.add(message.usage.output_tokens, {"agent_name": AGENT_NAME, "model_id": settings.ANTHROPIC_MODEL_ID})

# OpenAI SDK
agent_token_input_counter.add(response.usage.prompt_tokens, {"agent_name": AGENT_NAME, "model_id": settings.OPENAI_MODEL_ID})
agent_token_output_counter.add(response.usage.completion_tokens, {"agent_name": AGENT_NAME, "model_id": settings.OPENAI_MODEL_ID})
```

### 5. Tool 승인 / 거절 (supervisor 패턴)

supervisor가 sub-agent 호출을 승인/거절하는 시점에 추가합니다.

```python
from app.metrics import tool_approval_counter

def approve_tool(tool_name: str, agent_name: str):
    tool_approval_counter.add(1, {"agent_name": agent_name, "tool_name": tool_name, "result": "approved"})

def reject_tool(tool_name: str, agent_name: str):
    tool_approval_counter.add(1, {"agent_name": agent_name, "tool_name": tool_name, "result": "rejected"})
```

---

## IAM 권한

각 에이전트의 `iam.tf`에 아래 정책이 있어야 합니다.

```hcl
resource "aws_iam_role_policy" "agentcore_cloudwatch_metrics" {
  name = "cloudwatch-metrics"
  role = aws_iam_role.agentcore_runtime.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "cloudwatch:PutMetricData"
      Resource = "*"
      Condition = {
        StringEquals = {
          "cloudwatch:namespace" = "CDCI/AgentCore"
        }
      }
    }]
  })
}
```

---

## 각 에이전트별 AGENT_NAME 값

| 에이전트 | AGENT_NAME 값 |
|---|---|
| 영양소 분석 에이전트 | `analysis-agent` |
| 챗봇 에이전트 | `chatbot-agent` |
| 슈퍼바이저 에이전트 | `supervisor-agent` |
| 요약 에이전트 | `summary-agent` |

---

## CloudWatch SQL 주의사항

Grafana에서 CloudWatch Metrics Insights SQL 사용 시:

- `status`, `result` 등 예약어는 반드시 큰따옴표로 감쌉니다: `WHERE \"status\" = 'error'`
- 패널 하나에 SQL 쿼리는 **1개만** 허용됩니다. 2개 이상이면 500 에러 발생.
- 다중 dimension 메트릭은 `GROUP BY agent_name, model_id` 처럼 모든 dimension을 명시합니다.

---

## 확인 방법

코드 배포 후 약 **1~2분** 뒤 CloudWatch에서 확인:

```
CloudWatch > Metrics > 모든 메트릭 > 사용자 지정 네임스페이스 > CDCI/AgentCore
```

또는 AWS CLI:

```bash
aws cloudwatch list-metrics --namespace "CDCI/AgentCore" --region ap-northeast-2
```

메트릭이 보이면 Grafana Business Overview 대시보드에 자동으로 데이터가 표시됩니다.
