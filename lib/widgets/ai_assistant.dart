import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proto_app/product_detail_page.dart';
import '../services/llama_service.dart';

class AIAssistant extends StatefulWidget {
  const AIAssistant({super.key});

  @override
  State<AIAssistant> createState() => _AIAssistantState();
}

class _AIAssistantState extends State<AIAssistant> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  final List<_ChatMessage> _messages = [];
  final List<Map<String, String>> _conversation = [];

  bool _isTyping = false;

  List<Map<String, dynamic>> _recommendedProducts = [];

  /// The last useful shopping intent.
  ///
  /// This is deliberately kept separately from the current user message so
  /// follow-ups such as:
  ///   "show me bangles" -> "in red" -> "under 2000"
  /// can continue the same search.
  Map<String, dynamic>? _lastIntent;

  /// Product ids already shown in the current search flow.
  /// Used by "more" so the assistant does not repeat the same products.
  final Set<String> _shownProductIds = <String>{};

  /// Whether the previous assistant turn was waiting for the user to answer
  /// a clarification question.
  bool _waitingForClarification = false;

  // -------------------------------------------------------------------------
  // BASIC ALIASES
  // -------------------------------------------------------------------------

  static const Map<String, List<String>> _categoryAliases = {
    'Jewellery': [
      'jewellery',
      'jewelry',
      'jewel',
      'jewels',
      'ornament',
      'ornaments',
      'accessory',
      'accessories',
    ],
    'Clothing': [
      'clothing',
      'clothes',
      'apparel',
      'outfit',
      'outfits',
      'wear',
      'fashion',
    ],
    'Home Decor': [
      'home decor',
      'home decoration',
      'home décor',
      'decor',
      'decoration',
      'house decor',
      'home accessories',
    ],
    'Handicrafts': [
      'handicraft',
      'handicrafts',
      'craft',
      'crafts',
      'handmade crafts',
      'artisan crafts',
    ],
    'Kitchenware': [
      'kitchenware',
      'kitchen',
      'utensil',
      'utensils',
      'cookware',
    ],
    'Pottery': [
      'pottery',
      'ceramic',
      'ceramics',
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
    'Home & Kitchen': [
      'home and kitchen',
      'home kitchen',
    ],
  };

  static const Map<String, List<String>> _productTypeAliases = {
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
      'pot',
      'pots',
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

  static const Map<String, List<String>> _occasionAliases = {
    'wedding': [
      'wedding',
      'weddings',
      'bridal',
      'bride',
      'marriage',
      'shaadi',
    ],
    'festival': [
      'festival',
      'festivals',
      'festive',
      'festivity',
      'celebration',
      'celebrations',
    ],
    'everyday': [
      'everyday',
      'daily',
      'daily use',
      'daily wear',
      'regular wear',
      'casual',
    ],
    'birthday': [
      'birthday',
      'birthdays',
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

  static const Map<String, List<String>> _attributeAliases = {
    'handmade': [
      'handmade',
      'hand made',
      'handcrafted',
      'hand crafted',
      'artisan',
      'artisan-made',
      'artisan made',
      'locally made',
      'crafted',
    ],
    'traditional': [
      'traditional',
      'ethnic',
      'heritage',
      'classic',
    ],
    'modern': [
      'modern',
      'contemporary',
      'trendy',
      'stylish',
      'fashionable',
    ],
    'rustic': [
      'rustic',
      'earthy',
    ],
    'eco-friendly': [
      'eco-friendly',
      'eco friendly',
      'sustainable',
      'environment friendly',
    ],
  };

  static const List<String> _commonColours = [
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
    'earthy',
  ];

  static const Map<String, List<String>> _materialAliases = {
    'terracotta': ['terracotta', 'terracotta clay'],
    'clay': ['clay'],
    'cotton': ['cotton', 'cotton thread'],
    'silk': ['silk', 'silk thread'],
    'bamboo': ['bamboo'],
    'wood': ['wood', 'wooden'],
    'jute': ['jute'],
    'ceramic': ['ceramic', 'ceramics'],
    'wool': ['wool'],
    'brass': ['brass'],
    'metal': ['metal'],
    'beads': ['bead', 'beads', 'beaded'],
    'glass': ['glass'],
  };

  // -------------------------------------------------------------------------
  // LIFECYCLE
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _messages.add(
      const _ChatMessage(
        text:
            "Hi! I'm your Karigari shopping assistant. What handmade products are you looking for?",
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

  // -------------------------------------------------------------------------
  // MESSAGE FLOW
  // -------------------------------------------------------------------------

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _isTyping) {
      return;
    }

    final normalized = _normalise(text);

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
      _recommendedProducts = [];
    });

    _scrollToBottom();

    try {
      // ================================================================
      // CASE 1: GREETING / NORMAL CHAT
      // Do not hit Firestore or product search.
      // ================================================================

      if (_isGreetingOrCasual(normalized)) {
        await _respondWithoutSearch(
          _casualResponse(normalized),
        );
        return;
      }

      // ================================================================
      // CASE 10: NO
      // If the assistant previously asked a confirmation/clarification,
      // "no" must not trigger another product search.
      // ================================================================

      if (_isNegative(normalized)) {
        _waitingForClarification = false;

        await _respondWithoutSearch(
          _lastIntent != null
              ? "No problem. I won't change or show anything yet. Tell me what you'd like instead."
              : "No problem. Tell me what handmade product you're looking for.",
        );
        return;
      }

      // ================================================================
      // CASE 12: MORE
      // Exclude products already displayed and return the next batch.
      // ================================================================

      if (_isMoreRequest(normalized)) {
        if (_lastIntent == null) {
          await _respondWithoutSearch(
            "Sure — tell me what kind of handmade product you'd like me to show first.",
          );
          return;
        }

        final products = await _findMatchingProducts(
          _lastIntent!,
          excludeShown: true,
        );

        if (!mounted) return;

        if (products.isEmpty) {
          await _respondWithoutSearch(
            "I've shown all the matching products I currently have. If you'd like, you can change a filter or ask for a different type.",
          );
          return;
        }

        _shownProductIds.addAll(
          products.map(_productId),
        );

        await _showProducts(
          products,
          "Here are some more options without repeating the ones I just showed.",
        );
        return;
      }

      // ================================================================
      // CASES 6/7/8/9:
      // Llama understands the natural-language request, while the local
      // merge layer controls conversational state so a follow-up cannot
      // accidentally erase the previous search.
      // ================================================================

      Map<String, dynamic> currentIntent = {};

      try {
        currentIntent =
            await LlamaService.understandRequest(
          userMessage: text,
          conversation: _conversation
              .take(
                _conversation.length - 1,
              )
              .toList(),
          previousIntent: _lastIntent,
        );
      } catch (e) {
        debugPrint(
          'Llama intent error: $e',
        );
      }

      // ================================================================
      // CASE 2: VAGUE REQUEST
      // Do not search merely because the user said "something nice",
      // "show me something", etc.
      // ================================================================

      if (_isVagueRequest(
        text: text,
        intent: currentIntent,
      )) {
        final question =
            _clarificationForVagueRequest(
          text,
          currentIntent,
        );

        _waitingForClarification = true;

        await _respondWithoutSearch(
          question,
        );
        return;
      }

      // ================================================================
      // Merge deterministic information with the model's intent.
      // ================================================================

      final mergedIntent = _mergeIntent(
        previous: _lastIntent,
        current: currentIntent,
        userMessage: text,
      );

      debugPrint(
        'FINAL MERGED INTENT: $mergedIntent',
      );

      // ================================================================
      // CASE 9: YES / SHOW ME
      // Reuse the pending previous intent rather than interpreting "yes"
      // as a completely new search.
      // ================================================================

      if (_isConfirmation(normalized) &&
          _lastIntent != null) {
        mergedIntent['needsClarification'] = false;
        mergedIntent['clarificationQuestion'] = '';
      }

      // ================================================================
      // CASE 2 / 5:
      // If the model still says clarification is required, ask instead
      // of showing unrelated products.
      // ================================================================

      if (mergedIntent['needsClarification'] == true) {
        final question =
            mergedIntent['clarificationQuestion']
                    ?.toString()
                    .trim();

        _waitingForClarification = true;

        await _respondWithoutSearch(
          question?.isNotEmpty == true
              ? question!
              : _clarificationForIntent(
                  mergedIntent,
                ),
        );
        return;
      }

      // ================================================================
      // CASE 3/4/5/6/7/8:
      // Search only after we have an actual product-shopping intent.
      // ================================================================

      if (!_hasUsefulSearchIntent(mergedIntent)) {
        _waitingForClarification = true;

        await _respondWithoutSearch(
          _clarificationForVagueRequest(
            text,
            mergedIntent,
          ),
        );
        return;
      }

      _lastIntent = mergedIntent;
      _waitingForClarification = false;

      final products = await _findMatchingProducts(
        mergedIntent,
      );

      if (!mounted) return;

      // ================================================================
      // CASE 11: NO RESULTS
      // Do not silently return random products. Explain that there is
      // no exact match and give the user a way to broaden/change it.
      // ================================================================

      if (products.isEmpty) {
        await _respondWithoutSearch(
          _noResultsResponse(
            mergedIntent,
          ),
        );
        return;
      }

      _shownProductIds.clear();
      _shownProductIds.addAll(
        products.map(_productId),
      );

      String response;

      try {
        response =
            await LlamaService.generateResponse(
          userMessage: text,
          products: products,
          intent: mergedIntent,
          conversation: _conversation,
        );
      } catch (e) {
        debugPrint(
          'Llama response generation error: $e',
        );

        response =
            _fallbackResponse(
          products,
          mergedIntent,
        );
      }

      if (!mounted) return;

      setState(() {
        _isTyping = false;
        _recommendedProducts = products;

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
    } catch (e, stackTrace) {
      debugPrint(
        'AI assistant error: $e',
      );
      debugPrint(
        'STACK: $stackTrace',
      );

      if (!mounted) return;

      setState(() {
        _isTyping = false;

        _messages.add(
          const _ChatMessage(
            text:
                "I'm having trouble understanding that right now. Try describing the product you want, for example: \"handmade red bangles for a wedding\".",
            isUser: false,
          ),
        );

        _conversation.add({
          'role': 'assistant',
          'text':
              "I'm having trouble understanding that right now. Try describing the product you want, for example: \"handmade red bangles for a wedding\".",
        });
      });

      _scrollToBottom();
    }
  }

  // -------------------------------------------------------------------------
  // CONVERSATIONAL STATE / INTENT MERGING
  // -------------------------------------------------------------------------

  Map<String, dynamic> _mergeIntent({
    required Map<String, dynamic>? previous,
    required Map<String, dynamic> current,
    required String userMessage,
  }) {
    final text = _normalise(userMessage);

    // Start from the previous search so follow-ups retain context.
    final result = <String, dynamic>{
      ...?previous,
    };

    final isConfirmation = _isConfirmation(text);
    final isCorrection = _isCorrection(text);
    final isExplicitNewSearch = _isExplicitNewSearch(text);

    // ---------------------------------------------------------------
    // CASE 9: YES
    // ---------------------------------------------------------------
    if (isConfirmation && previous != null) {
      return {
        ...previous,
        'needsClarification': false,
        'clarificationQuestion': '',
      };
    }

    // ---------------------------------------------------------------
    // CASE 8: CHANGE / CORRECTION
    //
    // "Actually show necklaces instead."
    // "I meant earrings."
    // "No, I want home decor."
    //
    // The new category/type replaces the old one.
    // ---------------------------------------------------------------
    if (isCorrection || isExplicitNewSearch) {
      final detectedType =
          _detectProductType(text);

      final detectedCategory =
          _detectCategory(text);

      if (detectedType != null) {
        result['productType'] = detectedType;
      } else if (isCorrection &&
          _mentionsDifferentProductType(
            text,
            previous?['productType'],
          )) {
        result.remove('productType');
      }

      if (detectedCategory != null) {
        result['category'] = detectedCategory;
      }

      // A direct replacement such as "instead of red, blue" should
      // replace the colour rather than keep both.
      final replacementColour =
          _detectColours(text);

      if (isCorrection &&
          replacementColour.isNotEmpty) {
        result['colour'] = replacementColour;
      }

      final replacementMaterial =
          _detectMaterials(text);

      if (isCorrection &&
          replacementMaterial.isNotEmpty) {
        result['material'] =
            replacementMaterial;
      }

      result['needsClarification'] = false;
      result['clarificationQuestion'] = '';

      return result;
    }

    // ---------------------------------------------------------------
    // CASES 3/4/5/7:
    // Add newly mentioned information to the previous intent.
    // ---------------------------------------------------------------

    final detectedCategory =
        _detectCategory(text);

    final detectedProductType =
        _detectProductType(text);

    final detectedOccasion =
        _detectOccasion(text);

    final detectedMaterials =
        _detectMaterials(text);

    final detectedColours =
        _detectColours(text);

    final detectedStyles =
        _detectStyles(text);

    final detectedKeywords =
        _stringList(current['keywords']);

    if (detectedCategory != null) {
      result['category'] = detectedCategory;
    }

    if (detectedProductType != null) {
      result['productType'] = detectedProductType;

      // Product types are stronger than broad categories.
      if (_jewelleryTypes.contains(
        detectedProductType,
      )) {
        result['category'] = 'Jewellery';
      }

      if (_homeDecorTypes.contains(
        detectedProductType,
      )) {
        result['category'] = 'Home Decor';
      }

      if (_bagTypes.contains(
        detectedProductType,
      )) {
        result['category'] = 'Bags';
      }

      if (_clothingTypes.contains(
        detectedProductType,
      )) {
        result['category'] = 'Clothing';
      }
    }

    if (detectedOccasion != null) {
      result['occasion'] = detectedOccasion;
    }

    if (detectedMaterials.isNotEmpty) {
      result['material'] = _mergeList(
        _stringList(result['material']),
        detectedMaterials,
      );
    }

    if (detectedColours.isNotEmpty) {
      result['colour'] = _mergeList(
        _stringList(result['colour']),
        detectedColours,
      );
    }

    if (detectedStyles.isNotEmpty) {
      result['style'] = _mergeList(
        _stringList(result['style']),
        detectedStyles,
      );
    }

    if (_containsHandmade(text)) {
      result['handmade'] = true;
    }

    // Preserve useful fields returned by LlamaService.
    for (final key in const [
      'category',
      'subcategory',
      'productType',
      'occasion',
      'handmade',
      'needsClarification',
      'clarificationQuestion',
    ]) {
      final value = current[key];

      if (value != null &&
          value.toString().trim().isNotEmpty) {
        // Deterministic local detection wins for type/category because
        // those fields control strict product filtering.
        if (key == 'category' &&
            detectedCategory != null) {
          continue;
        }

        if (key == 'productType' &&
            detectedProductType != null) {
          continue;
        }

        if (key == 'occasion' &&
            detectedOccasion != null) {
          continue;
        }

        result[key] = value;
      }
    }

    // Merge list fields rather than letting a follow-up erase old filters.
    for (final key in const [
      'material',
      'colour',
      'style',
      'keywords',
    ]) {
      final incoming = _stringList(current[key]);

      if (incoming.isNotEmpty) {
        result[key] = _mergeList(
          _stringList(result[key]),
          incoming,
        );
      }
    }

    // If local information clearly gives us a search intent, do not let
    // an overly cautious model response turn it into a clarification.
    if (_hasConcreteLocalIntent(text)) {
      result['needsClarification'] = false;
      result['clarificationQuestion'] = '';
    }

    if (detectedKeywords.isNotEmpty &&
        _stringList(result['keywords']).isEmpty) {
      result['keywords'] = detectedKeywords;
    }

    return result;
  }

  static const Set<String> _jewelleryTypes = {
    'Bangles',
    'Necklace',
    'Earrings',
    'Bracelet',
  };

  static const Set<String> _homeDecorTypes = {
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
  };

  static const Set<String> _bagTypes = {
    'Bag',
  };

  static const Set<String> _clothingTypes = {
    'Saree',
    'Dress',
  };

  // -------------------------------------------------------------------------
  // CASE DETECTION
  // -------------------------------------------------------------------------

  bool _isGreetingOrCasual(String text) {
    const exactGreetings = {
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

    if (exactGreetings.contains(text)) {
      return true;
    }

    if (text.startsWith('hello ') ||
        text.startsWith('hi ') ||
        text.startsWith('hey ')) {
      final shoppingWords = [
        'looking',
        'want',
        'need',
        'show',
        'find',
        'buy',
        'product',
        'bangle',
        'necklace',
        'earring',
        'bag',
        'candle',
        'vase',
        'pot',
      ];

      if (!shoppingWords.any(text.contains)) {
        return true;
      }
    }

    return false;
  }

  String _casualResponse(String text) {
    if (text == 'thanks' ||
        text == 'thank you' ||
        text == 'thank you so much') {
      return "You're welcome! Whenever you're ready, tell me what handmade product you'd like to find.";
    }

    if (text == 'bye' ||
        text == 'goodbye') {
      return "Happy shopping on Karigari! Come back anytime if you need help finding a handmade product.";
    }

    return "Hi! 👋 I can help you find handmade products on Karigari. Tell me what you're looking for — for example, \"red handmade bangles for a wedding.\"";
  }

  bool _isNegative(String text) {
    const negatives = {
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

    return negatives.contains(text);
  }

  bool _isConfirmation(String text) {
    const confirmations = {
      'yes',
      'yes please',
      'yes show',
      'show',
      'show me',
      'okay',
      'ok',
      'sure',
      'please',
      'go ahead',
      'that works',
      'that is fine',
      "that's fine",
      'thats fine',
      'fine',
      'yep',
      'yeah',
      'yup',
    };

    return confirmations.contains(text);
  }

  bool _isMoreRequest(String text) {
    const moreRequests = {
      'more',
      'show more',
      'more products',
      'show me more',
      'more options',
      'more items',
      'anything else',
      'what else',
      'other options',
      'other products',
      'show other products',
    };

    return moreRequests.contains(text);
  }

  bool _isCorrection(String text) {
    const words = [
      'actually',
      'instead',
      'rather',
      'i meant',
      'i mean',
      'no i want',
      'no i need',
      'not that',
      'change it',
      'change that',
    ];

    return words.any(text.contains);
  }

  bool _isExplicitNewSearch(String text) {
    if (_lastIntent == null) {
      return false;
    }

    const starters = [
      'now show',
      'now i want',
      'now i need',
      'show me another',
      'find me another',
      'i want something else',
      'i need something else',
      'looking for something else',
    ];

    return starters.any(text.contains);
  }

  bool _hasUsefulSearchIntent(
    Map<String, dynamic> intent,
  ) {
    return _hasNonEmpty(intent['category']) ||
        _hasNonEmpty(intent['productType']) ||
        _hasNonEmpty(intent['subcategory']) ||
        _stringList(intent['material']).isNotEmpty ||
        _stringList(intent['colour']).isNotEmpty ||
        _stringList(intent['style']).isNotEmpty ||
        _stringList(intent['occasion']).isNotEmpty ||
        intent['handmade'] == true ||
        _stringList(intent['keywords']).isNotEmpty ||
        _stringList(intent['searchTerms']).isNotEmpty;
  }

  bool _hasConcreteLocalIntent(String text) {
    return _detectCategory(text) != null ||
        _detectProductType(text) != null ||
        _detectOccasion(text) != null ||
        _detectMaterials(text).isNotEmpty ||
        _detectColours(text).isNotEmpty ||
        _detectStyles(text).isNotEmpty ||
        _containsHandmade(text);
  }

  bool _isVagueRequest({
    required String text,
    required Map<String, dynamic> intent,
  }) {
    final normalized = _normalise(text);

    if (_isConfirmation(normalized) ||
        _isMoreRequest(normalized)) {
      return false;
    }

    if (_hasConcreteLocalIntent(normalized)) {
      return false;
    }

    if (_hasUsefulSearchIntent(intent) &&
        intent['needsClarification'] != true) {
      return false;
    }

    const vaguePhrases = [
      'something',
      'something nice',
      'something good',
      'anything',
      'anything nice',
      'some product',
      'some products',
      'some handmade stuff',
      'handmade stuff',
      'show me',
      'find something',
      'i want something',
      'i need something',
      'what do you have',
      'what can i buy',
      'give me something',
    ];

    if (vaguePhrases.contains(normalized)) {
      return true;
    }

    // Very short requests without a recognizable shopping entity are
    // treated as vague rather than producing random products.
    final words = normalized
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    return words.length <= 2 &&
        !_hasUsefulSearchIntent(intent);
  }

  String _clarificationForVagueRequest(
    String text,
    Map<String, dynamic> intent,
  ) {
    final category =
        intent['category']?.toString().trim();

    if (category != null &&
        category.isNotEmpty) {
      return "Sure! What type of ${category.toLowerCase()} are you looking for? For example, you can ask for a specific item, colour, material, or occasion.";
    }

    return "Sure! What kind of handmade product are you looking for? You can tell me a product type, category, colour, material, or occasion — for example, \"handmade red bangles for a wedding.\"";
  }

  String _clarificationForIntent(
    Map<String, dynamic> intent,
  ) {
    final category =
        intent['category']?.toString().trim();

    if (category != null &&
        category.isNotEmpty) {
      return "I can help with ${category.toLowerCase()}. Would you like a specific product type, or should I show you a variety?";
    }

    return "Could you tell me a little more about the handmade product you're looking for?";
  }

  bool _mentionsDifferentProductType(
    String text,
    dynamic oldType,
  ) {
    final old = _normalise(oldType);

    if (old.isEmpty) {
      return false;
    }

    final newType = _detectProductType(text);

    return newType != null &&
        _normalise(newType) != old;
  }

  // -------------------------------------------------------------------------
  // ENTITY DETECTION
  // -------------------------------------------------------------------------

  String? _detectCategory(String text) {
    final normalized = _normalise(text);

    for (final entry in _categoryAliases.entries) {
      for (final alias in entry.value) {
        if (_containsPhrase(
          normalized,
          alias,
        )) {
          return entry.key;
        }
      }
    }

    // Natural descriptions frequently imply a category through the item.
    final type = _detectProductType(normalized);

    if (type != null) {
      if (_jewelleryTypes.contains(type)) {
        return 'Jewellery';
      }

      if (_homeDecorTypes.contains(type)) {
        return 'Home Decor';
      }

      if (_bagTypes.contains(type)) {
        return 'Bags';
      }

      if (_clothingTypes.contains(type)) {
        return 'Clothing';
      }
    }

    return null;
  }

  String? _detectProductType(String text) {
    final normalized = _normalise(text);

    String? bestType;
    int bestLength = 0;

    for (final entry in _productTypeAliases.entries) {
      for (final alias in entry.value) {
        if (_containsPhrase(
          normalized,
          alias,
        )) {
          if (alias.length > bestLength) {
            bestType = entry.key;
            bestLength = alias.length;
          }
        }
      }
    }

    return bestType;
  }

  String? _detectOccasion(String text) {
    final normalized = _normalise(text);

    for (final entry in _occasionAliases.entries) {
      for (final alias in entry.value) {
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

  List<String> _detectMaterials(String text) {
    final normalized = _normalise(text);
    final result = <String>[];

    for (final entry in _materialAliases.entries) {
      if (entry.value.any(
        (alias) => _containsPhrase(
          normalized,
          alias,
        ),
      )) {
        result.add(entry.key);
      }
    }

    return result;
  }

  List<String> _detectColours(String text) {
    final normalized = _normalise(text);
    final result = <String>[];

    for (final colour in _commonColours) {
      if (_containsPhrase(
        normalized,
        colour,
      )) {
        result.add(colour);
      }
    }

    return result;
  }

  List<String> _detectStyles(String text) {
    final normalized = _normalise(text);
    final result = <String>[];

    for (final entry in _attributeAliases.entries) {
      if (entry.key == 'handmade') {
        continue;
      }

      if (entry.value.any(
        (alias) => _containsPhrase(
          normalized,
          alias,
        ),
      )) {
        result.add(entry.key);
      }
    }

    return result;
  }

  bool _containsHandmade(String text) {
    final normalized = _normalise(text);

    return _attributeAliases['handmade']!.any(
      (word) => _containsPhrase(
        normalized,
        word,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // PRODUCT SEARCH
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _findMatchingProducts(
    Map<String, dynamic> intent, {
    bool excludeShown = false,
  }) async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('products')
            .where(
              'isAvailable',
              isEqualTo: true,
            )
            .get();

    final List<_ScoredProduct> scoredProducts = [];

    for (final doc in snapshot.docs) {
      final data =
          Map<String, dynamic>.from(
        doc.data(),
      );

      data['documentId'] = doc.id;

      if (excludeShown &&
          _shownProductIds.contains(
            doc.id,
          )) {
        continue;
      }

      // -------------------------------------------------------------
      // STRICT PRODUCT TYPE
      //
      // If the user asks for bangles, do not return necklaces merely
      // because they are jewellery.
      // -------------------------------------------------------------

      final requestedType =
          _normalise(intent['productType']);

      if (requestedType.isNotEmpty &&
          !_matchesProductType(
            data,
            requestedType,
          )) {
        continue;
      }

      // -------------------------------------------------------------
      // STRICT CATEGORY
      // -------------------------------------------------------------

      final requestedCategory =
          _normalise(intent['category']);

      if (requestedCategory.isNotEmpty &&
          !_matchesCategory(
            data,
            requestedCategory,
          )) {
        continue;
      }

      // -------------------------------------------------------------
      // HANDMADE FILTER
      // -------------------------------------------------------------

      if (intent['handmade'] == true &&
          !_isHandmadeProduct(data)) {
        continue;
      }

      // -------------------------------------------------------------
      // FILTERS
      // -------------------------------------------------------------

      final requiredMaterials =
          _stringList(intent['material']);

      final requiredColours =
          _stringList(intent['colour']);

      final requiredStyles =
          _stringList(intent['style']);

      final requiredOccasions =
          _stringList(intent['occasion']);

      // These are true filters, not just ranking hints.
      if (requiredMaterials.isNotEmpty &&
          !_matchesAnyField(
            data,
            'material',
            requiredMaterials,
          )) {
        continue;
      }

      if (requiredColours.isNotEmpty &&
          !_matchesAnyField(
            data,
            'colour',
            requiredColours,
          )) {
        continue;
      }

      if (requiredStyles.isNotEmpty &&
          !_matchesAnyField(
            data,
            'style',
            requiredStyles,
          )) {
        continue;
      }

      if (requiredOccasions.isNotEmpty &&
          !_matchesOccasion(
            data,
            requiredOccasions,
          )) {
        continue;
      }

      final score =
          _calculateIntentScore(
        product: data,
        intent: intent,
      );

      if (score <= 0) {
        continue;
      }

      scoredProducts.add(
        _ScoredProduct(
          product: data,
          score: score,
        ),
      );
    }

    scoredProducts.sort(
      (a, b) {
        final scoreCompare =
            b.score.compareTo(
          a.score,
        );

        if (scoreCompare != 0) {
          return scoreCompare;
        }

        return _normalise(
          a.product['title'],
        ).compareTo(
          _normalise(
            b.product['title'],
          ),
        );
      },
    );

    return scoredProducts
        .take(5)
        .map(
          (item) => item.product,
        )
        .toList();
  }

  bool _matchesProductType(
    Map<String, dynamic> product,
    String requestedType,
  ) {
    final requested =
        _normalise(requestedType);

    final fields = <String>[
      _normalise(product['productType']),
      _normalise(product['subcategory']),
      _normalise(product['title']),
    ];

    final aliases =
        _productTypeAliasesFor(
      requested,
    );

    if (aliases.isEmpty) {
      return fields.any(
        (field) =>
            field == requested ||
            field.contains(requested),
      );
    }

    return aliases.any(
      (alias) => fields.any(
        (field) =>
            field == alias ||
            field.contains(alias),
      ),
    );
  }

  bool _matchesCategory(
    Map<String, dynamic> product,
    String requestedCategory,
  ) {
    final requested =
        _normalise(requestedCategory);

    final category =
        _normalise(product['category']);

    final sellerCategory =
        _normalise(product['sellerCategory']);

    final text =
        _buildProductText(product);

    final aliases =
        _categoryAliasesFor(
      requested,
    );

    if (aliases.any(
      (alias) =>
          category == alias ||
          sellerCategory == alias,
    )) {
      return true;
    }

    // Catalogs can have slightly different category names, so fall back
    // to semantic category evidence only after exact alias checking.
    if (requested == 'jewellery') {
      return _containsAny(
        text,
        [
          'jewellery',
          'jewelry',
          'bangle',
          'necklace',
          'earring',
          'bracelet',
        ],
      );
    }

    if (requested == 'home decor') {
      return _containsAny(
        text,
        [
          'home decor',
          'home decoration',
          'table cloth',
          'tablecloth',
          'table runner',
          'basket',
          'lantern',
          'candle holder',
          'wall hanging',
          'flower vase',
          'clay pot',
          'decor',
        ],
      );
    }

    if (requested == 'clothing') {
      return _containsAny(
        text,
        [
          'clothing',
          'apparel',
          'dress',
          'saree',
          'sari',
          'kurta',
          'shirt',
          'scarf',
          'dupatta',
        ],
      );
    }

    if (requested == 'kitchenware') {
      return _containsAny(
        text,
        [
          'kitchen',
          'utensil',
          'utensils',
          'serving',
          'cookware',
        ],
      );
    }

    if (requested == 'bags') {
      return _containsAny(
        text,
        [
          'bag',
          'handbag',
          'tote',
          'purse',
        ],
      );
    }

    if (requested == 'pottery') {
      return _containsAny(
        text,
        [
          'pottery',
          'pot',
          'clay',
          'terracotta',
          'ceramic',
        ],
      );
    }

    return text.contains(requested);
  }

  List<String> _categoryAliasesFor(
    String category,
  ) {
    final normalized =
        _normalise(category);

    for (final entry in _categoryAliases.entries) {
      if (_normalise(entry.key) ==
          normalized) {
        return entry.value
            .map(_normalise)
            .toList();
      }
    }

    return [
      normalized,
    ];
  }

  List<String> _productTypeAliasesFor(
    String type,
  ) {
    final normalized =
        _normalise(type);

    for (final entry in _productTypeAliases.entries) {
      if (_normalise(entry.key) ==
          normalized) {
        return entry.value
            .map(_normalise)
            .toList();
      }
    }

    return [
      normalized,
    ];
  }

  bool _matchesAnyField(
    Map<String, dynamic> product,
    String field,
    List<String> requested,
  ) {
    final values =
        _stringList(product[field]);

    if (values.isEmpty) {
      // Also inspect searchable text because seller/AI metadata can
      // occasionally be incomplete.
      final text =
          _buildProductText(product);

      return requested.any(
        (value) => text.contains(
          _normalise(value),
        ),
      );
    }

    return requested.any(
      (target) => values.any(
        (value) =>
            value == _normalise(target) ||
            value.contains(
              _normalise(target),
            ) ||
            _normalise(target).contains(
              value,
            ),
      ),
    );
  }

  bool _matchesOccasion(
    Map<String, dynamic> product,
    List<String> requested,
  ) {
    final occasions =
        _stringList(product['occasion']);

    final useCases =
        _stringList(product['useCases']);

    final text =
        _buildProductText(product);

    return requested.any(
      (target) {
        final normalizedTarget =
            _normalise(target);

        if (occasions.any(
          (value) => value == normalizedTarget ||
              value.contains(normalizedTarget) ||
              normalizedTarget.contains(value),
        )) {
          return true;
        }

        if (useCases.any(
          (value) => value.contains(
            normalizedTarget,
          ),
        )) {
          return true;
        }

        // Wedding/festive products may be catalogued as festive or
        // cultural rather than literally "wedding".
        if (normalizedTarget == 'wedding') {
          return text.contains('festive') ||
              text.contains('bridal') ||
              text.contains('wedding') ||
              text.contains('cultural');
        }

        return false;
      },
    );
  }

  int _calculateIntentScore({
    required Map<String, dynamic> product,
    required Map<String, dynamic> intent,
  }) {
    int score = 0;

    final title =
        _normalise(product['title']);

    final description =
        _normalise(product['description']);

    final productCategory =
        _normalise(product['category']);

    final subcategory =
        _normalise(product['subcategory']);

    final productType =
        _normalise(product['productType']);

    final text =
        _buildProductText(product);

    final tags =
        _stringList(product['tags']);

    final keywords =
        _stringList(product['keywords']);

    final searchTerms =
        _stringList(product['searchTerms']);

    final materials =
        _stringList(product['material']);

    final colours =
        _stringList(product['colour']);

    final styles =
        _stringList(product['style']);

    final occasions =
        _stringList(product['occasion']);

    final useCases =
        _stringList(product['useCases']);

    final requestedCategory =
        _normalise(intent['category']);

    final requestedType =
        _normalise(intent['productType']);

    final requestedSubcategory =
        _normalise(intent['subcategory']);

    if (requestedCategory.isNotEmpty &&
        _matchesCategory(
          product,
          requestedCategory,
        )) {
      score += 100;
    }

    if (requestedType.isNotEmpty &&
        _matchesProductType(
          product,
          requestedType,
        )) {
      score += 180;
    }

    if (requestedSubcategory.isNotEmpty &&
        (subcategory ==
                requestedSubcategory ||
            subcategory.contains(
              requestedSubcategory,
            ))) {
      score += 80;
    }

    for (final material
        in _stringList(intent['material'])) {
      if (_containsFlexible(
        materials,
        material,
      )) {
        score += 50;
      } else if (text.contains(
        _normalise(material),
      )) {
        score += 20;
      }
    }

    for (final colour
        in _stringList(intent['colour'])) {
      if (_containsFlexible(
        colours,
        colour,
      )) {
        score += 50;
      } else if (text.contains(
        _normalise(colour),
      )) {
        score += 20;
      }
    }

    for (final style
        in _stringList(intent['style'])) {
      if (_containsFlexible(
        styles,
        style,
      )) {
        score += 40;
      } else if (text.contains(
        _normalise(style),
      )) {
        score += 15;
      }
    }

    for (final occasion
        in _stringList(intent['occasion'])) {
      if (_containsFlexible(
        occasions,
        occasion,
      )) {
        score += 50;
      } else if (_containsFlexible(
        useCases,
        occasion,
      )) {
        score += 30;
      } else if (_matchesOccasion(
        product,
        [occasion],
      )) {
        score += 20;
      }
    }

    for (final keyword
        in _stringList(intent['keywords'])) {
      final k = _normalise(keyword);

      if (k.isEmpty) continue;

      if (title.contains(k)) {
        score += 35;
      }

      if (productType.contains(k)) {
        score += 30;
      }

      if (productCategory.contains(k)) {
        score += 20;
      }

      if (keywords.any(
        (value) => value.contains(k),
      )) {
        score += 25;
      }

      if (searchTerms.any(
        (value) => value.contains(k),
      )) {
        score += 20;
      }

      if (tags.any(
        (value) => value.contains(k),
      )) {
        score += 15;
      }

      if (description.contains(k)) {
        score += 8;
      }
    }

    // A product should receive a little relevance for being a genuine
    // handmade/artisan product even if the seller metadata is sparse.
    if (intent['handmade'] == true &&
        _isHandmadeProduct(product)) {
      score += 20;
    }

    // Small title bonus makes exact product names rank above generic matches.
    if (requestedType.isNotEmpty &&
        title.contains(requestedType)) {
      score += 20;
    }

    return score;
  }

  // -------------------------------------------------------------------------
  // NO-RESULTS / RESPONSE HANDLING
  // -------------------------------------------------------------------------

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

    final filters = <String>[];

    final colours =
        _stringList(intent['colour']);

    final materials =
        _stringList(intent['material']);

    final occasions =
        _stringList(intent['occasion']);

    if (colours.isNotEmpty) {
      filters.add(
        colours.join(', '),
      );
    }

    if (materials.isNotEmpty) {
      filters.add(
        materials.join(', '),
      );
    }

    if (occasions.isNotEmpty) {
      filters.add(
        occasions.join(', '),
      );
    }

    final itemName =
        type?.isNotEmpty == true
            ? type!
            : category?.isNotEmpty == true
                ? category!
                : 'products';

    if (filters.isNotEmpty) {
      return "I couldn't find an exact match for $itemName with ${filters.join(' and ')} right now. Would you like to remove one filter, change the product type, or broaden the search?";
    }

    return "I couldn't find a matching $itemName in the marketplace right now. Would you like to try a different product type or category?";
  }

  String _fallbackResponse(
    List<Map<String, dynamic>> products,
    Map<String, dynamic> intent,
  ) {
    if (products.isEmpty) {
      return _noResultsResponse(
        intent,
      );
    }

    final productType =
        intent['productType']
            ?.toString()
            .trim();

    final category =
        intent['category']
            ?.toString()
            .trim();

    if (productType != null &&
        productType.isNotEmpty) {
      return "I found ${products.length} ${_displayName(productType)} options that match what you're looking for.";
    }

    if (category != null &&
        category.isNotEmpty) {
      return "I found ${products.length} ${category.toLowerCase()} options that match what you're looking for.";
    }

    return "I found ${products.length} handmade products that may be a good match.";
  }

  Future<void> _respondWithoutSearch(
    String response,
  ) async {
    if (!mounted) return;

    setState(() {
      _isTyping = false;

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

      _recommendedProducts = [];
    });

    _scrollToBottom();
  }

  Future<void> _showProducts(
    List<Map<String, dynamic>> products,
    String response,
  ) async {
    if (!mounted) return;

    setState(() {
      _isTyping = false;
      _recommendedProducts = products;

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

  // -------------------------------------------------------------------------
  // PRODUCT HELPERS
  // -------------------------------------------------------------------------

  String _productId(
    Map<String, dynamic> product,
  ) {
    final id =
        product['documentId'] ??
            product['productId'] ??
            product['id'] ??
            product['title'] ??
            '';

    return id.toString();
  }

  bool _isHandmadeProduct(
    Map<String, dynamic> product,
  ) {
    final values = <String>[
      _normalise(product['title']),
      _normalise(product['description']),
      _normalise(product['category']),
      _normalise(product['sellerCategory']),
      ..._stringList(product['tags']),
      ..._stringList(product['keywords']),
      ..._stringList(product['searchTerms']),
      ..._stringList(product['style']),
    ];

    const handmadeWords = [
      'handmade',
      'handcrafted',
      'hand made',
      'hand crafted',
      'artisan',
      'artisan made',
      'artisan-made',
      'locally made',
      'crafted',
    ];

    return values.any(
      (value) => handmadeWords.any(
        (word) => value.contains(
          word,
        ),
      ),
    );
  }

  String _buildProductText(
    Map<String, dynamic> product,
  ) {
    final values = <String>[
      _normalise(product['title']),
      _normalise(product['description']),
      _normalise(product['category']),
      _normalise(product['subcategory']),
      _normalise(product['productType']),
      _normalise(product['sellerCategory']),
      ..._stringList(product['tags']),
      ..._stringList(product['keywords']),
      ..._stringList(product['searchTerms']),
      ..._stringList(product['material']),
      ..._stringList(product['colour']),
      ..._stringList(product['style']),
      ..._stringList(product['occasion']),
      ..._stringList(product['useCases']),
    ];

    return values
        .where(
          (value) => value.isNotEmpty,
        )
        .join(' ');
  }

  bool _containsAny(
    String text,
    List<String> values,
  ) {
    return values.any(
      (value) => text.contains(
        _normalise(value),
      ),
    );
  }

  bool _containsFlexible(
    List<String> values,
    String target,
  ) {
    final normalizedTarget =
        _normalise(target);

    return values.any(
      (value) =>
          value == normalizedTarget ||
          value.contains(
            normalizedTarget,
          ) ||
          normalizedTarget.contains(
            value,
          ),
    );
  }

  bool _containsPhrase(
    String text,
    String phrase,
  ) {
    final normalizedText =
        _normalise(text);

    final normalizedPhrase =
        _normalise(phrase);

    if (normalizedPhrase.isEmpty) {
      return false;
    }

    // Use word boundaries so "bag" does not accidentally match unrelated
    // words merely because the characters occur inside them.
    final escaped =
        RegExp.escape(normalizedPhrase)
            .replaceAll(
              r'\ ',
              r'\s+',
            );

    return RegExp(
      r'(^|\s)' +
          escaped +
          r'($|\s)',
      caseSensitive: false,
    ).hasMatch(
      normalizedText,
    );
  }

  bool _hasNonEmpty(dynamic value) {
    return value != null &&
        value.toString().trim().isNotEmpty;
  }

  List<String> _mergeList(
    List<String> first,
    List<String> second,
  ) {
    return {
      ...first.map(_normalise),
      ...second.map(_normalise),
    }.where(
      (value) => value.isNotEmpty,
    ).toList();
  }

  List<String> _stringList(
    dynamic value,
  ) {
    if (value is! List) {
      return [];
    }

    return value
        .map(
          (item) => _normalise(item),
        )
        .where(
          (item) => item.isNotEmpty,
        )
        .toSet()
        .toList();
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
          RegExp(r'[^\w\s-]'),
          ' ',
        )
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        )
        .trim();
  }

  String _displayName(
    String value,
  ) {
    final normalized =
        _normalise(value);

    switch (normalized) {
      case 'table cloth':
        return 'table cloth';
      case 'table runner':
        return 'table runner';
      case 'flower vase':
        return 'flower vase';
      case 'candle holder':
        return 'candle holder';
      case 'clay pot':
        return 'clay pot';
      case 'kitchen utensils':
        return 'kitchen utensils';
      default:
        return value;
    }
  }

  // -------------------------------------------------------------------------
  // NAVIGATION / SUGGESTIONS / SCROLL
  // -------------------------------------------------------------------------

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
            .replaceAll(
              '"',
              '',
            );

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
      'description':
          productDescription,
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
            curve:
                Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity:
                curvedAnimation,
            child:
                SlideTransition(
              position:
                  Tween<Offset>(
                begin:
                    const Offset(
                  0.04,
                  0,
                ),
                end:
                    Offset.zero,
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

  void _useSuggestion(
    String text,
  ) {
    _controller.text =
        text;

    _controller.selection =
        TextSelection.fromPosition(
      TextPosition(
        offset:
            _controller.text.length,
      ),
    );

    _inputFocusNode
        .requestFocus();
  }

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
                            )
                          .size
                          .height *
                          0.55
                      : MediaQuery.of(
                              context,
                            )
                          .size
                          .height *
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
            child: const Icon(
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
                    fontSize:
                        16,
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
                  const EdgeInsets
                      .fromLTRB(
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
                if (_isTyping &&
                    index ==
                        _messages
                            .length) {
                  return _buildTypingIndicator();
                }

                final recommendationIndex =
                    _messages
                            .length +
                        (_isTyping
                            ? 1
                            : 0);

                if (_recommendedProducts
                        .isNotEmpty &&
                    index ==
                        recommendationIndex) {
                  return _buildRecommendations();
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
            .replaceAll(
              '"',
              '',
            );

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
            color: Colors.black
                .withOpacity(
              0.06,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withOpacity(
                0.035,
              ),
              blurRadius: 10,
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
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              child: SizedBox(
                width: 68,
                height: 68,
                child:
                    imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit:
                                BoxFit.cover,
                            filterQuality:
                                FilterQuality
                                    .low,
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
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    title,
                    maxLines:
                        2,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      fontSize:
                          13,
                      fontWeight:
                          FontWeight
                              .w700,
                      color:
                          Color(
                        0xFF222222,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  if (seller
                      .isNotEmpty)
                    Text(
                      seller,
                      maxLines:
                          1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize:
                            10,
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
                      fontSize:
                          13,
                      fontWeight:
                          FontWeight
                              .w800,
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

  Widget _buildSuggestions() {
    return SizedBox(
      height: 52,
      child:
          ListView(
        scrollDirection:
            Axis.horizontal,
        padding:
            const EdgeInsets
                .symmetric(
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
        onPressed:
            () {
          _useSuggestion(
            text,
          );
        },
      ),
    );
  }

  Widget _buildMessage(
    _ChatMessage message,
  ) {
    return Align(
      alignment:
          message.isUser
              ? Alignment.centerRight
              : Alignment.centerLeft,
      child:
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
          bottom: 10,
        ),
        padding:
            const EdgeInsets
                .symmetric(
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
                    ? FontWeight
                        .w500
                    : FontWeight
                        .w400,
          ),
        ),
      ),
    );
  }

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
            const EdgeInsets
                .symmetric(
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
            color: Colors.black
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
                    TextInputAction
                        .newline,
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
                      EdgeInsets
                          .symmetric(
                    horizontal:
                        16,
                    vertical:
                        11,
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

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({
    required this.text,
    required this.isUser,
  });
}

class _ScoredProduct {
  final Map<String, dynamic> product;
  final int score;

  const _ScoredProduct({
    required this.product,
    required this.score,
  });
}