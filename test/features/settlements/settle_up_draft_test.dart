// SettleUpDraft tests (FR-SE-05).
//
// Tests the in-memory form state held by SettleUpController. The draft
// is immutable; every setter on the controller produces a new instance.
// Validation produces a field-keyed error map; an empty map means
// "valid to save".
//
// Mirrors test/features/expenses/expense_repository_test.dart's draft
// patterns and the SettleUpDraft contract ratified in Architect
// Notes §2.1.
//
// Written test-first; will fail to compile until the implementation
// (Step A) lands.

// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/settlements/domain/settle_up_draft.dart';

void main() {
  group('SettleUpDraft construction', () {
    test('initial draft pre-fills amountPaise = suggestedAmountPaise', () {
      final draft = SettleUpDraft.initial(
        suggestedAmountPaise: 5000,
        date: DateTime(2026, 6, 5),
      );
      expect(draft.suggestedAmountPaise, 5000);
      expect(draft.amountPaise, 5000);
      expect(draft.date, DateTime(2026, 6, 5));
      expect(draft.note, isNull);
    });

    test('copyWith preserves unspecified fields', () {
      final base = SettleUpDraft.initial(
        suggestedAmountPaise: 5000,
        date: DateTime(2026, 6),
      );
      final next = base.copyWith(amountPaise: 3000);
      expect(next.amountPaise, 3000);
      expect(next.suggestedAmountPaise, 5000);
      expect(next.date, base.date);
      expect(next.note, isNull);
    });

    test('copyWith can set note to a non-null value', () {
      final base = SettleUpDraft.initial(
        suggestedAmountPaise: 5000,
        date: DateTime(2026, 6),
      );
      final next = base.copyWith(note: 'Pizza');
      expect(next.note, 'Pizza');
    });

    test('copyWith allows clearing the note via clearNote: true', () {
      final base = SettleUpDraft.initial(
        suggestedAmountPaise: 5000,
        date: DateTime(2026, 6),
      ).copyWith(note: 'Pizza');
      final next = base.copyWith(clearNote: true);
      expect(next.note, isNull);
    });
  });

  group('SettleUpDraft.validate — amount', () {
    SettleUpDraft baseDraft({int amountPaise = 5000, int suggested = 5000}) =>
        SettleUpDraft.initial(
          suggestedAmountPaise: suggested,
          date: DateTime(2026, 6),
        ).copyWith(amountPaise: amountPaise);

    test('valid amount produces empty error map', () {
      final errors = baseDraft(amountPaise: 5000).validate();
      expect(errors, isEmpty);
    });

    test('amount == 0 → "must be greater than zero"', () {
      final errors = baseDraft(amountPaise: 0).validate();
      expect(errors['amount'], 'Amount must be greater than zero.');
    });

    test('amount > suggested → "cannot exceed outstanding balance"', () {
      final errors = baseDraft(amountPaise: 6000, suggested: 5000).validate();
      expect(errors['amount'], contains('cannot exceed the outstanding'));
      expect(errors['amount'], contains('₹50.00'));
    });

    test('amount == suggested is allowed (full settlement)', () {
      final errors = baseDraft(amountPaise: 5000, suggested: 5000).validate();
      expect(errors, isEmpty);
    });

    test('partial amount (1 paise less than suggested) is allowed', () {
      final errors = baseDraft(amountPaise: 4999, suggested: 5000).validate();
      expect(errors, isEmpty);
    });
  });

  group('SettleUpDraft.validate — note', () {
    SettleUpDraft draftWithNote(String? note) =>
        SettleUpDraft.initial(
          suggestedAmountPaise: 5000,
          date: DateTime(2026, 6),
        ).copyWith(note: note);

    test('null note is valid', () {
      final errors = draftWithNote(null).validate();
      expect(errors, isEmpty);
    });

    test('empty note is valid (boundary)', () {
      final errors = draftWithNote('').validate();
      expect(errors, isEmpty);
    });

    test('200-char note is valid (boundary)', () {
      final note = 'a' * 200;
      final errors = draftWithNote(note).validate();
      expect(errors, isEmpty);
    });

    test('201-char note → "must be 200 characters or fewer"', () {
      final note = 'a' * 201;
      final errors = draftWithNote(note).validate();
      expect(errors['note'], 'Note must be 200 characters or fewer.');
    });
  });

  group('SettleUpDraft.isPartial', () {
    test('full settlement amount == suggested → not partial', () {
      final draft = SettleUpDraft.initial(
        suggestedAmountPaise: 5000,
        date: DateTime(2026, 6),
      );
      expect(draft.isPartial, isFalse);
    });

    test('amount < suggested → partial', () {
      final draft = SettleUpDraft.initial(
        suggestedAmountPaise: 5000,
        date: DateTime(2026, 6),
      ).copyWith(amountPaise: 3000);
      expect(draft.isPartial, isTrue);
    });
  });

  group('SettleUpDraft.canonicalNote', () {
    test('null stays null', () {
      final draft = SettleUpDraft.initial(
        suggestedAmountPaise: 5000,
        date: DateTime(2026, 6),
      );
      expect(draft.canonicalNote, isNull);
    });

    test('empty string is canonicalised to null (§2.3)', () {
      final draft = SettleUpDraft.initial(
        suggestedAmountPaise: 5000,
        date: DateTime(2026, 6),
      ).copyWith(note: '');
      expect(draft.canonicalNote, isNull);
    });

    test('whitespace-only string is canonicalised to null', () {
      final draft = SettleUpDraft.initial(
        suggestedAmountPaise: 5000,
        date: DateTime(2026, 6),
      ).copyWith(note: '   ');
      expect(draft.canonicalNote, isNull);
    });

    test('non-empty string is preserved (trimmed)', () {
      final draft = SettleUpDraft.initial(
        suggestedAmountPaise: 5000,
        date: DateTime(2026, 6),
      ).copyWith(note: '  Pizza  ');
      expect(draft.canonicalNote, 'Pizza');
    });
  });
}
