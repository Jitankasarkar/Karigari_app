import 'package:flutter/material.dart';
import 'package:proto_app/buy_page.dart';

class ProductDetailPage extends StatefulWidget {
  final Map<String, String> product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late Map<String, String> product;

  @override
  void initState() {
    super.initState();
    product = widget.product;
  }

  Widget buildImage(String? path) {
    if (path == null || path.isEmpty) {
      return const SizedBox(
        height: 260,
        child: Center(child: Text("No image available")),
      );
    }

    final cleanPath = path.replaceAll('"', '');

    return Image.network(
      cleanPath,
      width: double.infinity,
      height: 260,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const SizedBox(
          height: 260,
          child: Center(child: CircularProgressIndicator()),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const SizedBox(
          height: 260,
          child: Center(child: Text("Image failed to load")),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanImage = product["image"]?.replaceAll('"', '') ?? "";

    return Scaffold(
      appBar: AppBar(
        title: Text(
          product["title"] ?? "",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color.fromARGB(255, 222, 128, 47),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildImage(product["image"]),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product["title"] ?? "",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      product["description"] ?? "",
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Crafted by: Local Artisan Group",
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Item Details",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "- 100% eco-friendly & handmade\n"
                      "- Locally sourced materials\n"
                      "- Customization available on request\n"
                      "- Lightweight and durable",
                      style: TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      '₹${product["price"] ?? "0"}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // TODO: Add to cart logic
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Color.fromARGB(255, 141, 83, 20)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Add to Cart"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BuyPage(
                            productName: product["title"] ?? "",
                            productPrice: product["price"] ?? "",
                            productImage: cleanImage,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 141, 83, 20),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Buy Now", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
