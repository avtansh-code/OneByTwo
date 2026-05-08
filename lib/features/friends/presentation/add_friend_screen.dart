import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/application/contact_permission_provider.dart';
import 'package:onebytwo/features/friends/application/contact_picker_controller.dart';
import 'package:onebytwo/features/friends/domain/contact_permission_state.dart';
import 'package:onebytwo/features/friends/domain/selected_contact.dart';
import 'package:onebytwo/features/friends/presentation/widgets/contact_list_tile.dart';
import 'package:onebytwo/features/friends/presentation/widgets/empty_contacts_state.dart';
import 'package:onebytwo/features/friends/presentation/widgets/manual_phone_entry_tab.dart';
import 'package:onebytwo/features/friends/presentation/widgets/permission_denied_view.dart';
import 'package:onebytwo/features/friends/presentation/widgets/phone_selector_bottom_sheet.dart';

/// Add-friend screen with a segmented control for choosing between
/// the contact picker (Path A) and manual phone entry (Path B).
///
/// Replaces the previous single-path `ContactPickerScreen` as the
/// primary entry point for adding friends.
class AddFriendScreen extends ConsumerStatefulWidget {
  /// Creates an [AddFriendScreen].
  const AddFriendScreen({super.key});

  @override
  ConsumerState<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends ConsumerState<AddFriendScreen> {
  String _selectedTab = 'contacts';
  final _searchController = TextEditingController();
  bool _searchTelemetryFired = false;
  bool _openedTelemetryFired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fireScreenViewed();
      _checkAndLoad();
    });
  }

  void _fireScreenViewed() {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: 'add_friend_screen_viewed',
            parameters: {'entry_path': 'contacts'},
          ),
    );
  }

  Future<void> _checkAndLoad() async {
    final permNotifier = ref.read(contactPermissionControllerProvider.notifier);
    await permNotifier.checkPermission();
    if (!mounted) return;

    final permState = ref.read(contactPermissionControllerProvider);
    if (permState == ContactPermissionState.granted) {
      await _loadContacts();
    }
  }

  Future<void> _loadContacts() async {
    final pickerNotifier = ref.read(contactPickerControllerProvider.notifier);
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
    final permNotifier = ref.read(contactPermissionControllerProvider.notifier);
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
    final pickerNotifier = ref.read(contactPickerControllerProvider.notifier);
    final contact = ref
        .read(contactPickerControllerProvider)
        .filteredContacts[index];
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

  void _onManualSubmit(SelectedContact contact) {
    // Navigate back with the manually entered contact, consistent
    // with the contact picker path which pops with the result.
    Navigator.of(context).pop(contact);
  }

  void _onTabChanged(Set<String> selection) {
    final newTab = selection.first;
    if (newTab == _selectedTab) return;

    setState(() {
      _selectedTab = newTab;
    });

    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: 'add_friend_tab_switched',
            parameters: {'tab': newTab},
          ),
    );
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
    ref.listen<ContactPickerState>(contactPickerControllerProvider, (
      previous,
      next,
    ) {
      if (next.selectedContact != null &&
          previous?.selectedContact != next.selectedContact) {
        _handleSelection();
      } else if (next.pendingMultiPhone != null &&
          previous?.pendingMultiPhone != next.pendingMultiPhone) {
        _handleSelection();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Add Friend')),
      body: Column(
        children: [
          // Segmented control for tab selection.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'contacts',
                    label: Text('From Contacts'),
                  ),
                  ButtonSegment(value: 'manual', label: Text('Enter Number')),
                ],
                selected: {_selectedTab},
                onSelectionChanged: _onTabChanged,
              ),
            ),
          ),

          // Tab content.
          Expanded(
            child: _selectedTab == 'contacts'
                ? _buildContactsTab(permState, pickerState)
                : ManualPhoneEntryTab(
                    onSubmit: _onManualSubmit,
                    analyticsService: ref.read(analyticsServiceProvider),
                  ),
          ),
        ],
      ),
    );
  }

  /// Builds the contacts tab content, replicating the
  /// `ContactPickerScreen` body logic.
  Widget _buildContactsTab(
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
          return const Center(child: CircularProgressIndicator());
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
                        final contact = pickerState.filteredContacts[index];
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
