# Animation plans — admin login page

Audit source: `improve-animations` skill run, 2026-08-14, commit ef5ec7f.
Target file: `backend/django_api/templates/admin/login.html`.

| # | Plan | Severity | Status |
|---|------|----------|--------|
| 001 | [Skip entrance on failed login + error shake](001-error-return-entrance-and-shake.md) | MEDIUM | TODO |
| 002 | [Unify stagger children easing](002-unify-entrance-easing.md) | MEDIUM | TODO |
| 003 | [Press feedback on «Войти»](003-submit-press-feedback.md) | MEDIUM | TODO |

Recommended order: 002 → 003 → 001 (smallest to largest; 001 touches the same
`<style>` block all three edit, so do it last to keep line references fresh).

Dependencies: none hard; all three land in one branch/PR
(`fix/admin-login-anim-audit`). Not-selected findings from the audit (4-6:
reduced-motion softening, hover gating for touch, sheen interrupt) remain
unplanned by owner's choice.
