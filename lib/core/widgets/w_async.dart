import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_colors.dart';

/// Convenient wrapper that renders an AsyncValue as skeleton / error / data.
class WAsyncView<T> extends StatelessWidget {
  const WAsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.loading,
    this.onRetry,
    this.emptyWidget,
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext, T) builder;
  final Widget? loading;
  final VoidCallback? onRetry;
  final Widget? emptyWidget;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (data) => builder(context, data),
      error: (e, st) => _ErrorView(error: e, onRetry: onRetry),
      loading: () => loading ?? const _SkeletonPage(),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = error.toString().isEmpty ? context.tr('common.somethingWentWrong') : '${error}';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off, size: 34, color: theme.colorScheme.onErrorContainer),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('common.couldNotLoadContent'),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: Text(context.tr('common.retry'))),
            ],
          ],
        ),
      ),
    );
  }
}

/// Animated placeholder blocks used while network data loads.
class WSkeleton extends StatelessWidget {
  const WSkeleton({super.key, this.width, this.height = 16, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest,
      highlightColor: scheme.surface,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _SkeletonPage extends StatelessWidget {
  const _SkeletonPage();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Shimmer.fromColors(
        baseColor: scheme.surfaceContainerHighest,
        highlightColor: scheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _block(100, 16),
                const Spacer(),
                _block(24, 24, circle: true),
                const SizedBox(width: 8),
                _block(24, 24, circle: true),
              ],
            ),
            const SizedBox(height: 20),
            _block(double.infinity, 42, radius: 21),
            const SizedBox(height: 16),
            _block(160, 22),
            const SizedBox(height: 12),
            _block(double.infinity, 14),
            _block(double.infinity, 14),
            const SizedBox(height: 12),
            _block(120, 14),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(child: _block(double.infinity, 180, radius: 16)),
                const SizedBox(width: 12),
                Expanded(child: _block(double.infinity, 320, radius: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _block(double w, double h, {bool circle = false, double radius = 8}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: circle ? null : BorderRadius.circular(radius),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
      ),
    );
  }
}

/// Small gold circular loading spinner used inside buttons.
class WInlineLoader extends StatelessWidget {
  const WInlineLoader({super.key, this.color = Colors.black, this.size = 20});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
    );
  }
}

/// A small dot + label for "online" sellers.
class WOnlineDot extends StatelessWidget {
  const WOnlineDot({super.key, required this.online});
  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? context.appColors.success : context.appColors.warning;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(
          online ? context.tr('common.onlineNow') : context.tr('common.offline'),
          style: TextStyle(fontSize: 11, color: context.appColors.success),
        ),
      ],
    );
  }
}