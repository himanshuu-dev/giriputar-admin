import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/supabase_providers.dart';
import '../model/product.dart';
import '../providers/products_providers.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  final _controller = ScrollController();
  final List<Product> _items = [];
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
      final next = await ref.refresh(productsPageProvider(_page).future);
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

  Future<void> openForm({Product? existing}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductFormPage(existing: existing)),
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
          SizedBox(
            height: 240,
            child: Center(child: Text('No products found.')),
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
          final product = _items[index];
          return ListTile(
            title: Text(product.name),
            leading: Image.network(product.imageUrl,cacheHeight: 100,),
            subtitle: Text('₹${product.price} • ${product.weight}'),
            trailing: Text(product.inStock ? 'In Stock' : 'Out'),
            onTap: () => openForm(existing: product),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(onPressed: () => openForm(), icon: const Icon(Icons.add)),
        ],
      ),
      body: RefreshIndicator(onRefresh: _refresh, child: body),
    );
  }
}

class ProductFormPage extends ConsumerStatefulWidget {
  const ProductFormPage({super.key, this.existing});

  final Product? existing;

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final idController = TextEditingController();
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final priceController = TextEditingController();
  final weightController = TextEditingController();
  final imageController = TextEditingController();
  final benefitsController = TextEditingController();
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String? _idSuffix;
  bool inStock = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      idController.text = e.id;
      nameController.text = e.name;
      descriptionController.text = e.description;
      priceController.text = e.price.toString();
      weightController.text = e.weight;
      imageController.text = e.imageUrl;
      benefitsController.text = e.benefits.join(', ');
      inStock = e.inStock;
    } else {
      _idSuffix = _randomSuffix();
      nameController.addListener(_syncIdFromName);
    }
  }

  @override
  void dispose() {
    if (widget.existing == null) {
      nameController.removeListener(_syncIdFromName);
    }
    idController.dispose();
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    weightController.dispose();
    imageController.dispose();
    benefitsController.dispose();
    super.dispose();
  }

  void _syncIdFromName() {
    if (widget.existing != null) return;
    final name = nameController.text.trim();
    if (name.isEmpty) {
      idController.text = '';
      return;
    }
    final slug = _slugify(name);
    final suffix = _idSuffix ??= _randomSuffix();
    idController.text = slug.isEmpty ? '' : '$slug-$suffix';
  }

  String _slugify(String input) {
    var slug = input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    slug = slug.replaceAll(RegExp(r'^-+|-+$'), '');
    return slug;
  }

  String _randomSuffix() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    final length = 4 + rand.nextInt(2);
    return List.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to read image bytes')),
      );
      return;
    }
    setState(() {
      _selectedImageBytes = file.bytes;
      _selectedImageName = file.name;
    });
  }

  Future<String> _uploadImage(String productId) async {
    final bytes = _selectedImageBytes;
    if (bytes == null) return imageController.text.trim();

    final client = ref.read(supabaseClientProvider);
    final ext = (_selectedImageName ?? '').split('.').last.trim();
    final filename =
        '${DateTime.now().millisecondsSinceEpoch}.${ext.isEmpty ? 'jpg' : ext}';
    final path = 'products/$productId/$filename';

    await client.storage
        .from(kProductImagesBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return client.storage.from(kProductImagesBucket).getPublicUrl(path);
  }

  Future<void> save() async {
    final id = idController.text.trim();
    final name = nameController.text.trim();
    final description = descriptionController.text.trim();
    final price = double.tryParse(priceController.text.trim());
    final weight = weightController.text.trim();
    final benefitsText = benefitsController.text.trim();
    final hasImage =
        _selectedImageBytes != null || imageController.text.trim().isNotEmpty;

    if (id.isEmpty ||
        name.isEmpty ||
        description.isEmpty ||
        weight.isEmpty ||
        benefitsText.isEmpty ||
        !hasImage) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All fields are required')));
      return;
    }

    if (price == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid price')));
      return;
    }
    if (widget.existing == null && idController.text.trim().isEmpty) {
      _syncIdFromName();
      if (idController.text.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid name')));
        return;
      }
    }

    setState(() => saving = true);
    final client = ref.read(supabaseClientProvider);
    String imageUrl = imageController.text.trim();
    try {
      if (_selectedImageBytes != null) {
        imageUrl = await _uploadImage(idController.text.trim());
        imageController.text = imageUrl;
      }
      final payload = Product(
        id: id,
        name: name,
        description: description,
        price: price,
        weight: weight,
        imageUrl: imageUrl,
        benefits: benefitsText
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        inStock: inStock,
      ).toMap();
      if (widget.existing == null) {
        await client.from('products').insert(payload);
      } else {
        await client
            .from('products')
            .update(payload)
            .eq('id', widget.existing!.id);
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
    final hasImage =
        _selectedImageBytes != null || imageController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Product' : 'Add Product'),
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
                          title: const Text('Delete product?'),
                          content: const Text(
                            'This will permanently delete the product.',
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
                            .from('products')
                            .delete()
                            .eq('id', widget.existing!.id);
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
          Text('Image', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_selectedImageBytes != null)
            Image.memory(_selectedImageBytes!, height: 180)
          else if (imageController.text.trim().isNotEmpty)
            Image.network(
              imageController.text.trim(),
              height: 180,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            )
          else
            const SizedBox(
              height: 120,
              child: Center(child: Text('No image selected')),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: Text(hasImage ? 'Replace Image' : 'Upload Image'),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: idController,
            readOnly: true,
            decoration: const InputDecoration(labelText: 'ID (auto)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
            ],
            decoration: const InputDecoration(labelText: 'Price',prefix: Text('Rs')),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: weightController,
            decoration: const InputDecoration(labelText: 'Weight'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: benefitsController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Benefits (comma separated)',
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            value: inStock,
            onChanged: (value) => setState(() => inStock = value),
            title: const Text('In Stock'),
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
