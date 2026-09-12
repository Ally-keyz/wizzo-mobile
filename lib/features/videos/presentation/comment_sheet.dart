import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/data/account_repository.dart';
import '../../account/models/profile.dart';
import '../../account/providers/account_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/w_image.dart';

/// Keyboard-aware comment sheet for a shoppable short. Comments double as
/// product reviews: posting requires a 1-5 star rating, and the submitted
/// text + rating are written to the same reviews store shown on Product
/// Detail (`type=product`).
class CommentSheet extends ConsumerStatefulWidget {
  const CommentSheet({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends ConsumerState<CommentSheet> {
  final _controller = TextEditingController();
  int _rating = 5;
  bool _posting = false;
  bool _viewerRatingsOnly = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    try {
      await ref
          .read(accountRepositoryProvider)
          .submitReview(
            productId: widget.productId,
            rating: _rating,
            comment: text,
          );
      _controller.clear();
      ref.invalidate(productReviewsProvider(widget.productId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('reviews.posted'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('reviews.postFailed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reviewsAsync = ref.watch(productReviewsProvider(widget.productId));
    final reviews = reviewsAsync.value ?? const <Review>[];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_back, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    context.tr('reviews.commentsTitle'),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(
                    () => _viewerRatingsOnly = !_viewerRatingsOnly,
                  ),
                  child: Text(
                    _viewerRatingsOnly
                        ? context.tr('reviews.viewerReviews')
                        : context.tr('common.all'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: reviews.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      context.tr('reviews.emptyShort'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: reviews.length,
                    itemBuilder: (context, i) {
                      final r = reviews[i];
                      return _ReviewTile(review: r);
                    },
                  ),
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            color: theme.colorScheme.surface,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr('reviews.yourRating'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      for (var i = 1; i <= 5; i++)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: Icon(
                            i <= _rating
                                ? Icons.star
                                : Icons.star_border,
                            size: 24,
                            color: i <= _rating
                                ? Palette.gold
                                : theme.colorScheme.outline,
                          ),
                          onPressed: () => setState(() => _rating = i),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          maxLines: 3,
                          minLines: 1,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: context.tr('reviews.addHint'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 44,
                        child: FilledButton(
                          onPressed: _posting || _controller.text.trim().isEmpty
                              ? null
                              : _post,
                          child: _posting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.secondaryContainer,
            child: Icon(
              Icons.person,
              size: 20,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        review.authorName ?? context.tr('reviews.anonymous'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (review.createdAt != null)
                      Text(
                        _rel(context, review.createdAt!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                if (review.rating != null) ...[
                  const SizedBox(height: 3),
                  RatingRow(
                    rating: review.rating!.toDouble(),
                    iconSize: 14,
                    showCount: false,
                  ),
                ],
                if (review.comment != null && review.comment!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    review.comment!,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _rel(BuildContext context, DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return context.tr('common.time.now');
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return DateFormat('MMM d').format(t);
  }
}