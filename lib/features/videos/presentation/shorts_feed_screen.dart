import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/data/account_repository.dart';
import '../../account/providers/account_providers.dart';
import '../../../core/routing/app_router.dart';
import '../data/videos_repository.dart';
import '../models/video_short.dart';
import 'short_video_page.dart';

/// Full-screen TikTok/Shorts-style vertical feed. Each page is a single video
/// that autoplays and loops; only the active page plays sound.
class ShortsFeedScreen extends ConsumerStatefulWidget {
  const ShortsFeedScreen({
    super.key,
    this.store,
    this.startProductId,
  });

  final String? store;
  final String? startProductId;

  @override
  ConsumerState<ShortsFeedScreen> createState() => _ShortsFeedScreenState();
}

class _ShortsFeedScreenState extends ConsumerState<ShortsFeedScreen>
    with RouteAware {
  final PageController _controller = PageController();
  int _current = 0;

  /// True while another route is pushed on top of the feed. All pages pause so
  /// no video keeps playing (or keeps audio) behind the next screen.
  bool _covered = false;

  VideosFeedArg get _scope =>
      (store: widget.store, startProductId: widget.startProductId);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      appRouteObserver.subscribe(this, route as ModalRoute<void>);
    }
  }

  @override
  void didPushNext() {
    if (!_covered) setState(() => _covered = true);
  }

  @override
  void didPopNext() {
    if (_covered) setState(() => _covered = false);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleLike(VideoShort pageShort) async {
    final scope = _scope;
    final feed = ref.read(videosFeedProvider(scope)).value;
    if (feed == null) return;

    final wasLiked = pageShort.likedByMe;
    ref.read(videosFeedProvider(scope).notifier).replace(
          wasLiked
              ? pageShort.copyWith(
                  likedByMe: false,
                  likeCount: (pageShort.likeCount - 1).clamp(0, 1 << 30),
                )
              : pageShort.copyWith(
                  likedByMe: true,
                  likeCount: pageShort.likeCount + 1,
                ),
        );

    try {
      await ref.read(accountRepositoryProvider).toggleWishlist(
            pageShort.product.id,
          );
    } catch (_) {
      ref.read(videosFeedProvider(scope).notifier).replace(pageShort);
    }
    ref.invalidate(wishlistProvider);
  }

  Future<void> _toggleSave(VideoShort pageShort) async {
    final scope = _scope;
    final result = await ref
        .read(videosRepositoryProvider)
        .toggleSave(pageShort.product.id);

    ref.read(videosFeedProvider(scope).notifier).replace(
          pageShort.copyWith(
            savedByMe: result.saved,
            saveCount: result.saveCount,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final scope = _scope;
    final async = ref.watch(videosFeedProvider(scope));

    return Scaffold(
      backgroundColor: Colors.black,
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white70),
        ),
        error: (e, _) => _ErrorState(
          message: 'Could not load shorts.\n$e',
          onRetry: () => ref.invalidate(videosFeedProvider(scope)),
        ),
        data: (page) {
          final items = page.items;
          if (items.isEmpty || items.every((s) => s.product.video == null)) {
            return const _EmptyState();
          }
          return Stack(
            children: [
              PageView.builder(
                controller: _controller,
                scrollDirection: Axis.vertical,
                itemCount: items.length,
                // Pre-build the adjacent page so its video starts loading
                // (and is ready/paused) before the user swipes to it.
                allowImplicitScrolling: true,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (context, i) => RepaintBoundary(
                  child: ShortVideoPage(
                    short: items[i],
                    active: i == _current && !_covered,
                    onLike: _toggleLike,
                    onSave: _toggleSave,
                  ),
                ),
              ),
              // Minimal top chrome over the video.
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white38, size: 64),
            const SizedBox(height: 16),
            Text(
              'No shorts available yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later or visit a seller shop.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}