# Design handoff note

When this implementation branch was authored, `design_handoff_iqralock_onboarding/` was **not in the git repository** (only a stub `README.txt` existed).

Tokens, type scale, radii, and onboarding copy were reconstructed from the implementation plan’s explicit values (palette **1c** Sand + Gold/Olive, screen order, progress percentages, component behaviors).

**Before visual QA or App Store screenshots:**

1. Add the handoff folder to the repo (README, `IqraLock.dc.html`, `screenshots/*.png`).
2. Diff every row of the README token table against `IqraLockKit/DesignSystem/Tokens.swift` and `Typography.swift`.
3. Diff every string against the handoff README — plan copy is directionally correct but may not be letter-identical.
4. Prefer README measurements over the HTML prototype; never port the HTML bezel/status bar.
