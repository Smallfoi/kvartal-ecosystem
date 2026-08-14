# 002 — Unify stagger children onto the card's entrance curve

- **Status**: TODO
- **Commit**: ef5ec7f
- **Severity**: MEDIUM
- **Category**: Easing & duration / Cohesion
- **Estimated scope**: 1 file, 1 line

## Problem

The card enters on a strong custom ease-out, but its children rise on the
built-in `ease`, which starts slow and reads as a different, weaker character
inside the same entrance.

```css
/* backend/django_api/templates/admin/login.html:56 — current */
.staw-card > * { animation: staw-rise .6s ease both; }
```

## Target

```css
/* target */
.staw-card > * { animation: staw-rise .5s cubic-bezier(.16,.84,.44,1) both; }
```

Same curve as `staw-card-in` (login.html:46), duration tightened from 600ms to
500ms so the last staggered child (delay .34s) settles at ~840ms instead of
~940ms.

## Repo conventions to follow

- The curve `cubic-bezier(.16,.84,.44,1)` is already the template's entrance
  signature at login.html:46 — reuse it verbatim.

## Steps

1. In `backend/django_api/templates/admin/login.html:56`, replace
   `animation: staw-rise .6s ease both;` with
   `animation: staw-rise .5s cubic-bezier(.16,.84,.44,1) both;`.

## Boundaries

- Do NOT change the stagger delays (lines 57-60) or the keyframes.
- Do NOT touch anything else.

## Verification

- **Mechanical**: page loads without console errors.
- **Feel check**: reload the login page; children now snap out of their rise
  quickly and decelerate — same character as the card itself. In DevTools →
  Animations panel at 10% speed, card and children curves should look like the
  same family (fast start, long settle).
- **Done when**: line 56 uses the shared curve and the entrance reads as one
  motion, not two.
