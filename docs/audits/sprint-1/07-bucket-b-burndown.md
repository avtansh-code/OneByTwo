# Bucket-B Burndown

> Tracks resolution of the 37 deferred findings from the Sprint 1 boundary audit
> (PR #14). Updated at the end of every Sprint 2 PR.
>
> Source: `docs/audits/sprint-1/00-triage-summary.md` (Bucket B section).
> Detail: `docs/audits/sprint-1/06-deferred-to-sprint-2.md`.
>
> Last updated: PR #32.

---

## Totals

| Category | Original | Resolved | Remaining |
|---|---|---|---|
| Code chores | 12 | 0 | 12 |
| Documentation chores | 8 | 0 | 8 |
| Dependency upgrades | 6 | 0 | 6 |
| Test coverage gaps | 8 | 3 | 5 |
| Infrastructure | 3 | 0 | 3 |
| **Total** | **37** | **3** | **34** |

Tracking format: 14 items logged as GitHub issues (#15 through #28); 23 items
logged in `06-deferred-to-sprint-2.md` only.

---

## Resolution Log

### PRs #29 and #30 (post-Sprint-1 chores)

PR #29 (OTP resend hotfix) and PR #30 (boundary contracts, emulator enforcement,
coverage gates) addressed **new findings** from Sprint 1 testing. They did not
directly close any of the 37 bucket-B audit items.

However, the following bucket-B items are now **indirectly mitigated** by PR #30
work, though they remain open until explicitly verified and closed:

| Bucket-B ID | Item | PR #30 Overlap | Status |
|---|---|---|---|
| CV2 | Add coverage section to PR description template | PR #30 added enforced coverage thresholds to the conventions doc and CI pipeline. The PR description template itself has not been updated. | Open (partially mitigated) |
| P1 | CF testing layers in conventions doc | Noted as "covered by CN1" in the triage (CN1 was Bucket A, fixed in PR #14). PR #30 further strengthened testing conventions. | Open (review for closure) |
| P2 | CF module layout in conventions doc | Noted as "covered by ADR-0011" in the triage (ADR-0011 was Bucket A, written in PR #14). | Open (review for closure) |
| SK3 | Field-level rules pattern in skill | Noted as "covered by ADR-0010 and CN2" in the triage (both Bucket A, PR #14). | Open (review for closure) |
| CN3 | Jest config separation in conventions doc | Noted as "fold into CN1" in the triage (CN1 was Bucket A, PR #14). | Open (review for closure) |

These five items (P1, P2, SK3, CN3, CV2) are candidates for batch closure in an
upcoming chore PR once a reviewer confirms the Bucket A work fully subsumes them.

### PR #31 (contact picker UI — FR-FR-01)

PR #31 is feature work on the Friends epic. **No bucket-B items are expected to
be resolved by this PR.**

### PR #32 (matching and friendship creation — FR-FR-01)

PR #32 implements friendship matching via a callable Cloud Function, Firestore
security rules for the `friendships` collection, and invite flow via the system
share sheet. This PR resolves the following bucket-B items:

| Bucket-B ID | Item | Resolution | Status |
|---|---|---|---|
| R1 | Friendship rules create validation tests | PR #32 includes Firestore rules tests covering friendship document creation (valid create, missing fields, wrong caller). | **Resolved** |
| R2 | Friendship rules update validation tests | PR #32 includes Firestore rules tests covering friendship document update scenarios. | **Resolved** |
| R3 | Friendship delete deny test | PR #32 includes a Firestore rules test verifying that friendship documents cannot be deleted by clients. | **Resolved** |
| INV2 | Share-sheet verification tests | PR #32's invite flow tests exercise the system share sheet path (Invariant 3 compliance). Partially addressed — full share-sheet content verification deferred to FR-FR-02. | Open (partially addressed) |

**Net result:** 3 items resolved (R1, R2, R3). 1 item partially addressed (INV2).

---

## Remaining Items by Category

### Code Chores (12 remaining)

| ID | Item | Natural Moment |
|---|---|---|
| M1 | Rename `authStateNotifierProvider` to `authStateProvider` | Standalone chore PR |
| T3 | Clarify `signup_otp_submitted` event | Next OTP screen touch |
| T4 | Add missing secondary telemetry events | Next auth screen touch |
| T5 | Fix `is_new_user` parameter type (int to bool) | Next OTP controller touch |
| M4 | Relocate core providers to `lib/core/providers/` | When shared providers needed |
| S1 | Splash screen timeout/error alignment (PM decision) | Sprint 2 polish |
| S3 | Phone entry OTP error: inline vs snackbar (PM decision) | Sprint 2 polish |
| S4 | Phone entry live formatting (XXXXX XXXXX) | Sprint 2 polish |
| S5 | OTP resend exhausted message text alignment | Next OTP touch |
| F2 | Group create rules missing `adminId` validation | Sprint 3 (groups) |
| SC1 | Concurrent submit guard test for phone entry | Next phone entry touch |
| SC3 | `MAX_SAFE_INTEGER` overflow test for algorithm | Standalone chore or expense PR |

### Documentation Chores (8 remaining)

| ID | Item | Natural Moment |
|---|---|---|
| CV2 | Add coverage section to PR description template | Before next feature PR |
| P1 | CF testing layers in conventions doc | Review for closure (may be covered by PR #14 CN1) |
| P2 | CF module layout in conventions doc | Review for closure (may be covered by PR #14 ADR-0011) |
| SK3 | Field-level rules pattern in skill | Review for closure (may be covered by PR #14 ADR-0010/CN2) |
| CN3 | Jest config separation in conventions doc | Review for closure (may be folded into PR #14 CN1) |
| CN4 | CF-specific PR checklist items | Sprint 2 CF PR |
| SR3 | Friends HTML mockup missing | Screen spec compensates; low urgency |
| SR8 | Expense event naming asymmetry | Before first expense PR |

### Dependency Upgrades (6 remaining)

| ID | Item | Timeline |
|---|---|---|
| D1 | Riverpod 3.x migration | Dedicated chore PR, Sprint 2 or 3 |
| D2 | `share_plus` upgrade (10 to 13) | Before first share-using PR |
| D4 | `build_runner` upgrade (discontinued transitives) | When convenient |
| D5 | `firebase-functions` 7.x evaluation | Before Sprint 2 CF work |
| D6 | npm audit moderate vulnerabilities | When firebase-admin/functions upgraded |
| D7 | Jest 30, TypeScript 6, ESLint 9 major bumps | When convenient |

### Test Coverage Gaps (8 remaining)

| ID | Item | Timeline |
|---|---|---|
| R1-R6 | Firestore rules test gaps (friendships and groups) | Sprint 2 friendship PR / Sprint 3 groups PR |
| R7-R8 | Storage rules test gaps (file size, content-type) | Sprint 2 chore |
| SC2 | OTP auto-retrieval timeout test | Android auto-read refinement |
| SC4 | Large group (100+) scalability test | Sprint 3 groups |
| INV2 | Share-sheet verification tests | When sharing features implemented |
| INV3 | Float/double rejection hook | Low priority; type system suffices |
| CV3 | Functions `function.ts` branch coverage at 76% | When expense triggers wired |
| PY3 | Expand integration tests for Sprint 2 flows | Sprint 2 ongoing |

### Infrastructure (3 remaining)

| ID | Item | Timeline |
|---|---|---|
| RT2 | CI step duration logging for trend monitoring | Sprint 2 |
| S2_sec | Release pipeline secrets (Google Play, TestFlight) | Before Sprint 6 |
| SR12 | DPDP compliance legal sign-off scheduling | Before Sprint 6 |

---

## Burndown Chart (text)

```
PR #14 (audit close):  37 remaining  ████████████████████████████████████░░  37/37
PR #29 (hotfix):       37 remaining  ████████████████████████████████████░░  37/37
PR #30 (chore):        37 remaining  ████████████████████████████████████░░  37/37
PR #31 (FR-FR-01 UI):  37 remaining  ████████████████████████████████████░░  37/37
```

No bucket-B items have been formally closed yet. The first natural resolution
moments arrive with PR #32 (friendship rules tests will address R1-R3) and any
dedicated chore PR that batch-closes the five items already covered by PR #14
Bucket A work (P1, P2, SK3, CN3, and partially CV2).
