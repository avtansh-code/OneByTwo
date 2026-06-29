import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/constants/legal_urls.dart';
import 'package:onebytwo/core/services/url_launcher_service.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/branding/obt_brand.dart';
import 'package:onebytwo/features/auth/application/onboarding_provider.dart';

/// First-launch onboarding (Haldi 2 — net-new in DC-04).
///
/// Three illustrated slides (Track / Split / Settle) in a [PageView] with
/// pagination dots, an always-available Skip, an ink-on-marigold
/// "Get started" CTA on the final slide, and the Terms of Service /
/// Privacy Policy links (SRS section 10). Shown exactly once on first
/// launch (gated by [hasSeenOnboardingProvider]) before phone entry; both
/// Skip and "Get started" mark it seen, which rebuilds the auth gate
/// (`OneBytwoApp`) to advance to phone entry.
///
/// This is the visual/onboarding layer only: it touches no money, balance,
/// share, or project surface, so all four invariants hold unchanged. It
/// adds only its own screen, a local first-launch flag, and the legal-link
/// launch (the system handler — Invariant 3 N/A: an outbound link, not
/// sharing).
class OnboardingScreen extends ConsumerStatefulWidget {
  /// Creates an [OnboardingScreen].
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  static const List<_SlideData> _slides = <_SlideData>[
    _SlideData(
      art: _SlideArt.track,
      headline: 'Track every shared spend',
      body: 'Log who paid for what in seconds — dinners, rent, trips, the lot.',
    ),
    // The ÷ brand mark stands literally between two friends.
    _SlideData(
      art: _SlideArt.split,
      headline: 'Split it any way you like',
      body:
          'Equally, by shares, by percentage, or exact rupees — '
          'we do the maths.',
    ),
    _SlideData(
      art: _SlideArt.settle,
      headline: 'Settle up in a single tap',
      body:
          "We simplify everyone's debts to the fewest payments. "
          'No awkward maths.',
    ),
  ];

