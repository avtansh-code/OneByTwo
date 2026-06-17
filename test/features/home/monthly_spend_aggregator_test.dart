// FR-HD-03 monthly-spend aggregator + IST-window unit tests (ADR-0017
// sections 2-4).
//
// Pure, Riverpod-free, Firestore-free tests of the two domain functions:
// `currentMonthWindowIst` (the fixed +05:30 IST month boundary) and
// `aggregateMonthlySpend` (the per-friendship fold of the user's OWN
// share per category, integer paise). Covers AC-1..AC-7, AC-11, AC-12,
// the descending sort, and the exact AC-5 IST boundary.

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';
import 'package:onebytwo/features/home/domain/monthly_spend_aggregator.dart';
import 'package:onebytwo/features/home/domain/monthly_spend_breakdown.dart';

const _me = 'uid-me';
const _other = 'uid-other';

/// Builds an expense whose split puts [userSharePaise] on the signed-in
/// user ([userId]) and [otherSharePaise] on the counterparty
/// ([counterpartyId]). `amountPaise` is the bill total (the sum), which
/// the aggregator must NOT count — only the user's share.
ExpenseDoc _expense({
  required ExpenseCategory category,
  required DateTime date,
  required int userSharePaise,
  int otherSharePaise = 0,
  String userId = _me,
  String counterpartyId = _other,
}) {
  return ExpenseDoc(
    amountPaise: userSharePaise + otherSharePaise,
    description: 'expense',
    category: category,
    date: date,
    payerId: userId,
    splits: [
      Split(userId: userId, sharePaise: userSharePaise),
      Split(userId: counterpartyId, sharePaise: otherSharePaise),
    ],
    splitMethod: SplitMethod.equal,
    createdBy: userId,
  );
}

