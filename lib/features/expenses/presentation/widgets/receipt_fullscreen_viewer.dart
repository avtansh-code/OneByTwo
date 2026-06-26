import 'dart:io';

import 'package:flutter/material.dart';

import 'package:onebytwo/features/expenses/domain/expense_draft.dart';

/// Fullscreen viewer for a receipt image (SCR-21 §Accessibility line
/// 372 — "Receipt image attached. Double-tap to view full size.").
///
/// Wraps a simple [Dialog] around an [InteractiveViewer] holding
/// either the local picker `XFile` or the remote download URL. Tap
/// outside the image OR tap the close button to dismiss. No zoom
/// gesture polish for v1.0 per architect §2.x (recommended a simple
/// `Dialog + InteractiveViewer + Image.network`).
class ReceiptFullscreenViewer extends StatelessWidget {
  /// Creates a [ReceiptFullscreenViewer]. At least one of
  /// `draft.receiptFile` or `draft.existingReceiptUrl` must be
  /// non-null; if both are null the viewer renders an empty box (no
  /// crash, but it should not be opened in that state).
  const ReceiptFullscreenViewer({required this.draft, super.key});

  /// Optional draft binding when launched from the Add Expense
  /// bottom sheet's Step 3 (carries either the picker file or the
  /// pre-existing URL).
  final ExpenseDraft? draft;

  /// Direct URL binding when launched from the Expense Detail
  /// screen's thumbnail tap (carries only the URL).
  static Widget fromUrl(String url) => _UrlViewer(url: url);

  @override
  Widget build(BuildContext context) {
    return _BaseViewer(child: _DraftImage(draft: draft));
  }
}

class _UrlViewer extends StatelessWidget {
  const _UrlViewer({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return _BaseViewer(
      child: Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 64,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _BaseViewer extends StatelessWidget {
  const _BaseViewer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog.fullscreen(
      backgroundColor: colors.scrim,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(child: child),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftImage extends StatelessWidget {
  const _DraftImage({required this.draft});

  final ExpenseDraft? draft;

  @override
  Widget build(BuildContext context) {
    final d = draft;
    if (d == null) return const SizedBox.shrink();
    final file = d.receiptFile;
    if (file != null) {
      return Image.file(File(file.path), fit: BoxFit.contain);
    }
    final url = d.existingReceiptUrl;
    if (url != null) {
      return Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 64,
            color: Colors.white,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
