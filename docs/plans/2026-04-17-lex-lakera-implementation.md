# lex-lakera Implementation Plan

**Date**: 2026-04-17
**Design Doc**: `docs/plans/2026-04-17-lex-lakera-design.md`

## Phase 1: Gem Scaffold & Core Infrastructure

### 1.1 Create gem skeleton

**Files to create:**

| File | Purpose |
|------|---------|
| `lex-lakera.gemspec` | Gem specification with dependencies |
| `Gemfile` | `gemspec` + dev dependencies |
| `.rspec` | `--format documentation --color --require spec_helper` |
| `LICENSE` | MIT license |
| `README.md` | Basic usage and setup |
| `CHANGELOG.md` | Initial entry |
| `CLAUDE.md` | Extension-specific Claude Code docs |
| `lib/legion/extensions/lakera/version.rb` | `VERSION = '0.1.0'` |

**Gemspec dependencies:**
```ruby
spec.add_dependency 'faraday', '>= 2.0'
spec.add_dependency 'legion-cache', '>= 1.3.11'
spec.add_dependency 'legion-crypt', '>= 1.4.9'
spec.add_dependency 'legion-data', '>= 1.4.17'
spec.add_dependency 'legion-json', '>= 1.2.1'
spec.add_dependency 'legion-logging', '>= 1.3.2'
spec.add_dependency 'legion-settings', '>= 1.3.14'
spec.add_dependency 'legion-transport', '>= 1.3.9'
spec.add_dependency 'multi_json'
```

### 1.2 Create helpers

**Files to create:**

| File | Purpose |
|------|---------|
| `lib/legion/extensions/lakera/helpers/client.rb` | Faraday client factory (SaaS + self-hosted) |
| `lib/legion/extensions/lakera/helpers/errors.rb` | Error hierarchy + `from_response` + `retryable?` |
| `lib/legion/extensions/lakera/helpers/retry.rb` | `with_retry` with exponential backoff |
| `lib/legion/extensions/lakera/helpers/response.rb` | `handle_response` + guard-specific parsers |

**`helpers/client.rb` specifics:**
- `DEFAULT_HOST = 'https://api.lakera.ai'`
- `REGIONS` hash mapping symbols to regional endpoint URLs
- `client(api_key:, host:, region:, timeout:, open_timeout:)` — SaaS Faraday connection with Bearer auth
- `self_hosted_client(host:, timeout:, open_timeout:)` — No-auth Faraday connection
- `module_function` for both methods

**`helpers/errors.rb` specifics:**
- `ApiError` base class with `status`, `error_type`, `body` attrs
- Subclasses: `AuthenticationError`, `RateLimitError`, `InvalidRequestError`, `ServerError`
- `STATUS_MAP`: 400 → InvalidRequestError, 401 → AuthenticationError, 429 → RateLimitError
- `RETRYABLE = [RateLimitError, ServerError]`
- `from_response(status:, body:)` — builds typed exception
- `retryable?(error)` — checks RETRYABLE membership

**`helpers/retry.rb` specifics:**
- Match lex-claude pattern exactly
- `DEFAULT_MAX_ATTEMPTS = 3`, `DEFAULT_BASE_DELAY = 1.0`, `DEFAULT_MAX_DELAY = 60.0`
- `with_retry` yields block, catches retryable errors, applies backoff

**`helpers/response.rb` specifics:**
- `handle_response(response)` — raise on non-2xx, return `{ result:, status: }`
- `parse_guard_result(body)` — extract `flagged`, `breakdown`, `payload`, `metadata`
- `parse_detailed_results(body)` — extract `results` array with confidence levels

### 1.3 Create identity module

**File:** `lib/legion/extensions/lakera/identity.rb`

- `provider_name = :lakera`
- `provider_type = :credential`
- `provide_token` — builds `Legion::Identity::Lease` from resolved API key
- `resolve_api_key` — reads from `Legion::Settings.dig(:security, :providers, :lakera, :api_key)`

### 1.4 Create spec helper

**File:** `spec/spec_helper.rb`

- Load `bundler/setup`, all `legion-*` helpers
- Define `Legion::Extensions::Helpers::Lex` module with all mixins
- Require `webmock/rspec` for HTTP stubbing
- Require `legion/extensions/lakera`
- Configure RSpec: persistence file, no monkey patching, expect syntax

**Spec expectations for Phase 1:**
- `spec/legion/extensions/lakera/helpers/client_spec.rb` — verify SaaS and self-hosted client creation, region resolution, header configuration, timeout settings
- `spec/legion/extensions/lakera/helpers/errors_spec.rb` — verify `from_response` mapping, `retryable?` classification, error hierarchy
- `spec/legion/extensions/lakera/helpers/retry_spec.rb` — verify retry behavior, backoff calculation, max attempts
- `spec/legion/extensions/lakera/helpers/response_spec.rb` — verify response handling, error raising, guard result parsing
- `spec/legion/extensions/lakera/identity_spec.rb` — verify credential resolution

---

