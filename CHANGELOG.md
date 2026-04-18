# Changelog

## 0.1.0 — 2026-04-17

- Initial release
- Guard runner: `check` (POST /v2/guard) and `check_detailed` (POST /v2/guard/results)
- Policies runner: CRUD for security policies (Enterprise SaaS)
- Projects runner: CRUD for projects (Enterprise SaaS)
- Health runner: policy health, policy lint, k8s probes (self-hosted)
- SaaS support with regional endpoints (US, EU, Asia)
- Self-hosted support with unauthenticated access
- Standalone Client class
- Identity module for Legion credential resolution
