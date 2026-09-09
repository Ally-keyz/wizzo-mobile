import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/city_picker_sheet.dart';
import '../../../core/widgets/w_async.dart';
import '../../../core/widgets/w_image.dart';
import '../../../core/widgets/w_widgets.dart';
import '../../../core/widgets/coming_soon_sheet.dart';
import '../../../core/widgets/fly_to_cart.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/data/notification_repository.dart';
import '../../settings/theme_provider.dart';
import '../models/deal.dart';
import '../models/product.dart';
import '../models/seller.dart';
import '../providers/catalog_providers.dart';
import 'nearby_sellers_screen.dart';
import 'product_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _greetingKey = 'home.greetingGoodDay';

  @override
  void initState() {
    super.initState();
    _computeGreeting();
    ref.read(nearbySellersProvider);
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

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: WAppMark(size: 30),
        ),
        titleSpacing: 8,
        title: Text(
          'Wizzo',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
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
          IconButton(
            onPressed: () => _openSearch(context),
            icon: const Icon(Icons.search),
          ),
          const CartAppBarAction(),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.refresh(homeFeedProvider.future),
            ref.refresh(homeDealsProvider.future),
            ref.refresh(topSellersProvider.future),
          ]);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _cityBar(context)),
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
                  style: theme.textTheme.headlineSmall?.copyWith(
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: _SearchButton(onTap: () => _openSearch(context)),
              ),
            ),

            // Promo / deals rail
            SliverToBoxAdapter(
              child: _DealsSection(onSeeAll: () => context.push('/deals/all')),
            ),

            // Categories rail
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                child: _CategoriesRail(
                  categories: ref.watch(categoriesProvider),
                ),
              ),
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

            // For You section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 30, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('home.forYou'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/search'),
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
            _ForYouSection(),

            // Continue viewing CTA — keeps the endless For You scroll going.
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
                  onTap: () => ComingSoonSheet.show(
                    context,
                    title: context.tr('home.communitySheetTitle'),
                    description: context.tr('home.communityDescription'),
                    icon: Icons.groups_outlined,
                    ctaLabel: context.tr('common.openTelegram'),
                  ),
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
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
    final picked = await showCityPicker(context, current);
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
}

class _SearchButton extends ConsumerWidget {
  const _SearchButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outline),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr('home.searchPlaceholder'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.tune, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
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
  static const _autoAdvance = Duration(seconds: 4);

  final _controller = PageController();
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _startAutoAdvance();
  }

  void _startAutoAdvance() {
    _timer?.cancel();
    _timer = Timer.periodic(_autoAdvance, (_) {
      if (!mounted || !_controller.hasClients) return;
      final deals = ref.read(homeDealsProvider).value;
      final count = deals?.length ?? 0;
      if (count <= 1) return;
      final next = (_current + 1) % count;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
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
          dealsAsync.when(
            data: (deals) {
              if (deals.isEmpty) return const SizedBox.shrink();
              return Column(
                children: [
                  SizedBox(
                    height: 180,
                    child: PageView.builder(
                      controller: _controller,
                      onPageChanged: (i) => setState(() => _current = i),
                      itemCount: deals.length,
                      itemBuilder: (_, i) => Padding(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: i < deals.length - 1 ? 0 : 16,
                        ),
                        child: _DealCarouselCard(
                          deal: deals[i],
                          onTap: widget.onSeeAll,
                        ),
                      ),
                    ),
                  ),
                  if (deals.length > 1) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(deals.length, (i) {
                        final active = i == _current;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 20 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: active
                                ? Palette.gold
                                : theme.colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ],
                ],
              );
            },
            loading: () => SizedBox(
              height: 180,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
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
    final bgUrl = deal.bannerUrl ?? deal.imageUrl ?? _firstProductImage(deal);
    final productCount = deal.productCount ?? deal.products.length;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bgUrl != null)
              WImage(url: bgUrl, fit: BoxFit.cover)
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Palette.navy, theme.colorScheme.inversePrimary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
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

class _CategoriesRail extends ConsumerWidget {
  const _CategoriesRail({required this.categories});

  final AsyncValue<List<CategoryNode>> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cats = categories.value ?? const <CategoryNode>[];

    if (cats.isEmpty) {
      return SizedBox(
        height: 90,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          children: List.generate(
            8,
            (_) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: WSkeleton(width: 56, height: 56, radius: 28),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            context.tr('home.browseCategories'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.82,
          children: List.generate(cats.length.clamp(0, 8), (i) {
            final cat = cats[i];
            return _CategoryTile(category: cat);
          }),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final CategoryNode category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.push('/browse/${category.slug}'),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              category.icon ?? Icons.grid_view_rounded,
              size: 26,
              color: context.appColors.info,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              category.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForYouSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(homeFeedProvider);
    const cardWidth = 170.0;

    if (feedAsync.isLoading && feedAsync.value == null) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 300,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: List.generate(
              4,
              (_) => const Padding(
                padding: EdgeInsets.only(right: 12),
                child: ProductCardSkeleton(width: cardWidth),
              ),
            ),
          ),
        ),
      );
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

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ProductCard(product: products[i]),
          );
        }, childCount: products.length),
      ),
    );
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
