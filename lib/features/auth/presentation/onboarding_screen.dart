import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/coming_soon_sheet.dart';
import '../../../core/widgets/w_widgets.dart';
import '../../settings/theme_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  List<({String title, String subtitle, IconData icon, String? art})> _slides(
    BuildContext context,
  ) =>
      [
        (
          title: context.tr('onboarding.t1Title'),
          subtitle: context.tr('onboarding.t1Subtitle'),
          icon: Icons.storefront_outlined,
          art: 'cart',
        ),
        (
          title: context.tr('onboarding.t2Title'),
          subtitle: context.tr('onboarding.t2Subtitle'),
          icon: Icons.local_offer_outlined,
          art: null,
        ),
        (
          title: context.tr('onboarding.t3Title'),
          subtitle: context.tr('onboarding.t3Subtitle'),
          icon: Icons.verified_user_outlined,
          art: null,
        ),
        (
          title: context.tr('onboarding.t4Title'),
          subtitle: context.tr('onboarding.t4Subtitle'),
          icon: Icons.shield_outlined,
          art: null,
        ),
      ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _getStarted() async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slides = _slides(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  const WAppMark(),
                  const Spacer(),
                  if (_page < slides.length - 1)
                    TextButton(
                      onPressed: _getStarted,
                      child: Text(
                        context.tr('onboarding.skip'),
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, index) {
                  final s = slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _slideArt(s, index),
                        const SizedBox(height: 36),
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.subtitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(slides.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? Palette.gold
                        : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      _page == slides.length - 1 ? _getStarted : _next,
                  child: Text(
                    _page == slides.length - 1
                        ? context.tr('onboarding.getStarted')
                        : context.tr('onboarding.next'),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextButton(
                onPressed: () => _showCommunity(context),
                child: Text(
                  context.tr('onboarding.joinCommunity'),
                  style: TextStyle(
                    color: context.appColors.info,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _showCommunity(BuildContext context) {
    ComingSoonSheet.show(
      context,
      title: context.tr('onboarding.communityTitle'),
      description: context.tr('onboarding.communityDesc'),
      icon: Icons.groups_outlined,
      ctaLabel: context.tr('onboarding.openTelegram'),
    );
  }

  Widget _slideArt(
    ({String title, String subtitle, IconData icon, String? art}) s,
    int index,
  ) {
    if (index == 0) {
      return Image.asset('assets/images/onboarding_cart.png', height: 260);
    }
    final gradient = switch (index) {
      1 => const [Color(0xFFFFE9A8), Color(0xFFFFD60A)],
      2 => const [Color(0xFFDBEAFE), Color(0xFF93C5FD)],
      _ => const [Color(0xFFDCFCE7), Color(0xFF86EFAC)],
    };
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(s.icon, size: 84, color: Colors.black54),
    );
  }
}
