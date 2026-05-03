// ignore_for_file: cascade_invocations
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/friends/application/contact_permission_provider.dart';
import 'package:onebytwo/features/friends/data/contact_service.dart';
import 'package:onebytwo/features/friends/domain/contact_permission_state.dart';

/// Fake [ContactService] with configurable behaviour for testing.
class FakeContactService implements ContactService {
  /// The permission state returned by [checkPermission].
  ContactPermissionState checkPermissionResult =
      ContactPermissionState.notDetermined;

  /// The permission state returned by [requestPermission].
  ContactPermissionState requestPermissionResult =
      ContactPermissionState.notDetermined;

  /// Contacts returned by [getContacts].
  List<DeviceContact> contactsResult = [];

  /// Whether [openSettings] was called.
  bool openSettingsCalled = false;

  @override
  Future<ContactPermissionState> checkPermission() async =>
      checkPermissionResult;

  @override
  Future<ContactPermissionState> requestPermission() async =>
      requestPermissionResult;

  @override
  Future<List<DeviceContact>> getContacts() async => contactsResult;

  @override
  Future<void> openSettings() async {
    openSettingsCalled = true;
  }
}

void main() {
  late FakeContactService fakeService;
  late ContactPermissionController controller;

  setUp(() {
    fakeService = FakeContactService();
    controller = ContactPermissionController(contactService: fakeService);
  });

  tearDown(() {
    controller.dispose();
  });

  group('ContactPermissionController', () {
    test('initial state is notDetermined', () {
      expect(controller.state, ContactPermissionState.notDetermined);
    });

    test('requestPermission when service returns granted updates '
        'state to granted', () async {
      fakeService.requestPermissionResult = ContactPermissionState.granted;

      await controller.requestPermission();

      expect(controller.state, ContactPermissionState.granted);
    });

    test('requestPermission when service returns denied updates '
        'state to denied', () async {
      fakeService.requestPermissionResult = ContactPermissionState.denied;

      await controller.requestPermission();

      expect(controller.state, ContactPermissionState.denied);
    });

    test('requestPermission when service returns deniedPermanently '
        'updates state to deniedPermanently', () async {
      fakeService.requestPermissionResult =
          ContactPermissionState.deniedPermanently;

      await controller.requestPermission();

      expect(controller.state, ContactPermissionState.deniedPermanently);
    });

    test('checkPermission updates state from service', () async {
      fakeService.checkPermissionResult = ContactPermissionState.granted;

      await controller.checkPermission();

      expect(controller.state, ContactPermissionState.granted);
    });

    test('openSettings delegates to service', () async {
      await controller.openSettings();

      expect(fakeService.openSettingsCalled, isTrue);
    });
  });
}
