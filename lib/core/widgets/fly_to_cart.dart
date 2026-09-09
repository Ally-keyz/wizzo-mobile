import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/cart/providers/cart_provider.dart';
import '../theme/app_colors.dart';
import 'w_widgets.dart';

/// Web-style "fly to cart" animation: the product thumbnail lifts off from the
/// tapped card, arcs along a quadratic bezier, shrinks/fades, and "lands" on
/// the cart target, where the commit happens and the badge pulses.
///
/// Any visible cart icon registers itself via [cartTargetKey] (see
/// `CartAppBarAction`). When no cart icon is on screen, the flight lands on a
/// temporary on-screen cart chip instead so the animation is always visible.
class FlyToCartController extends ChangeNotifier {
  /// The currently visible cart icon that flights should land on.
  final GlobalKey cartTargetKey = GlobalKey();

  final Set<String> _inFlight = {};

  void fly({
    required BuildContext context,
    required String productId,
    required Rect source,
    String? imageUrl,
    required VoidCallback onLand,
  }) {
    if (source.isEmpty || _inFlight.contains(productId)) return;

    final overlay = Overlay.of(context, rootOverlay: true);

    // Resolve the landing spot to the visible cart icon when there is one.
    Rect? to;
    final targetContext = cartTargetKey.currentContext;
    if (targetContext != null) {
      final box = targetContext.findRenderObject();
      if (box is RenderBox) {
        to = box.localToGlobal(Offset.zero) & box.size;
      }
    }

    // Otherwise draw a small cart chip where the app-bar icon would sit.
    OverlayEntry? chipEntry;
    if (to == null) {
      final mq = MediaQuery.of(context);
      to = Rect.fromLTWH(mq.size.width - 16 - 40, mq.padding.top + 12, 40, 40);
      chipEntry = OverlayEntry(
        opaque: false,
        maintainState: false,
        builder: (_) => _CartChipOverlay(rect: to!),
      );
    }

    final spriteSize = math
        .min(source.longestSide, 96.0)
        .clamp(40.0, 96.0)
        .toDouble();

    late final OverlayEntry spriteEntry;
    spriteEntry = OverlayEntry(
      opaque: false,
      maintainState: false,
      builder: (_) => _FlightSpriteOverlay(
        from: source,
        to: to!,
        size: spriteSize,
        imageUrl: imageUrl,
        onDone: () {
          _inFlight.remove(productId);
          if (spriteEntry.mounted) spriteEntry.remove();
          try {
            onLand();
          } catch (_) {
            // Commit failures are surfaced by the caller; never break the loop.
          }
          _pulse(overlay, to!.center);
          final chip = chipEntry;
          if (chip != null) {
            Future<void>.delayed(const Duration(milliseconds: 700), () {
              if (chip.mounted) chip.remove();
            });
          }
        },
      ),
    );

    _inFlight.add(productId);
    overlay.insert(spriteEntry);
    if (chipEntry != null) overlay.insert(chipEntry);
  }

  void _pulse(OverlayState overlay, Offset at) {
    late final OverlayEntry ring;
    ring = OverlayEntry(
      opaque: false,
      maintainState: false,
      builder: (_) => _PulseRingOverlay(
        at: at,
        onDone: () {
          if (ring.mounted) ring.remove();
        },
      ),
    );
    overlay.insert(ring);
  }
}

/// App-wide instance backing all flights.
final flyToCartController = FlyToCartController();

/// Cart icon for app bars: registers itself as the flight target and shows the
/// live count badge. Tap opens the cart.
class CartAppBarAction extends ConsumerWidget {
  const CartAppBarAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartCountProvider);
    return IconButton(
      key: flyToCartController.cartTargetKey,
      tooltip: context.tr('common.cart'),
      onPressed: () => context.push('/cart'),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.shopping_cart_outlined),
          if (count > 0)
            Positioned(right: -9, top: -9, child: WBadge(count: count)),
        ],
      ),
    );
  }
}

