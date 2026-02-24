import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/supabase_providers.dart';

final testimonialsPageProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, page) async {
  final client = ref.watch(supabaseClientProvider);
  final from = page * kPageSize;
  final to = from + kPageSize - 1;
  final rows = await client
      .from('testimonials')
      .select('*')
      .order('id', ascending: false)
      .range(from, to);
  return List<Map<String, dynamic>>.from(rows);
});
