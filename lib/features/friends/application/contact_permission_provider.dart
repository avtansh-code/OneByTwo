import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/friends/data/contact_service.dart';
import 'package:onebytwo/features/friends/domain/contact_permission_state.dart';

/// Controller that manages device contact permission state.
///
/// Initial state is [ContactPermissionState.notDetermined].
/// Exposes [requestPermission] and [openSettings] to drive the
/// permission flow.
class ContactPermissionController
    extends StateNotifier<ContactPermissionState> {
  /// Creates a [ContactPermissionController].
  ContactPermissionController({required ContactService contactService})
    : _contactService = contactService,
      super(ContactPermissionState.notDetermined);

  final ContactService _contactService;

  /// Requests contact permission from the user and updates state.
  Future<void> requestPermission() async {
    final result = await _contactService.requestPermission();
    if (!mounted) return;
    state = result;
  }

  /// Checks the current permission state without prompting.
  Future<void> checkPermission() async {
    final result = await _contactService.checkPermission();
    if (!mounted) return;
    state = result;
  }

  /// Opens the app's system settings page.
  Future<void> openSettings() async {
    await _contactService.openSettings();
  }
}

/// Riverpod provider for [ContactPermissionController].
final contactPermissionControllerProvider =
    StateNotifierProvider<ContactPermissionController, ContactPermissionState>((
      ref,
    ) {
      final contactService = ref.watch(contactServiceProvider);
      return ContactPermissionController(contactService: contactService);
    });
