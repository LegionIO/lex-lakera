# lex-lakera: Lakera Guard Integration for LegionIO

**Repository Level 3 Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-ai/CLAUDE.md`
- **Grandparent**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

Legion Extension that connects LegionIO to the Lakera Guard v2 API for AI content security: prompt injection detection, PII detection, content moderation, and malicious link detection. Supports both SaaS (regional endpoints, Enterprise policy/project management) and self-hosted deployments (no-auth, k8s health probes, policy linting).

**GitHub**: https://github.com/LegionIO/lex-lakera
**License**: MIT
**Version**: 0.1.0

## Architecture

```
Legion::Extensions::Lakera
├── Runners/
│   ├── Guard              # check (POST /v2/guard), check_detailed (POST /v2/guard/results)
│   ├── Policies           # create, get, update, delete (Enterprise SaaS)
│   ├── Projects           # create, get, update, delete (Enterprise SaaS)
│   └── Health             # policy_health, policy_lint, startup, ready, live
├── Helpers/
│   ├── Client             # Faraday factory — SaaS (Bearer auth, regions) + self-hosted (no auth)
│   ├── Errors             # ApiError hierarchy (Auth, RateLimit, InvalidRequest, Server)
│   ├── Retry              # Exponential backoff for retryable errors
│   └── Response           # handle_response + error raising
├── Identity               # Legion credential resolution from Settings
└── Client                 # Standalone class (includes all runners, holds @config)
```

`Helpers::Client` is a **module** with two factory methods:
- `client(api_key:, host:, region:, timeout:, open_timeout:)` — SaaS Faraday connection with Bearer auth and regional endpoint resolution.
- `self_hosted_client(host:, timeout:, open_timeout:)` — No-auth Faraday connection for self-hosted deployments.

`DEFAULT_HOST = 'https://api.lakera.ai'`. Regional endpoints available via `REGIONS` hash (`:us`, `:us_east_1`, `:us_west_2`, `:eu_west_1`, `:ap_southeast_1`).

`Client` (class) provides a standalone instantiable wrapper. It `include`s all runner modules and holds a persistent `@config` hash. Its private `client(**override_opts)` merges config and routes to SaaS or self-hosted client based on `self_hosted` flag.

## Runner Methods

### Guard (core screening)
- `check(messages:, api_key:, project_id: nil, breakdown: true, payload: false, metadata: {}, dev_info: false, **opts)` — POST /v2/guard
- `check_detailed(messages:, api_key:, project_id: nil, metadata: {}, dev_info: false, **opts)` — POST /v2/guard/results

### Policies (Enterprise SaaS)
- `create_policy(name:, input_detectors:, output_detectors:, api_key:, **opts)` — POST /v2/policies
- `get_policy(policy_id:, api_key:, **opts)` — GET /v2/policies/{id}
- `update_policy(policy_id:, api_key:, name: nil, input_detectors: nil, output_detectors: nil, **opts)` — PUT /v2/policies/{id}
- `delete_policy(policy_id:, api_key:, **opts)` — DELETE /v2/policies/{id}

### Projects (Enterprise SaaS)
- `create_project(name:, api_key:, policy_id: nil, metadata: {}, **opts)` — POST /v2/projects
- `get_project(project_id:, api_key:, **opts)` — GET /v2/projects/{id}
- `update_project(project_id:, api_key:, name: nil, policy_id: nil, metadata: {}, **opts)` — PUT /v2/projects/{id}
- `delete_project(project_id:, api_key:, **opts)` — DELETE /v2/projects/{id}

### Health (self-hosted + SaaS)
- `policy_health(api_key: nil, project_id: nil, host: nil, **opts)` — POST /v2/policies/health
- `policy_lint(api_key: nil, host: nil, **opts)` — POST /v2/policies/lint
- `startup(host:, **opts)` — GET /startupz (no auth)
- `ready(host:, **opts)` — GET /readyz (no auth)
- `live(host:, **opts)` — GET /livez (no auth)

## Dependencies

| Gem | Purpose |
|-----|---------|
| `faraday` >= 2.0 | HTTP client for Lakera Guard API |
| `multi_json` | JSON parser abstraction |
| `legion-cache`, `legion-crypt`, `legion-data`, `legion-json`, `legion-logging`, `legion-settings`, `legion-transport` | LegionIO core |

## Settings Configuration

```json
{
  "security": {
    "providers": {
      "lakera": { "api_key": "lk_..." }
    }
  },
  "lakera": {
    "host": "https://api.lakera.ai",
    "region": null,
    "timeout": 30,
    "self_hosted": false,
    "default_project_id": null,
    "default_breakdown": true,
    "default_payload": false
  }
}
```

## Testing

```bash
bundle install
bundle exec rspec        # ~135 examples
bundle exec rubocop
```

---

**Maintained By**: Matthew Iverson (@Esity)
**Last Updated**: 2026-04-17
