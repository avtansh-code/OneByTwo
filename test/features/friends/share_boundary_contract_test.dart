// Invariant 3 boundary-contract tests: system share sheet only.
//
// Two guards for Invariant 3 (SRS sections 3.4, 4.11, 12.2 — all outbound
// sharing uses the platform's system share sheet):
//
//   (a) Unit: the friend-invite path crosses the share boundary via
//       ShareServiceBase.share() — the single system-share-sheet seam
//       (lib/features/friends/data/share_service.dart).
//   (b) Grep: no platform-specific messaging package (WhatsApp, Telegram,
//       Facebook, Instagram, LINE, Viber, Signal, WeChat) is imported or
//       deep-linked anywhere under lib/, and share_plus / Share.share appear
//       only in the seam.
//
// Mirrors the *_boundary_contract_test.dart pattern (e.g.
// test/core/services/permission_settings_boundary_contract_test.dart) and
// functions/test/boundary-contracts/. This is the first automated
// enforcement of Invariant 3 (audit finding INV2).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/application/match_and_invite_controller.dart';
import 'package:onebytwo/features/friends/data/matching_repository.dart';
import 'package:onebytwo/features/friends/data/share_service.dart';
import 'package:onebytwo/features/friends/domain/selected_contact.dart';

/// Records calls crossing the [ShareServiceBase] boundary.
class _RecordingShareService implements ShareServiceBase {
  int callCount = 0;
  String? sharedText;

  @override
  Future<void> share(String text) async {
    callCount++;
    sharedText = text;
  }
}

/// Always reports the looked-up contact as unregistered (the invite path).
class _UnmatchedMatchingRepository {
  Future<MatchResult> lookupUser(String phoneNumber) async => const Unmatched();
}

/// Unused in the invite path; present only to satisfy the constructor.
class _NoopFriendshipRepository {}

/// Swallows analytics events.
class _NoopAnalyticsService implements AnalyticsService {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}
}

const _contact = SelectedContact(
  displayName: 'Priya Sharma',
  phoneNumbers: ['+919876543210'],
);