## Phase 2: Guard Runner (Core Screening)

### 2.1 Guard runner

**File:** `lib/legion/extensions/lakera/runners/guard.rb`

**Methods:**

`check(messages:, api_key:, project_id: nil, breakdown: true, payload: false, metadata: {}, dev_info: false, **opts)`
- Build request body from params
- POST to `/v2/guard` via `client(api_key:, **opts)`
- Handle response via `Helpers::Response.handle_response`
- Parse guard-specific fields
- Return `{ result: { flagged:, breakdown:, payload:, metadata: { request_uuid: } }, status: 200 }`

`check_detailed(messages:, api_key:, project_id: nil, metadata: {}, dev_info: false, **opts)`
- Build request body (same format as check, minus breakdown/payload)
- POST to `/v2/guard/results`
- Return `{ result: { results: [{ detector_type:, result:, ... }] }, status: 200 }`

**Spec expectations:**
- `spec/legion/extensions/lakera/runners/guard_spec.rb`
- WebMock stubs for `/v2/guard` and `/v2/guard/results`
- Test `check` with breakdown + payload enabled/disabled
- Test `check_detailed` with all confidence levels
- Test `check` with `project_id` and `metadata`
- Test error handling (401, 429, 500)
- Test with multi-message conversations (system + user + assistant)
- Test with ContentPart array format
- Test with tool_calls in assistant messages

---

## Phase 3: Policy & Project Runners (Enterprise SaaS)

### 3.1 Policies runner

**File:** `lib/legion/extensions/lakera/runners/policies.rb`

**Methods:**

| Method | HTTP | Path | Key Params |
|--------|------|------|------------|
| `create_policy` | POST | `/v2/policies` | `name:`, `input_detectors:`, `output_detectors:` |
| `get_policy` | GET | `/v2/policies/{policy_id}` | `policy_id:` |
| `update_policy` | PUT | `/v2/policies/{policy_id}` | `policy_id:`, `name:`, `input_detectors:`, `output_detectors:` |
| `delete_policy` | DELETE | `/v2/policies/{policy_id}` | `policy_id:` |

**Spec:** `spec/legion/extensions/lakera/runners/policies_spec.rb`
- WebMock stubs for all CRUD operations
- Test create with detector configuration
- Test update with partial fields
- Test delete returns success
- Test 401/404 error handling

### 3.2 Projects runner

**File:** `lib/legion/extensions/lakera/runners/projects.rb`

**Methods:**

| Method | HTTP | Path | Key Params |
|--------|------|------|------------|
| `create_project` | POST | `/v2/projects` | `name:`, `policy_id:`, `metadata:` |
| `get_project` | GET | `/v2/projects/{project_id}` | `project_id:` |
| `update_project` | PUT | `/v2/projects/{project_id}` | `project_id:`, `name:`, `policy_id:`, `metadata:` |
| `delete_project` | DELETE | `/v2/projects/{project_id}` | `project_id:` |

**Spec:** `spec/legion/extensions/lakera/runners/projects_spec.rb`
- WebMock stubs for all CRUD operations
- Test create with and without policy_id
- Test metadata tag handling
- Test 401/404 error handling

---

## Phase 4: Health Runner (Self-Hosted)

### 4.1 Health runner

**File:** `lib/legion/extensions/lakera/runners/health.rb`

**Methods:**

| Method | HTTP | Path | Auth | Key Params |
|--------|------|------|------|------------|
| `policy_health` | POST | `/v2/policies/health` | Bearer (optional) | `project_id:` |
| `policy_lint` | POST | `/v2/policies/lint` | Bearer (optional) | — |
| `startup` | GET | `/startupz` | None | — |
| `ready` | GET | `/readyz` | None | — |
| `live` | GET | `/livez` | None | — |

K8s probe methods use `self_hosted_client(host:)` — no Bearer token. The `host:` parameter is required for these methods (no default SaaS host).

`policy_health` and `policy_lint` work on both SaaS and self-hosted. When `api_key:` is provided, use authenticated client. When `nil`, use self-hosted client.

**Spec:** `spec/legion/extensions/lakera/runners/health_spec.rb`
- WebMock stubs for all health endpoints
- Test policy_health with SaaS (authenticated) and self-hosted (unauthenticated)
- Test policy_lint response parsing (passed/errors)
- Test k8s probes return status
- Test k8s probes don't send auth headers

---

## Phase 5: Client Class & Entry Point

### 5.1 Client class

**File:** `lib/legion/extensions/lakera/client.rb`

```ruby
class Client
  include Runners::Guard
  include Runners::Policies
  include Runners::Projects
  include Runners::Health

  attr_reader :config

  def initialize(api_key: nil, host: Helpers::Client::DEFAULT_HOST,
                 region: nil, self_hosted: false, **opts)
    @config = { api_key: api_key, host: host, region: region,
                self_hosted: self_hosted, **opts }
  end

  private

  def client(**override_opts)
    merged = config.merge(override_opts)
    if merged[:self_hosted] && !merged[:api_key]
      Helpers::Client.self_hosted_client(**merged.except(:api_key, :self_hosted, :region))
    else
      Helpers::Client.client(**merged.except(:self_hosted))
    end
  end
end
```

