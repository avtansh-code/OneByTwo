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
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (_isCommentLine(lines[i])) continue;
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
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (_isCommentLine(lines[i])) continue;
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

bool _isCommentLine(String raw) {
  final trimmed = raw.trim();
  return trimmed.startsWith('//') ||
      trimmed.startsWith('*') ||
      trimmed.startsWith('/*');
}
