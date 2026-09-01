import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:proto_app/product_detail_page.dart';
import 'package:proto_app/add_to_cart_page.dart';

import '../services/llama_service.dart';

class AIAssistant extends StatefulWidget {
  const AIAssistant({
    super.key,
  });

  @override
  State<AIAssistant> createState() =>
      _AIAssistantState();
}

class _AIAssistantState
    extends State<AIAssistant> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _controller =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  final FocusNode _inputFocusNode =
      FocusNode();

  // ============================================================
  // FIRESTORE
  // ============================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ============================================================
  // CHAT
  // ============================================================

  final List<_ChatMessage> _messages =
      <_ChatMessage>[];

  final List<Map<String, String>>
      _conversation =
      <Map<String, String>>[];

  bool _isTyping = false;

  // ============================================================
  // SHOPPING MEMORY
  // ============================================================

  Map<String, dynamic>? _lastIntent;

  /// Products currently displayed to the customer.
  List<Map<String, dynamic>>
      _shownProducts =
      <Map<String, dynamic>>[];

  /// Products selected by the customer
  /// and waiting for cart confirmation.
  List<Map<String, dynamic>>
      _pendingCartProducts =
      <Map<String, dynamic>>[];

  /// Waiting for:
  ///
  /// "yes"
  /// "yes add it"
  /// "no"
  ///
  bool _awaitingCartConfirmation =
      false;

  /// Waiting for the customer to identify
  /// a product from the displayed products.
  bool _awaitingProductSelection =
      false;

  /// Products already shown in the current search.
  final Set<String> _shownProductIds =
      <String>{};

  // ============================================================
  // ALIASES
  // ============================================================

  static const Map<String, List<String>>
      _categoryAliases = {
    'Jewellery': [
      'jewellery',
      'jewelry',
      'jewel',
      'jewels',
      'ornament',
      'ornaments',
    ],
    'Home Decor': [
      'home decor',
      'home decoration',
      'home décor',
      'decor',
      'decoration',
      'house decor',
    ],
    'Kitchenware': [
      'kitchenware',
      'kitchen',
      'utensil',
      'utensils',
      'cookware',
    ],
    'Clothing': [
      'clothing',
      'clothes',
      'apparel',
      'outfit',
      'outfits',
      'fashion',
    ],
    'Bags': [
      'bag',
      'bags',
      'handbag',
      'handbags',
      'purse',
      'purses',
      'tote',
    ],
    'Pottery': [
      'pottery',
      'ceramic',
      'ceramics',
    ],
    'Handicrafts': [
      'handicraft',
      'handicrafts',
      'craft',
      'crafts',
    ],
  };

  static const Map<String, List<String>>
      _productTypeAliases = {
    'Bangles': [
      'bangle',
      'bangles',
      'wrist bangle',
      'wrist bangles',
    ],
    'Necklace': [
      'necklace',
      'necklaces',
      'neck piece',
      'neckpieces',
      'neckwear',
    ],
    'Earrings': [
      'earring',
      'earrings',
      'ear ring',
    ],
    'Bracelet': [
      'bracelet',
      'bracelets',
    ],
    'Table Cloth': [
      'table cloth',
      'tablecloth',
      'table cover',
      'table covers',
    ],
    'Table Runner': [
      'table runner',
      'table runners',
    ],
    'Basket': [
      'basket',
      'baskets',
      'storage basket',
      'storage baskets',
    ],
    'Saree': [
      'saree',
      'sarees',
      'sari',
      'saris',
    ],
    'Dress': [
      'dress',
      'dresses',
    ],
    'Bag': [
      'bag',
      'bags',
      'handbag',
      'handbags',
      'tote bag',
      'tote bags',
    ],
    'Lantern': [
      'lantern',
      'lanterns',
    ],
    'Candle': [
      'candle',
      'candles',
      'soy candle',
      'scented candle',
    ],
    'Flower Vase': [
      'flower vase',
      'vase',
      'vases',
    ],
    'Clay Pot': [
      'clay pot',
      'clay pots',
      'terracotta pot',
      'terracotta pots',
    ],
    'Candle Holder': [
      'candle holder',
      'candle holders',
    ],
    'Wall Hanging': [
      'wall hanging',
      'wall hangings',
      'macrame wall hanging',
      'macrame',
    ],
    'Serving Tray': [
      'serving tray',
      'serving trays',
      'wooden tray',
      'tray',
      'trays',
    ],
    'Kitchen Utensils': [
      'kitchen utensil',
      'kitchen utensils',
      'wooden utensil',
      'wooden utensils',
    ],
  };

  static const Map<String, List<String>>
      _materialAliases = {
    'terracotta': [
      'terracotta',
      'terracotta clay',
    ],
    'clay': [
      'clay',
    ],
    'cotton': [
      'cotton',
      'cotton thread',
    ],
    'silk': [
      'silk',
      'silk thread',
    ],
    'bamboo': [
      'bamboo',
    ],
    'wood': [
      'wood',
      'wooden',
    ],
    'jute': [
      'jute',
    ],
    'ceramic': [
      'ceramic',
      'ceramics',
    ],
    'wool': [
      'wool',
    ],
    'brass': [
      'brass',
    ],
    'metal': [
      'metal',
    ],
    'beads': [
      'bead',
      'beads',
      'beaded',
    ],
    'glass': [
      'glass',
    ],
  };

  static const List<String>
      _colours = [
    'red',
    'blue',
    'green',
    'yellow',
    'black',
    'white',
    'pink',
    'orange',
    'purple',
    'brown',
    'gold',
    'silver',
    'beige',
    'cream',
    'maroon',
    'multicolour',
    'multicolor',
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _messages.add(
      const _ChatMessage(
        text:
            "Hi! 👋 I'm your Karigari shopping assistant. What handmade products are you looking for?",
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();

    super.dispose();
  }

  // ============================================================
  // CURRENT USER
  // ============================================================

  String? get _userId {
    return FirebaseAuth
        .instance
        .currentUser
        ?.uid;
  }

  // ============================================================
  // CART REFERENCE
  // ============================================================

  CollectionReference<Map<String, dynamic>>?
      get _cartReference {
    final uid = _userId;

    if (uid == null || uid.isEmpty) {
      return null;
    }

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('cart');
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> _sendMessage() async {
    final text =
        _controller.text.trim();

    if (text.isEmpty ||
        _isTyping) {
      return;
    }

    final normalized =
        _normalise(text);

    setState(() {
      _messages.add(
        _ChatMessage(
          text: text,
          isUser: true,
        ),
      );

      _conversation.add({
        'role': 'user',
        'text': text,
      });

      _controller.clear();

      _isTyping = true;
    });

    _scrollToBottom();

    try {
      // ========================================================
      // 1. CART CONFIRMATION
      // ========================================================

      if (_awaitingCartConfirmation &&
          _pendingCartProducts.isNotEmpty) {
        await _handleCartConfirmation(
          normalized,
        );

        return;
      }

      // ========================================================
      // 2. PRODUCT SELECTION
      // ========================================================

      if (_awaitingProductSelection &&
          _shownProducts.isNotEmpty) {
        final handled =
            await _handleProductSelection(
          text,
          normalized,
        );

        if (handled) {
          return;
        }

        // User may have abandoned the current
        // product selection and started a new search.
        if (_looksLikeNewShoppingRequest(
          text,
        )) {
          _awaitingProductSelection =
              false;

          _clearDisplayedProducts();

          await _processShoppingRequest(
            text,
          );

          return;
        }

        await _respond(
          "Which product would you like? "
          "You can tell me the product name.",
        );

        return;
      }

      // ========================================================
      // 3. RESET
      // ========================================================

      if (_isResetRequest(normalized)) {
        _resetShoppingState();

        await _respond(
          "Absolutely. Let's start fresh. What are you looking for?",
        );

        return;
      }

      // ========================================================
      // 4. NORMAL CONVERSATION
      // ========================================================

      if (_isCasualMessage(normalized)) {
        await _handleNormalConversation(
          text,
        );

        return;
      }

      // ========================================================
      // 5. NORMAL SHOPPING REQUEST
      // ========================================================

      await _processShoppingRequest(
        text,
      );
    } catch (e, stackTrace) {
      debugPrint(
        'AI assistant error: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) return;

      await _respond(
        "I'm having a little trouble understanding that right now. "
        "Tell me what handmade product you're looking for.",
      );
    }
  }

  // ============================================================
  // SHOPPING REQUEST
  // ============================================================

  Future<void> _processShoppingRequest(
    String text,
  ) async {
    Map<String, dynamic> llamaIntent = {};

    try {
      llamaIntent =
          await LlamaService
              .understandRequest(
        userMessage: text,
        conversation:
            _conversation
                .take(
                  _conversation.length > 0
                      ? _conversation.length - 1
                      : 0,
                )
                .toList(),
        previousIntent:
            _lastIntent,
        conversationState: {
          'awaitingProductSelection':
              _awaitingProductSelection,
          'awaitingCartConfirmation':
              _awaitingCartConfirmation,
          'shownProductIds':
              _shownProductIds.toList(),
        },
      );
    } catch (e) {
      debugPrint(
        'Llama understanding error: $e',
      );
    }

    // ==========================================================
    // MERGE AI + DETERMINISTIC UNDERSTANDING
    // ==========================================================

    final intent =
        _mergeIntent(
      previous: _lastIntent,
      current: llamaIntent,
      userMessage: text,
    );

    final explicitCategory =
        _detectCategory(text);

    final explicitType =
        _detectProductType(text);

    if (explicitCategory != null) {
      intent['category'] =
          explicitCategory;
    }

    if (explicitType != null) {
      intent['productType'] =
          explicitType;
    }

    // ==========================================================
    // IMPORTANT:
    //
    // Broad category request:
    //
    // "show me some home decor"
    //
    // MUST NOT search products immediately.
    // ==========================================================

    final category =
        intent['category']
            ?.toString()
            .trim();

    final productType =
        intent['productType']
            ?.toString()
            .trim();

    final occasion =
        _stringList(
      intent['occasion'],
    );

    final isBroadCategoryRequest =
        category != null &&
        category.isNotEmpty &&
        (productType == null ||
            productType.isEmpty) &&
        _hasNoSpecificAttribute(
          intent,
        );

    final isBroadGiftRequest =
        occasion.contains('gift') &&
        (category == null ||
            category.isEmpty) &&
        (productType == null ||
            productType.isEmpty);

    if (isBroadCategoryRequest ||
        isBroadGiftRequest) {
      _lastIntent = intent;

      await _askCatalogQuestion(
        category:
            isBroadCategoryRequest
                ? category
                : null,
        giftRequest:
            isBroadGiftRequest,
      );

      return;
    }

    // ==========================================================
    // VAGUE REQUEST
    // ==========================================================

    if (!_hasUsefulSearchIntent(
      intent,
    )) {
      await _askCatalogQuestion();

      return;
    }

    // ==========================================================
    // SAVE MEMORY
    // ==========================================================

    _lastIntent = intent;

    // ==========================================================
    // SEARCH FIRESTORE
    // ==========================================================

    final products =
        await _findMatchingProducts(
      intent,
    );

    if (!mounted) return;

    // ==========================================================
    // NO PRODUCTS
    // ==========================================================

    if (products.isEmpty) {
      await _respond(
        _noResultsResponse(
          intent,
        ),
      );

      return;
    }

    // ==========================================================
    // SAVE DISPLAYED PRODUCTS
    // ==========================================================

    _shownProducts = products;

    _shownProductIds
      ..clear()
      ..addAll(
        products.map(
          _productId,
        ),
      );

    _awaitingProductSelection =
        true;

    // ==========================================================
    // IMPORTANT:
    //
    // ONLY SAY THAT PRODUCTS WERE FOUND.
    //
    // DO NOT ASK TO ADD THEM TO CART.
    // ==========================================================

    final response =
        _foundProductsResponse(
      products,
      intent,
    );

    await _showProducts(
      products,
      response,
    );

    // NO _askToAddProduct HERE.
    //
    // This is the key fix.
  }

  // ============================================================
  // PRODUCT SELECTION
  // ============================================================

  Future<bool> _handleProductSelection(
    String text,
    String normalized,
  ) async {
    // ----------------------------------------------------------
    // First try exact product-name matching.
    // ----------------------------------------------------------

    final exactMatches =
        _productsMentionedByName(
      text,
    );

    if (exactMatches.length == 1) {
      await _askToAddProducts(
        exactMatches,
      );

      return true;
    }

    if (exactMatches.length > 1) {
      await _askToAddProducts(
        exactMatches,
      );

      return true;
    }

    // ----------------------------------------------------------
    // "this one", "that one", "yes this one"
    // ----------------------------------------------------------

    final refersToDisplayedProduct =
        _refersToDisplayedProduct(
      normalized,
    );

    if (refersToDisplayedProduct) {
      if (_shownProducts.length == 1) {
        await _askToAddProducts(
          [_shownProducts.first],
        );

        return true;
      }

      await _respond(
        "Sure. Which one do you mean? "
        "Please tell me the product name.",
      );

      return true;
    }

    // ----------------------------------------------------------
    // "these", "I like these", "I want to buy these"
    // ----------------------------------------------------------

    if (_refersToMultipleDisplayedProducts(
      normalized,
    )) {
      if (_shownProducts.isNotEmpty) {
        await _askToAddProducts(
          _shownProducts,
        );

        return true;
      }
    }

    // ----------------------------------------------------------
    // "I like the necklace"
    //
    // If exactly one displayed product matches
    // the requested product type, select it.
    // ----------------------------------------------------------

    final requestedType =
        _detectProductType(
      text,
    );

    if (requestedType != null) {
      final candidates =
          _shownProducts.where(
        (product) =>
            _matchesProductType(
          product,
          requestedType,
        ),
      ).toList();

      if (candidates.length == 1) {
        await _askToAddProducts(
          candidates,
        );

        return true;
      }

      if (candidates.length > 1) {
        await _respond(
          "I found several products of that type. "
          "Which one would you like?",
        );

        return true;
      }
    }

    return false;
  }

  // ============================================================
  // ASK CART CONFIRMATION
  // ============================================================

  Future<void> _askToAddProducts(
    List<Map<String, dynamic>> products,
  ) async {
    if (products.isEmpty) {
      return;
    }

    _pendingCartProducts =
        List<Map<String, dynamic>>.from(
      products,
    );

    // The product has now been selected. The displayed recommendation cards
    // must disappear while we wait for the cart confirmation. Otherwise the
    // old recommendation list stays pinned below the new assistant message.
    _clearDisplayedProducts();

    _awaitingCartConfirmation =
        true;

    _awaitingProductSelection =
        false;

    if (products.length == 1) {
      final title =
          _productTitle(
        products.first,
      );

      await _respond(
        'Great choice! Would you like to add "$title" to your cart?',
      );

      return;
    }

    await _respond(
      'Great choice! Would you like to add these ${products.length} products to your cart?',
    );
  }

  // ============================================================
  // CART CONFIRMATION
  // ============================================================

  Future<void> _handleCartConfirmation(
    String normalized,
  ) async {
    // ==========================================================
    // YES
    // ==========================================================

    if (_isPositive(normalized)) {
      final products =
          List<Map<String, dynamic>>.from(
        _pendingCartProducts,
      );

      final success =
          await _addProductsToCart(
        products,
      );

      if (!mounted) return;

      if (!success) {
        return;
      }

      _pendingCartProducts.clear();

      // The recommendation is finished once the product is added. Do not
      // leave the old product card visible under the success message.
      _clearDisplayedProducts();

      _awaitingCartConfirmation =
          false;

      await _respond(
        products.length == 1
            ? "Product added to your cart."
            : "Products added to your cart.",
        showCartButton: true,
      );

      return;
    }

    // ==========================================================
    // NO
    // ==========================================================

    if (_isNegative(normalized)) {
      _pendingCartProducts.clear();

      // User rejected the selected product, so its recommendation card is
      // no longer relevant.
      _clearDisplayedProducts();

      _awaitingCartConfirmation =
          false;

      await _respond(
        "Not a problem. What products are you looking for then?",
      );

      return;
    }

    // ==========================================================
    // USER ABANDONS CURRENT PRODUCT
    //
    // Example:
    //
    // "no, show me necklaces instead"
    // ==========================================================

    if (_looksLikeNewShoppingRequest(
      normalized,
    )) {
      _pendingCartProducts.clear();

      // The customer has moved on to a different request. Remove the old
      // recommendation cards before processing the new search.
      _clearDisplayedProducts();

      _awaitingCartConfirmation =
          false;

      await _processShoppingRequest(
        normalized,
      );

      return;
    }

    // ==========================================================
    // OTHER ANSWER
    // ==========================================================

    await _respond(
      "Would you like me to add it to your cart?",
    );
  }

  // ============================================================
  // ADD PRODUCTS TO FIRESTORE CART
  // ============================================================

  Future<bool> _addProductsToCart(
    List<Map<String, dynamic>> products,
  ) async {
    final cart =
        _cartReference;

    if (cart == null) {
      await _respond(
        "Please log in before adding products to your cart.",
      );

      return false;
    }

    try {
      for (final product in products) {
        await _addSingleProductToCart(
          cart,
          product,
        );
      }

      return true;
    } catch (e) {
      debugPrint(
        'Cart error: $e',
      );

      await _respond(
        "I couldn't add the product to your cart right now. Please try again.",
      );

      return false;
    }
  }

  // ============================================================
  // ADD ONE PRODUCT
  // ============================================================

  Future<void> _addSingleProductToCart(
    CollectionReference<
            Map<String, dynamic>>
        cart,
    Map<String, dynamic> product,
  ) async {
    final productId =
        _productId(product);

    if (productId.isEmpty) {
      throw Exception(
        'Missing product ID',
      );
    }

    final cartItem =
        cart.doc(productId);

    final existing =
        await cartItem.get();

    if (existing.exists) {
      final quantity =
          _toInt(
        existing.data()?['quantity'],
      );

      await cartItem.update({
        'quantity': quantity + 1,
        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      return;
    }

    await cartItem.set({
      'productId':
          productId,

      'title':
          _productTitle(product),

      'description':
          (product['description'] ??
                  '')
              .toString(),

      'price':
          (product['price'] ??
                  '0')
              .toString(),

      'imageUrl':
          _productImage(product),

      'sellerId':
          (product['sellerId'] ??
                  '')
              .toString(),

      'sellerName':
          (product['sellerName'] ??
                  'Local Artisan')
              .toString(),

      'quantity': 1,

      'addedAt':
          FieldValue.serverTimestamp(),

      'updatedAt':
          FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // CATALOG QUESTION
  // ============================================================

  Future<void> _askCatalogQuestion({
    String? category,
    bool giftRequest = false,
  }) async {
    final options =
        await _getCatalogOptions(
      category: category,
    );

    if (!mounted) return;

    String question;

    if (category != null &&
        category.isNotEmpty) {
      question =
          'Sure! What kind of ${category.toLowerCase()} would you like?';
    } else if (giftRequest) {
      question =
          'Sure! What kind of handmade gift are you looking for?';
    } else {
      question =
          'Sure! What kind of handmade product are you looking for?';
    }

    await _respond(
      question,
      choices: options,
    );
  }

  // ============================================================
  // GET REAL CATALOG OPTIONS
  // ============================================================

  Future<List<String>>
      _getCatalogOptions({
    String? category,
  }) async {
    try {
      final snapshot =
          await _firestore
              .collection('products')
              .where(
                'isAvailable',
                isEqualTo: true,
              )
              .get();

      final options =
          <String>{};

      for (final doc
          in snapshot.docs) {
        final data =
            doc.data();

        if (category != null &&
            category.isNotEmpty &&
            !_matchesCategory(
              data,
              category,
            )) {
          continue;
        }

        final type =
            data['productType'] ??
                data['subcategory'];

        if (type != null &&
            type.toString().trim().isNotEmpty) {
          options.add(
            type.toString().trim(),
          );
        }
      }

      final sorted =
          options.toList()
            ..sort();

      return sorted
          .take(10)
          .toList();
    } catch (e) {
      debugPrint(
        'Catalog option error: $e',
      );

      // Fallback to known types.
      if (category == 'Jewellery') {
        return [
          'Bangles',
          'Necklace',
          'Earrings',
          'Bracelet',
        ];
      }

      if (category == 'Home Decor') {
        return [
          'Candle',
          'Candle Holder',
          'Clay Pot',
          'Flower Vase',
          'Wall Hanging',
          'Table Runner',
          'Table Cloth',
        ];
      }

      return [];
    }
  }

  // ============================================================
  // FIRESTORE PRODUCT SEARCH
  // ============================================================

  Future<List<Map<String, dynamic>>>
      _findMatchingProducts(
    Map<String, dynamic> intent,
  ) async {
    final snapshot =
        await _firestore
            .collection('products')
            .where(
              'isAvailable',
              isEqualTo: true,
            )
            .get();

    final allProducts =
        <Map<String, dynamic>>[];

    for (final doc
        in snapshot.docs) {
      final data =
          Map<String, dynamic>.from(
        doc.data(),
      );

      data['documentId'] =
          doc.id;

      allProducts.add(
        data,
      );
    }

    // ==========================================================
    // EXACT PRODUCT NAME SEARCH
    //
    // Example:
    // "show me Beaded Necklace"
    //
    // Prefer the exact Firestore product.
    // ==========================================================

    final exactProducts =
        _findExactTitleMatches(
      allProducts,
      _currentSearchText(intent),
    );

    if (exactProducts.isNotEmpty) {
      return exactProducts
          .take(5)
          .toList();
    }

    // ==========================================================
    // FILTER PRODUCTS
    // ==========================================================

    final scored =
        <_ScoredProduct>[];

    for (final product
        in allProducts) {
      final requestedType =
          _normalise(
        intent['productType'],
      );

      final requestedCategory =
          _normalise(
        intent['category'],
      );

      // --------------------------------------------------------
      // PRODUCT TYPE
      // --------------------------------------------------------

      if (requestedType.isNotEmpty &&
          !_matchesProductType(
            product,
            requestedType,
          )) {
        continue;
      }

      // --------------------------------------------------------
      // CATEGORY
      // --------------------------------------------------------

      if (requestedCategory.isNotEmpty &&
          !_matchesCategory(
            product,
            requestedCategory,
          )) {
        continue;
      }

      // --------------------------------------------------------
      // HANDMADE
      // --------------------------------------------------------

      if (intent['handmade'] ==
              true &&
          !_isHandmadeProduct(
            product,
          )) {
        continue;
      }

      // --------------------------------------------------------
      // MATERIAL
      // --------------------------------------------------------

      final materials =
          _stringList(
        intent['material'],
      );

      if (materials.isNotEmpty &&
          !_matchesAnyField(
            product,
            'material',
            materials,
          )) {
        continue;
      }

      // --------------------------------------------------------
      // COLOUR
      // --------------------------------------------------------

      final colours =
          _stringList(
        intent['colour'],
      );

      if (colours.isNotEmpty &&
          !_matchesAnyField(
            product,
            'colour',
            colours,
          )) {
        continue;
      }

      // --------------------------------------------------------
      // STYLE
      // --------------------------------------------------------

      final styles =
          _stringList(
        intent['style'],
      );

      if (styles.isNotEmpty &&
          !_matchesAnyField(
            product,
            'style',
            styles,
          )) {
        continue;
      }

      // --------------------------------------------------------
      // OCCASION
      // --------------------------------------------------------

      final occasions =
          _stringList(
        intent['occasion'],
      );

      if (occasions.isNotEmpty &&
          !_matchesOccasion(
            product,
            occasions,
          )) {
        continue;
      }

      // --------------------------------------------------------
      // BUDGET
      // --------------------------------------------------------

      if (!_matchesBudget(
        product,
        intent['budget'],
      )) {
        continue;
      }

      final score =
          _calculateScore(
        product,
        intent,
      );

      scored.add(
        _ScoredProduct(
          product: product,
          score: score,
        ),
      );
    }

    scored.sort(
      (a, b) =>
          b.score.compareTo(
        a.score,
      ),
    );

    return scored
        .take(5)
        .map(
          (item) => item.product,
        )
        .toList();
  }

  // ============================================================
  // CURRENT SEARCH TEXT
  //
  // Stored in intent so exact-title matching can work.
  // ============================================================

  String _currentSearchText(
    Map<String, dynamic> intent,
  ) {
    return (
      intent['_searchText'] ??
      ''
    ).toString();
  }

  // ============================================================
  // EXACT TITLE MATCH
  // ============================================================

  List<Map<String, dynamic>>
      _findExactTitleMatches(
    List<Map<String, dynamic>>
        products,
    String query,
  ) {
    final normalizedQuery =
        _normalise(query);

    if (normalizedQuery.isEmpty) {
      return [];
    }

    final matches =
        <Map<String, dynamic>>[];

    for (final product
        in products) {
      final title =
          _normalise(
        product['title'],
      );

      if (title.isEmpty) {
        continue;
      }

      if (title ==
          normalizedQuery) {
        matches.add(
          product,
        );
      }
    }

    return matches;
  }

  // ============================================================
  // MERGE INTENT
  // ============================================================

  Map<String, dynamic> _mergeIntent({
    required Map<String, dynamic>?
        previous,
    required Map<String, dynamic>
        current,
    required String userMessage,
  }) {
    final result =
        <String, dynamic>{
      ...?previous,
      ...current,
    };

    result['_searchText'] =
        userMessage;

    final type =
        _detectProductType(
      userMessage,
    );

    final category =
        _detectCategory(
      userMessage,
    );

    final colours =
        _detectColours(
      userMessage,
    );

    final materials =
        _detectMaterials(
      userMessage,
    );

    if (type != null) {
      result['productType'] =
          type;
    }

    if (category != null) {
      result['category'] =
          category;
    }

    if (colours.isNotEmpty) {
      result['colour'] =
          colours;
    }

    if (materials.isNotEmpty) {
      result['material'] =
          materials;
    }

    // Product type determines category.
    if (type != null) {
      if (_isJewelleryType(
        type,
      )) {
        result['category'] =
            'Jewellery';
      }

      if (_isHomeDecorType(
        type,
      )) {
        result['category'] =
            'Home Decor';
      }

      if (_isClothingType(
        type,
      )) {
        result['category'] =
            'Clothing';
      }

      if (_isBagType(
        type,
      )) {
        result['category'] =
            'Bags';
      }
    }

    // ----------------------------------------------------------
    // OCCASION
    // ----------------------------------------------------------

    final occasion =
        _detectOccasion(
      userMessage,
    );

    if (occasion != null) {
      result['occasion'] =
          [occasion];
    }

    // ----------------------------------------------------------
    // HANDMADE
    // ----------------------------------------------------------

    if (_containsHandmade(
      userMessage,
    )) {
      result['handmade'] =
          true;
    }

    // ----------------------------------------------------------
    // Preserve previous intent for follow-ups.
    // ----------------------------------------------------------
bool _isExplicitNewSearch(String message) {
  final text = message.trim().toLowerCase();

  if (text.isEmpty) {
    return false;
  }

  // These are usually responses to the assistant's
  // previous question/action, NOT new searches.
  const continuationPhrases = {
    'yes',
    'yeah',
    'yep',
    'yup',
    'sure',
    'okay',
    'ok',
    'please',
    'yes please',
    'yes this one',
    'this one',
    'i like this',
    'i like this one',
    'i want this',
    'i want this one',
    'i would like this',
    'i would like to buy this',
    'i would like to buy these',
    'add it',
    'add this',
    'add this to cart',
    'buy this',
    'buy this one',
    'no',
    'no thanks',
    'no thank you',
    'nevermind',
  };

  if (continuationPhrases.contains(text)) {
    return false;
  }

  // Explicit phrases that clearly indicate the user
  // wants to start a different product search.
  const newSearchPhrases = [
    'show me',
    'find me',
    'i am looking for',
    'i\'m looking for',
    'i want',
    'i need',
    'looking for',
    'search for',
    'search me',
    'find some',
    'show some',
    'show a',
    'show me some',
    'show me a',
    'do you have',
    'can you show',
    'can i see',
    'i would like',
    'i\'d like',
  ];

  for (final phrase in newSearchPhrases) {
    if (text.startsWith(phrase)) {
      return true;
    }
  }

  // Product/category words strongly indicate a new search
  // when the message is not merely confirming a product.
  const productWords = [
    'necklace',
    'necklaces',
    'bangle',
    'bangles',
    'earring',
    'earrings',
    'jewellery',
    'jewelry',
    'table runner',
    'table runners',
    'table cloth',
    'tablecloth',
    'clay pot',
    'pots',
    'home decor',
    'home decoration',
    'kitchenware',
    'bags',
    'bag',
    'clothing',
    'dress',
    'dresses',
    'accessories',
    'gift',
    'gifts',
    'handmade',
  ];

  for (final word in productWords) {
    if (text.contains(word)) {
      // Avoid treating a product confirmation such as
      // "I like the beaded necklace" as a new search.
      if (text.startsWith('i like') ||
          text.startsWith('i want this') ||
          text.startsWith('i would like this') ||
          text.startsWith('this one') ||
          text.startsWith('yes')) {
        return false;
      }

      return true;
    }
  }

  return false;
}
    if (previous != null) {
      if (type == null &&
          !_isExplicitNewSearch(
            userMessage,
          )) {
        if (previous['productType'] !=
                null &&
            result['productType']
                == null) {
          result['productType'] =
              previous['productType'];
        }
      }
    }

    return result;
  }

  // ============================================================
  // MATCH PRODUCT TYPE
  // ============================================================

  bool _matchesProductType(
    Map<String, dynamic> product,
    String requestedType,
  ) {
    final requested =
        _normalise(
      requestedType,
    );

    final fields = [
      _normalise(
        product['productType'],
      ),
      _normalise(
        product['subcategory'],
      ),
      _normalise(
        product['title'],
      ),
    ];

    final aliases =
        _aliasesForType(
      requested,
    );

    return aliases.any(
      (alias) => fields.any(
        (field) =>
            field == alias ||
            field.contains(alias),
      ),
    );
  }

  // ============================================================
  // MATCH CATEGORY
  // ============================================================

  bool _matchesCategory(
    Map<String, dynamic> product,
    String requestedCategory,
  ) {
    final requested =
        _normalise(
      requestedCategory,
    );

    final category =
        _normalise(
      product['category'],
    );

    final sellerCategory =
        _normalise(
      product['sellerCategory'],
    );

    if (category ==
            requested ||
        sellerCategory ==
            requested) {
      return true;
    }

    final type =
        _normalise(
      product['productType'],
    );

    if (requested ==
            'jewellery' &&
        _isJewelleryType(
          _titleCaseType(type),
        )) {
      return true;
    }

    if (requested ==
            'home decor' &&
        _isHomeDecorType(
          _titleCaseType(type),
        )) {
      return true;
    }

    if (requested ==
            'clothing' &&
        _isClothingType(
          _titleCaseType(type),
        )) {
      return true;
    }

    if (requested ==
            'bags' &&
        _isBagType(
          _titleCaseType(type),
        )) {
      return true;
    }

    return false;
  }

  // ============================================================
  // MATCH FIELD
  // ============================================================

  bool _matchesAnyField(
    Map<String, dynamic> product,
    String field,
    List<String> requested,
  ) {
    final values =
        _stringList(
      product[field],
    );

    final text =
        _buildProductText(
      product,
    );

    return requested.any(
      (target) {
        final t =
            _normalise(target);

        return values.any(
              (value) =>
                  value == t ||
                  value.contains(t) ||
                  t.contains(value),
            ) ||
            text.contains(t);
      },
    );
  }

  // ============================================================
  // OCCASION
  // ============================================================

  bool _matchesOccasion(
    Map<String, dynamic> product,
    List<String> requested,
  ) {
    final text =
        _buildProductText(
      product,
    );

    final occasions =
        _stringList(
      product['occasion'],
    );

    final useCases =
        _stringList(
      product['useCases'],
    );

    return requested.any(
      (occasion) {
        final value =
            _normalise(
          occasion,
        );

        return occasions.any(
              (item) =>
                  item.contains(value),
            ) ||
            useCases.any(
              (item) =>
                  item.contains(value),
            ) ||
            text.contains(value);
      },
    );
  }

  // ============================================================
  // BUDGET
  // ============================================================

  bool _matchesBudget(
    Map<String, dynamic> product,
    dynamic budget,
  ) {
    if (budget is! Map) {
      return true;
    }

    final min =
        _toDouble(
      budget['min'],
    );

    final max =
        _toDouble(
      budget['max'],
    );

    if (min == null &&
        max == null) {
      return true;
    }

    final price =
        _toDouble(
      product['price'],
    );

    if (price == null) {
      return true;
    }

    if (min != null &&
        price < min) {
      return false;
    }

    if (max != null &&
        price > max) {
      return false;
    }

    return true;
  }

  // ============================================================
  // SCORE
  // ============================================================

  int _calculateScore(
    Map<String, dynamic> product,
    Map<String, dynamic> intent,
  ) {
    int score = 0;

    final title =
        _normalise(
      product['title'],
    );

    final text =
        _buildProductText(
      product,
    );

    final type =
        _normalise(
      product['productType'],
    );

    final requestedType =
        _normalise(
      intent['productType'],
    );

    final requestedCategory =
        _normalise(
      intent['category'],
    );

    if (requestedType.isNotEmpty &&
        _matchesProductType(
          product,
          requestedType,
        )) {
      score += 200;
    }

    if (requestedCategory.isNotEmpty &&
        _matchesCategory(
          product,
          requestedCategory,
        )) {
      score += 100;
    }

    for (final colour
        in _stringList(
      intent['colour'],
    )) {
      if (text.contains(
        colour,
      )) {
        score += 50;
      }
    }

    for (final material
        in _stringList(
      intent['material'],
    )) {
      if (text.contains(
        material,
      )) {
        score += 50;
      }
    }

    for (final style
        in _stringList(
      intent['style'],
    )) {
      if (text.contains(
        style,
      )) {
        score += 40;
      }
    }

    for (final occasion
        in _stringList(
      intent['occasion'],
    )) {
      if (text.contains(
        occasion,
      )) {
        score += 40;
      }
    }

    if (requestedType.isNotEmpty &&
        title.contains(
          requestedType,
        )) {
      score += 60;
    }

    if (type.isNotEmpty &&
        requestedType == type) {
      score += 80;
    }

    return score;
  }

  // ============================================================
  // PRODUCT TEXT
  // ============================================================

  String _buildProductText(
    Map<String, dynamic> product,
  ) {
    return [
      product['title'],
      product['description'],
      product['category'],
      product['subcategory'],
      product['productType'],
      product['sellerCategory'],
      ..._stringList(
        product['tags'],
      ),
      ..._stringList(
        product['keywords'],
      ),
      ..._stringList(
        product['searchTerms'],
      ),
      ..._stringList(
        product['material'],
      ),
      ..._stringList(
        product['colour'],
      ),
      ..._stringList(
        product['style'],
      ),
      ..._stringList(
        product['occasion'],
      ),
      ..._stringList(
        product['useCases'],
      ),
    ].map(
      _normalise,
    ).where(
      (value) => value.isNotEmpty,
    ).join(' ');
  }

  // ============================================================
  // HANDMADE
  // ============================================================

  bool _isHandmadeProduct(
    Map<String, dynamic> product,
  ) {
    final text =
        _buildProductText(
      product,
    );

    const words = [
      'handmade',
      'handcrafted',
      'hand made',
      'hand crafted',
      'artisan',
      'crafted',
      'locally made',
    ];

    return words.any(
      text.contains,
    );
  }

  // ============================================================
  // CATEGORY DETECTION
  // ============================================================

  String? _detectCategory(
    String text,
  ) {
    final normalized =
        _normalise(text);

    for (final entry
        in _categoryAliases.entries) {
      for (final alias
          in entry.value) {
        if (_containsPhrase(
          normalized,
          alias,
        )) {
          return entry.key;
        }
      }
    }

    final type =
        _detectProductType(
      normalized,
    );

    if (type != null) {
      if (_isJewelleryType(
        type,
      )) {
        return 'Jewellery';
      }

      if (_isHomeDecorType(
        type,
      )) {
        return 'Home Decor';
      }

      if (_isClothingType(
        type,
      )) {
        return 'Clothing';
      }

      if (_isBagType(
        type,
      )) {
        return 'Bags';
      }
    }

    return null;
  }

  // ============================================================
  // PRODUCT TYPE DETECTION
  // ============================================================

  String? _detectProductType(
    String text,
  ) {
    final normalized =
        _normalise(text);

    String? best;
    int bestLength = 0;

    for (final entry
        in _productTypeAliases.entries) {
      for (final alias
          in entry.value) {
        if (_containsPhrase(
          normalized,
          alias,
        )) {
          if (alias.length >
              bestLength) {
            best = entry.key;
            bestLength =
                alias.length;
          }
        }
      }
    }

    return best;
  }

  // ============================================================
  // OCCASION
  // ============================================================

  String? _detectOccasion(
    String text,
  ) {
    final normalized =
        _normalise(text);

    const aliases = {
      'wedding': [
        'wedding',
        'bridal',
        'bride',
        'marriage',
        'shaadi',
      ],
      'festival': [
        'festival',
        'festive',
        'celebration',
      ],
      'birthday': [
        'birthday',
      ],
      'housewarming': [
        'housewarming',
        'house warming',
      ],
      'gift': [
        'gift',
        'gifts',
        'present',
        'presents',
      ],
    };

    for (final entry
        in aliases.entries) {
      for (final alias
          in entry.value) {
        if (_containsPhrase(
          normalized,
          alias,
        )) {
          return entry.key;
        }
      }
    }

    return null;
  }

  // ============================================================
  // COLOURS
  // ============================================================

  List<String> _detectColours(
    String text,
  ) {
    final normalized =
        _normalise(text);

    return _colours.where(
      (colour) =>
          _containsPhrase(
        normalized,
        colour,
      ),
    ).toList();
  }

  // ============================================================
  // MATERIAL
  // ============================================================

  List<String> _detectMaterials(
    String text,
  ) {
    final normalized =
        _normalise(text);

    final result =
        <String>[];

    for (final entry
        in _materialAliases.entries) {
      if (entry.value.any(
        (alias) =>
            _containsPhrase(
          normalized,
          alias,
        ),
      )) {
        result.add(
          entry.key,
        );
      }
    }

    return result;
  }

  // ============================================================
  // HANDMADE DETECTION
  // ============================================================

  bool _containsHandmade(
    String text,
  ) {
    final normalized =
        _normalise(text);

    return [
      'handmade',
      'hand made',
      'handcrafted',
      'hand crafted',
      'artisan',
      'crafted',
    ].any(
      (word) =>
          _containsPhrase(
        normalized,
        word,
      ),
    );
  }

  // ============================================================
  // BROAD REQUEST CHECK
  // ============================================================

  bool _hasNoSpecificAttribute(
    Map<String, dynamic> intent,
  ) {
    return _stringList(
          intent['colour'],
        ).isEmpty &&
        _stringList(
          intent['material'],
        ).isEmpty &&
        _stringList(
          intent['style'],
        ).isEmpty &&
        _stringList(
          intent['occasion'],
        ).isEmpty;
  }

  bool _hasUsefulSearchIntent(
    Map<String, dynamic> intent,
  ) {
    return _hasNonEmpty(
          intent['category'],
        ) ||
        _hasNonEmpty(
          intent['productType'],
        ) ||
        _stringList(
          intent['colour'],
        ).isNotEmpty ||
        _stringList(
          intent['material'],
        ).isNotEmpty ||
        _stringList(
          intent['style'],
        ).isNotEmpty ||
        _stringList(
          intent['occasion'],
        ).isNotEmpty ||
        intent['handmade'] == true;
  }

  // ============================================================
  // PRODUCT SELECTION DETECTION
  // ============================================================

  List<Map<String, dynamic>>
      _productsMentionedByName(
    String text,
  ) {
    final normalized =
        _normalise(text);

    final matches =
        <Map<String, dynamic>>[];

    for (final product
        in _shownProducts) {
      final title =
          _normalise(
        product['title'],
      );

      if (title.isEmpty) {
        continue;
      }

      if (normalized.contains(
        title,
      )) {
        matches.add(
          product,
        );
      }
    }

    return matches;
  }

  bool _refersToDisplayedProduct(
    String normalized,
  ) {
    const phrases = [
      'this one',
      'that one',
      'yes this one',
      'yes that one',
      'i like this',
      'i like that',
      'i like this one',
      'i like that one',
      'buy this',
      'buy that',
      'buy this one',
      'buy that one',
      'i want this',
      'i want that',
      'i want this one',
      'i want that one',
      'i would like this',
      'i would like that',
      'i would like to buy this',
      'i would like to buy that',
      'yes i want this',
      'yes i want that',
    ];

    return phrases.any(
      normalized.contains,
    );
  }

  bool _refersToMultipleDisplayedProducts(
    String normalized,
  ) {
    const phrases = [
      'these',
      'those',
      'i like these',
      'i like those',
      'buy these',
      'buy those',
      'i want these',
      'i want those',
      'i would like to buy these',
      'i would like to buy those',
    ];

    return phrases.any(
      normalized.contains,
    );
  }

  // ============================================================
  // NEW SHOPPING REQUEST
  // ============================================================

  bool _looksLikeNewShoppingRequest(
    String text,
  ) {
    return _detectCategory(text) != null ||
        _detectProductType(text) != null ||
        _detectOccasion(text) != null ||
        _detectColours(text).isNotEmpty ||
        _detectMaterials(text).isNotEmpty ||
        _containsHandmade(text) ||
        text.contains(
          'show me',
        ) ||
        text.contains(
          'looking for',
        ) ||
        text.contains(
          'i want',
        ) ||
        text.contains(
          'i need',
        ) ||
        text.contains(
          'find me',
        );
  }

  // ============================================================
  // CASUAL
  // ============================================================

  bool _isCasualMessage(
    String text,
  ) {
    const values = {
      'hi',
      'hello',
      'hey',
      'hii',
      'hiii',
      'good morning',
      'good afternoon',
      'good evening',
      'how are you',
      'how are you doing',
      'thanks',
      'thank you',
      'thank you so much',
      'bye',
      'goodbye',
    };

    return values.contains(
      text,
    );
  }

  Future<void>
      _handleNormalConversation(
    String text,
  ) async {
    String response;

    try {
      response =
          await LlamaService
              .generateResponse(
        userMessage: text,
        products: const [],
        intent: const {
          'action':
              'normal_conversation',
        },
        conversation:
            _conversation,
      );
    } catch (e) {
      if (text.contains(
            'thank',
          )) {
        response =
            "You're welcome! 😊 What handmade products are you looking for?";
      } else if (text == 'bye' ||
          text == 'goodbye') {
        response =
            "Happy shopping on Karigari! 👋";
      } else {
        response =
            "Hi! 👋 What handmade products are you looking for?";
      }
    }

    await _respond(
      response,
    );
  }

  // ============================================================
  // POSITIVE
  // ============================================================

  bool _isPositive(
    String text,
  ) {
    const values = {
      'yes',
      'yes please',
      'yep',
      'yeah',
      'yup',
      'sure',
      'okay',
      'ok',
      'go ahead',
      'please do',
      'add it',
      'add that',
      'add this',
      'do it',
      'yes add it',
      'yes i want it',
      'yes i would like to buy this',
      'yes i would like to buy it',
    };

    if (values.contains(
      text,
    )) {
      return true;
    }

    return text.startsWith(
          'yes ',
        ) ||
        text.startsWith(
          'yeah ',
        ) ||
        text.startsWith(
          'yep ',
        );
  }

  // ============================================================
  // NEGATIVE
  // ============================================================

  bool _isNegative(
    String text,
  ) {
    const values = {
      'no',
      'nope',
      'nah',
      'not really',
      'no thanks',
      'no thank you',
      'dont',
      "don't",
      'not this',
      'not that',
    };

    return values.contains(
      text,
    );
  }

  // ============================================================
  // RESET
  // ============================================================

  bool _isResetRequest(
    String text,
  ) {
    const values = {
      'start over',
      'start again',
      'reset',
      'clear',
      'forget that',
      'never mind',
      'nevermind',
      'forget it',
    };

    return values.contains(
      text,
    );
  }

  void _resetShoppingState() {
    _lastIntent = null;

    _shownProducts = [];

    _shownProductIds.clear();

    _pendingCartProducts.clear();

    _awaitingCartConfirmation =
        false;

    _awaitingProductSelection =
        false;
  }

  // ============================================================
  // CLEAR DISPLAYED PRODUCTS
  // ============================================================

  void _clearDisplayedProducts() {
    _shownProducts = <Map<String, dynamic>>[];
    _shownProductIds.clear();
  }

  // ============================================================
  // RESPONSE
  // ============================================================

  Future<void> _respond(
    String text, {
    List<String> choices = const [],
    bool showCartButton = false,
  }) async {
    if (!mounted) return;

    setState(() {
      _isTyping = false;

      _messages.add(
        _ChatMessage(
          text: text,
          isUser: false,
          choices: choices,
          showCartButton:
              showCartButton,
        ),
      );

      _conversation.add({
        'role': 'assistant',
        'text': text,
      });
    });

    _scrollToBottom();
  }

  // ============================================================
  // SHOW PRODUCTS
  // ============================================================

  Future<void> _showProducts(
    List<Map<String, dynamic>>
        products,
    String response,
  ) async {
    if (!mounted) return;

    setState(() {
      _isTyping = false;

      _shownProducts =
          products;

      _messages.add(
        _ChatMessage(
          text: response,
          isUser: false,
        ),
      );

      _conversation.add({
        'role': 'assistant',
        'text': response,
      });
    });

    _scrollToBottom();
  }

  // ============================================================
  // FOUND RESPONSE
  // ============================================================

  String _foundProductsResponse(
    List<Map<String, dynamic>>
        products,
    Map<String, dynamic> intent,
  ) {
    final count =
        products.length;

    if (count == 1) {
      return "I found 1 product that matches your request.";
    }

    return "I found $count products that match your request.";
  }

  // ============================================================
  // NO RESULTS
  // ============================================================

  String _noResultsResponse(
    Map<String, dynamic> intent,
  ) {
    final type =
        intent['productType']
            ?.toString()
            .trim();

    final category =
        intent['category']
            ?.toString()
            .trim();

    final item =
        type != null &&
                type.isNotEmpty
            ? type
            : category != null &&
                    category.isNotEmpty
                ? category
                : 'products';

    return "I couldn't find a matching $item right now. "
        "Would you like to try a different colour, material, budget, or product type?";
  }

  // ============================================================
  // PRODUCT CARD
  // ============================================================

  Widget _buildProductCard(
    Map<String, dynamic> product,
  ) {
    final title =
        _productTitle(
      product,
    );

    final price =
        (product['price'] ??
                '0')
            .toString();

    final imageUrl =
        _productImage(
      product,
    );

    final seller =
        (product['sellerName'] ??
                '')
            .toString()
            .trim();

    return GestureDetector(
      onTap: () {
        _openProduct(
          product,
        );
      },
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 12,
        ),
        padding:
            const EdgeInsets.all(
          8,
        ),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          border: Border.all(
            color: Colors.black
                .withOpacity(
              0.06,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withOpacity(
                0.06,
              ),
              blurRadius: 12,
              offset:
                  const Offset(
                0,
                5,
              ),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              child: SizedBox(
                width: 72,
                height: 72,
                child:
                    imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (
                              context,
                              error,
                              stackTrace,
                            ) {
                              return const ColoredBox(
                                color:
                                    Color(
                                  0xFFF3F3F3,
                                ),
                                child:
                                    Icon(
                                  Icons
                                      .broken_image_outlined,
                                  color:
                                      Colors.grey,
                                ),
                              );
                            },
                          )
                        : const ColoredBox(
                            color:
                                Color(
                              0xFFF3F3F3,
                            ),
                            child:
                                Icon(
                              Icons
                                  .image_outlined,
                              color:
                                  Colors.grey,
                            ),
                          ),
              ),
            ),
            const SizedBox(
              width: 11,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          Color(
                        0xFF222222,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  if (seller.isNotEmpty)
                    Text(
                      seller,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 10,
                        color:
                            Color(
                          0xFF888888,
                        ),
                      ),
                    ),
                  const SizedBox(
                    height: 5,
                  ),
                  Text(
                    '₹$price',
                    style:
                        const TextStyle(
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          Color(
                        0xFFD66A16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration:
                  const BoxDecoration(
                color:
                    Color(
                  0xFFFFF1E7,
                ),
                shape:
                    BoxShape.circle,
              ),
              child:
                  const Icon(
                Icons
                    .arrow_forward_ios_rounded,
                size: 13,
                color:
                    Color(
                  0xFFD66A16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PRODUCT TITLE
  // ============================================================

  String _productTitle(
    Map<String, dynamic> product,
  ) {
    return (
      product['title'] ??
      ''
    ).toString();
  }

  // ============================================================
  // PRODUCT IMAGE
  // ============================================================

  String _productImage(
    Map<String, dynamic> product,
  ) {
    return (
      product['imageUrl'] ??
      product['image'] ??
      ''
    )
        .toString()
        .replaceAll(
          '"',
          '',
        )
        .trim();
  }

  // ============================================================
  // PRODUCT ID
  // ============================================================

  String _productId(
    Map<String, dynamic> product,
  ) {
    return (
      product['documentId'] ??
      product['productId'] ??
      product['id'] ??
      ''
    ).toString();
  }

  // ============================================================
  // OPEN PRODUCT
  // ============================================================

  void _openProduct(
    Map<String, dynamic> product,
  ) {
    final productData =
        <String, String>{
      'title':
          _productTitle(
        product,
      ),
      'description':
          (product['description'] ??
                  '')
              .toString(),
      'price':
          (product['price'] ??
                  '0')
              .toString(),
      'imageUrl':
          _productImage(
        product,
      ),
      'sellerName':
          (product['sellerName'] ??
                  'Local Artisan')
              .toString(),
      'sellerId':
          (product['sellerId'] ??
                  '')
              .toString(),
    };

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ProductDetailPage(
          product: productData,
        ),
      ),
    );
  }

  // ============================================================
  // GO TO CART
  // ============================================================

  void _goToCart() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const AddToCartPage(),
      ),
    );
  }

  // ============================================================
  // SUGGESTIONS
  // ============================================================

  Widget _buildSuggestions() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection:
            Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 14,
        ),
        children: [
          _suggestionChip(
            '💍 Wedding bangles',
          ),
          _suggestionChip(
            '🏠 Home decor',
          ),
          _suggestionChip(
            '🎁 Handmade gifts',
          ),
          _suggestionChip(
            '👗 Traditional clothing',
          ),
        ],
      ),
    );
  }

  Widget _suggestionChip(
    String text,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        right: 8,
      ),
      child: ActionChip(
        label: Text(
          text,
          style:
              const TextStyle(
            fontSize: 11,
            fontWeight:
                FontWeight.w600,
          ),
        ),
        backgroundColor:
            Colors.white,
        side: BorderSide(
          color: Colors.black
              .withOpacity(
            0.08,
          ),
        ),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            20,
          ),
        ),
        onPressed: () {
          _controller.text =
              text;

          _inputFocusNode
              .requestFocus();
        },
      ),
    );
  }

  // ============================================================
  // CHAT AREA
  // ============================================================

  Widget _buildChatArea() {
    return Container(
      color:
          const Color(
        0xFFFAFAFA,
      ),
      child: Column(
        children: [
          if (_messages.length <=
              1)
            _buildSuggestions(),

          Expanded(
            child:
                ListView.builder(
              controller:
                  _scrollController,
              padding:
                  const EdgeInsets.fromLTRB(
                15,
                10,
                15,
                15,
              ),
              itemCount:
                  _messages.length +
                  (_isTyping
                      ? 1
                      : 0) +
                  (_shownProducts
                          .isNotEmpty
                      ? 1
                      : 0),
              itemBuilder:
                  (
                context,
                index,
              ) {
                if (_isTyping &&
                    index ==
                        _messages.length) {
                  return _buildTypingIndicator();
                }

                final productIndex =
                    _messages.length +
                        (_isTyping
                            ? 1
                            : 0);

                if (_shownProducts
                        .isNotEmpty &&
                    index ==
                        productIndex) {
                  return Column(
                    children:
                        _shownProducts
                            .map(
                              _buildProductCard,
                            )
                            .toList(),
                  );
                }

                return _buildMessage(
                  _messages[index],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  Widget _buildMessage(
    _ChatMessage message,
  ) {
    return Align(
      alignment:
          message.isUser
              ? Alignment.centerRight
              : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            message.isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
        children: [
          Container(
            constraints:
                BoxConstraints(
              maxWidth:
                  MediaQuery.of(
                        context,
                      ).size.width *
                      0.76,
            ),
            margin:
                const EdgeInsets.only(
              bottom: 8,
            ),
            padding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 11,
            ),
            decoration:
                BoxDecoration(
              color:
                  message.isUser
                      ? const Color(
                          0xFFD66A16,
                        )
                      : Colors.white,
              borderRadius:
                  BorderRadius.only(
                topLeft:
                    const Radius.circular(
                  17,
                ),
                topRight:
                    const Radius.circular(
                  17,
                ),
                bottomLeft:
                    Radius.circular(
                  message.isUser
                      ? 17
                      : 5,
                ),
                bottomRight:
                    Radius.circular(
                  message.isUser
                      ? 5
                      : 17,
                ),
              ),
              border:
                  message.isUser
                      ? null
                      : Border.all(
                          color: Colors
                              .black
                              .withOpacity(
                            0.06,
                          ),
                        ),
            ),
            child: Text(
              message.text,
              style:
                  TextStyle(
                color:
                    message.isUser
                        ? Colors.white
                        : const Color(
                            0xFF242424,
                          ),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),

          // ======================================================
          // FIRESTORE CATALOG OPTIONS
          // ======================================================

          if (!message.isUser &&
              message.choices
                  .isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 10,
              ),
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children:
                    message.choices
                        .map(
                          (
                            choice,
                          ) =>
                              ActionChip(
                            label:
                                Text(
                              choice,
                              style:
                                  const TextStyle(
                                fontSize:
                                    11,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                            backgroundColor:
                                Colors.white,
                            side:
                                const BorderSide(
                              color:
                                  Color(
                                0xFFE4D5C8,
                              ),
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                18,
                              ),
                            ),
                            onPressed:
                                () {
                              _controller.text =
                                  choice;

                              _sendMessage();
                            },
                          ),
                        )
                        .toList(),
              ),
            ),

          // ======================================================
          // GO TO CART
          // ======================================================

          if (message.showCartButton)
            Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 12,
              ),
              child:
                  OutlinedButton.icon(
                onPressed:
                    _goToCart,
                icon:
                    const Icon(
                  Icons
                      .shopping_cart_outlined,
                  size: 16,
                ),
                label:
                    const Text(
                  'Go to cart',
                ),
                style:
                    OutlinedButton.styleFrom(
                  foregroundColor:
                      const Color(
                    0xFFD66A16,
                  ),
                  side:
                      const BorderSide(
                    color:
                        Color(
                      0xFFD66A16,
                    ),
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // TYPING
  // ============================================================

  Widget _buildTypingIndicator() {
    return Align(
      alignment:
          Alignment.centerLeft,
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 10,
        ),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 12,
        ),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(
            18,
          ),
          border: Border.all(
            color: Colors.black
                .withOpacity(
              0.06,
            ),
          ),
        ),
        child: const Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            _TypingDot(),
            SizedBox(width: 5),
            _TypingDot(),
            SizedBox(width: 5),
            _TypingDot(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INPUT
  // ============================================================

  Widget _buildInputArea() {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        12,
        9,
        12,
        11,
      ),
      color: Colors.white,
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFF5F5F5,
                ),
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
              child: TextField(
                controller:
                    _controller,
                focusNode:
                    _inputFocusNode,
                minLines: 1,
                maxLines: 4,
                textInputAction:
                    TextInputAction
                        .newline,
                onSubmitted: (_) {
                  _sendMessage();
                },
                decoration:
                    const InputDecoration(
                  hintText:
                      'What are you looking for?',
                  hintStyle:
                      TextStyle(
                    color:
                        Color(
                      0xFF999999,
                    ),
                    fontSize: 13,
                  ),
                  border:
                      InputBorder.none,
                  contentPadding:
                      EdgeInsets
                          .symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          GestureDetector(
            onTap:
                _sendMessage,
            child: Container(
              width: 43,
              height: 43,
              decoration:
                  const BoxDecoration(
                gradient:
                    LinearGradient(
                  colors: [
                    Color(
                      0xFFFF8A3D,
                    ),
                    Color(
                      0xFFD66A16,
                    ),
                  ],
                ),
                shape:
                    BoxShape.circle,
              ),
              child:
                  const Icon(
                Icons
                    .arrow_upward_rounded,
                color:
                    Colors.white,
                size: 21,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        18,
        16,
        12,
        15,
      ),
      decoration:
          const BoxDecoration(
        gradient:
            LinearGradient(
          colors: [
            Color(
              0xFFFF8A3D,
            ),
            Color(
              0xFFD66A16,
            ),
          ],
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withOpacity(
                0.18,
              ),
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child:
                const Icon(
              Icons.auto_awesome,
              color:
                  Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Karigari Assistant',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                SizedBox(
                  height: 3,
                ),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      color:
                          Color(
                        0xFFB8FFCB,
                      ),
                      size: 7,
                    ),
                    SizedBox(
                      width: 5,
                    ),
                    Text(
                      'Shopping assistant',
                      style:
                          TextStyle(
                        color:
                            Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.of(
                context,
              ).pop();
            },
            icon:
                const Icon(
              Icons
                  .close_rounded,
              color:
                  Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final keyboardHeight =
        MediaQuery.of(context)
            .viewInsets
            .bottom;

    return Stack(
      children: [
        Positioned(
          left: 14,
          right: 14,
          bottom:
              keyboardHeight > 0
                  ? keyboardHeight +
                      10
                  : 82,
          child: Material(
            color:
                Colors.transparent,
            child: Container(
              height:
                  keyboardHeight > 0
                      ? MediaQuery.of(
                            context,
                          ).size.height *
                          0.55
                      : MediaQuery.of(
                            context,
                          ).size.height *
                          0.60,
              constraints:
                  const BoxConstraints(
                maxHeight: 620,
                minHeight: 350,
              ),
              decoration:
                  BoxDecoration(
                color:
                    Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  28,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(
                      0.16,
                    ),
                    blurRadius: 35,
                    offset:
                        const Offset(
                      0,
                      12,
                    ),
                  ),
                ],
              ),
              child:
                  ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  28,
                ),
                child:
                    Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child:
                          _buildChatArea(),
                    ),
                    _buildInputArea(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  List<String> _aliasesForType(
    String type,
  ) {
    for (final entry
        in _productTypeAliases
            .entries) {
      if (_normalise(
            entry.key,
          ) ==
          type) {
        return entry.value
            .map(
              _normalise,
            )
            .toList();
      }
    }

    return [type];
  }

  bool _isJewelleryType(
    String type,
  ) {
    return {
      'Bangles',
      'Necklace',
      'Earrings',
      'Bracelet',
    }.contains(
      type,
    );
  }

  bool _isHomeDecorType(
    String type,
  ) {
    return {
      'Lantern',
      'Candle',
      'Flower Vase',
      'Clay Pot',
      'Candle Holder',
      'Wall Hanging',
      'Serving Tray',
      'Basket',
      'Table Cloth',
      'Table Runner',
    }.contains(
      type,
    );
  }

  bool _isClothingType(
    String type,
  ) {
    return {
      'Saree',
      'Dress',
    }.contains(
      type,
    );
  }

  bool _isBagType(
    String type,
  ) {
    return type == 'Bag';
  }

  String _titleCaseType(
    String normalized,
  ) {
    for (final key
        in _productTypeAliases
            .keys) {
      if (_normalise(
            key,
          ) ==
          normalized) {
        return key;
      }
    }

    return normalized;
  }

  bool _containsPhrase(
    String text,
    String phrase,
  ) {
    final normalizedText =
        _normalise(text);

    final normalizedPhrase =
        _normalise(phrase);

    if (normalizedPhrase
        .isEmpty) {
      return false;
    }

    final escaped =
        RegExp.escape(
      normalizedPhrase,
    ).replaceAll(
      r'\ ',
      r'\s+',
    );

    return RegExp(
      r'(^|\s)' +
          escaped +
          r'($|\s)',
      caseSensitive:
          false,
    ).hasMatch(
      normalizedText,
    );
  }

  String _normalise(
    dynamic value,
  ) {
    if (value == null) {
      return '';
    }

    return value
        .toString()
        .toLowerCase()
        .trim()
        .replaceAll(
          RegExp(
            r'[^\w\s-]',
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'\s+',
          ),
          ' ',
        )
        .trim();
  }

  List<String> _stringList(
    dynamic value,
  ) {
    if (value is! List) {
      return [];
    }

    return value
        .map(
          (item) =>
              _normalise(
            item,
          ),
        )
        .where(
          (item) =>
              item.isNotEmpty,
        )
        .toSet()
        .toList();
  }

  bool _hasNonEmpty(
    dynamic value,
  ) {
    return value != null &&
        value
            .toString()
            .trim()
            .isNotEmpty;
  }

  int _toInt(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value
              .toString(),
        ) ??
        0;
  }

  double? _toDouble(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value
          .toString()
          .replaceAll(
            '₹',
            '',
          )
          .replaceAll(
            ',',
            '',
          )
          .trim(),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!_scrollController
            .hasClients) {
          return;
        }

        _scrollController
            .animateTo(
          _scrollController
              .position
              .maxScrollExtent,
          duration:
              const Duration(
            milliseconds: 300,
          ),
          curve:
              Curves.easeOut,
        );
      },
    );
  }
}

// ================================================================
// CHAT MESSAGE
// ================================================================

class _ChatMessage {
  final String text;
  final bool isUser;

  final List<String> choices;

  final bool showCartButton;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.choices = const [],
    this.showCartButton = false,
  });
}

// ================================================================
// SCORED PRODUCT
// ================================================================

class _ScoredProduct {
  final Map<String, dynamic>
      product;

  final int score;

  const _ScoredProduct({
    required this.product,
    required this.score,
  });
}

// ================================================================
// TYPING DOT
// ================================================================

class _TypingDot extends StatelessWidget {
  const _TypingDot();

  @override
  Widget build(
    BuildContext context,
  ) {
    return const SizedBox(
      width: 7,
      height: 7,
      child: DecoratedBox(
        decoration:
            BoxDecoration(
          color:
              Color(0xFFD66A16),
          shape:
              BoxShape.circle,
        ),
      ),
    );
  }
}