**Spec:** `spec/legion/extensions/lakera/client_spec.rb`
- Test SaaS initialization with api_key
- Test self-hosted initialization without api_key
- Test region selection
- Test that all runner methods are available
- Test client delegation to Helpers::Client

### 5.2 Main entry point

**File:** `lib/legion/extensions/lakera.rb`

```ruby
require 'legion/extensions/lakera/version'
require 'legion/extensions/lakera/helpers/client'
require 'legion/extensions/lakera/helpers/errors'
require 'legion/extensions/lakera/helpers/retry'
require 'legion/extensions/lakera/helpers/response'
require 'legion/extensions/lakera/runners/guard'
require 'legion/extensions/lakera/runners/policies'
require 'legion/extensions/lakera/runners/projects'
require 'legion/extensions/lakera/runners/health'
require 'legion/extensions/lakera/client'
require 'legion/extensions/lakera/identity'

module Legion
  module Extensions
    module Lakera
      extend Legion::Extensions::Core if Legion::Extensions.const_defined? :Core, false
    end
  end
end
```

**Spec:** `spec/legion/extensions/lakera/lakera_spec.rb`
- Test module loads without error
- Test VERSION constant
- Test Client class is accessible

---

## Phase 6: Documentation

### 6.1 CLAUDE.md

**File:** `CLAUDE.md`

Document:
- Architecture diagram
- Runner methods and signatures
- Helpers overview
- Dependencies table
- SaaS vs self-hosted usage
- Testing commands
- Settings configuration

### 6.2 README.md

Basic usage examples:
- SaaS quick start (check content)
- Self-hosted health monitoring
- Enterprise policy management
- Standalone Client class usage

---

## Complete File Listing

```
lex-lakera/
├── lex-lakera.gemspec
├── Gemfile
├── .rspec
├── LICENSE
├── README.md
├── CHANGELOG.md
├── CLAUDE.md
├── docs/
│   └── plans/
│       ├── 2026-04-17-lex-lakera-design.md
│       └── 2026-04-17-lex-lakera-implementation.md
├── lib/
│   └── legion/
│       └── extensions/
│           ├── lakera.rb
│           └── lakera/
│               ├── version.rb
│               ├── client.rb
│               ├── identity.rb
│               ├── helpers/
│               │   ├── client.rb
│               │   ├── errors.rb
│               │   ├── retry.rb
│               │   └── response.rb
│               └── runners/
│                   ├── guard.rb
│                   ├── policies.rb
│                   ├── projects.rb
│                   └── health.rb
└── spec/
    ├── spec_helper.rb
    └── legion/
        └── extensions/
            └── lakera/
                ├── lakera_spec.rb
                ├── client_spec.rb
                ├── identity_spec.rb
                ├── helpers/
                │   ├── client_spec.rb
                │   ├── errors_spec.rb
                │   ├── retry_spec.rb
                │   └── response_spec.rb
                └── runners/
                    ├── guard_spec.rb
                    ├── policies_spec.rb
                    ├── projects_spec.rb
                    └── health_spec.rb
```

**Total files:** 30 (14 lib, 12 spec, 4 config/docs)

## Spec Coverage Expectations

| Area | Estimated Examples |
|------|-------------------|
| Helpers::Client | ~10 (SaaS client, self-hosted client, regions, timeouts, headers) |
| Helpers::Errors | ~10 (from_response mapping, retryable?, hierarchy, edge cases) |
| Helpers::Retry | ~6 (retry on retryable, raise on non-retryable, max attempts, backoff) |
| Helpers::Response | ~8 (handle success, handle errors, parse guard, parse detailed) |
| Identity | ~5 (resolve api_key, provide_token, nil cases) |
| Runners::Guard | ~15 (check variations, check_detailed, errors, message formats) |
| Runners::Policies | ~10 (CRUD + error cases) |
| Runners::Projects | ~10 (CRUD + error cases) |
| Runners::Health | ~12 (policy_health SaaS/self-hosted, lint, 3 k8s probes, auth behavior) |
| Client | ~8 (init modes, delegation, runner availability) |
| Module | ~3 (loads, version, constants) |
| **Total** | **~97 examples** |

## Dependencies & Ordering

- Phase 1 has no external dependencies (pure gem scaffold + helpers)
- Phase 2 depends on Phase 1 (Guard runner uses all helpers)
- Phases 3 and 4 depend on Phase 1 only (can be done in parallel)
- Phase 5 depends on Phases 2–4 (Client includes all runners)
- Phase 6 depends on Phase 5 (documents final API)

```
Phase 1 (scaffold) ─┬─> Phase 2 (guard) ──────┐
                     ├─> Phase 3 (policies)  ───┼─> Phase 5 (client) ─> Phase 6 (docs)
                     └─> Phase 4 (health)    ───┘
```
