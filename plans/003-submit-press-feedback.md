# 003 — Real press feedback on the «Войти» button

- **Status**: TODO
- **Commit**: ef5ec7f
- **Severity**: MEDIUM
- **Category**: Physicality & origin
- **Estimated scope**: 1 file, ~4 lines

## Problem

`:active` merely cancels the hover lift — the primary CTA has no press
compression, so the click feels inert.

```css
/* backend/django_api/templates/admin/login.html:73-81 — current */
#login-form .submit-row {
  position: relative; overflow: hidden;
  transition: transform .2s ease, box-shadow .25s ease;
}
#login-form .submit-row:hover {
  transform: translateY(-1px);
  box-shadow: 0 10px 26px -8px rgba(10, 132, 255, .4);
}
#login-form .submit-row:active { transform: translateY(0); }
```

## Target

Press compresses to `scale(0.98)` with a fast 160ms strong ease-out; release
returns through the same transition (interruptible, retargets mid-motion).

```css
/* target */
#login-form .submit-row {
  position: relative; overflow: hidden;
  transition: transform .16s cubic-bezier(0.23, 1, 0.32, 1), box-shadow .25s ease;
}
#login-form .submit-row:hover {
  transform: translateY(-1px);
  box-shadow: 0 10px 26px -8px rgba(10, 132, 255, .4);
}
#login-form .submit-row:active { transform: translateY(0) scale(.98); }
```

Values from the audit playbook: press scale 0.95–0.98 (use .98 — quiet admin),
transition ~160ms strong ease-out `cubic-bezier(0.23, 1, 0.32, 1)`.

## Repo conventions to follow

- Keep the existing selector structure and the `box-shadow .25s ease` part of
  the transition untouched.

## Steps

1. In `backend/django_api/templates/admin/login.html:75`, change
   `transition: transform .2s ease, box-shadow .25s ease;` to
   `transition: transform .16s cubic-bezier(0.23, 1, 0.32, 1), box-shadow .25s ease;`.
2. In line 81, change `transform: translateY(0);` to
   `transform: translateY(0) scale(.98);`.

## Boundaries

- Do NOT touch the sheen (`::after`) rules.
- Do NOT change hover values.

## Verification

- **Mechanical**: page loads without console errors.
- **Feel check**: press and hold «Войти» — the button visibly compresses;
  release — it springs back through the hover state. Rapid click spam never
  snaps or restarts from zero (CSS transition retargets).
- **Done when**: `:active` includes `scale(.98)` and press/release feels
  compressed-then-released, not inert.
