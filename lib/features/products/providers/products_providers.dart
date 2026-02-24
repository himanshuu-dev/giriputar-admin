import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/supabase_providers.dart';
import '../model/product.dart';

final productsPageProvider =
    FutureProvider.family<List<Product>, int>((ref, page) async {
  final client = ref.watch(supabaseClientProvider);
  final from = page * kPageSize;
  final to = from + kPageSize - 1;
  final rows = await client
      .from('products')
      .select('*')
      .order('id', ascending: true)
      .range(from, to);
  return List<Map<String, dynamic>>.from(rows).map(Product.fromMap).toList();
});
