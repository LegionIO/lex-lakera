# lex-lakera Design Document

**Date**: 2026-04-17
**Author**: Matt Iverson
**Status**: Draft

## Problem Statement

LegionIO lacks integration with Lakera Guard, an AI content security platform that detects prompt injection attacks, PII leakage, content policy violations, and malicious links. As LegionIO routes LLM requests through `legion-llm` and various provider extensions (lex-claude, lex-bedrock, lex-openai), there is no centralized guardrail layer to screen inputs/outputs before they reach providers or users.

Lakera Guard provides a real-time screening API that can be inserted into the LLM pipeline to flag dangerous content. The extension should support both Lakera's SaaS platform and self-hosted deployments.

## Proposed Solution

Build `lex-lakera`, a LEX extension following the established `lex-claude` pattern, wrapping the Lakera Guard v2 API. The extension provides:

1. **Guard screening** — real-time content screening via `POST /v2/guard`
2. **Detailed results** — per-detector confidence analysis via `POST /v2/guard/results`
3. **Policy management** — CRUD for security policies (Enterprise SaaS)
4. **Project management** — CRUD for projects (Enterprise SaaS)
5. **Self-hosted operations** — policy health checks, linting, and k8s probes

### Lakera Guard v2 API Surface

#### POST /v2/guard — Screen Content

**Request (GuardRequest):**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `messages` | `Array<Message>` | Yes | OpenAI chat format messages |
| `project_id` | `String` | No | Policy selector; uses default if omitted |
| `breakdown` | `Boolean` | No | Include per-detector flagging details |
| `payload` | `Boolean` | No | Include PII/profanity match locations |
| `metadata` | `GuardRequestMetadata` | No | Request context |
| `dev_info` | `Boolean` | No | Include build info in response |

**Message object:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `content` | `String` or `Array<ContentPart>` | Yes | Message text |
| `role` | `String` (enum) | Yes | `system`, `user`, `assistant`, `tool`, `developer` |
| `tool_calls` | `Array<ToolCall>` | No | For assistant messages |

**ContentPart object:**

| Field | Type | Description |
|-------|------|-------------|
| `type` | `String` | Always `"text"` |
| `text` | `String` | Content text |

**GuardRequestMetadata object:**

| Field | Type | Description |
|-------|------|-------------|
| `user_id` | `String` | End user identifier |
| `session_id` | `String` | Conversation identifier |
| `ip_address` | `String` (IPv4) | User's IP address |
| `internal_request_id` | `String` | Correlation identifier |

**Response (GuardResponse):**

| Field | Type | Condition | Description |
|-------|------|-----------|-------------|
| `flagged` | `Boolean` | Always | Whether content was flagged |
| `breakdown` | `Array<BreakdownItem>` | When `breakdown: true` | Per-detector results |
| `payload` | `Array<PayloadItem>` | When `payload: true` | Match locations |
| `metadata` | `GuardResponseMetadata` | Always | Contains `request_uuid` |
| `dev_info` | `DevInfo` | When `dev_info: true` | Build information |

**BreakdownItem:**

| Field | Type | Description |
|-------|------|-------------|
| `project_id` | `String` | Project identifier |
| `policy_id` | `String` | Policy identifier |
| `detector_id` | `String` | Detector identifier |
| `detector_type` | `String` | `prompt_attack`, `moderated_content`, `pii`, `unknown_links` |
| `detected` | `Boolean` | Whether this detector flagged |
| `message_id` | `Integer` | Index into request messages array |

**PayloadItem:**

| Field | Type | Description |
|-------|------|-------------|
| `start` | `Integer` | Match start position in text |
| `end` | `Integer` | Match end position in text |
| `text` | `String` | The matched text |
| `detector_type` | `String` | Detection category |
| `labels` | `Array<String>` | Classification labels |
| `message_id` | `Integer` | Message index |

#### POST /v2/guard/results — Detailed Results

