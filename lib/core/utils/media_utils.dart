library;

/// Rewrites a Cloudinary media URL to request a smaller, lower-bandwidth
/// rendition for the mobile feed (e.g. `.../video/upload/v1/...` becomes
/// `.../video/upload/w_720,q_60/v1/...`). Non-Cloudinary URLs are returned
/// unchanged so playback keeps working for any other host.
String optimizeCloudinaryUrl(String url, {int width = 720}) {
  const marker = '/video/upload/';
  final idx = url.indexOf(marker);
  if (idx < 0) return url;
  final head = url.substring(0, idx + marker.length);
  final tail = url.substring(idx + marker.length);
  // Avoid double-transforming URLs that already carry a transformation.
  if (tail.startsWith('w_')) return url;
  return '${head}w_$width,q_60/$tail';
}