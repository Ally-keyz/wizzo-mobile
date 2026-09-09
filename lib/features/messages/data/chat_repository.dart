import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../models/chat.dart';

/// Chat endpoints mirroring the web `chatService`.
class ChatRepository {
  ChatRepository(this._api);

  final ApiClient _api;

  Future<List<Conversation>> conversations(String? selfId) async {
    final data = await _api.get('/conversations');
    if (data is List) {
      return data.map((c) => Conversation.fromApi(c, selfId: selfId)).toList();
    }
    if (data is Map) {
      final items = data['conversations'] ?? data['items'] ?? data['data'];
      if (items is List) {
        return items.map((c) => Conversation.fromApi(c, selfId: selfId)).toList();
      }
    }
    return const [];
  }

  Future<int> unreadCount(String? selfId) async {
    final data = await _api.get('/conversations');
    final items = data is List
        ? data
        : (data is Map ? (data['conversations'] ?? data['items'] ?? const []) : const []);
    if (items is! List) return 0;
    var total = 0;
    for (final c in items) {
      if (c is Map) {
        total += Conversation.parseUnread(c['unreadCount'], selfId);
      }
    }
    return total;
  }

  Future<List<ChatMessage>> messages(String conversationId, {String? selfId}) async {
    final data = await _api.get('/conversations/$conversationId/messages');
    final items = data is List
        ? data
        : (data is Map ? (data['messages'] ?? data['items'] ?? data['data']) : const []);
    if (items is! List) return const [];
    final self = selfId ?? '';
    // The API returns messages newest-first; reverse so the latest message
    // appears at the bottom of the conversation (oldest → newest).
    return items
        .map((m) => ChatMessage.fromApi(m, selfId: self))
        .toList()
        .reversed
        .toList();
  }

  Future<Conversation> start(
    String participantId, {
    String? productId,
    String type = 'buyer_seller',
  }) async {
    final data = await _api.post('/conversations', body: {
      'type': type,
      'participantId': participantId,
      if (productId != null) 'productId': productId,
    });
    return Conversation.fromApi(data is Map ? data : const {});
  }

  /// People you can start a chat with (sellers + admins, and buyers when the
  /// current user is a seller).
  Future<List<ChatContact>> contacts() async {
    final data = await _api.get('/users/contacts');
    final items = data is List
        ? data
        : (data is Map ? (data['contacts'] ?? data['items'] ?? const []) : const []);
    if (items is! List) return const [];
    return items.whereType<Map>().map(ChatContact.fromApi).toList();
  }

  Future<ChatMessage> sendMessage(
    String conversationId,
    String content, {
    String type = 'text',
    String? mediaUrl,
    String selfId = '',
  }) async {
    final data = await _api.post('/conversations/$conversationId/messages', body: {
      'content': content,
      'type': type,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
    });
    return ChatMessage.fromApi(data, selfId: selfId);
  }

  /// Uploads a local image to Cloudinary and returns its URL. Uses the
  /// authenticated `/uploads/cloudinary-signature` endpoint to sign the upload.
  Future<String> uploadImage(String filePath, {String folder = 'wizzo/chat'}) async {
    final sigData = await _api.post(
      '/uploads/cloudinary-signature',
      body: {'folder': folder},
    );
    final sig = sigData is Map ? sigData : const <String, dynamic>{};
    final cloudName = sig['cloudName']?.toString();
    if (cloudName == null || cloudName.isEmpty) {
      throw Exception('Could not get an upload signature');
    }
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = sig['apiKey']?.toString() ?? ''
      ..fields['timestamp'] = sig['timestamp']?.toString() ?? ''
      ..fields['signature'] = sig['signature']?.toString() ?? ''
      ..fields['folder'] = folder
      ..fields['cloud_name'] = cloudName;
    try {
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
    } on FileSystemException catch (e) {
      throw Exception('Could not read the selected file: ${e.message}');
    }

    final streamed = await request.send().timeout(const Duration(seconds: 120));
    final response = await http.Response.fromStream(streamed);
    final decoded = _tryDecode(response.bodyBytes);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final url = decoded is Map
          ? (decoded['secure_url'] ?? decoded['url'])?.toString()
          : null;
      if (url != null && url.isNotEmpty) return url;
      throw Exception('Upload failed: ${decoded is Map ? decoded['error'] : 'unknown'}');
    }
    throw Exception('Upload failed (${response.statusCode})');
  }

  static dynamic _tryDecode(List<int> bytes) {
    if (bytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(bytes));
    } catch (_) {
      return null;
    }
  }

  Future<void> markRead(String conversationId) async {
    try {
      await _api.patch('/conversations/$conversationId/read');
    } catch (_) {
      // Non-fatal.
    }
  }
}