import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alert.dart';
import '../services/api_service.dart';

final alertsProvider = FutureProvider<List<Alert>>((ref) async {
  try {
    final res = await ApiService().getNearbyAlerts(0, 0);
    return res.data ?? [];
  } catch (_) {
    return [];
  }
});
