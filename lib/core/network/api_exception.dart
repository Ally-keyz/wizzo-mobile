/// Error raised by the API client, mirroring the web app's `ApiError`.
class ApiException implements Exception {
  const ApiException({
    required this.status,
    required this.code,
    required this.message,
  });

  final int status;
  final String code;
  final String message;

  bool get isNetworkError => status == 0;
  bool get isUnauthorized => status == 401;
  bool get isConflict => status == 409;
  bool get isNotFound => status == 404;

  @override
  String toString() => message;
}