import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/supabase_providers.dart';
import '../providers/orders_providers.dart';

const List<String> _orderStatuses = [
  'new',
  'confirmed',
  'out for deliver',
  'delivered',
  'cancelled',
];

String _statusLabel(String status) {
  if (status.trim().isEmpty) return 'Unknown';
  return status
      .split(' ')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

Color _statusColor(String status) {
  switch (status) {
    case 'new':
      return Colors.blue;
    case 'confirmed':
      return Colors.orange;
    case 'out for deliver':
      return Colors.orange;
    case 'delivered':
      return Colors.green;
    case 'cancelled':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  final _controller = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  int _page = 0;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNext());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients || !_hasMore || _loading) return;
    if (_controller.position.pixels >=
        _controller.position.maxScrollExtent - 200) {
      _loadNext();
    }
  }

  Future<void> _loadNext() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final next = await ref.refresh(ordersPageProvider(_page).future);
      if (!mounted) return;
      setState(() {
        _items.addAll(next);
        _page++;
        _hasMore = next.length == kPageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
    });
    await _loadNext();
  }

  @override
  Widget build(BuildContext context) {
    final hasItems = _items.isNotEmpty;
    final showLoader = _loading && !hasItems;
    final showEmpty = !showLoader && !hasItems && _error == null;
    final showError = !showLoader && !hasItems && _error != null;

    Widget body;
    if (showLoader) {
      body = const Center(child: CircularProgressIndicator());
    } else if (showError) {
      body = ListView(
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 240,
            child: Center(
              child: Text(
                'Failed to load.\n$_error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    } else if (showEmpty) {
      body = ListView(
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 240, child: Center(child: Text('No orders found.'))),
        ],
      );
    } else {
      body = ListView.separated(
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, index) =>
            index < _items.length ? const Divider(height: 1) : SizedBox(),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final order = _items[index];
          final status = order['status']?.toString().trim().toLowerCase() ?? '';
          return ListTile(
            title: Text('Order ${order['id']} (₹${order['total_amount']})'),
            subtitle: Text(order['customer_name']?.toString() ?? ''),
            trailing: (status.isNotEmpty)
                ? Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _statusColor(status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: const TextStyle(color: Colors.white),
                    ),
                  )
                : SizedBox.shrink(),
            onTap: () async {
              final updated = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => OrderDetailsPage(order: order),
                ),
              );
              if (updated == true) {
                await _refresh();
              }
            },
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: RefreshIndicator(onRefresh: _refresh, child: body),
    );
  }
}

class OrderDetailsPage extends ConsumerStatefulWidget {
  const OrderDetailsPage({super.key, required this.order});

  final Map<String, dynamic> order;

  @override
  ConsumerState<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends ConsumerState<OrderDetailsPage> {
  late Map<String, dynamic> _order;
  bool _saving = false;
  bool _updated = false;

  @override
  void initState() {
    super.initState();
    _order = Map<String, dynamic>.from(widget.order);
  }

  Future<void> _updateStatus(String status) async {
    if (_saving) return;
    setState(() => _saving = true);
    final client = ref.read(supabaseClientProvider);
    try {
      await client
          .from('orders')
          .update({'status': status})
          .eq('id', _order['id']);
      if (!mounted) return;
      setState(() {
        _order['status'] = status;
        _updated = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Status updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items =
        (_order['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final status = _order['status']?.toString().trim().toLowerCase() ?? 'new';

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_updated);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Order ${_order['id']}')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name: ${_order['customer_name']}'),
                    Text('Email: ${_order['customer_email']}'),
                    Text('Phone: ${_order['customer_phone']}'),
                    Text('Address: ${_order['shipping_address']}'),
                    Text(
                      '${_order['city']}, ${_order['state']} - ${_order['pincode']}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Status', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _orderStatuses.contains(status) ? status : 'new',
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _orderStatuses
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_statusLabel(value)),
                    ),
                  )
                  .toList(),
              onChanged: _saving ? null : (value) => _updateStatus(value!),
            ),
            const SizedBox(height: 12),
            Text('Items', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Card(
                child: ListTile(
                  title: Text(item['product_name']?.toString() ?? ''),
                  subtitle: Text('Qty: ${item['quantity']}'),
                  trailing: Text(
                    '₹${(num.tryParse(item['price'].toString()) ?? 0) * (num.tryParse(item['quantity'].toString()) ?? 0)}',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text('Total: ₹${_order['total_amount']}'),
          ],
        ),
      ),
    );
  }
}
