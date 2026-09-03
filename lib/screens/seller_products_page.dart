import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SellerProductsPage extends StatefulWidget {
  final String sellerId;
  final String sellerName;

  const SellerProductsPage({
    super.key,
    required this.sellerId,
    required this.sellerName,
  });

  @override
  State<SellerProductsPage> createState() => _SellerProductsPageState();
}

class _SellerProductsPageState extends State<SellerProductsPage> {
  // =========================================================
  // THEME
  // =========================================================

  static const Color primaryOrange = Color(0xFFE4862D);

  static const Color deepOrange = Color(0xFFD66A16);

  static const Color background = Color(0xFFF8F5F0);

  static const Color cardBackground = Color(0xFFFFFEFC);

  static const Color textPrimary = Color(0xFF172033);

  static const Color textSecondary = Color(0xFF737985);

  static const Color accent = Color(0xFF14B8A6);

  static const Color accentLight = Color(0xFFE5F8F4);

  static const Color inactiveColor = Color(0xFFF59E0B);

  // =========================================================
  // FIRESTORE
  // =========================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =========================================================
  // SEARCH / FILTER
  // =========================================================

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = "";
  String _selectedFilter = "All";

  // =========================================================
  // PRICE
  // =========================================================

  double _getPrice(dynamic price) {
    if (price == null) {
      return 0;
    }

    if (price is num) {
      return price.toDouble();
    }

    return double.tryParse(price.toString()) ?? 0;
  }

  // =========================================================
  // DATE
  // =========================================================

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();

