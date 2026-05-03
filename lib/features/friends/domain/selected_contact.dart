import 'package:flutter/foundation.dart';

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
  });

  /// The contact's display name.
  final String displayName;

  /// E.164 normalised Indian phone numbers (e.g. `+919876543210`).
  final List<String> phoneNumbers;

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
  String toString() => 'SelectedContact(displayName: $displayName, '
      'phoneNumbers: $phoneNumbers)';
}
