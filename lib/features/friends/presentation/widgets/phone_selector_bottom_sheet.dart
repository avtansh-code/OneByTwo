import 'package:flutter/material.dart';

/// Shows a modal bottom sheet allowing the user to choose from multiple
/// phone numbers.
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
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Choose a phone number',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...phones.map(
              (phone) => ListTile(
                title: Text(phone),
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
