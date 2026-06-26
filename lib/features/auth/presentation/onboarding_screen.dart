import 'package:flutter/material.dart';
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
      icon: Icons.currency_rupee,
      headline: 'Track every shared spend',
      body: 'Log who paid for what in seconds — dinners, rent, trips, the lot.',
    ),
    // The ÷ brand mark stands literally between two friends (no icon).
    _SlideData(
      icon: null,
      headline: 'Split it any way you like',
      body:
          'Equally, by shares, by percentage, or exact rupees — '
          'we do the maths.',
    ),
    _SlideData(
      icon: Icons.check_rounded,
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
    if (await launcher.canLaunch(uri)) {
      await launcher.launchExternal(uri);
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
                onPageChanged: (index) => setState(() => _page = index),
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
class _SlideData {
  const _SlideData({
    required this.icon,
    required this.headline,
    required this.body,
  });

  /// The slide icon; `null` renders the ÷ brand mark instead.
  final IconData? icon;
  final String headline;
  final String body;
}

/// A single onboarding slide: a brand illustration holder, a Bricolage
/// hero headline, and a Hanken supporting line. Scrolls (rather than
/// overflows) under large dynamic type.
class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.data});

  final _SlideData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ExcludeSemantics(
              child: Container(
                width: 132,
                height: 132,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: data.icon == null
                    ? OBTBrandMark(size: 72, color: colorScheme.primary)
                    : Icon(data.icon, size: 60, color: colorScheme.primary),
              ),
            ),
            const SizedBox(height: 40),
            Semantics(
              header: true,
              child: Text(
                data.headline,
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              data.body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
