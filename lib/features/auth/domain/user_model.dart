import 'package:cloud_firestore/cloud_firestore.dart';

/// Domain model for the `users/{userId}` Firestore document.
///
/// See `docs/design/07-technical/firestore-schema.md` for the
/// authoritative field definitions.
class UserModel {
  /// Creates a [UserModel].
  const UserModel({
    required this.phoneNumber,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
    this.photoUrl,
    this.fcmTokens = const [],
    this.notificationPrefs = const {
      'newExpense': true,
      'settlement': true,
      'reminder': true,
    },
    this.locale = 'en-IN',
  });

  /// Creates a [UserModel] from a Firestore document snapshot.
  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserModel(
      phoneNumber: data['phoneNumber'] as String,
      displayName: data['displayName'] as String,
      photoUrl: data['photoUrl'] as String?,
      fcmTokens: List<String>.from(data['fcmTokens'] as List? ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notificationPrefs: Map<String, bool>.from(
        data['notificationPrefs'] as Map? ??
            {'newExpense': true, 'settlement': true, 'reminder': true},
      ),
      locale: data['locale'] as String? ?? 'en-IN',
    );
  }

  /// E.164 format phone number (restricted to +91 prefix).
  final String phoneNumber;

  /// User-chosen display name. Maximum 50 characters.
  final String displayName;

  /// Cloud Storage download URL for the user's avatar.
  final String? photoUrl;

  /// One entry per device; managed on app launch.
  final List<String> fcmTokens;

  /// Document creation time.
  final DateTime createdAt;

  /// Last modification time.
  final DateTime updatedAt;

  /// Boolean flags controlling push notification categories.
  final Map<String, bool> notificationPrefs;

  /// BCP 47 locale code. v1.0 supports only `'en-IN'`.
  final String locale;

  /// Converts this model to a Firestore-compatible map for reads.
  Map<String, dynamic> toFirestore() {
    return {
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'fcmTokens': fcmTokens,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'notificationPrefs': notificationPrefs,
      'locale': locale,
    };
  }

  /// Creates the Firestore map for initial document creation.
  ///
  /// Uses [FieldValue.serverTimestamp] for `createdAt` and
  /// `updatedAt` to ensure server-authoritative timestamps.
  static Map<String, dynamic> toCreateMap({
    required String phoneNumber,
    required String displayName,
    String? photoUrl,
  }) {
    return {
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'fcmTokens': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'notificationPrefs': {
        'newExpense': true,
        'settlement': true,
        'reminder': true,
      },
      'locale': 'en-IN',
    };
  }
}
