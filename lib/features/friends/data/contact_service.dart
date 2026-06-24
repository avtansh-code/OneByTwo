import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/core/services/app_settings_service.dart';
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
  /// Creates a [FlutterContactService].
  ///
  /// [appSettings] backs [openSettings], deep-linking the user to the
  /// OS app-settings page so a permanently-denied contact permission
  /// can be re-granted.
  const FlutterContactService({required AppSettingsService appSettings})
    : _appSettings = appSettings;

  final AppSettingsService _appSettings;

  @override
  Future<ContactPermissionState> checkPermission() async {
    final status = await fc.FlutterContacts.permissions.check(
      fc.PermissionType.read,
    );
    return _mapPermissionStatus(status);
  }

  @override
  Future<ContactPermissionState> requestPermission() async {
    final status = await fc.FlutterContacts.permissions.request(
      fc.PermissionType.read,
    );
    return _mapPermissionStatus(status);
  }

  @override
  Future<List<DeviceContact>> getContacts() async {
    final contacts = await fc.FlutterContacts.getAll(
      properties: fc.ContactProperties.allProperties,
    );
    return contacts
        .map(
          (c) => DeviceContact(
            displayName: c.displayName ?? '',
            phoneNumbers: c.phones.map((p) => p.number).toList(),
          ),
        )
        .toList();
  }

  @override
  Future<void> openSettings() => _appSettings.openAppSettings();
}

/// Maps the `flutter_contacts` 2.x [fc.PermissionStatus] to the app's
/// [ContactPermissionState].
///
/// `limited` (iOS 18+ partial access) counts as granted; `permanentlyDenied`
/// and `restricted` drive the SCR-10 "Open Settings" CTA.
ContactPermissionState _mapPermissionStatus(fc.PermissionStatus status) {
  switch (status) {
    case fc.PermissionStatus.granted:
    case fc.PermissionStatus.limited:
      return ContactPermissionState.granted;
    case fc.PermissionStatus.denied:
      return ContactPermissionState.denied;
    case fc.PermissionStatus.permanentlyDenied:
    case fc.PermissionStatus.restricted:
      return ContactPermissionState.deniedPermanently;
    case fc.PermissionStatus.notDetermined:
      return ContactPermissionState.notDetermined;
  }
}

/// Provides a [ContactService] instance.
///
/// Override in tests with a fake implementation.
final contactServiceProvider = Provider<ContactService>(
  (ref) =>
      FlutterContactService(appSettings: ref.watch(appSettingsServiceProvider)),
);
