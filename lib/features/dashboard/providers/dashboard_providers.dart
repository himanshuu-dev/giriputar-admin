import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';

final todayOrdersCountProvider = FutureProvider<int>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client.from('orders').select('id').limit(1000);
  final now = DateTime.now();
  final dayStart = DateTime(
    now.year,
    now.month,
    now.day,
  ).millisecondsSinceEpoch;
  final dayEnd = DateTime(
    now.year,
    now.month,
    now.day + 1,
  ).millisecondsSinceEpoch;

  var count = 0;
  for (final row in rows) {
    final id = int.tryParse(row['id'].toString());
    if (id != null && id >= dayStart && id < dayEnd) {
      count++;
    }
  }
  return count;
});
