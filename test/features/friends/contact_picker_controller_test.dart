// ignore_for_file: cascade_invocations
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/friends/application/contact_picker_controller.dart';
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
  late ContactPickerController controller;

  setUp(() {
    fakeService = FakeContactService();
    controller = ContactPickerController(contactService: fakeService);
  });

  tearDown(() {
    controller.dispose();
  });

  group('ContactPickerController', () {
    test('initial state has empty contacts, no selection, not loading', () {
      expect(controller.state.contacts, isEmpty);
      expect(controller.state.filteredContacts, isEmpty);
      expect(controller.state.searchQuery, '');
      expect(controller.state.selectedContact, isNull);
      expect(controller.state.pendingMultiPhone, isNull);
      expect(controller.state.isLoading, isFalse);
    });

    test('loadContacts populates the contacts list', () async {
      fakeService.contactsResult = [
        const DeviceContact(
          displayName: 'Amit Kumar',
          phoneNumbers: ['9876543210'],
        ),
        const DeviceContact(
          displayName: 'Priya Sharma',
          phoneNumbers: ['8765432109'],
        ),
      ];

      await controller.loadContacts();

      expect(controller.state.contacts, hasLength(2));
      expect(controller.state.filteredContacts, hasLength(2));
      expect(controller.state.isLoading, isFalse);
    });

    test('search filter updates filteredContacts case-insensitively '
        'matching name', () async {
      fakeService.contactsResult = [
        const DeviceContact(
          displayName: 'Amit Kumar',
          phoneNumbers: ['9876543210'],
        ),
        const DeviceContact(
          displayName: 'Priya Sharma',
          phoneNumbers: ['8765432109'],
        ),
      ];

      await controller.loadContacts();
      controller.updateSearch('amit');

      expect(controller.state.filteredContacts, hasLength(1));
      expect(controller.state.filteredContacts.first.displayName, 'Amit Kumar');
    });

    test('search filter matches phone number', () async {
      fakeService.contactsResult = [
        const DeviceContact(
          displayName: 'Amit Kumar',
          phoneNumbers: ['9876543210'],
        ),
        const DeviceContact(
          displayName: 'Priya Sharma',
          phoneNumbers: ['8765432109'],
        ),
      ];

      await controller.loadContacts();
      controller.updateSearch('9876');

      expect(controller.state.filteredContacts, hasLength(1));
      expect(controller.state.filteredContacts.first.displayName, 'Amit Kumar');
    });

    test('search with empty query shows all contacts', () async {
      fakeService.contactsResult = [
        const DeviceContact(
          displayName: 'Amit Kumar',
          phoneNumbers: ['9876543210'],
        ),
        const DeviceContact(
          displayName: 'Priya Sharma',
          phoneNumbers: ['8765432109'],
        ),
      ];

      await controller.loadContacts();
      controller.updateSearch('amit');
      controller.updateSearch('');

      expect(controller.state.filteredContacts, hasLength(2));
    });

    test('selecting a contact with one valid phone number sets '
        'selectedContact directly', () async {
      const contact = DeviceContact(
        displayName: 'Amit Kumar',
        phoneNumbers: ['9876543210'],
      );

      controller.selectContact(contact);

      expect(controller.state.selectedContact, isNotNull);
      expect(controller.state.selectedContact!.displayName, 'Amit Kumar');
      expect(controller.state.selectedContact!.phoneNumbers, ['+919876543210']);
      expect(controller.state.pendingMultiPhone, isNull);
    });

    test('selecting a contact with multiple valid phones sets '
        'pendingMultiPhone', () async {
      const contact = DeviceContact(
        displayName: 'Priya Sharma',
        phoneNumbers: ['9876543210', '8765432109'],
      );

      controller.selectContact(contact);

      expect(controller.state.pendingMultiPhone, isNotNull);
      expect(controller.state.pendingMultiPhone!.displayName, 'Priya Sharma');
      expect(controller.state.selectedContact, isNull);
    });

    test('resolving multi-phone sets selectedContact with chosen '
        'number', () async {
      const contact = DeviceContact(
        displayName: 'Priya Sharma',
        phoneNumbers: ['9876543210', '8765432109'],
      );

      controller.selectContact(contact);
      controller.resolveMultiPhone('8765432109');

      expect(controller.state.selectedContact, isNotNull);
      expect(controller.state.selectedContact!.displayName, 'Priya Sharma');
      expect(controller.state.selectedContact!.phoneNumbers, ['+918765432109']);
      expect(controller.state.pendingMultiPhone, isNull);
    });

    test('clearSelection clears selectedContact and pendingMultiPhone', () {
      const contact = DeviceContact(
        displayName: 'Amit Kumar',
        phoneNumbers: ['9876543210'],
      );

      controller.selectContact(contact);
      expect(controller.state.selectedContact, isNotNull);

      controller.clearSelection();

      expect(controller.state.selectedContact, isNull);
      expect(controller.state.pendingMultiPhone, isNull);
    });

    test('contact with zero valid Indian numbers after normalisation '
        'sets selectedContact with empty phoneNumbers', () {
      const contact = DeviceContact(
        displayName: 'John Smith',
        phoneNumbers: ['+447911123456', '+1234567890'],
      );

      controller.selectContact(contact);

      expect(controller.state.selectedContact, isNotNull);
      expect(controller.state.selectedContact!.displayName, 'John Smith');
      expect(controller.state.selectedContact!.phoneNumbers, isEmpty);
      expect(controller.state.pendingMultiPhone, isNull);
    });

    test('contact with all non-Indian numbers has empty '
        'phoneNumbers in selectedContact', () {
      const contact = DeviceContact(
        displayName: 'US Friend',
        phoneNumbers: ['+12025551234'],
      );

      controller.selectContact(contact);

      expect(controller.state.selectedContact, isNotNull);
      expect(controller.state.selectedContact!.phoneNumbers, isEmpty);
    });

    test('resolveMultiPhone with no pending contact does nothing', () {
      controller.resolveMultiPhone('9876543210');

      expect(controller.state.selectedContact, isNull);
      expect(controller.state.pendingMultiPhone, isNull);
    });

    test('loadContacts preserves existing search filter', () async {
      fakeService.contactsResult = [
        const DeviceContact(
          displayName: 'Amit Kumar',
          phoneNumbers: ['9876543210'],
        ),
        const DeviceContact(
          displayName: 'Priya Sharma',
          phoneNumbers: ['8765432109'],
        ),
      ];

      controller.updateSearch('priya');
      await controller.loadContacts();

      expect(controller.state.filteredContacts, hasLength(1));
      expect(
        controller.state.filteredContacts.first.displayName,
        'Priya Sharma',
      );
    });
  });
}