Same request schema as `/v2/guard`. Does not log requests or create audit trails.

**Response (DetailedResults):**

| Field | Type | Description |
|-------|------|-------------|
| `results` | `Array<DetailedResultItem>` | Per-detector confidence results |

**DetailedResultItem:**

| Field | Type | Description |
|-------|------|-------------|
| `project_id` | `String` | Project identifier |
| `policy_id` | `String` | Policy identifier |
| `detector_id` | `String` | Detector identifier |
| `detector_type` | `String` | Detection category |
| `result` | `String` (enum) | Confidence level |
| `custom_matched` | `Boolean` | Whether custom rules matched |
| `message_id` | `Integer` | Message index |

**Confidence levels:** `l1_confident` > `l2_very_likely` > `l3_likely` > `l4_less_likely` > `l5_unlikely` > `no_level`

#### Policy Management (Enterprise SaaS — Platform API)

| Operation | Method | Path |
|-----------|--------|------|
| Create | POST | `/v2/policies` |
| Get | GET | `/v2/policies/{policy_id}` |
| Update | PUT | `/v2/policies/{policy_id}` |
| Delete | DELETE | `/v2/policies/{policy_id}` |

Policies define detector configurations with input_detectors and output_detectors arrays. Each detector has a type and sensitivity level (L1–L4).

**Detector types:** `prompt_attack`, `moderated_content`, `pii`, `unknown_links`

**Sensitivity levels:**
- L1 (Lenient) — minimal false positives
- L2 (Balanced) — moderate
- L3 (Stricter) — higher false positives, fewer false negatives
- L4 (Paranoid) — maximum coverage (default)

#### Project Management (Enterprise SaaS — Platform API)

| Operation | Method | Path |
|-----------|--------|------|
| Create | POST | `/v2/projects` |
| Get | GET | `/v2/projects/{project_id}` |
| Update | PUT | `/v2/projects/{project_id}` |
| Delete | DELETE | `/v2/projects/{project_id}` |

Projects link to policies and carry metadata tags (Application, Model, custom). Changing tags retroactively affects historical log display.

#### Self-Hosted Endpoints

**Policy Health Check:**

`POST /v2/policies/health`

| Request Field | Type | Required | Description |
|---------------|------|----------|-------------|
| `project_id` | `String` | No | Project to check; uses default if omitted |

| Response Field | Type | Description |
|----------------|------|-------------|
| `status` | `String` (enum) | `ok` or `error` |
| `is_default` | `Boolean` | Whether using default policy |
| `message` | `String` or `null` | Human-readable status |
| `lint` | `LintResult` | Validation details |

**LintResult:**

| Field | Type | Description |
|-------|------|-------------|
| `passed` | `Boolean` | Whether validation passed |
| `errors` | `Array<LintError>` | Issues found |

**LintError:**

| Field | Type | Description |
|-------|------|-------------|
| `message` | `String` | Error description |
| `severity` | `String` (enum) | `error` or `warning` |

**Policy Linter:**

`POST /v2/policies/lint`

Returns `PolicyLintResponse` with `passed` (Boolean) and `errors` (Array<LintError>).

**Kubernetes Probes (GET, port 8000, no auth):**

| Endpoint | Purpose | Recommended Config |
|----------|---------|-------------------|
| `/startupz` | Startup probe | periodSeconds: 10, failureThreshold: 30 |
| `/readyz` | Readiness probe | periodSeconds: 5, failureThreshold: 1 |
| `/livez` | Liveness probe | periodSeconds: 5, failureThreshold: 3 |

#### Regional Endpoints

| Region | URL |
|--------|-----|
| US (multi-region) | `https://us.api.lakera.ai` |
| US East (N. Virginia) | `https://us-east-1.api.lakera.ai` |
| US West (Oregon) | `https://us-west-2.api.lakera.ai` |
| EU (Ireland) | `https://eu-west-1.api.lakera.ai` |
| Asia (Singapore) | `https://ap-southeast-1.api.lakera.ai` |
| Default | `https://api.lakera.ai` |

