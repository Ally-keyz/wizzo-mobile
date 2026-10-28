import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/location/location_providers.dart';
import '../../../core/location/location_service.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/geo.dart';
import '../../../core/widgets/city_picker_sheet.dart';
import '../../../core/widgets/w_async.dart';
import '../../../core/widgets/w_image.dart';
import '../../../core/widgets/w_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/data/notification_repository.dart';
import '../../settings/theme_provider.dart';
import '../models/deal.dart';
import '../models/product.dart';
import '../models/seller.dart';
import '../providers/catalog_providers.dart';
import 'nearby_sellers_screen.dart';
import 'product_card.dart';
import 'product_shelf.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _greetingKey = 'home.greetingGoodDay';

  /// Category currently filtering the home feed; `null` means "All".
  String? _categorySlug;
  String? _categoryName;

  @override
  void initState() {
    super.initState();
    _computeGreeting();
    ref.read(nearbySellersProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoDetect());
  }

  /// Ask for the device location on first launch so the app can show the
  /// user's real city and nearby sellers instead of the Kigali default.
  Future<void> _maybeAutoDetect() async {
    if (await AppPrefs.locationPrompted()) return;
    if (!mounted) return;
    // Respect a city the user already chose (or coordinates we already have).
    if ((await AppPrefs.lastCity()).isNotEmpty) return;
    if (await AppPrefs.lastCoords() != null) return;
    if (!mounted) return;
    await _detectAndSaveLocation();
    if (mounted) await AppPrefs.setLocationPrompted(true);
  }

  /// Triggers the native location permission prompt, then persists the
  /// detected coordinates and city. Returns the city label, or null on failure.
  Future<String?> _detectAndSaveLocation() async {
    final result = await ref.read(locationServiceProvider).detect();
    final loc = result.location;
    if (loc == null) {
      if (mounted) _showLocationError(result.failure);
      return null;
    }
    if (mounted) {
      await ref
          .read(savedCoordsProvider.notifier)
          .set(NumPoint(lat: loc.latitude, lng: loc.longitude));
      if (loc.label.isNotEmpty) {
        await ref.read(lastCityProvider.notifier).setCity(loc.label);
      }
    }
    return loc.label.isNotEmpty ? loc.label : null;
  }

  void _showLocationError(LocationFailure? failure) {
    final service = ref.read(locationServiceProvider);
    final denied =
        failure == LocationFailure.denied ||
        failure == LocationFailure.deniedForever;
    final serviceOff = failure == LocationFailure.serviceDisabled;
    final key = denied
        ? 'city.locationDenied'
        : serviceOff
        ? 'city.locationServiceOff'
        : 'city.locationUnavailable';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(context.tr(key)),
          action: denied
              ? SnackBarAction(
                  label: context.tr('city.openSettings'),
                  onPressed: service.openAppSettings,
                )
              : serviceOff
              ? SnackBarAction(
                  label: context.tr('city.turnOnLocation'),
                  onPressed: service.openLocationSettings,
                )
              : null,
        ),
      );
  }

  void _computeGreeting() {
    final hour = DateTime.now().hour;
    _greetingKey = hour < 12
        ? 'home.greetingMorning'
        : hour < 17
        ? 'home.greetingAfternoon'
        : 'home.greetingEvening';
  }

  Future<void> _openNotifications(BuildContext context) async {
    if (context.mounted) context.push('/notifications');
  }

  Future<void> _openSearch(BuildContext context) async {
    if (context.mounted) context.push('/search');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userName = ref.watch(authDisplayNameProvider);
    final unreadNotifications =
        ref.watch(notificationsUnreadProvider).value ?? 0;

    // Light mode paints the home app bar and the category filter strip in the
    // same light-zinc tone. Dark mode keeps the plain canvas colour.
    final barColor = theme.brightness == Brightness.light
        ? Palette.lightMuted
        : theme.colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: barColor,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 52,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: WAppMark(size: 26),
        ),
        titleSpacing: 6,
        // The old full-width search bar moved up here as a compact field.
        title: Row(
          children: [
            Expanded(
              child: _AppBarSearchField(onTap: () => _openSearch(context)),
            ),
          ],
        ),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => _openNotifications(context),
            icon: Badge(
              isLabelVisible: unreadNotifications > 0,
              backgroundColor: Palette.gold,
              textColor: Colors.black,
              label: Text(
                unreadNotifications > 99 ? '99+' : '$unreadNotifications',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Icon(Icons.notifications_none),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final jobs = <Future<dynamic>>[
            ref.refresh(homeFeedProvider.future),
            ref.refresh(homeDealsProvider.future),
            ref.refresh(promotedProductsProvider.future),
            ref.refresh(topSellersProvider.future),
          ];
          final slug = _categorySlug;
          if (slug != null) {
            jobs.add(ref.refresh(categoryProductsProvider(slug).future));
          }
          await Future.wait(jobs);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  context.tr(
                    userName?.isNotEmpty == true
                        ? 'home.greetingWithName'
                        : 'home.greetingOnly',
                    namedArgs: {
                      'greeting': context.tr(_greetingKey),
                      'name': userName ?? '',
                    },
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  context.tr('home.tagline'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _HomeCategoriesRail(
                selectedSlug: _categorySlug,
                onSelected: (category) {
                  setState(() {
                    // Tapping the active chip clears the filter.
                    final isSame =
                        category != null && category.slug == _categorySlug;
                    _categorySlug = isSame ? null : category?.slug;
                    _categoryName = isSame ? null : category?.name;
                  });
                },
              ),
            ),
            SliverToBoxAdapter(child: _cityBar(context)),

            // Promo / deals rail
            SliverToBoxAdapter(
              child: _DealsSection(onSeeAll: () => context.push('/deals/all')),
            ),

            // View Shorts pill
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: Material(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => context.push('/shorts'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context.tr('common.viewShorts'),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const Icon(
                            Icons.navigate_next,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // For You section — the grid follows the active category chip.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _categoryName ?? context.tr('home.forYou'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push(
                        _categorySlug == null
                            ? '/search'
                            : '/browse/$_categorySlug',
                      ),
                      child: Text(
                        context.tr('common.seeAll'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_categorySlug == null)
              _ForYouSection()
            else
              _CategoryFeedSection(slug: _categorySlug!),

            // Continue viewing CTA — keeps the endless For You scroll going.
            if (_categorySlug == null)
              const SliverToBoxAdapter(child: _ContinueViewingButton()),

            // Top sellers rail
            SliverToBoxAdapter(
              child: _TopSellersSection(sellers: ref.watch(topSellersProvider)),
            ),

            // Community CTA
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: GoldCTA(
                  label: context.tr('home.communityCta'),
                  subtitle: context.tr('home.communitySubtitle'),
                  icon: Icons.groups_outlined,
                  onTap: () => _openWhatsAppCommunity(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cityBar(BuildContext context) {
    final theme = Theme.of(context);
    final city = ref.watch(lastCityProvider);
    final label = city.isEmpty ? AppConfig.defaultCity : city;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: GestureDetector(
        onTap: () => _changeCity(context, label),
        child: Row(
          children: [
            Icon(Icons.location_on, size: 16, color: context.appColors.info),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.appColors.info,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: context.appColors.info),
          ],
        ),
      ),
    );
  }

  Future<void> _changeCity(BuildContext context, String current) async {
    final picked = await showCityPicker(
      context,
      current,
      onUseCurrentLocation: _detectAndSaveLocation,
    );
    if (picked != null && picked.isNotEmpty) {
      await ref.read(lastCityProvider.notifier).setCity(picked);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(
                context.tr('home.browsingCity', namedArgs: {'city': picked}),
              ),
              duration: const Duration(milliseconds: 1200),
            ),
          );
      }
    }
  }

  /// Opens the Wizzo WhatsApp community group.
  static const _whatsAppCommunityUrl =
      'https://chat.whatsapp.com/HEeBCmTxFVKAXLNsU8hbZT?s=cl&p=i&mlu=4&ilr=4';

  Future<void> _openWhatsAppCommunity(BuildContext context) async {
    final launched = await launchUrl(
      Uri.parse(_whatsAppCommunityUrl),
      mode: LaunchMode.externalApplication,
    );
    if (launched || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(context.tr('common.linkOpenError')),
      ),
    );
  }
}

/// Compact, non-editable search field that lives in the home app bar. Tapping
/// it opens the full search screen, exactly like the old full-width field.
class _AppBarSearchField extends StatelessWidget {
  const _AppBarSearchField({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    return Semantics(
      button: true,
      label: context.tr('home.searchPlaceholder'),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isLight ? scheme.surface : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: scheme.outline),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('home.searchPlaceholder'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrolling category chips that filter the home feed in place.
class _HomeCategoriesRail extends ConsumerWidget {
  const _HomeCategoriesRail({
    required this.selectedSlug,
    required this.onSelected,
  });

  final String? selectedSlug;
  final ValueChanged<CategoryNode?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesProvider);
    final list = categories.value ?? const <CategoryNode>[];
    final bandColor = theme.brightness == Brightness.light
        ? Palette.lightMuted
        : theme.colorScheme.surface;

    if (list.isEmpty) {
      // Keep the band from flashing while the tree loads; hide it entirely on
      // error (the Categories tab still reaches every category).
      if (categories.hasError) return const SizedBox.shrink();
      return Container(
        height: 56,
        color: bandColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: const Row(
          children: [
            WSkeleton(width: 56, height: 34, radius: 17),
            SizedBox(width: 8),
            WSkeleton(width: 92, height: 34, radius: 17),
            SizedBox(width: 8),
            WSkeleton(width: 76, height: 34, radius: 17),
          ],
        ),
      );
    }

    return Container(
      height: 56,
      color: bandColor,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: list.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CategoryChip(
              label: context.tr('home.all'),
              selected: selectedSlug == null,
              onTap: () => onSelected(null),
            );
          }
          final category = list[index - 1];
          return _CategoryChip(
            label: category.name,
            selected: selectedSlug == category.slug,
            onTap: () => onSelected(category),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    return Material(
      color: selected
          ? Palette.gold
          : (isLight ? scheme.surface : scheme.surfaceContainerHighest),
      shape: StadiumBorder(
        side: BorderSide(color: selected ? Palette.gold : scheme.outline),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected ? Colors.black : scheme.onSurface,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Product grid for the selected home category (the "For You" grid while a
/// category chip is active).
class _CategoryFeedSection extends ConsumerWidget {
  const _CategoryFeedSection({required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(categoryProductsProvider(slug));

    if (products.isLoading && products.value == null) {
      return const SliverToBoxAdapter(child: ProductGridSkeleton());
    }

    if (products.hasError && products.value == null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 32),
          child: WAsyncView(
            value: products,
            onRetry: () => ref.invalidate(categoryProductsProvider(slug)),
            builder: (_, _) => const SizedBox(),
          ),
        ),
      );
    }

    final list = products.value ?? const <Product>[];
    if (list.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
          child: Text(
            context.tr('home.noCategoryProducts'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return SliverProductGrid(products: list);
  }
}

final authDisplayNameProvider = Provider<String?>((ref) {
  return ref.watch(authControllerProvider).user?.fullName;
});

class _DealsSection extends ConsumerStatefulWidget {
  const _DealsSection({required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  ConsumerState<_DealsSection> createState() => _DealsSectionState();
}

class _DealsSectionState extends ConsumerState<_DealsSection> {
  static const _autoAdvance = Duration(seconds: 5);
  static const _gutter = 20.0;
  static const _bannerHeight = 190.0;

  // Full-viewport pages with an inner gutter: exactly one banner is visible at
  // rest, centred with equal space on both sides, instead of a rail of peeking
  // product cards.
  final _controller = PageController();
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_autoAdvance, (_) => _advance());
  }

  /// Number of slides currently shown: deal banners win, promoted products are
  /// the fallback when no deal banner is configured.
  int _slideCount() {
    final deals = ref.read(homeDealsProvider).value ?? const <Deal>[];
    if (deals.isNotEmpty) return deals.length;
    return (ref.read(promotedProductsProvider).value ?? const <Product>[])
        .length;
  }

  void _advance() {
    if (!mounted || !_controller.hasClients) return;
    final count = _slideCount();
    if (count <= 1) return;
    final next = (_current + 1) % count;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dealsAsync = ref.watch(homeDealsProvider);
    final promotedAsync = ref.watch(promotedProductsProvider);

    // Deal banners are the richer presentation, so keep them when we have any.
    final deals = dealsAsync.value ?? const <Deal>[];
    final promoted = promotedAsync.value ?? const <Product>[];

    // Nothing on promotion at all: drop the heading too, rather than leaving
    // an "Exclusive Deals" title with an empty gap underneath it.
    if (deals.isEmpty &&
        promoted.isEmpty &&
        !dealsAsync.isLoading &&
        !promotedAsync.isLoading) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('deals.exclusive'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: widget.onSeeAll,
                  child: Row(
                    children: [
                      Text(
                        context.tr('common.seeAll'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: context.appColors.info,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Color(0xFF3B82F6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (deals.isNotEmpty)
            _carousel(
              count: deals.length,
              itemBuilder: (_, i) =>
                  _DealCarouselCard(deal: deals[i], onTap: widget.onSeeAll),
            )
          else if (promoted.isNotEmpty)
            _carousel(
              count: promoted.length,
              itemBuilder: (_, i) =>
                  _PromotedCarouselCard(product: promoted[i]),
            )
          else if (promotedAsync.isLoading)
            _loadingBanner(context),
          if (deals.length > 1 || (deals.isEmpty && promoted.length > 1))
            _dots(context, deals.isNotEmpty ? deals.length : promoted.length),
        ],
      ),
    );
  }

  /// Single-slide carousel. Each page is inset by [_gutter] on both sides, so
  /// the banner is ~90% of the screen width and only one is visible at a time.
  Widget _carousel({
    required int count,
    required IndexedWidgetBuilder itemBuilder,
  }) {
    return SizedBox(
      height: _bannerHeight,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // Pause while the user drags, resume once the page settles so the
          // banner being read is not yanked away.
          if (notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            _timer?.cancel();
          } else if (notification is ScrollEndNotification) {
            _restartTimer();
          }
          return false;
        },
        child: PageView.builder(
          controller: _controller,
          itemCount: count,
          onPageChanged: (i) {
            setState(() => _current = i);
            _restartTimer();
          },
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: _gutter),
            child: itemBuilder(context, i),
          ),
        ),
      ),
    );
  }

  Widget _dots(BuildContext context, int count) {
    final active = _current.clamp(0, count - 1);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final isActive = i == active;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isActive ? 20 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: isActive
                  ? Palette.gold
                  : Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  /// Placeholder in the same 90%-wide footprint while promotions load.
  Widget _loadingBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _gutter),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: _bannerHeight,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
    );
  }
}

/// Full-bleed banner card for one deal inside the auto-advancing carousel.
class _DealCarouselCard extends StatelessWidget {
  const _DealCarouselCard({required this.deal, required this.onTap});

  final Deal deal;
  final VoidCallback onTap;

  String _typeLabel(BuildContext context) => switch (deal.type) {
    DealType.flash => context.tr('deals.flashSale'),
    DealType.today => context.tr('deals.todayDeal'),
    DealType.limited => context.tr('deals.limitedOffer'),
    DealType.clearance => context.tr('deals.clearance'),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bannerUrl = deal.bannerUrl ?? deal.imageUrl;
    final productCount = deal.productCount ?? deal.products.length;

    // A designed banner fills the whole slide. Without one we fall back to the
    // product-photo layout, whose image panel is full-bleed too.
    if (bannerUrl == null) {
      return _PromoSlide(
        imageUrl: _firstProductImage(deal),
        title: deal.title,
        subtitle: deal.subtitle,
        onTap: onTap,
        badges: [
          _SlidePill(_typeLabel(context), highlight: true),
          if (deal.discountPercent != null)
            _SlidePill('-${deal.discountPercent}%'),
        ],
        footer: Wrap(
          spacing: 10,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            WCountdown(deal.endsAt),
            if (productCount > 0)
              Text(
                context.tr(
                  'deals.productCount',
                  namedArgs: {'count': '$productCount'},
                ),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            WImage(url: bannerUrl, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.72),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Palette.gold,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _typeLabel(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      if (deal.discountPercent != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '-${deal.discountPercent}%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    deal.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (deal.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      deal.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      WCountdown(deal.endsAt, light: true),
                      if (productCount > 0)
                        Text(
                          context.tr(
                            'deals.productCount',
                            namedArgs: {'count': '$productCount'},
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String? _firstProductImage(Deal deal) {
    for (final p in deal.products) {
      if (p.images.isNotEmpty) return p.images.first;
    }
    return null;
  }
}

/// Product-backed promo slide: the photo is shown whole (`BoxFit.contain`)
/// beside the details instead of being cropped into a banner-shaped box.
class _PromotedCarouselCard extends StatelessWidget {
  const _PromotedCarouselCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return _PromoSlide(
      imageUrl: product.images.isNotEmpty ? product.images.first : null,
      title: product.name,
      onTap: () => context.push('/product/${product.id}'),
      badges: [
        if (product.discount > 0)
          _SlidePill('-${product.discount}%', highlight: true),
      ],
      price: PriceRow(
        price: product.price,
        originalPrice: product.originalPrice,
      ),
    );
  }
}

/// Image + details slide shared by product promotions and deal cards that have
/// no designed banner. The photo fills its panel edge to edge (cropped to fit)
/// so the card never shows empty letterbox bands beside the image.
class _PromoSlide extends StatelessWidget {
  const _PromoSlide({
    required this.title,
    required this.onTap,
    this.imageUrl,
    this.subtitle,
    this.badges = const [],
    this.price,
    this.footer,
  });

  final String title;
  final VoidCallback onTap;
  final String? imageUrl;
  final String? subtitle;
  final List<Widget> badges;
  final Widget? price;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Full-bleed image panel: the photo fills the whole left side of
            // the card (edge to edge, top to bottom) instead of being
            // letterboxed inside a padded box.
            SizedBox(
              width: 132,
              child: imageUrl != null
                  ? WImage(url: imageUrl, fit: BoxFit.cover)
                  : ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.image_outlined,
                        size: 32,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (badges.isNotEmpty)
                      Wrap(spacing: 6, runSpacing: 4, children: badges),
                    const Spacer(),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (price != null) ...[const SizedBox(height: 6), price!],
                    if (footer != null) ...[const SizedBox(height: 6), footer!],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlidePill extends StatelessWidget {
  const _SlidePill(this.text, {this.highlight = false});

  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: highlight
            ? Palette.gold
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: highlight ? Colors.black : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ForYouSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(homeFeedProvider);

    if (feedAsync.isLoading && feedAsync.value == null) {
      return const SliverToBoxAdapter(child: ProductGridSkeleton());
    }

    if (feedAsync.hasError && feedAsync.value == null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 32),
          child: WAsyncView(
            value: feedAsync,
            onRetry: () => ref.invalidate(homeFeedProvider),
            builder: (_, _) => const SizedBox(),
          ),
        ),
      );
    }

    final products = feedAsync.value?.items ?? const <Product>[];
    if (products.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox(height: 32));
    }

    return SliverProductGrid(products: products);
  }
}

class _ContinueViewingButton extends ConsumerStatefulWidget {
  const _ContinueViewingButton();

  @override
  ConsumerState<_ContinueViewingButton> createState() =>
      _ContinueViewingButtonState();
}

class _ContinueViewingButtonState
    extends ConsumerState<_ContinueViewingButton> {
  bool _loading = false;

  Future<void> _loadMore() async {
    setState(() => _loading = true);
    await ref.read(homeFeedProvider.notifier).loadMore();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feed = ref.watch(homeFeedProvider);
    final products = feed.value?.items ?? const <Product>[];
    if (products.isEmpty || !(feed.value?.hasNext ?? false)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: Palette.gold,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _loading ? null : _loadMore,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_loading) ...[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Palette.navy,
                    ),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  const Icon(
                    Icons.play_circle_fill,
                    color: Palette.navy,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    context.tr('home.continueViewing'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Palette.navy,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (!_loading) ...[
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.chevron_right,
                    color: Palette.navy,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopSellersSection extends ConsumerWidget {
  const _TopSellersSection({required this.sellers});

  final AsyncValue<List<Seller>> sellers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final list = sellers.value ?? const <Seller>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('home.topSellers'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/sellers/nearby'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr('home.nearbySellers'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 118,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: list.isEmpty ? 4 : list.length,
            itemBuilder: (context, i) {
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Row(
                    children: [
                      WSkeleton(width: 64, height: 64, radius: 32),
                      SizedBox(width: 8),
                    ],
                  ),
                );
              }
              final seller = list[i];
              return Padding(
                padding: const EdgeInsets.only(right: 18),
                child: SellerMiniCard(seller: seller),
              );
            },
          ),
        ),
      ],
    );
  }
}
