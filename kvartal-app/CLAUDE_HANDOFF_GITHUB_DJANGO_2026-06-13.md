# Cloud Handoff: GitHub Workflow and Django Backend Migration

Date: 2026-06-13
Audience: Cloud / Claude working on KVARTAL ecosystem
Status: Strategic direction approved by project owner

## Important Decision

From now on, all project work must move to GitHub-based workflow.

The ecosystem backend will be migrated from the current FastAPI prototype to Django + Django REST Framework. This migration must be gradual and careful. Do not remove the existing FastAPI backend until the Django backend has matching endpoints and the mobile apps are verified against it.

## New Working Model

We will use GitHub as the source of truth for the whole ecosystem.

Recommended repository model: monorepo.

Proposed future structure:

```text
kvartal-ecosystem/
  apps/
    kvartal_app/
    sport_store/
    website/
    admin_panel/

  backend/
    django_api/
    legacy_fastapi/
    migrations/
    scripts/

  docs/
    ECOSYSTEM_ARCHITECTURE.md
    ROADMAP.md
    API_CONTRACTS.md
    GIT_WORKFLOW.md
    DJANGO_MIGRATION_PLAN.md

  infra/
    docker/
    nginx/
    postgres/
    github-actions/

  assets/
    brand/
    logos/
```

Until the monorepo is created, keep changes documented in the current project and avoid irreversible moves.

## GitHub Rules Going Forward

1. `main` must stay stable.
2. No direct feature work on `main` after GitHub is set up.
3. Every task should use a separate branch:
   - `feature/github-monorepo-setup`
   - `feature/django-api-bootstrap`
   - `feature/shared-auth-django`
   - `fix/kvartal-gps-route`
   - `docs/django-migration-plan`
4. Work should be merged through Pull Requests.
5. Pull Requests must include:
   - what changed;
   - why it changed;
   - tests/checks run;
   - screenshots or APK notes when UI/mobile behavior changes.
6. Cloud and Codex must not overwrite each other's unmerged work.
7. Before changing files, check current branch and Git status.
8. After meaningful changes, update docs/handoff notes.

## Immediate GitHub Setup Tasks

1. Create private GitHub repository: `kvartal-ecosystem`.
2. Prepare `.gitignore` for Flutter, Python, Django, Android, local DBs and secrets.
3. Move or copy current projects into monorepo structure:
   - current KVARTAL app;
   - SportStore app;
   - current FastAPI backend;
   - docs.
4. Make initial commit from clean current state.
5. Add GitHub Actions checks:
   - Flutter analyze/test for KVARTAL;
   - later Flutter analyze/test for SportStore;
   - Python tests/lint for backend.
6. Add branch protection for `main` after first stable setup.

## Backend Migration Direction

Current backend state:

- FastAPI prototype exists.
- It has dev phone auth, shared profile endpoints and SQLite dev storage.
- Current important API contracts:
  - `POST /v1/auth/phone/verify`
  - `GET /v1/auth/me`
  - `PATCH /v1/profile`

Target backend:

- Django
- Django REST Framework
- PostgreSQL
- PostGIS for territory geometry
- Redis/Celery later for background jobs
- Django Admin for internal operations

## Migration Rule

The mobile apps should not be forced to change all at once.

Django must first reproduce the current FastAPI API contract. Keep response JSON compatible where possible.

Example auth response shape to preserve:

```json
{
  "token": "...",
  "user": {
    "id": "...",
    "name": "...",
    "phone": "...",
    "email": "...",
    "city": "...",
    "avatarPath": "..."
  }
}
```

## Proposed Django Apps

```text
accounts        users, auth, sessions, linked providers
profiles        profile fields, avatar, city
runs            runs, route points, run history
territories     captured polygons, ownership, PostGIS geometry
maps            offline map packs, cities, districts, versions
loyalty         points, bonuses, achievements
store           SportStore catalog, orders, purchases
clubs           clubs, members, ratings
notifications   push/in-app notifications
admin_tools     moderation, support, analytics
```

## Migration Phases

### Phase 1: GitHub / Monorepo Foundation

- Set up GitHub repository.
- Add docs and workflow rules.
- Ensure current KVARTAL builds from repo.
- Do not change backend architecture yet.

### Phase 2: Django Backend Bootstrap

- Create `backend/django_api`.
- Configure Django REST Framework.
- Configure PostgreSQL locally or via Docker.
- Add basic health endpoint.
- Add project settings for dev/staging/prod.

### Phase 3: Auth/Profile Compatibility

- Implement Django endpoints compatible with current FastAPI:
  - phone verify;
  - current user;
  - update profile.
- Connect KVARTAL to Django API.
- Verify login/profile on phone.

### Phase 4: SportStore Shared Account

- Connect SportStore to the same Django account/profile API.
- Remove local-only profile as source of truth.
- Confirm one account works in both apps.

### Phase 5: Territory and Runs

- Move run history to backend.
- Store GPS tracks.
- Store territories in PostGIS.
- Implement proper geometry union/difference.
- Prevent duplicate territory overlays.

### Phase 6: Store/Loyalty/Admin

- Store points and loyalty transactions centrally.
- Add SportStore orders/catalog modules.
- Use Django Admin for internal management.

## Important Notes For Cloud

- Do not delete FastAPI immediately.
- Do not rename/move large project folders until GitHub monorepo structure is agreed and committed.
- Do not change Flutter API URLs randomly. Prefer a config switch between FastAPI and Django during migration.
- Preserve current mobile behavior while backend changes behind the API contract.
- Keep changes small and branch-based.
- Update this handoff and related docs after backend migration work.


## Docker Decision

Docker is accepted as a required future part of the ecosystem infrastructure, but it is not the first step.

Planned order:

1. GitHub workflow and monorepo.
2. Django REST Framework backend scaffold.
3. PostgreSQL/PostGIS connection.
4. Docker Compose for local infrastructure.
5. Redis/Celery/background workers after backend modules need them.

Docker should eventually run the backend stack consistently for Cloud, Codex and deployment:

- Django API;
- PostgreSQL;
- PostGIS;
- Redis;
- Celery worker;
- Celery beat;
- optional nginx/admin tooling.

Do not spend time on full Docker infrastructure before the GitHub setup and Django bootstrap are stable. It is OK to prepare `infra/` or `docker-compose.yml` later as a separate branch/PR.

## Current Priority

1. GitHub workflow first.
2. Monorepo structure second.
3. Django migration third.
4. Backend modules and shared account after Django auth/profile compatibility is stable.