Users are responsible for choosing the correct regional endpoint.

### Extension Architecture

```
Legion::Extensions::Lakera
├── Runners/
│   ├── Guard              # check, check_detailed (guard + guard/results)
│   ├── Policies           # create, get, update, delete (Enterprise SaaS)
│   ├── Projects           # create, get, update, delete (Enterprise SaaS)
│   └── Health             # policy_health, policy_lint, startup, ready, live (self-hosted)
├── Helpers/
│   ├── Client             # Faraday HTTP client factory (SaaS + self-hosted modes)
│   ├── Errors             # ApiError hierarchy with status/type mapping
│   ├── Retry              # Exponential backoff for retryable errors
│   └── Response           # Response normalization + payload parsing
├── Identity               # Legion credential resolution (Settings → api_key)
└── Client                 # Standalone client class (includes all runners, holds @config)
```

### Runner Method Signatures

#### Guard Runner

```ruby
module Legion::Extensions::Lakera::Runners::Guard
  extend Legion::Extensions::Lakera::Helpers::Client

  # Screen content via POST /v2/guard
  def check(messages:, api_key:, project_id: nil, breakdown: true,
            payload: false, metadata: {}, dev_info: false, **opts)
    # Returns: { result: { flagged:, breakdown:, payload:, metadata: }, status: 200 }
  end

  # Detailed per-detector confidence via POST /v2/guard/results
  def check_detailed(messages:, api_key:, project_id: nil,
                     metadata: {}, dev_info: false, **opts)
    # Returns: { result: { results: [{ detector_type:, result:, ... }] }, status: 200 }
  end
end
```

#### Policies Runner

```ruby
module Legion::Extensions::Lakera::Runners::Policies
  extend Legion::Extensions::Lakera::Helpers::Client

  def create_policy(name:, input_detectors:, output_detectors:, api_key:, **opts)
  def get_policy(policy_id:, api_key:, **opts)
  def update_policy(policy_id:, name: nil, input_detectors: nil,
                    output_detectors: nil, api_key:, **opts)
  def delete_policy(policy_id:, api_key:, **opts)
end
```

#### Projects Runner

```ruby
module Legion::Extensions::Lakera::Runners::Projects
  extend Legion::Extensions::Lakera::Helpers::Client

  def create_project(name:, policy_id: nil, metadata: {}, api_key:, **opts)
  def get_project(project_id:, api_key:, **opts)
  def update_project(project_id:, name: nil, policy_id: nil,
                     metadata: {}, api_key:, **opts)
  def delete_project(project_id:, api_key:, **opts)
end
```

#### Health Runner

```ruby
module Legion::Extensions::Lakera::Runners::Health
  extend Legion::Extensions::Lakera::Helpers::Client

  # POST /v2/policies/health
  def policy_health(project_id: nil, api_key: nil, **opts)
    # Returns: { result: { status:, is_default:, message:, lint: }, status: 200 }
  end

  # POST /v2/policies/lint
  def policy_lint(api_key: nil, **opts)
    # Returns: { result: { passed:, errors: }, status: 200 }
  end

  # GET /startupz — self-hosted only, no auth
  def startup(**opts)

  # GET /readyz — self-hosted only, no auth
  def ready(**opts)

  # GET /livez — self-hosted only, no auth
  def live(**opts)
end
```

### Client Helper — SaaS vs Self-Hosted

