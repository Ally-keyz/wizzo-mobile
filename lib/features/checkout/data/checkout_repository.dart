import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/api_providers.dart';

import '../../../core/network/api_client.dart';
import '../models/checkout.dart';

class CheckoutRepository {
  CheckoutRepository(this._api);

  final ApiClient _api;

  Future<PlacementSummary> placeOrder({
    required List<Map<String, dynamic>> sellerPayments,
    String? couponCode,
    String deliveryOption = 'delivery',
    String? deliveryAddressId,
    List<String> proofSubmittedSellerIds = const [],
    String? paymentMethod,
    Map<String, dynamic>? paymentDetails,
  }) async {
    final data = await _api.post('/orders/checkout', body: {
      'sellerPaymentSelection': sellerPayments,
      'deliveryOption': deliveryOption,
      if (deliveryAddressId != null && deliveryAddressId.isNotEmpty)
        'deliveryAddressId': deliveryAddressId,
      if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
      if (paymentMethod != null && paymentMethod.isNotEmpty)
        'paymentMethod': paymentMethod,
      if (paymentDetails != null && paymentDetails.isNotEmpty)
        'paymentDetails': paymentDetails,
    });
    return PlacementSummary.fromApi(
      data,
      proofSubmittedSellerIds: proofSubmittedSellerIds,
    );
  }

  Future<Coupon> validateCoupon(String code, {List<Map<String, dynamic>> lines = const []}) async {
    final data = await _api.post('/coupons/validate', body: {
      'code': code.trim(),
      if (lines.isNotEmpty) 'lines': lines,
    });
    return Coupon.fromApi(data is Map ? data : {'code': code.trim()});
  }

  /// Pay-in instructions for a set of seller user ids (mirrors the web
  /// `/sellers/payment-accounts` call used on checkout and confirmation).
  Future<List<SellerPaymentInfo>> getSellersPaymentAccounts(
    List<String> sellerUserIds,
  ) async {
    final ids = sellerUserIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const [];
    final data = await _api.get(
      '/sellers/payment-accounts',
      query: {'ids': ids.join(',')},
    );
    final items = data is List ? data : const <dynamic>[];
    return items.map(SellerPaymentInfo.fromApi).toList();
  }

  /// Attaches payment proof to an already-placed seller order (the buyer
  /// sends money out-of-band, then uploads a receipt/screenshot here).
  Future<void> submitPaymentProof({
    required String orderId,
    required PaymentKind method,
    String? transactionReference,
    String? proofUrl,
    String? proofName,
    String? proofType,
  }) async {
    await _api.post('/orders/$orderId/payment-proof', body: {
      'method': method.apiValue,
      if (transactionReference != null && transactionReference.isNotEmpty)
        'transactionReference': transactionReference,
      if (proofUrl != null && proofUrl.isNotEmpty) 'proofUrl': proofUrl,
      if (proofName != null && proofName.isNotEmpty) 'proofName': proofName,
      if (proofType != null && proofType.isNotEmpty) 'proofType': proofType,
    });
  }

  /// Uploads a local image to Cloudinary and returns its URL (used for the
  /// obligatory payment-proof attachment on non-COD orders).
  Future<String> uploadImage(String filePath, {String folder = 'wizzo/proofs'}) async {
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
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      decoded = null;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final url = decoded is Map
          ? (decoded['secure_url'] ?? decoded['url'])?.toString()
          : null;
      if (url == null || url.isEmpty) {
        throw Exception('Upload failed: could not read the URL');
      }
      return url;
    }
    throw Exception('Upload failed (${response.statusCode})');
  }
}

final checkoutRepositoryProvider = Provider<CheckoutRepository>((ref) {
  return CheckoutRepository(ref.watch(apiClientProvider));
});