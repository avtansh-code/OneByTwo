import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/friends/domain/contact_permission_state.dart';

/// Raw contact data from the device.
class DeviceContact {
  /// Creates a [DeviceContact].
  const DeviceContact({required this.displayName, required this.phoneNumbers});

  /// The contact's display name.
  final String displayName;

  /// Raw phone number strings as stored on the device.
  final List<String> phoneNumbers;

  @override
  String toString() =>
      'DeviceContact(displayName: $displayName, '
      'phoneNumbers: $phoneNumbers)';
}

/// Abstraction over device contact access.
///
/// Provides permission checks, contact retrieval, and settings navigation.
/// Override with a fake in tests to avoid platform plugin initialisation.
abstract class ContactService {
  /// Checks the current permission state without prompting.
  Future<ContactPermissionState> checkPermission();

  /// Requests contact permission from the user.
  Future<ContactPermissionState> requestPermission();

  /// Retrieves all contacts from the device.
  ///
  /// Returns an empty list if permission has not been granted.
  Future<List<DeviceContact>> getContacts();

  /// Opens the app's system settings page so the user can grant
  /// permission manually.
  Future<void> openSettings();
}

/// Production [ContactService] backed by `flutter_contacts`.
class FlutterContactService implements ContactService {
  @override
  Future<ContactPermissionState> checkPermission() async {
    final granted = await fc.FlutterContacts.requestPermission();
    return granted
        ? ContactPermissionState.granted
        : ContactPermissionState.denied;
  }

  @override
  Future<ContactPermissionState> requestPermission() async {
    final granted = await fc.FlutterContacts.requestPermission();
    return granted
        ? ContactPermissionState.granted
        : ContactPermissionState.denied;
  }

  @override
  Future<List<DeviceContact>> getContacts() async {
    final contacts = await fc.FlutterContacts.getContacts(withProperties: true);
    return contacts
        .map(
          (c) => DeviceContact(
            displayName: c.displayName,
            phoneNumbers: c.phones.map((p) => p.number).toList(),
          ),
        )
        .toList();
  }

  @override
  Future<void> openSettings() async {
    // Opens the external contact picker as a fallback.
    // In production, consider using app_settings or similar for
    // navigating directly to the app permission settings page.
    await fc.FlutterContacts.openExternalPick();
  }
}

/// Provides a [ContactService] instance.
///
/// Override in tests with a fake implementation.
final contactServiceProvider = Provider<ContactService>(
  (ref) => FlutterContactService(),
);
