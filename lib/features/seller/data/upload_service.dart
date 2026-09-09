import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_providers.dart';

/// Uploads image files to Cloudinary using a short-lived signature issued by
/// the Wizzo backend (POST /uploads/cloudinary-signature).
class UploadService {
  UploadService(this._api);

  final ApiClient _api;

  static const _uploadHost = 'api.cloudinary.com';

  /// Uploads an [XFile]-path image and returns its secure URL.
  Future<String> uploadImage(
    String filePath, {
    String? name,
    String folder = 'wizzo/products',
  }) async {
    final signature = await _signature(folder);
    final uploadUrl =
        'https://$_uploadHost/v1_1/${signature['cloudName']}/image/upload';
    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl))
      ..fields['api_key'] = signature['apiKey'].toString()
      ..fields['timestamp'] = signature['timestamp'].toString()
      ..fields['folder'] = folder
      ..fields['signature'] = signature['signature'].toString()
      ..files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamed = await request.send().timeout(const Duration(seconds: 90));
    final response = await http.Response.fromStream(streamed);
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is Map && json['secure_url'] is String) {
      return json['secure_url'] as String;
    }
    throw Exception('Image upload failed (${response.statusCode}). Try again.');
  }

  Future<Map<String, dynamic>> _signature(String folder) async {
    final data = await _api.post(
      '/uploads/cloudinary-signature',
      body: {'folder': folder},
    );
    if (data is Map<String, dynamic>) return data;
    throw const ApiException(
      status: 0,
      code: 'upload',
      message: 'Could not prepare the image upload.',
    );
  }

  /// Uploads a video file to Cloudinary and returns its secure URL. Uses the
  /// Wizzo backend's video-signature endpoint (POST /uploads/video-signature)
  /// which authorises a `video/upload` to Cloudinary.
  Future<String> uploadVideo(
    String filePath, {
    String folder = 'wizzo/products/videos',
  }) async {
    final signature = await _videoSignature(folder);
    final uploadUrl =
        'https://$_uploadHost/v1_1/${signature['cloudName']}/video/upload';
    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl))
      ..fields['api_key'] = signature['apiKey'].toString()
      ..fields['timestamp'] = signature['timestamp'].toString()
      ..fields['folder'] = folder
      ..fields['signature'] = signature['signature'].toString()
      ..files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamed = await request.send().timeout(const Duration(seconds: 180));
    final response = await http.Response.fromStream(streamed);
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is Map && json['secure_url'] is String) {
      return json['secure_url'] as String;
    }
    throw Exception('Video upload failed (${response.statusCode}). Try again.');
  }

  Future<Map<String, dynamic>> _videoSignature(String folder) async {
    final data = await _api.post(
      '/uploads/video-signature',
      body: {'folder': folder},
    );
    if (data is Map<String, dynamic>) return data;
    throw const ApiException(
      status: 0,
      code: 'upload',
      message: 'Could not prepare the video upload.',
    );
  }
}

final uploadServiceProvider = Provider((ref) {
  return UploadService(ref.watch(apiClientProvider));
});