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

/// Rewrites a Cloudinary image URL to a high-quality rendition sized for the
/// device, using Cloudinary's automatic format/quality (`f_auto,q_auto`) so the
/// app gets the sharpest pixels at the smallest byte size. URLs that are
/// already transformed, or that live outside this Cloudinary cloud, are left
/// untouched.
String highQualityCloudinaryUrl(String url, {int width = 800}) {
  const marker = 'res.cloudinary.com/dgk50tb79/image/upload/';
  final idx = url.indexOf(marker);
  if (idx < 0) return url;
  final tailStart = idx + marker.length;
  final tail = url.substring(tailStart);
  // A plain upload path starts with the version segment (e.g. "v1234/...").
  // Any other prefix means a transformation is already present — leave it.
  if (!tail.startsWith('v')) return url;
  return '${url.substring(0, tailStart)}c_limit,w_$width,f_auto,q_auto/$tail';
}
