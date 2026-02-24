class Product {
  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.weight,
    required this.imageUrl,
    required this.benefits,
    required this.inStock,
  });

  final String id;
  final String name;
  final String description;
  final double price;
  final String weight;
  final String imageUrl;
  final List<String> benefits;
  final bool inStock;

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      weight: map['weight']?.toString() ?? '',
      imageUrl: map['image_url']?.toString() ?? '',
      benefits:
          (map['benefits'] as List?)?.map((v) => v.toString()).toList() ?? [],
      inStock: map['in_stock'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'weight': weight,
      'image_url': imageUrl,
      'benefits': benefits,
      'in_stock': inStock,
    };
  }
}
