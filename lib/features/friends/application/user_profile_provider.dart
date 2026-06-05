import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';

/// Per-uid family provider that resolves a friend's [UserModel] from
/// Firestore on demand. Each unique uid is cached for the lifetime of
/// the Riverpod container, so repeated reads inside the friends-list
/// stream (one per snapshot delivery) hit the cache after the first
/// fetch.
///
/// Returning `null` indicates the user document does not exist or could
/// not be resolved (deleted account, transient permission glitch, etc.).
/// The consumer is responsible for falling back to a placeholder display
/// name; see `friendsListProvider` for the canonical fallback.
///
/// Per architect note §4 on
/// `docs/sprint-zero/stories/FR-FR-03-friends-list.md`, this is an
/// intentional one-shot/cached read. A friend's `displayName` change
/// will not live-update the list mid-session; we revisit if this
/// surfaces as a UX issue.
final userProfileProvider = FutureProvider.family<UserModel?, String>((
  ref,
  uid,
) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.getUser(uid);
});
