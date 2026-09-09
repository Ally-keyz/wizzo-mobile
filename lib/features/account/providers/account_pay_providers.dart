import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/account_repository.dart';
import '../models/profile.dart';

final paymentMethodsProvider = FutureProvider<List<PaymentMethod>>((ref) {
  return ref.watch(accountRepositoryProvider).paymentMethods();
});

final walletProvider = FutureProvider<Wallet>((ref) {
  return ref.watch(accountRepositoryProvider).wallet();
});

final reviewsProvider = FutureProvider<List<Review>>((ref) {
  return ref.watch(accountRepositoryProvider).reviews();
});