/// A product thumbnail that flies along a quadratic bezier to the target.
class _FlightSpriteOverlay extends StatefulWidget {
  const _FlightSpriteOverlay({
    required this.from,
    required this.to,
    required this.size,
    this.imageUrl,
    required this.onDone,
  });

  final Rect from;
  final Rect to;
  final double size;
  final String? imageUrl;
  final VoidCallback onDone;

  @override
  State<_FlightSpriteOverlay> createState() => _FlightSpriteOverlayState();
}

class _FlightSpriteOverlayState extends State<_FlightSpriteOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 650),
        )
        ..addStatusListener(_onStatus)
        ..forward();

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static double _ease(double t) =>
      t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;

  @override
  Widget build(BuildContext context) {
    final from = widget.from;
    final to = widget.to;
    final control = Offset(
      (from.center.dx + to.center.dx) / 2,
      math.min(from.center.dy, to.center.dy) -
          math.max(140.0, (to.center.dx - from.center.dx).abs() * 0.30),
    );
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _ease(_controller.value);
            final inv = 1 - t;
            final x =
                inv * inv * from.center.dx +
                2 * inv * t * control.dx +
                t * t * to.center.dx;
            final y =
                inv * inv * from.center.dy +
                2 * inv * t * control.dy +
                t * t * to.center.dy;
            final scale = (1 - 0.8 * t).clamp(0.05, 1.0);
            final opacity = t > 0.82 ? ((1 - t) / 0.18).clamp(0.0, 1.0) : 1.0;
            return Stack(
              children: [
                Positioned(
                  left: x - widget.size / 2,
                  top: y - widget.size / 2,
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(opacity: opacity, child: child),
                  ),
                ),
              ],
            );
          },
          child: _Sprite(size: widget.size, imageUrl: widget.imageUrl),
        ),
      ),
    );
  }
}

class _Sprite extends StatelessWidget {
  const _Sprite({required this.size, this.imageUrl});

  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: imageUrl != null
          ? Image.network(
              imageUrl!,
              cacheWidth: size.round(),
              cacheHeight: size.round(),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _FlyingCartIcon(),
            )
          : const _FlyingCartIcon(),
    );
  }
}

class _FlyingCartIcon extends StatelessWidget {
  const _FlyingCartIcon();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.shopping_bag_outlined, color: Palette.gold, size: 22),
    );
  }
}

/// Expanding gold ring that pops on the cart icon when a flight lands.
class _PulseRingOverlay extends StatefulWidget {
  const _PulseRingOverlay({required this.at, required this.onDone});

  final Offset at;
  final VoidCallback onDone;

  @override
  State<_PulseRingOverlay> createState() => _PulseRingOverlayState();
}

class _PulseRingOverlayState extends State<_PulseRingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 380),
        )
        ..addStatusListener(_onStatus)
        ..forward();

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final t = _controller.value;
            final size = 30 + 22 * t;
            final opacity = (1 - t).clamp(0.0, 1.0);
            return Stack(
              children: [
                Positioned(
                  left: widget.at.dx - size / 2,
                  top: widget.at.dy - size / 2,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Palette.gold, width: 3),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Transient cart chip shown when no app-bar cart icon is on screen, so the
/// flight always has somewhere obvious to land.
class _CartChipOverlay extends StatelessWidget {
  const _CartChipOverlay({required this.rect});

  final Rect rect;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: rect.left,
      top: rect.top,
      child: IgnorePointer(
        child: Consumer(
          builder: (context, ref, _) {
            final count = ref.watch(cartCountProvider);
            return Container(
              width: rect.width,
              height: rect.height,
              decoration: const BoxDecoration(
                color: Palette.gold,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Center(
                    child: Icon(
                      Icons.shopping_cart_outlined,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                  if (count > 0)
                    Positioned(right: -4, top: -6, child: WBadge(count: count)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