```ruby
module Legion::Extensions::Lakera::Helpers::Client
  DEFAULT_HOST = 'https://api.lakera.ai'

  REGIONS = {
    us:             'https://us.api.lakera.ai',
    us_east_1:      'https://us-east-1.api.lakera.ai',
    us_west_2:      'https://us-west-2.api.lakera.ai',
    eu_west_1:      'https://eu-west-1.api.lakera.ai',
    ap_southeast_1: 'https://ap-southeast-1.api.lakera.ai'
  }.freeze

  module_function

  # SaaS client — requires api_key, supports region selection
  def client(api_key:, host: DEFAULT_HOST, region: nil, timeout: 30,
             open_timeout: 10, **_opts)
    resolved_host = region ? REGIONS.fetch(region, host) : host

    Faraday.new(url: resolved_host) do |conn|
      conn.request :json
      conn.response :json, content_type: /\bjson$/
      conn.headers['Authorization'] = "Bearer #{api_key}"
      conn.headers['Content-Type']  = 'application/json'
      conn.options.timeout      = timeout
      conn.options.open_timeout = open_timeout
    end
  end

  # Self-hosted client — no auth, custom host required
  def self_hosted_client(host:, timeout: 30, open_timeout: 10, **_opts)
    Faraday.new(url: host) do |conn|
      conn.request :json
      conn.response :json, content_type: /\bjson$/
      conn.headers['Content-Type'] = 'application/json'
      conn.options.timeout      = timeout
      conn.options.open_timeout = open_timeout
    end
  end
end
```

### Error Hierarchy

```ruby
module Legion::Extensions::Lakera::Helpers::Errors
  class ApiError < StandardError
    attr_reader :status, :error_type, :body
  end

  class AuthenticationError  < ApiError; end  # 401
  class RateLimitError       < ApiError; end  # 429
  class InvalidRequestError  < ApiError; end  # 400
  class ServerError          < ApiError; end  # 500+

  STATUS_MAP = {
    400 => InvalidRequestError,
    401 => AuthenticationError,
    429 => RateLimitError
  }.freeze

  RETRYABLE = [RateLimitError, ServerError].freeze
end
```

### Audit Exchange Integration

Guard results should be publishable to the LegionIO audit exchange via `additional_e_to_q` for compliance logging:

```ruby
# When check() returns flagged: true
{
  exchange: 'llm.audit',
  routing_key: 'lakera.guard.flagged',
  payload: {
    request_uuid: response[:result][:metadata][:request_uuid],
    flagged: true,
    detector_types: breakdown.select { |b| b[:detected] }.map { |b| b[:detector_type] },
    timestamp: Time.now.iso8601
  }
}
```

### Settings Configuration

```json
{
  "security": {
    "providers": {
      "lakera": {
        "api_key": "lk_..."
      }
    }
  },
  "lakera": {
    "host": "https://api.lakera.ai",
    "region": null,
    "timeout": 30,
    "open_timeout": 10,
    "self_hosted": false,
    "default_project_id": null,
    "default_breakdown": true,
    "default_payload": false
  }
}
```

## Alternatives Considered

1. **Direct HTTP calls in legion-llm** — Rejected. Lakera is a standalone security service, not an LLM provider. A dedicated extension keeps concerns separated and allows independent versioning.

2. **Middleware/interceptor pattern in legion-llm** — Considered for automatic screening of all LLM traffic. Deferred to a future legion-llm enhancement that could optionally invoke lex-lakera. The extension itself should be usable standalone.

3. **Only SaaS support** — Rejected per user requirement. Self-hosted deployments are common in enterprise environments with data residency requirements.

## Constraints and Trade-offs

- **No streaming** — Lakera Guard v2 does not support SSE/streaming responses. All calls are synchronous request/response.
- **Policy/Project CRUD requires Enterprise SaaS** — These endpoints are not available on self-hosted deployments. The runners should work but will return appropriate errors from the API.
- **K8s probes are unauthenticated GET requests** — The Health runner must support calls without an API key for self-hosted probe checks.
- **Regional endpoint responsibility** — Lakera does not auto-route. The extension surfaces region selection but the caller must choose correctly.
- **Rate limiting** — Lakera returns 429 on rate limit. The retry helper handles this with exponential backoff, matching the lex-claude pattern.
