# Invariants

These four constraints are non-negotiable. Every agent, every skill, and every hook
in this repository must respect them. A violation of any invariant is a blocking defect.

1. **Money is integer paise.** All monetary values are stored and transmitted as
   integer paise (1 INR = 100 paise). Conversion to rupees with two decimal places
   happens exclusively at the UI layer. Floats are never used for money.
   — SRS section 7.3

2. **`simplifiedBalances` is server-maintained and client-read-only.** The
   `simplifiedBalances` field on `friendships` and `groups` documents is written
   solely by the `recomputeSimplifiedBalances` Cloud Function. Client SDKs may read
   the field but must never write to it. This is enforced by Firestore Security Rules.
   — SRS sections 4.6, 7.3, 7.5

3. **System share sheet only.** All outbound sharing (friend invites, group invites,
   balance sharing) uses the platform's system share sheet. The app must not target,
   deep-link to, or import packages for any specific messaging app (WhatsApp,
   Telegram, etc.). The OS-presented options are the user's choice.
   — SRS sections 3.4, 4.11, 12.2

4. **Single Firebase project.** There is exactly one Firebase project: production.
   No staging or development projects exist. All pre-merge testing runs against the
   Firebase Emulator Suite. Introducing a second project ID in `firebase.json`,
   `.firebaserc`, or workflow files is forbidden.
   — SRS sections 3.4, 9.1
