import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/w_image.dart';
import '../../../core/widgets/w_widgets.dart';
import '../providers/account_pay_providers.dart';

class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reviews = ref.watch(reviewsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('reviews.title'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
      body: reviews.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => WEmptyState(
          icon: Icons.cloud_off,
          title: context.tr('reviews.loadFailed'),
          subtitle: '${e}',
          actionLabel: context.tr('common.retry'),
          onAction: () => ref.invalidate(reviewsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return WEmptyState(
              icon: Icons.rate_review_outlined,
              title: context.tr('reviews.empty'),
              subtitle: context.tr('reviews.emptyHint'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final review = list[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            review.productName ?? review.sellerName ?? context.tr('reviews.placeholder'),
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          formatDate(review.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    RatingRow(rating: review.rating?.toDouble(), showCount: false, iconSize: 14),
                    if (review.comment != null && review.comment!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(review.comment!, style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}