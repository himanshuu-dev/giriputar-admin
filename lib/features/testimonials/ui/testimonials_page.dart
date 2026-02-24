import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/supabase_providers.dart';
import '../providers/testimonials_providers.dart';

class TestimonialsPage extends ConsumerStatefulWidget {
  const TestimonialsPage({super.key});

  @override
  ConsumerState<TestimonialsPage> createState() => _TestimonialsPageState();
}

class _TestimonialsPageState extends ConsumerState<TestimonialsPage> {
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
      final next = await ref.refresh(testimonialsPageProvider(_page).future);
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

  Future<void> openForm({Map<String, dynamic>? existing}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TestimonialFormPage(existing: existing),
      ),
    );
    if (changed == true) {
      await _refresh();
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
              child: Text('Failed to load.\n$_error', textAlign: TextAlign.center),
            ),
          ),
        ],
      );
    } else if (showEmpty) {
      body = ListView(
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 240,
            child: Center(child: Text('No testimonials found.')),
          ),
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
          final testimonial = _items[index];
          return ListTile(
            title: Text(testimonial['name']?.toString() ?? ''),
            subtitle: Text(testimonial['text']?.toString() ?? ''),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('⭐ ${testimonial['rating']}'),
                if (testimonial['featured'] == true) const Text('Featured'),
              ],
            ),
            onTap: () => openForm(existing: testimonial),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Testimonials'),
        actions: [
          IconButton(onPressed: () => openForm(), icon: const Icon(Icons.add)),
        ],
      ),
      body: RefreshIndicator(onRefresh: _refresh, child: body),
    );
  }
}

class TestimonialFormPage extends ConsumerStatefulWidget {
  const TestimonialFormPage({super.key, this.existing});

  final Map<String, dynamic>? existing;

  @override
  ConsumerState<TestimonialFormPage> createState() =>
      _TestimonialFormPageState();
}

class _TestimonialFormPageState extends ConsumerState<TestimonialFormPage> {
  final nameController = TextEditingController();
  final locationController = TextEditingController();
  final textController = TextEditingController();
  int rating = 5;
  bool featured = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      nameController.text = e['name']?.toString() ?? '';
      locationController.text = e['location']?.toString() ?? '';
      rating = int.tryParse(e['rating']?.toString() ?? '') ?? 5;
      textController.text = e['text']?.toString() ?? '';
      featured = e['featured'] == true;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    textController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final name = nameController.text.trim();
    final location = locationController.text.trim();
    final text = textController.text.trim();
    if (name.isEmpty || location.isEmpty || text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields are required')),
      );
      return;
    }
    if (rating < 1 || rating > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rating must be between 1 and 5')),
      );
      return;
    }

    final payload = {
      'name': name,
      'location': location,
      'rating': rating,
      'text': text,
      'featured': featured,
    };

    setState(() => saving = true);
    final client = ref.read(supabaseClientProvider);
    try {
      if (widget.existing == null) {
        await client.from('testimonials').insert(payload);
      } else {
        await client
            .from('testimonials')
            .update(payload)
            .eq('id', widget.existing!['id']);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Testimonial' : 'Add Testimonial'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: saving
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete testimonial?'),
                          content: const Text(
                            'This will permanently delete the testimonial.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      final client = ref.read(supabaseClientProvider);
                      try {
                        await client
                            .from('testimonials')
                            .delete()
                            .eq('id', widget.existing!['id']);
                        if (!mounted) return;
                        Navigator.of(context).pop(true);
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Delete failed: $e')),
                        );
                      }
                    },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: locationController,
            decoration: const InputDecoration(labelText: 'Location'),
          ),
          const SizedBox(height: 10),
          Text(
            'Rating',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              final value = index + 1;
              return IconButton(
                onPressed: () => setState(() => rating = value),
                icon: Icon(
                  value <= rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: textController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Review Text'),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            value: featured,
            onChanged: (value) => setState(() => featured = value),
            title: const Text('Featured'),
          ),
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
    );
  }
}
