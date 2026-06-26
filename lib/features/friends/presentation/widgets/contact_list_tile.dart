import 'package:flutter/material.dart';

import 'package:onebytwo/core/theme/obt_colors.dart';

/// A list tile displaying a device contact's name and phone number.
///
/// Shows a [CircleAvatar] with the first letter of the contact's name,
/// the display name in bold, and the first phone number as a subtitle.
/// Reskinned to the Haldi meta-text token (DC-06).
class ContactListTile extends StatelessWidget {
  /// Creates a [ContactListTile].
  const ContactListTile({
    required this.displayName,
    required this.phoneNumber,
    required this.onTap,
    super.key,
  });

  /// The contact's display name.
  final String displayName;

  /// The first phone number to display as a subtitle.
  final String phoneNumber;

  /// Called when the tile is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Semantics(
      label: '$displayName, $phoneNumber',
      child: ListTile(
        leading: CircleAvatar(child: Text(initial)),
        title: Text(
          displayName,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          phoneNumber,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: OBTColors.metaText(theme),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