  bool get _isLastPage => _page == _slides.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    // Reduced motion (an accessibility requirement) jumps instead of slides.
    if (MediaQuery.of(context).disableAnimations) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(
        index,
        duration: AppTheme.motionDurationMedium,
        curve: AppTheme.motionCurve,
      );
    }
  }

  void _next() {
    if (!_isLastPage) _goToPage(_page + 1);
  }

  /// Marks onboarding seen (Skip / Get started). The auth gate observes
  /// [hasSeenOnboardingProvider] and replaces this screen with phone entry.
  Future<void> _finish() async {
    await ref.read(hasSeenOnboardingProvider.notifier).markSeen();
  }

  Future<void> _openUrl(String url) async {
    final launcher = ref.read(urlLauncherServiceProvider);
    final uri = Uri.parse(url);
    var launched = false;
    if (await launcher.canLaunch(uri)) {
      try {
        launched = await launcher.launchExternal(uri);
      } on PlatformException catch (_) {
        // A canLaunch false-positive must not crash; fall back below.
      }
    }
    // Mirror the contact-support fallback: never fail silently — surface the
    // URL so a browserless device still has a path to the document.
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Semantics(
            liveRegion: true,
            child: Text('Could not open the link. Visit $url'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Top bar — Skip, hidden on the terminal CTA slide.
            SizedBox(
              height: 48,
              child: _isLastPage
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: TextButton(
                          onPressed: _finish,
                          child: const Text('Skip'),
                        ),
                      ),
                    ),
            ),

            // Slides.
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() => _page = index);
                  // Announce the new slide so assistive tech gets a
                  // page-change cue (the headers alone are silent on swipe).
                  SemanticsService.sendAnnouncement(
                    View.of(context),
                    _slides[index].headline,
                    Directionality.of(context),
                  );
                },
                itemBuilder: (context, index) =>
                    _OnboardingSlide(data: _slides[index]),
              ),
            ),

            // Bottom controls — dots + next-FAB, or the CTA + legal links.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: _isLastPage
                  ? _FinalControls(
                      dots: _Dots(count: _slides.length, active: _page),
                      onGetStarted: _finish,
                      onTerms: () => _openUrl(LegalUrls.termsOfService),
                      onPrivacy: () => _openUrl(LegalUrls.privacyPolicy),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        _Dots(count: _slides.length, active: _page),
                        FloatingActionButton(
                          onPressed: _next,
                          tooltip: 'Next',
                          elevation: 0,
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            semanticLabel: 'Next',
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Immutable copy + illustration descriptor for one onboarding slide.
enum _SlideArt { track, split, settle }

class _SlideData {
  const _SlideData({
    required this.art,
    required this.headline,
    required this.body,
  });

  /// Which flat spot-illustration to render in the slide's panel.
  final _SlideArt art;
  final String headline;
  final String body;
}

/// A single onboarding slide: a flat spot-illustration in a tonal panel, a
/// left-aligned Bricolage hero headline, and a Hanken supporting line.
/// Scrolls (rather than overflows) under large dynamic type.
class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.data});

  final _SlideData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // The flat spot-illustration panel (300 dp tall, tonal, radius 28).
          ExcludeSemantics(
            child: Container(
              height: 288,
              margin: const EdgeInsets.fromLTRB(28, 8, 28, 0),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Center(child: _SlideArtwork(art: data.art)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 32, 30, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    data.headline,
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontSize: 27,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  data.body,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The flat, geometric spot-illustration for each slide, recreated from the
/// handoff's rounded shapes (receipt + rupee coin; the ÷ between two
/// friends; a success check with accent dots).
class _SlideArtwork extends StatelessWidget {
  const _SlideArtwork({required this.art});

  final _SlideArt art;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final teal = obtColors.balancePositive;

    switch (art) {
      case _SlideArt.track:
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Transform.rotate(
              angle: -0.105,
              child: Container(
                width: 128,
                height: 160,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  children: <Widget>[
                    Container(height: 13, color: colorScheme.primary),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: <Widget>[
                          for (final w in const <double>[1, 0.72, 1, 0.55])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: w,
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: colorScheme.outlineVariant,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 56,
              bottom: 54,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: teal, shape: BoxShape.circle),
                child: const Icon(
                  Icons.currency_rupee,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ],
        );
      case _SlideArt.split:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _dot(58, colorScheme.primary),
            const SizedBox(width: 10),
            OBTBrandMark(size: 44, color: colorScheme.secondary),
            const SizedBox(width: 10),
            _dot(58, teal),
          ],
        );
      case _SlideArt.settle:
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: teal, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 58),
            ),
            Positioned(left: 72, top: 58, child: _dot(24, colorScheme.primary)),
            Positioned(
              right: 64,
              bottom: 64,
              child: _dot(16, colorScheme.secondary),
            ),
          ],
        );
    }
  }

  Widget _dot(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Pagination dots — the active dot is an elongated marigold pill, the
/// rest are neutral. Decorative (the live slide carries its own header).
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(count, (i) {
          final isActive = i == active;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? colorScheme.primary : colorScheme.outline,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
          );
        }),
      ),
    );
  }
}

/// The terminal-slide controls: dots, the ink-on-marigold "Get started"
/// CTA, and the Terms / Privacy legal links (SRS section 10).
class _FinalControls extends StatelessWidget {
  const _FinalControls({
    required this.dots,
    required this.onGetStarted,
    required this.onTerms,
    required this.onPrivacy,
  });

  final Widget dots;
  final VoidCallback onGetStarted;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        dots,
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onGetStarted,
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusButton),
              ),
            ),
            child: const Text('Get started'),
          ),
        ),
        const SizedBox(height: 14),
        _LegalLine(onTerms: onTerms, onPrivacy: onPrivacy),
      ],
    );
  }
}

/// "By continuing you agree to our [Terms of Service] & [Privacy Policy]."
/// rendered as a centred line with two real, labelled, 48 dp link buttons.
class _LegalLine extends StatelessWidget {
  const _LegalLine({required this.onTerms, required this.onPrivacy});

  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: OBTColors.metaText(theme),
    );
    final linkStyle = TextButton.styleFrom(
      foregroundColor: obtColors.link,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      textStyle: theme.textTheme.bodySmall?.copyWith(
        decoration: TextDecoration.underline,
      ),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text('By continuing you agree to our', style: metaStyle),
        TextButton(
          onPressed: onTerms,
          style: linkStyle,
          child: const Text('Terms of Service'),
        ),
        Text('&', style: metaStyle),
        TextButton(
          onPressed: onPrivacy,
          style: linkStyle,
          child: const Text('Privacy Policy'),
        ),
      ],
    );
  }
}
