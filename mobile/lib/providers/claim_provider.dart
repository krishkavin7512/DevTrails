import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/claim.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

bool _isObjectId(String? id) =>
    id != null && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(id);

final claimsProvider = FutureProvider<List<Claim>>((ref) async {
  final riderId = ref.watch(riderIdProvider);
  if (!_isObjectId(riderId)) return [];

  try {
    final res = await ApiService().getRiderClaims(riderId!, limit: 20);
    return res.data ?? [];
  } catch (_) {
    return [];
  }
});
