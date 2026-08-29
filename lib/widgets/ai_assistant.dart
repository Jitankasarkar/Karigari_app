import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proto_app/product_detail_page.dart';

class AIAssistant extends StatefulWidget {
  const AIAssistant({
    super.key,
  });

  @override
  State<AIAssistant> createState() => _AIAssistantState();
}

class _AIAssistantState extends State<AIAssistant> {
  final TextEditingController _controller =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  final FocusNode _inputFocusNode =
      FocusNode();

  final List<_ChatMessage> _messages = [];

  bool _isTyping = false;

  List<Map<String, dynamic>> _recommendedProducts = [];

  @override
  void initState() {
    super.initState();

    _messages.add(
      const _ChatMessage(
        text:
            "Hi! I'm your Karigari shopping assistant. What kind of handmade items are you looking for?",
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

  // =========================================================
  // SEND MESSAGE
  // =========================================================

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _isTyping) {
      return;
    }

    setState(() {
      _messages.add(
        _ChatMessage(
          text: text,
          isUser: true,
        ),
      );

      _controller.clear();

      _isTyping = true;

      _recommendedProducts = [];
    });

    _scrollToBottom();

    try {
      final products =
          await _findMatchingProducts(text);

      if (!mounted) return;

      setState(() {
        _isTyping = false;
        _recommendedProducts = products;

        if (products.isEmpty) {
          _messages.add(
            const _ChatMessage(
              text:
                  "I couldn't find an exact match right now. Try describing the colour, occasion, material, or type of handmade product you're looking for.",
              isUser: false,
            ),
          );
        } else {
          _messages.add(
            _ChatMessage(
              text:
                  _buildRecommendationMessage(
                text,
                products.length,
              ),
              isUser: false,
            ),
          );
        }
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint(
        "AI assistant search error: $e",
      );

      if (!mounted) return;

      setState(() {
        _isTyping = false;

        _messages.add(
          const _ChatMessage(
            text:
                "Sorry, I couldn't search the marketplace right now. Please try again.",
            isUser: false,
          ),
        );
      });

      _scrollToBottom();
    }
  }

  // =========================================================
  // FIND MATCHING PRODUCTS
  // =========================================================

  Future<List<Map<String, dynamic>>>
      _findMatchingProducts(
    String query,
  ) async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('products')
            .where(
              'isAvailable',
              isEqualTo: true,
            )
            .get();

    final queryWords =
        _extractWords(query);

    final List<_ScoredProduct>
        scoredProducts = [];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final score =
          _calculateProductScore(
        data,
        queryWords,
      );

      if (score > 0) {
        final product =
            Map<String, dynamic>.from(data);

        product['documentId'] = doc.id;

        scoredProducts.add(
          _ScoredProduct(
            product: product,
            score: score,
          ),
        );
      }
    }

    scoredProducts.sort(
      (a, b) =>
          b.score.compareTo(a.score),
    );

    return scoredProducts
        .take(5)
        .map(
          (item) => item.product,
        )
        .toList();
  }

  // =========================================================
  // CALCULATE PRODUCT SCORE
  // =========================================================

  int _calculateProductScore(
    Map<String, dynamic> product,
    Set<String> queryWords,
  ) {
    int score = 0;

    final title =
        _normalise(product['title']);

    final description =
        _normalise(product['description']);

    final category =
        _normalise(product['category']);

    final subcategory =
        _normalise(product['subcategory']);

    final tags =
        _listToString(product['tags']);

    final keywords =
        _listToString(product['keywords']);

    final searchTerms =
        _listToString(product['searchTerms']);

    // =======================================================
    // TITLE
    // =======================================================

    for (final word in queryWords) {
      if (title.contains(word)) {
        score += 10;
      }
    }

    // =======================================================
    // CATEGORY
    // =======================================================

    for (final word in queryWords) {
      if (category.contains(word)) {
        score += 7;
      }
    }

    // =======================================================
    // SUBCATEGORY
    // =======================================================

    for (final word in queryWords) {
      if (subcategory.contains(word)) {
        score += 8;
      }
    }

    // =======================================================
    // TAGS
    // =======================================================

    for (final word in queryWords) {
      for (final tag in tags) {
        if (tag.contains(word)) {
          score += 6;
        }
      }
    }

    // =======================================================
    // KEYWORDS
    // =======================================================

    for (final word in queryWords) {
      for (final keyword in keywords) {
        if (keyword.contains(word)) {
          score += 5;
        }
      }
    }

    // =======================================================
    // SEARCH TERMS
    // =======================================================

    for (final word in queryWords) {
      for (final searchTerm in searchTerms) {
        if (searchTerm.contains(word)) {
          score += 5;
        }
      }
    }

    // =======================================================
    // DESCRIPTION
    // =======================================================

    for (final word in queryWords) {
      if (description.contains(word)) {
        score += 2;
      }
    }

    return score;
  }

  // =========================================================
  // EXTRACT SEARCH WORDS
  // =========================================================

  Set<String> _extractWords(
    String text,
  ) {
    final stopWords = {
      'i',
      'am',
      'looking',
      'for',
      'a',
      'an',
      'the',
      'some',
      'want',
      'need',
      'find',
      'me',
      'please',
      'show',
      'showing',
      'can',
      'you',
      'something',
      'that',
      'with',
      'and',
      'of',
      'to',
      'my',
      'is',
      'are',
      'in',
      'on',
      'do',
      'have',
      'has',
      'would',
      'like',
    };

    return text
        .toLowerCase()
        .replaceAll(
          RegExp(r'[^a-zA-Z0-9\s]'),
          ' ',
        )
        .split(
          RegExp(r'\s+'),
        )
        .map(
          (word) => word.trim(),
        )
        .where(
          (word) =>
              word.length >= 2 &&
              !stopWords.contains(word),
        )
        .toSet();
  }

  // =========================================================
  // NORMALISE
  // =========================================================

  String _normalise(
    dynamic value,
  ) {
    return value
            ?.toString()
            .toLowerCase()
            .trim() ??
        '';
  }

  // =========================================================
  // LIST → STRING LIST
  // =========================================================

  List<String> _listToString(
    dynamic value,
  ) {
    if (value is! List) {
      return [];
    }

    return value
        .map(
          (item) =>
              item.toString().toLowerCase(),
        )
        .toList();
  }

  // =========================================================
  // RECOMMENDATION MESSAGE
  // =========================================================

  String _buildRecommendationMessage(
    String query,
    int count,
  ) {
    if (count == 1) {
      return "✨ I found something that matches what you're looking for.";
    }

    return "✨ I found $count products that could match your request.";
  }

  // =========================================================
  // OPEN PRODUCT
  // =========================================================
  //
  // IMPORTANT:
  // ProductDetailPage expects Map<String, String>.
  //
  // We therefore explicitly convert the Firestore values
  // into String values before navigating.
  //
  // We also use a lightweight custom route animation to
  // make the transition smoother.
  // =========================================================

  void _openProduct(
    Map<String, dynamic> product,
  ) {
    final productTitle =
        (product['title'] ?? '')
            .toString();

    final productDescription =
        (product['description'] ?? '')
            .toString();

    final productPrice =
        (product['price'] ?? '0')
            .toString();

    final productImage =
        (product['imageUrl'] ??
                product['image'] ??
                '')
            .toString()
            .replaceAll('"', '');

    final sellerName =
        (product['sellerName'] ?? '')
                .toString()
                .trim()
                .isNotEmpty
            ? product['sellerName']
                .toString()
                .trim()
            : 'Local Artisan';

    final sellerId =
        (product['sellerId'] ?? '')
            .toString();

    final productData =
        <String, String>{
      'title': productTitle,
      'description': productDescription,
      'price': productPrice,
      'imageUrl': productImage,
      'sellerName': sellerName,
      'sellerId': sellerId,
    };

    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration:
            const Duration(
          milliseconds: 220,
        ),

        reverseTransitionDuration:
            const Duration(
          milliseconds: 180,
        ),

        pageBuilder:
            (
          context,
          animation,
          secondaryAnimation,
        ) {
          return ProductDetailPage(
            product: productData,
          );
        },

        transitionsBuilder:
            (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
          final curvedAnimation =
              CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curvedAnimation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                begin:
                    const Offset(
                  0.04,
                  0,
                ),
                end: Offset.zero,
              ).animate(
                curvedAnimation,
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  // =========================================================
  // SUGGESTION
  // =========================================================

  void _useSuggestion(
    String text,
  ) {
    _controller.text = text;

    _controller.selection =
        TextSelection.fromPosition(
      TextPosition(
        offset:
            _controller.text.length,
      ),
    );

    _inputFocusNode.requestFocus();
  }

  // =========================================================
  // SCROLL
  // =========================================================

  void _scrollToBottom() {
    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!_scrollController
            .hasClients) {
          return;
        }

        _scrollController.animateTo(
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

  // =========================================================
  // BUILD
  // =========================================================

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
                  ? keyboardHeight + 10
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
                border:
                    Border.all(
                  color: Colors.black
                      .withOpacity(
                    0.06,
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  28,
                ),
                child: Column(
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

  // =========================================================
  // HEADER
  // =========================================================

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
            Color(0xFFFF8A3D),
            Color(0xFFD66A16),
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
                  "Karigari Assistant",
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
                      "Shopping assistant",
                      style:
                          TextStyle(
                        color:
                            Colors.white70,
                        fontSize:
                            11,
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
              Icons.close_rounded,
              color:
                  Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // CHAT AREA
  // =========================================================

  Widget _buildChatArea() {
    return Container(
      color:
          const Color(
        0xFFFAFAFA,
      ),
      child: Column(
        children: [
          if (_messages.length <= 1)
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
                  (_recommendedProducts
                          .isNotEmpty
                      ? 1
                      : 0),

              itemBuilder:
                  (
                context,
                index,
              ) {
                // -----------------------------------------
                // TYPING
                // -----------------------------------------

                if (_isTyping &&
                    index ==
                        _messages.length) {
                  return _buildTypingIndicator();
                }

                // -----------------------------------------
                // RECOMMENDATIONS
                // -----------------------------------------

                final recommendationIndex =
                    _messages.length +
                    (_isTyping
                        ? 1
                        : 0);

                if (_recommendedProducts
                        .isNotEmpty &&
                    index ==
                        recommendationIndex) {
                  return _buildRecommendations();
                }

                // -----------------------------------------
                // MESSAGE
                // -----------------------------------------

                final message =
                    _messages[index];

                return _buildMessage(
                  message,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // RECOMMENDATIONS
  // =========================================================

  Widget _buildRecommendations() {
    return Column(
      children:
          _recommendedProducts
              .map(
                (product) =>
                    _buildProductCard(
                  product,
                ),
              )
              .toList(),
    );
  }

  // =========================================================
  // PRODUCT CARD
  // =========================================================

  Widget _buildProductCard(
    Map<String, dynamic> product,
  ) {
    final title =
        (product['title'] ?? '')
            .toString();

    final price =
        (product['price'] ?? '0')
            .toString();

    final imageUrl =
        (product['imageUrl'] ??
                product['image'] ??
                '')
            .toString()
            .replaceAll('"', '');

    final seller =
        (product['sellerName'] ?? '')
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
          bottom: 10,
        ),

        padding:
            const EdgeInsets.all(
          8,
        ),

        decoration:
            BoxDecoration(
          color:
              Colors.white,

          borderRadius:
              BorderRadius.circular(
            16,
          ),

          border:
              Border.all(
            color:
                Colors.black
                    .withOpacity(
              0.06,
            ),
          ),

          boxShadow: [
            BoxShadow(
              color:
                  Colors.black
                      .withOpacity(
                0.035,
              ),

              blurRadius:
                  10,

              offset:
                  const Offset(
                0,
                4,
              ),
            ),
          ],
        ),

        child: Row(
          children: [
            // =============================================
            // IMAGE
            // =============================================

            ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                12,
              ),

              child:
                  SizedBox(
                width: 68,
                height: 68,

                child:
                    imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit:
                                BoxFit.cover,

                            filterQuality:
                                FilterQuality.low,

                            errorBuilder:
                                (
                              context,
                              error,
                              stackTrace,
                            ) {
                              return const
                                  ColoredBox(
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
                        : const
                            ColoredBox(
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

            // =============================================
            // PRODUCT INFO
            // =============================================

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                children: [
                  Text(
                    title,

                    maxLines: 2,

                    overflow:
                        TextOverflow
                            .ellipsis,

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
                          TextOverflow
                              .ellipsis,

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

            // =============================================
            // ARROW
            // =============================================

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

  // =========================================================
  // SUGGESTIONS
  // =========================================================

  Widget _buildSuggestions() {
    return SizedBox(
      height: 52,

      child:
          ListView(
        scrollDirection:
            Axis.horizontal,

        padding:
            const EdgeInsets.symmetric(
          horizontal: 14,
        ),

        children: [
          _suggestionChip(
            "💍 Wedding bangles",
          ),

          _suggestionChip(
            "🏠 Home decor",
          ),

          _suggestionChip(
            "🎁 Handmade gifts",
          ),

          _suggestionChip(
            "👗 Traditional clothing",
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

      child:
          ActionChip(
        label:
            Text(
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

        side:
            BorderSide(
          color:
              Colors.black
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
          _useSuggestion(
            text,
          );
        },
      ),
    );
  }

  // =========================================================
  // MESSAGE
  // =========================================================

  Widget _buildMessage(
    _ChatMessage message,
  ) {
    return Align(
      alignment:
          message.isUser
              ? Alignment.centerRight
              : Alignment.centerLeft,

      child: Container(
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
          bottom: 10,
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
                      color:
                          Colors.black
                              .withOpacity(
                        0.06,
                      ),
                    ),
        ),

        child:
            Text(
          message.text,

          style:
              TextStyle(
            color:
                message.isUser
                    ? Colors.white
                    : const Color(
                        0xFF242424,
                      ),

            fontSize:
                13,

            height:
                1.4,

            fontWeight:
                message.isUser
                    ? FontWeight.w500
                    : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // TYPING INDICATOR
  // =========================================================

  Widget _buildTypingIndicator() {
    return Align(
      alignment:
          Alignment.centerLeft,

      child:
          Container(
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
          color:
              Colors.white,

          borderRadius:
              BorderRadius.circular(
            18,
          ),

          border:
              Border.all(
            color:
                Colors.black
                    .withOpacity(
              0.06,
            ),
          ),
        ),

        child:
            const Row(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            SizedBox(
              width: 7,
              height: 7,
              child:
                  DecoratedBox(
                decoration:
                    BoxDecoration(
                  color:
                      Color(
                    0xFFD66A16,
                  ),
                  shape:
                      BoxShape.circle,
                ),
              ),
            ),

            SizedBox(
              width: 5,
            ),

            SizedBox(
              width: 7,
              height: 7,
              child:
                  DecoratedBox(
                decoration:
                    BoxDecoration(
                  color:
                      Color(
                    0xFFD66A16,
                  ),
                  shape:
                      BoxShape.circle,
                ),
              ),
            ),

            SizedBox(
              width: 5,
            ),

            SizedBox(
              width: 7,
              height: 7,
              child:
                  DecoratedBox(
                decoration:
                    BoxDecoration(
                  color:
                      Color(
                    0xFFD66A16,
                  ),
                  shape:
                      BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // INPUT
  // =========================================================

  Widget _buildInputArea() {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        12,
        9,
        12,
        11,
      ),

      color:
          Colors.white,

      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.end,

        children: [
          Expanded(
            child:
                Container(
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

              child:
                  TextField(
                controller:
                    _controller,

                focusNode:
                    _inputFocusNode,

                minLines:
                    1,

                maxLines:
                    4,

                textInputAction:
                    TextInputAction.newline,

                onSubmitted:
                    (_) {
                  _sendMessage();
                },

                decoration:
                    const InputDecoration(
                  hintText:
                      "What are you looking for?",

                  hintStyle:
                      TextStyle(
                    color:
                        Color(
                      0xFF999999,
                    ),

                    fontSize:
                        13,
                  ),

                  border:
                      InputBorder.none,

                  contentPadding:
                      EdgeInsets.symmetric(
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

            child:
                Container(
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
}

// =============================================================
// CHAT MESSAGE
// =============================================================

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({
    required this.text,
    required this.isUser,
  });
}

// =============================================================
// SCORED PRODUCT
// =============================================================

class _ScoredProduct {
  final Map<String, dynamic> product;
  final int score;

  const _ScoredProduct({
    required this.product,
    required this.score,
  });
}