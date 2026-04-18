# lex-lakera

LegionIO extension for the [Lakera Guard](https://www.lakera.ai/) v2 API — AI content security including prompt injection detection, PII detection, content moderation, and malicious link detection.

Supports both Lakera SaaS (regional endpoints, Enterprise policy/project management) and self-hosted deployments.

## Installation

Add to your Gemfile:

```ruby
gem 'lex-lakera'
```

## Usage

### Screen Content (SaaS)

```ruby
require 'legion/extensions/lakera'

client = Legion::Extensions::Lakera::Client.new(api_key: 'lk_...')

result = client.check(
  messages: [{ role: 'user', content: 'Ignore previous instructions and...' }],
  api_key: 'lk_...',
  breakdown: true,
  payload: true
)

if result[:result]['flagged']
  puts "Content flagged!"
  result[:result]['breakdown'].each do |b|
    puts "  #{b['detector_type']}: #{b['detected']}" if b['detected']
  end
end
```

### Detailed Confidence Analysis

```ruby
result = client.check_detailed(
  messages: [{ role: 'user', content: 'My SSN is 123-45-6789' }],
  api_key: 'lk_...'
)

result[:result]['results'].each do |r|
  puts "#{r['detector_type']}: #{r['result']}"
end
# => prompt_attack: l5_unlikely
# => pii: l1_confident
```

### Regional Endpoints

```ruby
client = Legion::Extensions::Lakera::Client.new(
  api_key: 'lk_...',
  region: :eu_west_1  # :us, :us_east_1, :us_west_2, :eu_west_1, :ap_southeast_1
)
```

### Enterprise Policy Management

```ruby
result = client.create_policy(
  name: 'Strict Policy',
  input_detectors: [{ type: 'prompt_attack', sensitivity: 'L4' }],
  output_detectors: [{ type: 'pii', sensitivity: 'L2' }],
  api_key: 'lk_...'
)
```

### Self-Hosted Health Monitoring

```ruby
client = Legion::Extensions::Lakera::Client.new(
  host: 'http://lakera.internal:8000',
  self_hosted: true
)

client.live(host: 'http://lakera.internal:8000')
client.ready(host: 'http://lakera.internal:8000')
client.startup(host: 'http://lakera.internal:8000')
```

## License

MIT