      const months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ];

      return "${date.day} ${months[date.month - 1]} ${date.year}";
    }

    return "Date unavailable";
  }

  // =========================================================
  // IMAGE URL
  // =========================================================

  String _getImageUrl(Map<String, dynamic> data) {
    final value = data['imageUrl'] ?? data['image'] ?? "";

    return value.toString().replaceAll('"', '').trim();
  }

  // =========================================================
  // TAGS
  // =========================================================

  List<String> _getTags(Map<String, dynamic> data) {
    final rawTags = data['tags'];

    if (rawTags is List) {
      return rawTags
          .map((tag) => tag.toString().trim())
          .where((tag) => tag.isNotEmpty)
          .take(3)
          .toList();
    }

    return [];
  }

  // =========================================================
  // ACTIVE STATUS
  // =========================================================

  bool _isProductActive(Map<String, dynamic> data) {
    final value = data['isAvailable'];

    if (value is bool) {
      return value;
    }

    return true;
  }

  // =========================================================
  // DELETE PRODUCT
  // =========================================================

  Future<void> _deleteProduct(QueryDocumentSnapshot document) async {
    final data = document.data() as Map<String, dynamic>;

    final productName = data['title']?.toString().trim().isNotEmpty == true
        ? data['title'].toString().trim()
        : "this product";

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE8E4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFE4573D),
                    size: 27,
                  ),
                ),

                const SizedBox(height: 14),

                const Text(
                  "Delete product?",
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Are you sure you want to delete "$productName"?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: textSecondary,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  "This product will also disappear from the buyer catalog.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: Color(0xFF9A9A9A),
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext, false);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textPrimary,
                            side: const BorderSide(color: Color(0xFFE8E1DA)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext, true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE4573D),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          child: const Text(
                            "Delete",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _firestore.collection('products').doc(document.id).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF172033),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF5EEAD4),
                size: 20,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  '"$productName" deleted.',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFE4573D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: const Text(
            "Unable to delete product. Please try again.",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      );

      debugPrint("Error deleting product: $e");
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: primaryOrange,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: background,
        body: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('products')
              .where('sellerId', isEqualTo: widget.sellerId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: primaryOrange),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    "Unable to load products.\n\n${snapshot.error}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: textSecondary),
                  ),
                ),
              );
            }

            final allProducts = snapshot.data?.docs ?? [];

            // =================================================
            // FILTER PRODUCTS
            // =================================================

            final filteredProducts = allProducts.where((doc) {
              final data = doc.data() as Map<String, dynamic>;

              final title = data['title']?.toString().toLowerCase() ?? "";

              final category = data['category']?.toString().toLowerCase() ?? "";

              final tags = _getTags(data).join(" ").toLowerCase();

              final matchesSearch =
                  _searchQuery.isEmpty ||
                  title.contains(_searchQuery) ||
                  category.contains(_searchQuery) ||
                  tags.contains(_searchQuery);

              final active = _isProductActive(data);

              final matchesFilter =
                  _selectedFilter == "All" ||
                  (_selectedFilter == "Active" && active) ||
                  (_selectedFilter == "Inactive" && !active);

              return matchesSearch && matchesFilter;
            }).toList();

            // =================================================
            // SORT NEWEST FIRST
            // =================================================

            filteredProducts.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;

              final bData = b.data() as Map<String, dynamic>;

              final aTime = aData['timestamp'];

              final bTime = bData['timestamp'];

              if (aTime is Timestamp && bTime is Timestamp) {
                return bTime.compareTo(aTime);
              }

              return 0;
            });

            // =================================================
            // STATS
            // =================================================

            final activeCount = allProducts.where((doc) {
              final data = doc.data() as Map<String, dynamic>;

              return _isProductActive(data);
            }).length;

            final inactiveCount = allProducts.length - activeCount;

            final categories = allProducts
                .map((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  return data['category']?.toString().trim() ?? "";
                })
                .where((value) => value.isNotEmpty)
                .toSet()
                .length;

            return RefreshIndicator(
              color: primaryOrange,
              onRefresh: () async {
                setState(() {});
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // =================================================
                  // HEADER
                  // =================================================

                  SliverToBoxAdapter(
                    child: _buildHeader(totalProducts: allProducts.length),
                  ),

                  // =================================================
                  // QUICK STATS
                  // =================================================
                  SliverToBoxAdapter(
                    child: _buildQuickStats(
                      total: allProducts.length,
                      active: activeCount,
                      inactive: inactiveCount,
                      categories: categories,
                    ),
                  ),

                  // =================================================
                  // SEARCH
                  // =================================================
                  SliverToBoxAdapter(child: _buildSearch()),

                  // =================================================
                  // FILTERS
                  // =================================================
                  SliverToBoxAdapter(child: _buildFilters()),

                  // =================================================
                  // SECTION HEADER
                  // =================================================
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 21,
                            decoration: BoxDecoration(
                              color: primaryOrange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),

                          const SizedBox(width: 9),

                          Expanded(
                            child: Text(
                              _selectedFilter == "All"
                                  ? "All Products"
                                  : "$_selectedFilter Products",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),

                          Text(
                            filteredProducts.length.toString(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // =================================================
                  // PRODUCTS
                  // =================================================
                  if (filteredProducts.isEmpty)
                    SliverToBoxAdapter(child: _buildEmptyState())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 35),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final document = filteredProducts[index];

                          final data = document.data() as Map<String, dynamic>;

                          return _buildProductCard(document, data, index);
                        }, childCount: filteredProducts.length),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildHeader({required int totalProducts}) {
    final double topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding + 10, 20, 25),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE99529), Color(0xFFD96E18)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =================================================
          // TOP ROW
          // =================================================

          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Products",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 2),

                    const Text(
                      "Your handmade catalog",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),

          const SizedBox(height: 23),

          // =================================================
          // COUNT
          // =================================================
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                totalProducts.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -1,
                ),
              ),

              const SizedBox(width: 10),

              const Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Text(
                  "products in your shop",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // QUICK STATS
  // =========================================================

  Widget _buildQuickStats({
    required int total,
    required int active,
    required int inactive,
    required int categories,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 20),
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEDE5DC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMiniStat(
              icon: Icons.inventory_2_outlined,
              value: total.toString(),
              label: "All",
              color: accent,
              background: accentLight,
            ),
          ),

          _buildStatDivider(),

          Expanded(
            child: _buildMiniStat(
              icon: Icons.check_circle_outline_rounded,
              value: active.toString(),
              label: "Active",
              color: const Color(0xFF10B981),
              background: const Color(0xFFEEF9F1),
            ),
          ),

          _buildStatDivider(),

          Expanded(
            child: _buildMiniStat(
              icon: Icons.pause_circle_outline_rounded,
              value: inactive.toString(),
              label: "Inactive",
              color: inactiveColor,
              background: const Color(0xFFFFF7E8),
            ),
          ),

          _buildStatDivider(),

          Expanded(
            child: _buildMiniStat(
              icon: Icons.sell_outlined,
              value: categories.toString(),
              label: "Categories",
              color: const Color(0xFF7167E8),
              background: const Color(0xFFF3F1FF),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MINI STAT
  // =========================================================

  Widget _buildMiniStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required Color background,
  }) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 21),
        ),

        const SizedBox(height: 6),

        Text(
          value,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),

        const SizedBox(height: 1),

        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // STAT DIVIDER
  // =========================================================

  Widget _buildStatDivider() {
    return Container(width: 1, height: 54, color: const Color(0xFFEDE8E2));
  }

  // =========================================================
  // SEARCH
  // =========================================================

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8E1DA)),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value.trim().toLowerCase();
            });
          },
          style: const TextStyle(
            fontSize: 13,
            color: textPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: const InputDecoration(
            hintText: "Search products, tags or categories",
            hintStyle: TextStyle(fontSize: 13, color: Color(0xFF9B9B9B)),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: Color(0xFF777777),
              size: 22,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 17),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // FILTERS
  // =========================================================

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Row(
        children: [
          _buildFilterButton("All"),
          const SizedBox(width: 9),
          _buildFilterButton("Active"),
          const SizedBox(width: 9),
          _buildFilterButton("Inactive"),
        ],
      ),
    );
  }

  // =========================================================
  // FILTER BUTTON
  // =========================================================

  Widget _buildFilterButton(String title) {
    final bool selected = _selectedFilter == title;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = title;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? primaryOrange : cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? primaryOrange : const Color(0xFFE5DED6),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : textSecondary,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // PRODUCT CARD
  // =========================================================

  Widget _buildProductCard(
    QueryDocumentSnapshot document,
    Map<String, dynamic> data,
    int index,
  ) {
    final String title = data['title']?.toString().trim().isNotEmpty == true
        ? data['title'].toString().trim()
        : "Untitled Product";

    final double price = _getPrice(data['price']);

    final String imageUrl = _getImageUrl(data);

    final List<String> tags = _getTags(data);

    final bool active = _isProductActive(data);

    final Color statusColor = active ? const Color(0xFF10B981) : inactiveColor;

    // =========================================================
    // COMPACT CARD
    // =========================================================

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 250 + (index * 45)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: const Color(0xFFEDE5DC)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.022),
              blurRadius: 11,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // =================================================
            // IMAGE
            // =================================================

            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 102,
                height: 102,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildImagePlaceholder();
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) {
                            return child;
                          }

                          return _buildImagePlaceholder(loading: true);
                        },
                      )
                    : _buildImagePlaceholder(),
              ),
            ),

            const SizedBox(width: 12),

            // =================================================
            // RIGHT CONTENT
            // =================================================
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                              height: 1.12,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        splashRadius: 22,
                        offset: const Offset(0, 42),
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        icon: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF7F3EE),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.more_horiz_rounded,
                            size: 20,
                            color: Color(0xFF777777),
                          ),
                        ),
                        onSelected: (value) {
                          if (value == "delete") {
                            _deleteProduct(document);
                          }
                        },
                        itemBuilder: (context) {
                          return const [
                            PopupMenuItem<String>(
                              value: "delete",
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline_rounded,
                                    color: Color(0xFFE4573D),
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    "Delete product",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFE4573D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ];
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "₹${price.toStringAsFixed(0)}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: deepOrange,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  if (tags.isNotEmpty)
                    SizedBox(
                      height: 22,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.zero,
                        children: tags.map((tag) {
                          return Container(
                            margin: const EdgeInsets.only(right: 5),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F2EE),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Text(
                              tag,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: Color(0xFF969696),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _formatDate(data['timestamp']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              active ? "Active" : "Inactive",
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // =========================================================
  // IMAGE PLACEHOLDER
  // =========================================================

  Widget _buildImagePlaceholder({bool loading = false}) {
    return Container(
      color: const Color(0xFFF3EFEA),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primaryOrange,
                ),
              )
            : const Icon(
                Icons.image_outlined,
                color: Color(0xFFB5AEA6),
                size: 30,
              ),
      ),
    );
  }

  // =========================================================
  // EMPTY STATE
  // =========================================================

  Widget _buildEmptyState() {
    final bool searching = _searchQuery.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 30),
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEDE5DC)),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1E4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: deepOrange,
              size: 30,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            searching
                ? "No products found"
                : _selectedFilter == "Inactive"
                ? "No inactive products"
                : "No products yet",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            searching
                ? "Try a different product name, tag or category."
                : "Products uploaded to your shop will appear here.",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
