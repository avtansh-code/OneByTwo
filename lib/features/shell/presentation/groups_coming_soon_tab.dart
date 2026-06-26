import 'package:flutter/material.dart';

import 'package:onebytwo/core/widgets/feedback/obt_empty_state.dart';

/// Tab-2 content of the authenticated shell: the Haldi [OBTEmptyState]
/// stand-in for the Groups feature, which is built fresh in Sprint 4.
///
/// DC-05 **deletes** the former bespoke `GroupsListPlaceholder` throwaway
/// and composes the shared empty-state component here instead — the stub
/// is removed, not converted (AC-3). The 5-tab + FAB shell structure is
/// unchanged; only the tab-2 content becomes the shared design-system
/// empty-state. The tab owns its own [AppBar], per the shell's
/// no-injected-AppBar contract (architect §2.10).
class GroupsComingSoonTab extends StatelessWidget {
  /// Creates the Groups "coming soon" tab.
  const GroupsComingSoonTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(header: true, child: const Text('Groups')),
        automaticallyImplyLeading: false,
      ),
      body: const SafeArea(
        child: OBTEmptyState(
          illustration: Icon(Icons.groups_outlined, size: 72),
          headline: 'Groups — coming soon',
          supportingText:
              'Group expense splitting and shared balances arrive in a '
              'future update.',
        ),
      ),
    );
  }
}
