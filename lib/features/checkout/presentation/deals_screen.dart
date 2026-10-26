import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/w_widgets.dart';
import '../../catalog/presentation/product_card.dart';
import '../../catalog/providers/catalog_providers.dart';

/// Full-screen "All Deals" browse — every discounted product currently on
/// promotion (flash + today's deals), one product per page at 90% screen width
/// with automatic sliding to the next deal.
class DealsAllScreen extends ConsumerStatefulWidget {
  const DealsAllScreen({super.key});

  @override
  ConsumerState<DealsAllScreen> createState() => _DealsAllScreenState();
}

class _DealsAllScreenState extends ConsumerState<DealsAllScreen> {
  static const _slideInterval = Duration(seconds: 4);
  static const _slideDuration = Duration(milliseconds: 450);

  final PageController _controller = PageController(viewportFraction: 0.9);
  Timer? _timer;
  int _index = 0;
  int _count = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Keeps the auto-slide timer and page position in sync with the deal count
  /// (which only becomes known once the async list resolves).
  void _configure(int count) {
    if (!mounted) return;
    if (_count != count) {
      _count = count;
      if (_index >= count) {
        setState(() => _index = 0);
        if (_controller.hasClients) _controller.jumpToPage(0);
      }
      _restartTimer();
    } else if (_timer == null) {
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_count <= 1) return;
    _timer = Timer.periodic(_slideInterval, (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % _count;
      _controller.animateToPage(
        next,
        duration: _slideDuration,
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productsAsync = ref.watch(allDealsProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('deals.all'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: productsAsync.when(
        loading: () => const Center(
          child: SizedBox(width: 260, child: ProductCardSkeleton()),
        ),
        error: (e, _) => WEmptyState(
          icon: Icons.cloud_off,
          title: context.tr('deals.loadFailed'),
          subtitle: '$e',
          actionLabel: context.tr('common.retry'),
          onAction: () => ref.invalidate(allDealsProductsProvider),
        ),
        data: (products) {
          if (products.isEmpty) {
            return WEmptyState(
              icon: Icons.local_offer_outlined,
              title: context.tr('deals.none'),
              subtitle: context.tr('deals.noneHint'),
            );
          }
          final maxDiscount = products.fold<int>(
            0,
            (max, p) => p.discount > max ? p.discount : max,
          );
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _configure(products.length),
          );
          final current = _index.clamp(0, products.length - 1) + 1;
          return SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        size: 20,
                        color: Palette.gold,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.tr(
                            'deals.productsUpToOff',
                            namedArgs: {
                              'count': '${products.length}',
                              'percent': '$maxDiscount',
                            },
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      // A manual swipe pauses the timer; it resumes once the
                      // page settles so the deal being read isn't yanked away.
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
                      itemCount: products.length,
                      onPageChanged: (index) {
                        setState(() => _index = index);
                        _restartTimer();
                      },
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // Match the card image's aspect ratio to the space
                              // left after its price/title/seller block so the
                              // photo fills the whole slide on every screen size.
                              const detailsBudget = 100.0;
                              const innerPadding = 26.0;
                              final width =
                                  constraints.maxWidth - innerPadding;
                              final imageHeight =
                                  constraints.maxHeight -
                                  innerPadding -
                                  detailsBudget;
                              final ratio = width <= 0 || imageHeight <= 0
                                  ? 3 / 4
                                  : width / imageHeight;
                              return DecoratedBox(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    12,
                                    12,
                                    14,
                                  ),
                                  child: ProductCard(
                                    product: products[index],
                                    imageAspectRatio: ratio,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (products.length > 1) ...[
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < products.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: i == _index.clamp(0, products.length - 1)
                              ? 20
                              : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _index.clamp(0, products.length - 1)
                                ? Palette.gold
                                : theme.colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      'deals.itemOf',
                      namedArgs: {
                        'current': '$current',
                        'total': '${products.length}',
                      },
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}
