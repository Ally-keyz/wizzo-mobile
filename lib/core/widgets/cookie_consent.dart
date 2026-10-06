import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../storage/app_prefs.dart';

class CookieConsentBanner extends StatefulWidget {
  const CookieConsentBanner({super.key});

  @override
  State<CookieConsentBanner> createState() => _CookieConsentBannerState();
}

class _CookieConsentBannerState extends State<CookieConsentBanner> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    AppPrefs.cookieConsent().then((v) {
      if (mounted && v == null) setState(() => _visible = true);
    });
  }

  Future<void> _choose(String value) async {
    await AppPrefs.setCookieConsent(value);
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('cookies.bannerText'),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _choose('denied'),
                    child: Text(context.tr('cookies.deny')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _choose('accepted'),
                    child: Text(context.tr('cookies.allow')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