void main() {
  // June 2026 window (AC-5): start 2026-05-31T18:30:00Z, end
  // 2026-06-30T18:30:00Z.
  final june2026 = currentMonthWindowIst(DateTime.utc(2026, 6, 15, 12));

  group('currentMonthWindowIst (ADR-0017 section 3)', () {
    test('June 2026 → start 2026-05-31T18:30Z, end 2026-06-30T18:30Z', () {
      final window = currentMonthWindowIst(DateTime.utc(2026, 6, 15, 12));
      expect(window.startUtc, DateTime.utc(2026, 5, 31, 18, 30));
      expect(window.endUtc, DateTime.utc(2026, 6, 30, 18, 30));
    });

    test('December rolls the upper bound into the next January', () {
      final window = currentMonthWindowIst(DateTime.utc(2026, 12, 20, 12));
      expect(window.startUtc, DateTime.utc(2026, 11, 30, 18, 30));
      expect(window.endUtc, DateTime.utc(2026, 12, 31, 18, 30));
    });

    test('uses the IST calendar month, not the UTC one', () {
      // 2026-05-31T20:00Z is 2026-06-01T01:30 IST — already June in IST.
      final window = currentMonthWindowIst(DateTime.utc(2026, 5, 31, 20));
      expect(window.startUtc, DateTime.utc(2026, 5, 31, 18, 30));
      expect(window.endUtc, DateTime.utc(2026, 6, 30, 18, 30));
    });

    test('an instant just before IST month start stays in the prior '
        'month', () {
      // 2026-05-31T18:00Z is 2026-05-31T23:30 IST — still May.
      final window = currentMonthWindowIst(DateTime.utc(2026, 5, 31, 18));
      expect(window.startUtc, DateTime.utc(2026, 4, 30, 18, 30));
      expect(window.endUtc, DateTime.utc(2026, 5, 31, 18, 30));
    });
  });

  group('aggregateMonthlySpend — user share (AC-1, AC-2, AC-3)', () {
    test("AC-2: counts the user's share, never the bill total", () {
      // ₹1,000.00 bill (100000 paise) split equally → user share 50000.
      final breakdown = aggregateMonthlySpend(
        input: [
          (
            otherUserId: _other,
            expenses: [
              _expense(
                category: ExpenseCategory.food,
                date: DateTime.utc(2026, 6, 10),
                userSharePaise: 50000,
                otherSharePaise: 50000,
              ),
            ],
          ),
        ],
        monthStartUtc: june2026.startUtc,
        nextMonthStartUtc: june2026.endUtc,
      );

      expect(breakdown.categories, hasLength(1));
      expect(breakdown.categories.single.category, ExpenseCategory.food);
      expect(breakdown.categories.single.totalPaise, 50000);
      expect(breakdown.monthTotalPaise, 50000);
    });

    test('AC-1: folds multiple friendships into per-category subtotals '
        'and a month total', () {
      final breakdown = aggregateMonthlySpend(
        input: [
          (
            otherUserId: 'uid-bob',
            expenses: [
              _expense(
                category: ExpenseCategory.food,
                date: DateTime.utc(2026, 6, 5),
                userSharePaise: 50000,
                otherSharePaise: 50000,
                counterpartyId: 'uid-bob',
              ),
              _expense(
                category: ExpenseCategory.travel,
                date: DateTime.utc(2026, 6, 6),
                userSharePaise: 30000,
                otherSharePaise: 30000,
                counterpartyId: 'uid-bob',
              ),
            ],
          ),
          (
            otherUserId: 'uid-carol',
            expenses: [
              _expense(
                category: ExpenseCategory.food,
                date: DateTime.utc(2026, 6, 7),
                userSharePaise: 20000,
                otherSharePaise: 20000,
                counterpartyId: 'uid-carol',
              ),
            ],
          ),
        ],
        monthStartUtc: june2026.startUtc,
        nextMonthStartUtc: june2026.endUtc,
      );

      expect(breakdown.monthTotalPaise, 100000);
      expect(breakdown.categories, hasLength(2));
      // Food (70000) before Travel (30000) — descending paise.
      expect(breakdown.categories[0].category, ExpenseCategory.food);
      expect(breakdown.categories[0].totalPaise, 70000);
      expect(breakdown.categories[1].category, ExpenseCategory.travel);
      expect(breakdown.categories[1].totalPaise, 30000);
    });

    test('AC-3: the same category folds across friendships into one '
        'segment', () {
      final breakdown = aggregateMonthlySpend(
        input: [
          (
            otherUserId: 'uid-bob',
            expenses: [
              _expense(
                category: ExpenseCategory.groceries,
                date: DateTime.utc(2026, 6, 3),
                userSharePaise: 15000,
                counterpartyId: 'uid-bob',
              ),
            ],
          ),
          (
            otherUserId: 'uid-carol',
            expenses: [
              _expense(
                category: ExpenseCategory.groceries,
                date: DateTime.utc(2026, 6, 9),
                userSharePaise: 25000,
                counterpartyId: 'uid-carol',
              ),
            ],
          ),
        ],
        monthStartUtc: june2026.startUtc,
        nextMonthStartUtc: june2026.endUtc,
      );

      expect(breakdown.categories, hasLength(1));
      expect(breakdown.categories.single.category, ExpenseCategory.groceries);
      expect(breakdown.categories.single.totalPaise, 40000);
    });

    test('an expense the user is not a split member of contributes 0', () {
      final breakdown = aggregateMonthlySpend(
        input: [
          (
            otherUserId: _other,
            expenses: [
              // Only the counterparty has a split — the user's complement
              // share is 0.
              ExpenseDoc(
                amountPaise: 50000,
                description: 'their own',
                category: ExpenseCategory.food,
                date: DateTime.utc(2026, 6, 4),
                payerId: _other,
                splits: const [Split(userId: _other, sharePaise: 50000)],
                splitMethod: SplitMethod.equal,
                createdBy: _other,
              ),
            ],
          ),
        ],
        monthStartUtc: june2026.startUtc,
        nextMonthStartUtc: june2026.endUtc,
      );

      expect(breakdown.categories, isEmpty);
      expect(breakdown.monthTotalPaise, 0);
    });
  });

  group('aggregateMonthlySpend — IST month filter (AC-4, AC-5, AC-6)', () {
    test('AC-4: prior-month expenses are excluded', () {
      final breakdown = aggregateMonthlySpend(
        input: [
          (
            otherUserId: _other,
            expenses: [
              _expense(
                category: ExpenseCategory.food,
                // 20 May 2026 — previous month.
                date: DateTime.utc(2026, 5, 20),
                userSharePaise: 50000,
              ),
            ],
          ),
        ],
        monthStartUtc: june2026.startUtc,
        nextMonthStartUtc: june2026.endUtc,
      );

      expect(breakdown.categories, isEmpty);
      expect(breakdown.monthTotalPaise, 0);
    });

    test('next-month expenses are excluded (upper-bound defence)', () {
      final breakdown = aggregateMonthlySpend(
        input: [
          (
            otherUserId: _other,
            expenses: [
              _expense(
                category: ExpenseCategory.food,
                // 2026-07-01T05:00 IST — already July.
                date: DateTime.utc(2026, 6, 30, 23, 30),
                userSharePaise: 50000,
              ),
            ],
          ),
        ],
        monthStartUtc: june2026.startUtc,
        nextMonthStartUtc: june2026.endUtc,
      );

      expect(breakdown.categories, isEmpty);
    });

    test('AC-5: the IST boundary excludes 23:00 IST on the last prior day '
        'and includes 00:30 IST on the first day', () {
      final breakdown = aggregateMonthlySpend(
        input: [
          (
            otherUserId: _other,
            expenses: [
              // 2026-05-31T23:00 IST == 2026-05-31T17:30Z — before window.
              _expense(
                category: ExpenseCategory.travel,
                date: DateTime.utc(2026, 5, 31, 17, 30),
                userSharePaise: 11111,
              ),
              // 2026-06-01T00:30 IST == 2026-05-31T19:00Z — in window.
              _expense(
                category: ExpenseCategory.food,
                date: DateTime.utc(2026, 5, 31, 19),
                userSharePaise: 22222,
              ),
            ],
          ),
        ],
        monthStartUtc: june2026.startUtc,
        nextMonthStartUtc: june2026.endUtc,
      );

      expect(breakdown.categories, hasLength(1));
      expect(breakdown.categories.single.category, ExpenseCategory.food);
      expect(breakdown.categories.single.totalPaise, 22222);
    });

    test('the exact lower bound instant is included (half-open window)', () {
      final breakdown = aggregateMonthlySpend(
        input: [
          (
            otherUserId: _other,
            expenses: [
              _expense(
                category: ExpenseCategory.rent,
                date: june2026.startUtc,
                userSharePaise: 60000,
              ),
            ],
          ),
        ],
        monthStartUtc: june2026.startUtc,
        nextMonthStartUtc: june2026.endUtc,
      );

      expect(breakdown.categories.single.totalPaise, 60000);
    });

    test('AC-6: soft-deletion is a query-filter contract — the reducer '
        'sums every in-window expense it is handed', () {
      // ExpenseDoc carries no `deleted` flag (ADR-0017 section 5): deleted
      // docs are excluded by the repository `where(deleted == false)`
      // query before they reach the reducer, so the reducer faithfully
      // includes every (non-deleted) in-window expense it receives.
      final breakdown = aggregateMonthlySpend(
        input: [
          (
            otherUserId: _other,
            expenses: [
              _expense(
                category: ExpenseCategory.utilities,
                date: DateTime.utc(2026, 6, 12),
                userSharePaise: 7000,
              ),
            ],
          ),
        ],
        monthStartUtc: june2026.startUtc,
        nextMonthStartUtc: june2026.endUtc,
      );

      expect(breakdown.categories.single.totalPaise, 7000);
    });
  });

  group('aggregateMonthlySpend — shape (AC-7, AC-11, AC-12, sort)', () {
    test('AC-7: no qualifying spend → an empty breakdown', () {
      final breakdown = aggregateMonthlySpend(
        input: const [(otherUserId: _other, expenses: <ExpenseDoc>[])],
        monthStartUtc: june2026.startUtc,
        nextMonthStartUtc: june2026.endUtc,
      );

      expect(breakdown.isEmpty, isTrue);
      expect(breakdown.categories, isEmpty);
      expect(breakdown.monthTotalPaise, 0);
    });

    test('empty input also yields an empty breakdown', () {
      final breakdown = aggregateMonthlySpend(
        input: const [],
        monthStartUtc: june2026.startUtc,
        nextMonthStartUtc: june2026.endUtc,
      );

      expect(breakdown.isEmpty, isTrue);
      expect(breakdown.monthTotalPaise, 0);
    });

    test('AC-11: a single-category month yields one segment at the full '
        'total', () {
      final breakdown = aggregateMonthlySpend(
        input: [
          (
            otherUserId: _other,
            expenses: [
              _expense(
                category: ExpenseCategory.rent,
                date: DateTime.utc(2026, 6),
                userSharePaise: 120000,
              ),
            ],
          ),
        ],
        monthStartUtc: june2026.startUtc,
        nextMonthStartUtc: june2026.endUtc,
      );

      expect(breakdown.categories, hasLength(1));
      expect(breakdown.categories.single.category, ExpenseCategory.rent);
      expect(breakdown.categories.single.totalPaise, 120000);
      expect(breakdown.monthTotalPaise, 120000);
    });

    test('AC-12: all 8 categories render, `other` is an ordinary segment, '
        'sorted descending', () {
      final expenses = <ExpenseDoc>[
        for (var i = 0; i < ExpenseCategory.values.length; i++)
          _expense(
            category: ExpenseCategory.values[i],
            date: DateTime.utc(2026, 6, 2 + i),
            // Strictly increasing shares so the descending order is the
            // reverse of the enum order.
            userSharePaise: 1000 * (i + 1),
          ),
      ];

      final breakdown = aggregateMonthlySpend(
        input: [(otherUserId: _other, expenses: expenses)],
        monthStartUtc: june2026.startUtc,
        nextMonthStartUtc: june2026.endUtc,
      );

      expect(breakdown.categories, hasLength(8));
      // `other` (the 8th, largest share here) leads; no collapsed tail.
      expect(breakdown.categories.first.category, ExpenseCategory.other);
      expect(breakdown.categories.last.category, ExpenseCategory.food);
      // Descending by paise throughout.
      for (var i = 0; i < breakdown.categories.length - 1; i++) {
        expect(
          breakdown.categories[i].totalPaise >=
              breakdown.categories[i + 1].totalPaise,
          isTrue,
        );
      }
      expect(breakdown.monthTotalPaise, 1000 * (1 + 2 + 3 + 4 + 5 + 6 + 7 + 8));
    });

    test('equal paise tie-breaks deterministically on the enum index', () {
      final breakdown = aggregateMonthlySpend(
        input: [
          (
            otherUserId: _other,
            expenses: [
              _expense(
                category: ExpenseCategory.shopping,
                date: DateTime.utc(2026, 6, 8),
                userSharePaise: 5000,
              ),
              _expense(
                category: ExpenseCategory.food,
                date: DateTime.utc(2026, 6, 9),
                userSharePaise: 5000,
              ),
            ],
          ),
        ],
        monthStartUtc: june2026.startUtc,
        nextMonthStartUtc: june2026.endUtc,
      );

      // food.index (0) < shopping.index (6) → food first on the tie.
      expect(breakdown.categories[0].category, ExpenseCategory.food);
      expect(breakdown.categories[1].category, ExpenseCategory.shopping);
    });
  });

  group('value-object equality (CategorySpend, MonthlySpendBreakdown)', () {
    test('equal values are == and share a hashCode', () {
      const a = CategorySpend(category: ExpenseCategory.food, totalPaise: 5000);
      const b = CategorySpend(category: ExpenseCategory.food, totalPaise: 5000);
      expect(a, b);
      expect(a.hashCode, b.hashCode);

      const m1 = MonthlySpendBreakdown(categories: [a], monthTotalPaise: 5000);
      const m2 = MonthlySpendBreakdown(categories: [b], monthTotalPaise: 5000);
      expect(m1, m2);
      expect(m1.hashCode, m2.hashCode);
    });

    test('differing category or total breaks equality', () {
      const food = CategorySpend(
        category: ExpenseCategory.food,
        totalPaise: 5000,
      );
      const travel = CategorySpend(
        category: ExpenseCategory.travel,
        totalPaise: 5000,
      );
      const cheaperFood = CategorySpend(
        category: ExpenseCategory.food,
        totalPaise: 4000,
      );
      expect(food == travel, isFalse);
      expect(food == cheaperFood, isFalse);

      const base = MonthlySpendBreakdown(
        categories: [food],
        monthTotalPaise: 5000,
      );
      const differentTotal = MonthlySpendBreakdown(
        categories: [food],
        monthTotalPaise: 4000,
      );
      const differentCategories = MonthlySpendBreakdown(
        categories: [travel],
        monthTotalPaise: 5000,
      );
      expect(base == differentTotal, isFalse);
      expect(base == differentCategories, isFalse);
    });
  });
}
