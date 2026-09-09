import '../../catalog/models/product.dart';

/// A single entry in the shoppable shorts feed: a published product that has
/// a video attached, annotated with engagement counts derived from the
/// wishlist (likes), bookmarks (saves) and product reviews (comments).
class VideoShort {
  const VideoShort({
    required this.product,
    this.likeCount = 0,
    this.likedByMe = false,
    this.saveCount = 0,
    this.savedByMe = false,
    this.commentCount = 0,
  });

  final Product product;
  final int likeCount;
  final bool likedByMe;
  final int saveCount;
  final bool savedByMe;
  final int commentCount;

  factory VideoShort.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid short payload');
    }
    return VideoShort(
      product: Product.fromApi(json),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      likedByMe: json['likedByMe'] == true,
      saveCount: (json['saveCount'] as num?)?.toInt() ?? 0,
      savedByMe: json['savedByMe'] == true,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
    );
  }

  VideoShort copyWith({
    Product? product,
    int? likeCount,
    bool? likedByMe,
    int? saveCount,
    bool? savedByMe,
    int? commentCount,
  }) {
    return VideoShort(
      product: product ?? this.product,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      saveCount: saveCount ?? this.saveCount,
      savedByMe: savedByMe ?? this.savedByMe,
      commentCount: commentCount ?? this.commentCount,
    );
  }
}

/// Feed pagination envelope returned by GET /products/video-feed.
class VideoFeedPage {
  const VideoFeedPage({
    required this.items,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  final List<VideoShort> items;
  final int total;
  final int page;
  final int totalPages;

  factory VideoFeedPage.fromApi(dynamic json) {
    if (json is! Map<String, dynamic>) {
      const page = VideoFeedPage(items: [], total: 0, page: 1, totalPages: 0);
      return page;
    }
    final raw = json['items'];
    final items = raw is List
        ? raw.map(VideoShort.fromApi).toList()
        : const <VideoShort>[];
    return VideoFeedPage(
      items: items,
      total: (json['total'] as num?)?.toInt() ?? items.length,
      page: (json['page'] as num?)?.toInt() ?? 1,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}