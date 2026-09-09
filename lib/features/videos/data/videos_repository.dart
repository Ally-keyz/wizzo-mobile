import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_providers.dart';
import '../models/video_short.dart';

class VideosRepository {
  VideosRepository(this._api);

  final ApiClient _api;

  /// Newest-first feed of published products that have a video attached.
  /// `store` scopes to one seller's shorts; `startProductId` pins the given
  /// product at the top of page 1 (used to "jump into the feed" from a product
  /// detail page).
  Future<VideoFeedPage> fetchFeed({
    int page = 1,
    int limit = 10,
    String? store,
    String? startProductId,
  }) async {
    final data = await _api.get(
      '/products/video-feed',
      query: {
        'page': page,
        'limit': limit,
        if (store != null && store.isNotEmpty) 'store': store,
        if (startProductId != null && startProductId.isNotEmpty && page == 1)
          'product': startProductId,
      },
    );
    if (data is Map<String, dynamic>) return VideoFeedPage.fromApi(data);
    return const VideoFeedPage(items: [], total: 0, page: 1, totalPages: 0);
  }

  /// Toggles a saved bookmark and returns the server's authoritative
  /// `{saved, saveCount}`.
  Future<({bool saved, int saveCount})> toggleSave(
    String productId,
  ) async {
    final data = await _api.post('/bookmarks/toggle', body: {
      'productId': productId,
    });
    final map = data is Map ? data : const <String, dynamic>{};
    return (
      saved: map['saved'] == true,
      saveCount: (map['saveCount'] as num?)?.toInt() ?? 0,
    );
  }
}

final videosRepositoryProvider = Provider<VideosRepository>((ref) {
  return VideosRepository(ref.watch(apiClientProvider));
});

/// Feed scoping args shared across entry points.
typedef VideosFeedArg = ({String? store, String? startProductId});

/// The shorts feed, family-scoped by optional store slug and an optional
/// "start product id" so the same provider backs the general feed, the
/// per-seller feed, and the product-detail entry.
class VideosFeedController extends AsyncNotifier<VideoFeedPage> {
  VideosFeedController(this._scope);

  final VideosFeedArg _scope;

  @override
  Future<VideoFeedPage> build() {
    return ref.watch(videosRepositoryProvider).fetchFeed(
          page: 1,
          limit: 20,
          store: _scope.store,
          startProductId: _scope.startProductId,
        );
  }

  /// Replaces one item in the loaded page (optimistic engagement update).
  void replace(VideoShort replacement) {
    final feed = state.value;
    if (feed == null) return;
    state = AsyncData(VideoFeedPage(
      items: feed.items
          .map((s) => s.product.id == replacement.product.id
              ? replacement
              : s)
          .toList(),
      total: feed.total,
      page: feed.page,
      totalPages: feed.totalPages,
    ));
  }
}

final videosFeedProvider = AsyncNotifierProvider.family<
    VideosFeedController, VideoFeedPage, VideosFeedArg>(
  VideosFeedController.new,
);