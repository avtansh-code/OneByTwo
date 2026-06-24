import 'package:flutter/foundation.dart';

/// How the user supplied a contact in the add-friend flow.
///
/// Surfaced as the non-identifying `method` parameter on the
/// `friend_added` telemetry event so the SRS section 5.10 acquisition
/// funnel can be segmented by entry path. Carries no PII.
///
/// The telemetry plan also documents an `invite` value; that path is
/// emitted by the `friend_invite_*` events (a non-user is invited
/// rather than added), never by `friend_added`, so it is intentionally
/// absent here.
enum AddFriendEntryMethod {
  /// The contact was chosen from the device contact picker (Path A).
  contacts,

  /// The contact was typed into the manual phone-entry field (Path B).
  manual;

  /// The analytics wire value (`contacts` / `manual`). Defined
  /// explicitly so renaming an enum case cannot silently change the
  /// emitted telemetry token.
  String get wireName => switch (this) {
    AddFriendEntryMethod.contacts => 'contacts',
    AddFriendEntryMethod.manual => 'manual',
  };
}

/// A contact selected from the device picker.
///
/// Phone numbers are E.164 normalised Indian mobile numbers only.
/// Non-Indian numbers are filtered before construction.
@immutable
class SelectedContact {
  /// Creates a [SelectedContact].
  const SelectedContact({
    required this.displayName,
    required this.phoneNumbers,
    this.method = AddFriendEntryMethod.contacts,
  });

  /// The contact's display name.
  final String displayName;

  /// E.164 normalised Indian phone numbers (e.g. `+919876543210`).
  final List<String> phoneNumbers;

  /// The entry path that produced this contact, threaded to the
  /// `friend_added` telemetry `method` parameter (T4).
  ///
  /// Telemetry provenance only: it is deliberately excluded from
  /// [toMap], `==`, and [hashCode] so a contact's identity remains its
  /// name and numbers regardless of how it was entered, preserving the
  /// two-key boundary hand-off contract.
  final AddFriendEntryMethod method;

  /// Returns a copy of this contact with [method] replaced.
  SelectedContact copyWith({AddFriendEntryMethod? method}) => SelectedContact(
    displayName: displayName,
    phoneNumbers: phoneNumbers,
    method: method ?? this.method,
  );

  /// Converts to a map for boundary-contract assertions.
  Map<String, Object> toMap() => {
    'displayName': displayName,
    'phoneNumbers': phoneNumbers,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectedContact &&
          displayName == other.displayName &&
          listEquals(phoneNumbers, other.phoneNumbers);

  @override
  int get hashCode => Object.hash(displayName, Object.hashAll(phoneNumbers));

  @override
  String toString() =>
      'SelectedContact(displayName: $displayName, '
      'phoneNumbers: $phoneNumbers)';
}