void main() {
  group('share boundary contract (invariant 3) — share-sheet seam', () {
    test('the friend-invite path crosses ShareServiceBase.share()', () async {
      final share = _RecordingShareService();
      final controller = MatchAndInviteController(
        matchingRepository: _UnmatchedMatchingRepository(),
        friendshipRepository: _NoopFriendshipRepository(),
        currentUserPhone: '+919999999999',
        currentUserId: 'uid-self',
        analyticsService: _NoopAnalyticsService(),
        shareService: share,
      );

      // No registered match -> the invite (system-share-sheet) path is taken.
      await controller.performLookup(_contact);
      await controller.openInviteShareSheet();

      expect(
        share,
        isA<ShareServiceBase>(),
        reason: 'Invites must route through the ShareServiceBase seam.',
      );
      expect(share.callCount, 1);
      expect(share.sharedText, isNotNull);
      expect(share.sharedText, isNotEmpty);
    });

    test('the production ShareService implements the ShareServiceBase '
        'seam', () {
      expect(ShareService(), isA<ShareServiceBase>());
    });
  });

  group('share boundary contract (invariant 3) — no platform targets', () {
    test('no platform-specific messaging package is referenced in lib/', () {
      final violations = <String>[];
      for (final file in _dartFilesUnder('lib')) {
        final lines = _codeLinesOf(file);
        for (var i = 0; i < lines.length; i++) {
          for (final pattern in _forbiddenSharePatterns) {
            if (pattern.hasMatch(lines[i])) {
              violations.add(
                '${file.path}:${i + 1}: forbidden platform-share target '
                'matching /${pattern.pattern}/',
              );
            }
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason:
            'Invariant 3: outbound sharing must use the system share sheet '
            'only.\n${violations.join('\n')}',
      );
    });

    test('share_plus and Share.share appear only in the share-sheet '
        'seam', () {
      const seam = 'lib/features/friends/data/share_service.dart';
      final offenders = <String>[];
      for (final file in _dartFilesUnder('lib')) {
        if (file.path.endsWith('share_service.dart')) continue;
        final lines = _codeLinesOf(file);
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('package:share_plus/') ||
              lines[i].contains('Share.share')) {
            offenders.add('${file.path}:${i + 1}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'share_plus / Share.share must be confined to $seam (the single '
            'Invariant-3 boundary).\n${offenders.join('\n')}',
      );
    });
  });

  group('share boundary contract (invariant 3) — comment stripper', () {
    /// Convenience: does any forbidden pattern match the stripped form of
    /// the single [source] line?
    bool stripsToForbidden(String source) {
      final code = _stripComments([source]).single;
      return _forbiddenSharePatterns.any((p) => p.hasMatch(code));
    }

    test('a forbidden token in a trailing line comment is not flagged', () {
      // Was a false positive: the line does not start with `//`, so the
      // trailing comment was scanned as code.
      expect(
        stripsToForbidden('final ok = true; // wa_share is fine here'),
        isFalse,
      );
    });

    test('a forbidden token in a whole-line comment is not flagged', () {
      expect(
        stripsToForbidden('   // see whatsapp_share for context'),
        isFalse,
      );
    });

    test('a forbidden token inside a multi-line block comment body is not '
        'flagged', () {
      final stripped = _stripComments(<String>[
        '/* this block mentions',
        '   wa_share in its body',
        '   and ends here */',
      ]);
      final anyForbidden = stripped.any(
        (line) => _forbiddenSharePatterns.any((p) => p.hasMatch(line)),
      );
      expect(anyForbidden, isFalse);
    });

    test('a real URL-scheme target in code is preserved (no false '
        'negative)', () {
      // The `//` in `whatsapp://` is preceded by `:`, so it must NOT be
      // treated as a comment delimiter.
      expect(
        stripsToForbidden("launchUrl('whatsapp://send?text=hi');"),
        isTrue,
      );
    });

    test('a protocol-relative target inside a string is preserved', () {
      // `//wa.me/` is preceded by a quote, not whitespace.
      expect(stripsToForbidden("const link = '//wa.me/919876543210';"), isTrue);
    });

    test('a real target after a block-comment close on the same line is '
        'preserved', () {
      expect(stripsToForbidden('/* note */ telegram_share();'), isTrue);
    });
  });
}

/// Platform-specific share targets forbidden by Invariant 3. Mirrors
/// `.github/hooks/pre-tool-use/block-platform-share-targets.sh` and adds the
/// common deep-link hosts and URL schemes.
final _forbiddenSharePatterns = <RegExp>[
  RegExp('whatsapp_share|wa_share|whatsapp_unilink'),
  RegExp('telegram_share|telegram_bot'),
  RegExp('facebook_share|fb_share'),
  RegExp('instagram_share'),
  RegExp('line_share'),
  RegExp('viber_share'),
  RegExp('signal_share'),
  RegExp('wechat_share'),
  RegExp(r'//wa\.me/|api\.whatsapp\.com'),
  RegExp(r'whatsapp://|tg://|//t\.me/|fb-messenger://|instagram://'),
];

List<File> _dartFilesUnder(String dir) {
  final root = Directory(dir);
  if (!root.existsSync()) return <File>[];
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

/// Returns the lines of [file] with comments removed, so the greps match
/// only real code. Each returned entry keeps its original 1-based index
/// position (line N maps to result[N - 1]).
List<String> _codeLinesOf(File file) => _stripComments(file.readAsLinesSync());

/// Strips Dart comments from [rawLines], preserving line positions.
///
/// Handles three cases the start-of-line-only check missed:
///   - trailing line comments (`foo(); // wa_share`),
///   - whole-line comments (`// ...`, leading-indented or not),
///   - multi-line block comments (`/* ... */`), including a target hidden
///     after a block-comment close on the same line.
///
/// A `//` is treated as a line comment only when it begins the line or is
/// preceded by whitespace. This deliberately protects the URL tokens in
/// [_forbiddenSharePatterns] that themselves contain `//` — `whatsapp://`
/// (preceded by `:`) and `//wa.me/` / `//t.me/` (string-internal, preceded
/// by a quote) — so stripping never produces a false negative for them.
List<String> _stripComments(List<String> rawLines) {
  final out = <String>[];
  var inBlock = false;
  for (final raw in rawLines) {
    final buf = StringBuffer();
    var i = 0;
    while (i < raw.length) {
      if (inBlock) {
        final end = raw.indexOf('*/', i);
        if (end == -1) {
          i = raw.length;
        } else {
          i = end + 2;
          inBlock = false;
        }
        continue;
      }
      if (i + 1 < raw.length && raw[i] == '/' && raw[i + 1] == '*') {
        inBlock = true;
        i += 2;
        continue;
      }
      if (i + 1 < raw.length && raw[i] == '/' && raw[i + 1] == '/') {
        final atBoundary = i == 0 || _isWhitespace(raw[i - 1]);
        if (atBoundary) break; // rest of the line is a comment
      }
      buf.write(raw[i]);
      i++;
    }
    out.add(buf.toString());
  }
  return out;
}

bool _isWhitespace(String ch) => ch == ' ' || ch == '\t';
