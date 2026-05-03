import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/application/contact_permission_provider.dart';
import 'package:onebytwo/features/friends/application/contact_picker_controller.dart';
import 'package:onebytwo/features/friends/domain/contact_permission_state.dart';
import 'package:onebytwo/features/friends/presentation/widgets/contact_list_tile.dart';
import 'package:onebytwo/features/friends/presentation/widgets/empty_contacts_state.dart';
import 'package:onebytwo/features/friends/presentation/widgets/permission_denied_view.dart';
import 'package:onebytwo/features/friends/presentation/widgets/phone_selector_bottom_sheet.dart';

/// Contact picker screen for the add-friend flow (SCR-10).
///
/// Reads device contacts via [contactPickerControllerProvider] and
/// manages permission state via [contactPermissionControllerProvider].
/// On selection of a contact with a single valid phone number, the
/// screen pops with the result. For contacts with multiple valid
/// numbers, a bottom sheet is shown for disambiguation.
class ContactPickerScreen extends ConsumerStatefulWidget {
  /// Creates a [ContactPickerScreen].
  const ContactPickerScreen({super.key});

  @override
  ConsumerState<ContactPickerScreen> createState() =>
      _ContactPickerScreenState();
}

class _ContactPickerScreenState extends ConsumerState<ContactPickerScreen> {
  final _searchController = TextEditingController();
  bool _searchTelemetryFired = false;
  bool _openedTelemetryFired = false;

  @override
  void initState() {
    super.initState();
    // Schedule permission check after the first frame so that
    // provider reads are safe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoad();
    });
  }

  Future<void> _checkAndLoad() async {
    final permNotifier =
        ref.read(contactPermissionControllerProvider.notifier);
    await permNotifier.checkPermission();
    if (!mounted) return;

    final permState = ref.read(contactPermissionControllerProvider);
    if (permState == ContactPermissionState.granted) {
      await _loadContacts();
    }
  }

  Future<void> _loadContacts() async {
    final pickerNotifier =
        ref.read(contactPickerControllerProvider.notifier);
    await pickerNotifier.loadContacts();
    if (!mounted) return;

    if (!_openedTelemetryFired) {
      _openedTelemetryFired = true;
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logEvent(name: 'friend_contact_picker_opened'),
      );
    }
  }

  Future<void> _requestPermission() async {
    final permNotifier =
        ref.read(contactPermissionControllerProvider.notifier);
    await permNotifier.requestPermission();
    if (!mounted) return;

    final permState = ref.read(contactPermissionControllerProvider);
    if (permState == ContactPermissionState.granted) {
      await _loadContacts();
    }
  }

  void _onSearchChanged(String query) {
    ref.read(contactPickerControllerProvider.notifier).updateSearch(query);

    if (!_searchTelemetryFired && query.isNotEmpty) {
      _searchTelemetryFired = true;
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logEvent(name: 'friend_contact_search_used'),
      );
    }
  }

  void _onContactTapped(int index) {
    final pickerNotifier =
        ref.read(contactPickerControllerProvider.notifier);
    final contact =
        ref.read(contactPickerControllerProvider).filteredContacts[index];
    pickerNotifier.selectContact(contact);
  }

  void _handleSelection() {
    final state = ref.read(contactPickerControllerProvider);

    if (state.pendingMultiPhone != null) {
      final phones = state.pendingMultiPhone!.phoneNumbers;
      showPhoneSelector(
        context: context,
        phones: phones,
        onSelect: (phone) {
          ref
              .read(contactPickerControllerProvider.notifier)
              .resolveMultiPhone(phone);
        },
      );
      return;
    }

    if (state.selectedContact != null) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logEvent(name: 'friend_contact_selected'),
      );
      Navigator.of(context).pop(state.selectedContact);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final permState = ref.watch(contactPermissionControllerProvider);
    final pickerState = ref.watch(contactPickerControllerProvider);

    // React to selection or multi-phone changes.
    ref.listen<ContactPickerState>(
      contactPickerControllerProvider,
      (previous, next) {
        if (next.selectedContact != null &&
            previous?.selectedContact != next.selectedContact) {
          _handleSelection();
        } else if (next.pendingMultiPhone != null &&
            previous?.pendingMultiPhone != next.pendingMultiPhone) {
          _handleSelection();
        }
      },
    );

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          final state = ref.read(contactPickerControllerProvider);
          if (state.selectedContact == null) {
            unawaited(
              ref.read(analyticsServiceProvider).logEvent(
                    name:
                        'friend_contact_picker_dismissed_without_selection',
                  ),
            );
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Friend'),
        ),
        body: _buildBody(permState, pickerState),
      ),
    );
  }

  Widget _buildBody(
    ContactPermissionState permState,
    ContactPickerState pickerState,
  ) {
    switch (permState) {
      case ContactPermissionState.notDetermined:
        return Center(
          child: FilledButton(
            onPressed: _requestPermission,
            child: const Text('Grant Contact Access'),
          ),
        );

      case ContactPermissionState.denied:
        return PermissionDeniedView(
          isDeniedPermanently: false,
          onGrantPermission: _requestPermission,
          onOpenSettings: () {
            ref
                .read(contactPermissionControllerProvider.notifier)
                .openSettings();
          },
        );

      case ContactPermissionState.deniedPermanently:
        return PermissionDeniedView(
          isDeniedPermanently: true,
          onGrantPermission: _requestPermission,
          onOpenSettings: () {
            ref
                .read(contactPermissionControllerProvider.notifier)
                .openSettings();
          },
        );

      case ContactPermissionState.granted:
        if (pickerState.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search contacts',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            Expanded(
              child: pickerState.filteredContacts.isEmpty
                  ? const EmptyContactsState()
                  : ListView.builder(
                      itemCount: pickerState.filteredContacts.length,
                      itemBuilder: (context, index) {
                        final contact =
                            pickerState.filteredContacts[index];
                        final phone = contact.phoneNumbers.isNotEmpty
                            ? contact.phoneNumbers.first
                            : '';
                        return ContactListTile(
                          displayName: contact.displayName,
                          phoneNumber: phone,
                          onTap: () => _onContactTapped(index),
                        );
                      },
                    ),
            ),
          ],
        );
    }
  }
}
