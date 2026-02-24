import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../orders/ui/orders_page.dart';
import '../../products/ui/products_page.dart';
import '../../site_settings/ui/site_settings_page.dart';
import '../../testimonials/ui/testimonials_page.dart';
import '../providers/dashboard_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayOrdersAsync = ref.watch(todayOrdersCountProvider);

    final items = <({String title, IconData icon, Widget page})>[
      (
        title: 'View Products',
        icon: Icons.inventory_2,
        page: const ProductsPage(),
      ),
      (
        title: 'View Orders',
        icon: Icons.receipt_long,
        page: const OrdersPage(),
      ),
      (
        title: 'Testimonials',
        icon: Icons.reviews,
        page: const TestimonialsPage(),
      ),
      (
        title: 'Site Settings',
        icon: Icons.settings,
        page: const SiteSettingsPage(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giriputtar Admin'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(todayOrdersCountProvider),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.today),
                title: const Text('Today Orders'),
                subtitle: todayOrdersAsync.when(
                  data: (count) => Text(
                    count.toString(),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  loading: () => const Text('Loading...'),
                  error: (e, _) => Text('Error: $e'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.7,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(
                        context,
                      ).push(MaterialPageRoute(builder: (_) => item.page));
                    },
                    child: Card(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(item.icon, size: 36),
                          const SizedBox(height: 8),
                          Text(item.title),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
