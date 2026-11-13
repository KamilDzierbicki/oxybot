# Contributing to OxyBot

Thanks for helping. OxyBot is a Rails app, so most changes are a model method, a view and a test.

## Setup

```bash
bundle install
docker compose up -d db
bin/rails db:prepare db:seed
bin/dev            # http://localhost:3120, mock model, no API keys needed
```

## Before you open a pull request

```bash
bin/rails test
bin/rubocop
bin/brakeman
```

All three must pass. Tests run offline: model calls go to the built-in mock model (`lib/mock_llm.rb`) and every
external API is stubbed with WebMock.

## How the code is organized

- Follow Rails conventions: put behaviour on models and concerns, keep controllers thin, use plain Ruby objects next
  to their model for larger operations. No service objects.
- Every query starts from the current account. A change that can leak data between accounts is a security bug.
- Treat model output as user input: validate it in code before saving or acting on it.
- A new chat platform is an adapter that includes `Integration::Chat` and maps its events to `receive_message`.
- A new document kind is a template in `config/document_templates`, a `*_sections` method in `Document::Brief` and a
  name in `Document::KINDS`.
- Prompts live in `config/prompts` in Langfuse's text format (`{{variable}}`).

## Commit messages

Use `<type>: <summary>`, where type is one of `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `style`, `perf`, `ci`.
