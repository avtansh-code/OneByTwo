import 'package:flutter/material.dart';

import 'package:onebytwo/core/theme/obt_colors.dart';

/// Connectivity / sync status driving [OBTOfflineBanner].
enum OBTSyncStatus {
  /// Connected and fully synced — the banner is hidden.
  online,

  /// No connectivity — the offline bar is shown.
  offline,

  /// Connected but with local writes still flushing to the server.
  pendingSync,
}

/// Global offline / pending-sync banner (foundation plan section 4.2 #8).
///
/// Presentational only — DC-03 ships the primitive; the connectivity
/// wiring (which host overlays it on every surface) is a later
/// conversion concern. Renders nothing for [OBTSyncStatus.online], an
/// amber offline bar for [OBTSyncStatus.offline], and a "Syncing N
/// changes" bar for [OBTSyncStatus.pendingSync].
///
/// The status is announced as text (`liveRegion`) so the signal is never
/// colour alone (bed + icon + label). Under
/// [MediaQueryData.disableAnimations] the sync glyph does not spin.
class OBTOfflineBanner extends StatefulWidget {
  /// Creates an [OBTOfflineBanner].
  const OBTOfflineBanner({
    required this.status,
    this.pendingCount = 0,
    super.key,
  });

  /// The connectivity / sync status to render.
  final OBTSyncStatus status;

  /// Number of pending local changes shown in the
  /// [OBTSyncStatus.pendingSync] state.
  final int pendingCount;

  @override
  State<OBTOfflineBanner> createState() => _OBTOfflineBannerState();
}

class _OBTOfflineBannerState extends State<OBTOfflineBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSpin();
  }

  @override
  void didUpdateWidget(OBTOfflineBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSpin();
  }

  void _syncSpin() {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final shouldSpin =
        widget.status == OBTSyncStatus.pendingSync && !reduceMotion;
    if (shouldSpin) {
      if (!_spin.isAnimating) {
        _spin.repeat();
      }
    } else {
      if (_spin.isAnimating) {
        _spin.stop();
      }
      _spin.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status == OBTSyncStatus.online) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isOffline = widget.status == OBTSyncStatus.offline;

    final warning = theme.extension<OBTColors>()?.warning ?? colors.secondary;
    final background = isOffline ? warning : colors.surfaceContainerHighest;
    // Ink reads AA on the amber bed in both themes; onSurface on the warm
    // surface bed for pending-sync.
    final foreground = isOffline ? colors.onPrimary : colors.onSurface;

    final label = isOffline
        ? 'You are offline. Changes will sync when you reconnect.'
        : _pendingLabel(widget.pendingCount);

    final icon = isOffline
        ? Icon(Icons.cloud_off, size: 18, color: foreground)
        : RotationTransition(
            turns: _spin,
            child: Icon(Icons.sync, size: 18, color: foreground),
          );

    return Semantics(
      liveRegion: true,
      label: label,
      child: Material(
        color: background,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: <Widget>[
              ExcludeSemantics(child: icon),
              const SizedBox(width: 10),
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _pendingLabel(int count) {
    final noun = count == 1 ? 'change' : 'changes';
    return 'Syncing $count $noun…';
  }
}
