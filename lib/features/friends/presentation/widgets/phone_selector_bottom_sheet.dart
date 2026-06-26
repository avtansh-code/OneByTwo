import 'package:flutter/material.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';

/// Shows a modal bottom sheet allowing the user to choose from multiple
/// phone numbers (SCR-10 / Haldi 10), reskinned to the Haldi sheet
/// radius + overline title (DC-06).
///
/// Each phone number is displayed as a [ListTile]. When tapped, the
/// [onSelect] callback is invoked with the chosen number and the sheet
/// is closed.
Future<void> showPhoneSelector({
  required BuildContext context,
  required List<String> phones,
  required void Function(String) onSelect,
}) {
  return showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTheme.radiusSheet),
      ),
    ),
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Choose a phone number',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: OBTColors.metaText(theme),
                  letterSpacing: 0.6,
                ),
              ),
            ),
            ...phones.map(
              (phone) => ListTile(
                title: Text(phone, style: theme.textTheme.bodyLarge),
                onTap: () {
                  Navigator.of(context).pop();
                  onSelect(phone);
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
