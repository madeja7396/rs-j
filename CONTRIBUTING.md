# Contributing

Contributions are welcome: bug reports, feature proposals, code, docs, and CI improvements.

## Community Guidelines

- Code of Conduct: `CODE_OF_CONDUCT.md`
- Security reporting: `SECURITY.md`
- Support channels: `SUPPORT.md`

## Issue Templates

- Bug report:
  `https://github.com/madeja7396/rs-j/issues/new?template=bug_report.yml`
- Feature request:
  `https://github.com/madeja7396/rs-j/issues/new?template=feature_request.yml`

## Local Development

```bash
./scripts/setup_dev_env.sh
./scripts/check_env.sh
cargo fmt --all
cargo clippy --all-targets --features deploy -- -D warnings
cargo test --lib
```

## Pull Request Flow

1. Create a branch from `main`.
2. Make changes with tests/docs updates as needed.
3. Keep commits scoped and readable (phase-oriented commits are preferred).
4. Push and open a PR to `main`.
5. Ensure CI is green (`fmt`, `clippy`, `test`).

## Upstream Context

This repository is a fork of `ClementTsang/bottom` and keeps upstream compatibility in mind.
When changing shared behavior, document it in `README.md` and `docs/roadmap.md`.
