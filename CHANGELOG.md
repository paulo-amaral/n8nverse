# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project now follows Semantic Versioning for public releases.

## [Unreleased]

## [0.1.0] - 2026-03-26

### Added
- Docker Compose setup for running n8n locally with Caddy and external PostgreSQL
- Local Caddy TLS setup for `https://n8n.localhost`
- Security guardrails for git, CI, and example environment handling
- PostgreSQL bootstrap script for Postgres.app users on macOS
- Optional Kubernetes manifests for a minimal external-PostgreSQL deployment
- README walkthrough and local sign-in screenshot

### Changed
- Migrated the local hostname from `n8n.local` to `n8n.localhost`
- Switched local TLS management from `mkcert` back to Caddy `tls internal`

