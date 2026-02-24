import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';

final siteSettingsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final row = await client
      .from('site_settings')
      .select('*')
      .eq('id', 1)
      .single();
  return Map<String, dynamic>.from(row);
});
