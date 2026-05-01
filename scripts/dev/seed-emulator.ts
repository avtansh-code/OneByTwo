/**
 * Emulator seed data script — placeholder for Sprint 1.
 *
 * This script will be used to populate the Firebase Emulator Suite with
 * test data for local development. Currently empty; seed functions will
 * be added alongside the first feature PR (FR-AU-01).
 *
 * Usage:
 *   npx ts-node scripts/dev/seed-emulator.ts
 *
 * @module seed-emulator
 */

async function seed(): Promise<void> {
  // TODO(functions-dev): add seed data for auth, users, friendships #sprint-1
  console.log("Seed script placeholder — no data to seed yet.");
}

seed().catch((err) => {
  console.error("Seed failed:", err);
  process.exit(1);
});
