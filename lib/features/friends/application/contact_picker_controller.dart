import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/friends/data/contact_service.dart';
import 'package:onebytwo/features/friends/domain/phone_normaliser.dart';
import 'package:onebytwo/features/friends/domain/selected_contact.dart';

/// Immutable state for the contact picker.
@immutable
class ContactPickerState {
  /// Creates a [ContactPickerState].
  const ContactPickerState({
    this.contacts = const [],
    this.filteredContacts = const [],
    this.searchQuery = '',
    this.selectedContact,
    this.pendingMultiPhone,
    this.isLoading = false,
  });

  /// All contacts retrieved from the device.
  final List<DeviceContact> contacts;

  /// Contacts filtered by the current [searchQuery].
  final List<DeviceContact> filteredContacts;

  /// The current search query string.
  final String searchQuery;

  /// The selected and normalised contact, ready for hand-off.
  final SelectedContact? selectedContact;

  /// Set when a contact with multiple valid phone numbers is tapped.
  ///
  /// The presentation layer should display a phone selector sheet.
  final DeviceContact? pendingMultiPhone;

  /// Whether contacts are currently being loaded.
  final bool isLoading;

  /// Creates a copy with the given fields replaced.
  ContactPickerState copyWith({
    List<DeviceContact>? contacts,
    List<DeviceContact>? filteredContacts,
    String? searchQuery,
    SelectedContact? Function()? selectedContact,
    DeviceContact? Function()? pendingMultiPhone,
    bool? isLoading,
  }) {
    return ContactPickerState(
      contacts: contacts ?? this.contacts,
      filteredContacts: filteredContacts ?? this.filteredContacts,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedContact: selectedContact != null
          ? selectedContact()
          : this.selectedContact,
      pendingMultiPhone: pendingMultiPhone != null
          ? pendingMultiPhone()
          : this.pendingMultiPhone,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Controller for the contact picker screen.
///
/// Manages loading contacts from the device, filtering by search query,
/// selecting a contact, and resolving multi-phone contacts.
class ContactPickerController extends StateNotifier<ContactPickerState> {
  /// Creates a [ContactPickerController].
  ContactPickerController({required ContactService contactService})
      : _contactService = contactService,
        super(const ContactPickerState());

  final ContactService _contactService;

  /// Loads all contacts from the device.
  Future<void> loadContacts() async {
    state = state.copyWith(isLoading: true);
    final contacts = await _contactService.getContacts();
    if (!mounted) return;
    state = state.copyWith(
      contacts: contacts,
      filteredContacts: _applyFilter(contacts, state.searchQuery),
      isLoading: false,
    );
  }

  /// Updates the search query and filters the contact list.
  ///
  /// Matches are case-insensitive against display name and phone numbers.
  void updateSearch(String query) {
    state = state.copyWith(
      searchQuery: query,
      filteredContacts: _applyFilter(state.contacts, query),
    );
  }

  /// Selects a contact from the device list.
  ///
  /// If the contact has exactly one valid Indian phone number after
  /// normalisation, [ContactPickerState.selectedContact] is set directly.
  /// If there are multiple valid numbers,
  /// [ContactPickerState.pendingMultiPhone] is set so the presentation
  /// layer can show a phone selector.
  /// If there are zero valid numbers, [ContactPickerState.selectedContact]
  /// is set with an empty phone list.
  void selectContact(DeviceContact contact) {
    final normalised = normalisePhoneNumbers(contact.phoneNumbers);

    if (normalised.length > 1) {
      state = state.copyWith(
        pendingMultiPhone: () => contact,
        selectedContact: () => null,
      );
      return;
    }

    state = state.copyWith(
      selectedContact: () => SelectedContact(
        displayName: contact.displayName,
        phoneNumbers: normalised,
      ),
      pendingMultiPhone: () => null,
    );
  }

  /// Resolves a multi-phone selection by choosing a specific number.
  ///
  /// The [selectedNumber] is normalised to E.164 before setting
  /// [ContactPickerState.selectedContact].
  void resolveMultiPhone(String selectedNumber) {
    final pending = state.pendingMultiPhone;
    if (pending == null) return;

    final normalised = normaliseToE164(selectedNumber);
    final phones = normalised != null ? [normalised] : <String>[];

    state = state.copyWith(
      selectedContact: () => SelectedContact(
        displayName: pending.displayName,
        phoneNumbers: phones,
      ),
      pendingMultiPhone: () => null,
    );
  }

  /// Clears the current selection.
  void clearSelection() {
    state = state.copyWith(
      selectedContact: () => null,
      pendingMultiPhone: () => null,
    );
  }

  List<DeviceContact> _applyFilter(List<DeviceContact> contacts, String query) {
    if (query.isEmpty) return contacts;

    final lowerQuery = query.toLowerCase();
    return contacts.where((contact) {
      if (contact.displayName.toLowerCase().contains(lowerQuery)) return true;
      return contact.phoneNumbers.any(
        (phone) => phone.toLowerCase().contains(lowerQuery),
      );
    }).toList();
  }
}

/// Riverpod provider for [ContactPickerController].
final contactPickerControllerProvider =
    StateNotifierProvider<ContactPickerController, ContactPickerState>((ref) {
  final contactService = ref.watch(contactServiceProvider);
  return ContactPickerController(contactService: contactService);
});
