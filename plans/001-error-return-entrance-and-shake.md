# 001 — Skip entrance choreography on failed login; shake the error

- **Status**: TODO
- **Commit**: ef5ec7f
- **Severity**: MEDIUM
- **Category**: Purpose & frequency (+ missed opportunity: error feedback)
- **Estimated scope**: 1 file (backend/django_api/templates/admin/login.html), ~25 lines CSS + 2 template attrs

## Problem

The login page is server-rendered. A failed login reloads the page, and the full
entrance choreography replays: card entrance 0.7s + 4-child stagger ending at
~0.94s. A user who mistypes a password twice watches the ceremony three times,
and at that moment their attention should go to the error, which currently
enters like any other staggered child with no distinct feedback.

```css
/* backend/django_api/templates/admin/login.html:46 — current */
animation: staw-card-in .7s cubic-bezier(.16,.84,.44,1) both;
```

```django
{# backend/django_api/templates/admin/login.html:110 — current #}
<div class="staw-card">
```

```django
{# backend/django_api/templates/admin/login.html:117 — current #}
<div class="flex flex-col gap-4 mb-8 *:mb-0">
```

## Target

When the form has errors, the card gets class `staw-returning`: entrance is a
180ms opacity-only fade, stagger is skipped entirely, and the error block gets
a 320ms horizontal shake.

```css
/* target — add after the staw-rise keyframes block */
.staw-card.staw-returning { animation: staw-fade .18s cubic-bezier(0.23, 1, 0.32, 1) both; }
.staw-card.staw-returning > * { animation: none; opacity: 1; transform: none; }
@keyframes staw-fade { from { opacity: 0; } to { opacity: 1; } }

.staw-returning .staw-errors { animation: staw-shake .32s cubic-bezier(.36,.07,.19,.97) both; }
@keyframes staw-shake {
  10%, 90% { transform: translateX(-2px); }
  20%, 80% { transform: translateX(3px); }
  30%, 50%, 70% { transform: translateX(-4px); }
  40%, 60% { transform: translateX(4px); }
}
```

```django
{# target — card opens with conditional class #}
<div class="staw-card{% if form.errors or form.non_field_errors %} staw-returning{% endif %}">
```

```django
{# target — error wrapper gets a hook class #}
<div class="staw-errors flex flex-col gap-4 mb-8 *:mb-0">
```

Reduced-motion block (login.html:95-99) must also disable the shake: add
`.staw-errors` to the selector list that sets `animation: none !important`.

## Repo conventions to follow

- All motion in this template is inline CSS in the `{% block extrastyle %}`
  `<style>` tag, prefixed `staw-` — keep that prefix.
- GPU-only properties (`transform`/`opacity`) — the file already does this
  everywhere; do not animate anything else.
- Comments in Russian, e.g. `/* ── Тихий ambient-фон ── */` — match.

## Steps

1. In `backend/django_api/templates/admin/login.html`, inside the `<style>`
   block after the `staw-rise` keyframes (line 61), add the `.staw-returning`
   and `.staw-errors` CSS from Target.
2. Change line 110 `<div class="staw-card">` to the conditional-class version
   from Target.
3. Change line 117 error wrapper to add `staw-errors` class.
4. In the `prefers-reduced-motion` block, extend the first selector list to
   include `.staw-returning .staw-errors`.

## Boundaries

- Do NOT touch the aurora background, the button, the eye toggle, or any other
  template.
- Do NOT change form markup beyond adding the two classes.
- Do NOT add dependencies or JS.
- If line numbers have drifted, STOP and report.

## Verification

- **Mechanical**: `docker compose -f backend/docker-compose.yml exec web python manage.py check` → no errors (or restart container and GET /v1/health → 200).
- **Feel check**: open http://localhost:8000/admin/login/ in Chrome:
  - Fresh load (no errors): full entrance plays as before.
  - Submit wrong credentials: card appears in a quick fade (no stagger), the
    red error block shakes horizontally once, ~3 oscillations, then rests.
  - DevTools → Rendering → emulate `prefers-reduced-motion: reduce`, submit
    wrong credentials again: no shake, no movement, content fully visible.
- **Done when**: failed login shows error within ~200ms with a single shake,
  and a fresh visit still gets the full premium entrance.
