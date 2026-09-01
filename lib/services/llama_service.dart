import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class LlamaService {
  // ============================================================
  // OLLAMA CONFIGURATION
  // ============================================================

  static const String _baseUrl =
      'http://10.242.159.181:11434';

  static const String _model =
      'llama3.2:3b';

  static const Duration _requestTimeout =
      Duration(seconds: 60);

  // ============================================================
  // UNDERSTAND USER REQUEST
  // ============================================================

  static Future<Map<String, dynamic>> understandRequest({
    required String userMessage,
    List<Map<String, String>> conversation = const [],
    Map<String, dynamic>? previousIntent,
    Map<String, dynamic>? conversationState,
  }) async {
    final conversationText =
        _buildConversationText(conversation);

    final previousIntentText =
        previousIntent == null
            ? 'No previous shopping intent.'
            : jsonEncode(previousIntent);

    final stateText =
        conversationState == null
            ? 'No conversation state.'
            : jsonEncode(conversationState);

    final prompt = '''
You are Karigari's local shopping conversation engine.

Karigari is a marketplace for handmade products.

Your job is to understand what the customer means.

You DO NOT search Firestore.

You DO NOT invent products.

You DO NOT invent product IDs.

You DO NOT decide whether a product is added to the cart.

Flutter handles those operations.

You only understand the user's language and produce structured intent.

============================================================
IMPORTANT CONVERSATIONAL RULE
============================================================

A product search and product selection are DIFFERENT things.

If the user says:

"show me necklaces"

this means SEARCH for necklaces.

It does NOT mean:

"buy a necklace"

If the user says:

"I like the Beaded Necklace"

this means they are selecting a product that may already have been displayed.

Flutter handles that selection.

============================================================
EXAMPLES
============================================================

User:
"show me necklaces"

Return:

productType = Necklace
category = Jewellery

Do NOT ask a clarification question.

------------------------------------------------------------

User:
"I want handmade necklaces"

Return:

productType = Necklace
category = Jewellery
handmade = true

Do NOT ask a clarification question.

------------------------------------------------------------

User:
"show me some home decor"

This is broad.

Return:

category = Home Decor
productType = null
needsClarification = true

------------------------------------------------------------

User:
"show me handmade gift items"

This is broad.

Do not invent a product type.

Return:

category = null
productType = null
occasion = ["gift"]
handmade = true
needsClarification = true

------------------------------------------------------------

User:
"clay pots"

Return:

productType = Clay Pot
category = Home Decor

------------------------------------------------------------

User:
"red bangles for a wedding"

Return:

category = Jewellery
productType = Bangles
colour = ["red"]
occasion = ["wedding"]

------------------------------------------------------------

User:
"something cheaper"

Preserve the previous search.

Modify the budget/search.

------------------------------------------------------------

User:
"show me something else"

Preserve the previous category/type unless the user explicitly changes it.

------------------------------------------------------------

User:
"actually show me necklaces"

Replace the old product type with Necklace.

Do NOT preserve an old product type such as Bangles.

============================================================
NORMAL CONVERSATION
============================================================

Handle normal conversation naturally.

Examples:

"hi"
"hello"
"how are you?"
"thanks"
"what can you do?"

These are not product searches.

Return:

action = normal_conversation

============================================================
SHORT CONFIRMATIONS
============================================================

Short answers such as:

"yes"
"yeah"
"okay"
"sure"

must be interpreted using conversation state.

However, Flutter handles actual cart confirmation and product selection.

If the conversation state says that the user is selecting a displayed product, do not turn "yes" into a new search.

============================================================
SPELLING
============================================================

Interpret:

jwellery
jewlery
jewllery

as Jewellery.

Interpret:

necklaces

as Necklace.

Interpret:

bangles

as Bangles.

Interpret:

earrings

as Earrings.

Interpret:

table runners

as Table Runner.

Interpret:

table cloths
tablecloth

as Table Cloth.

============================================================
OUTPUT
============================================================

Return ONLY valid JSON.

Use exactly:

{
  "action": "search_products | clarification | normal_conversation | modify_search",

  "needsClarification": false,

  "clarificationQuestion": "",

  "category": null,

  "subcategory": null,

  "productType": null,

  "material": [],

  "colour": [],

  "style": [],

  "occasion": [],

  "budget": {
    "min": null,
    "max": null
  },

  "handmade": false,

  "keywords": [],

  "searchModification": {
    "type": "",
    "value": ""
  },

  "reason": ""
}

============================================================
PREVIOUS CONVERSATION
============================================================

$conversationText

============================================================
PREVIOUS INTENT
============================================================

$previousIntentText

============================================================
CONVERSATION STATE
============================================================

$stateText

============================================================
CURRENT USER MESSAGE
============================================================

$userMessage
''';

    final decoded = await _generateJson(
      prompt,
      temperature: 0.1,
    );

    return _normaliseIntent(decoded);
  }

  // ============================================================
  // NATURAL CONVERSATION RESPONSE
  // ============================================================

  static Future<String> generateResponse({
    required String userMessage,
    required List<Map<String, dynamic>> products,
    required Map<String, dynamic> intent,
    List<Map<String, String>> conversation = const [],
    Map<String, dynamic>? conversationState,
  }) async {
    final safeProducts = products.map((product) {
      return {
        'id': product['documentId'] ??
            product['productId'] ??
            product['id'],
        'title': product['title'],
        'price': product['price'],
        'category': product['category'],
        'productType': product['productType'],
      };
    }).toList();

    final prompt = '''
You are Karigari, a friendly conversational shopping assistant.

You are powered by a local Llama model.

The Flutter application controls Firestore and cart operations.

You must NEVER invent:

- products
- prices
- product IDs
- sellers
- availability
- product features

============================================================
CURRENT USER MESSAGE
============================================================

$userMessage

============================================================
CONVERSATION
============================================================

${_buildConversationText(conversation)}

============================================================
INTENT
============================================================

${jsonEncode(intent)}

============================================================
CONVERSATION STATE
============================================================

${conversationState == null ? 'No state.' : jsonEncode(conversationState)}

============================================================
PRODUCTS FROM FIRESTORE
============================================================

${jsonEncode(safeProducts)}

============================================================
RULES
============================================================

If action is normal_conversation:

Have a natural conversation.

If the user says hello:

Say something like:

"Hi! 👋 What kind of handmade products are you looking for?"

If the user thanks you:

Respond naturally.

If products were found:

Say that you found matching products.

Do NOT list their names because Flutter displays product cards.

Example:

"I found 3 products that match your request."

If products are empty:

Explain that you could not find a close match.

Do not invent alternatives.

Keep the response short.

Usually 1–2 sentences.

Return ONLY the response text.
''';

    return _generateText(
      prompt,
      temperature: 0.35,
    );
  }

  // ============================================================
  // GENERATE JSON
  // ============================================================

  static Future<Map<String, dynamic>> _generateJson(
    String prompt, {
    double temperature = 0.1,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/generate'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': _model,
            'prompt': prompt,
            'stream': false,
            'format': 'json',
            'options': {
              'temperature': temperature,
              'num_ctx': 8192,
            },
          }),
        )
        .timeout(_requestTimeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Llama request failed: '
        '${response.statusCode}\n'
        '${response.body}',
      );
    }

    final body = jsonDecode(response.body);

    final raw = body['response'];

    if (raw == null) {
      throw Exception(
        'Llama returned an empty response.',
      );
    }

    final text = raw.toString().trim();

    if (text.isEmpty) {
      throw Exception(
        'Llama returned an empty response.',
      );
    }

    try {
      final decoded = jsonDecode(text);

      if (decoded is! Map) {
        throw Exception(
          'Expected a JSON object.',
        );
      }

      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      throw Exception(
        'Llama returned invalid JSON.\n\n'
        'Response:\n$text\n\n'
        'Error:\n$e',
      );
    }
  }

  // ============================================================
  // GENERATE TEXT
  // ============================================================

  static Future<String> _generateText(
    String prompt, {
    double temperature = 0.35,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/generate'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': _model,
            'prompt': prompt,
            'stream': false,
            'options': {
              'temperature': temperature,
              'num_ctx': 8192,
            },
          }),
        )
        .timeout(_requestTimeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Llama response generation failed: '
        '${response.statusCode}',
      );
    }

    final body = jsonDecode(response.body);

    final text = body['response']
        ?.toString()
        .trim();

    if (text == null || text.isEmpty) {
      throw Exception(
        'Llama returned an empty response.',
      );
    }

    return text;
  }

  // ============================================================
  // CONVERSATION TEXT
  // ============================================================

  static String _buildConversationText(
    List<Map<String, String>> conversation,
  ) {
    if (conversation.isEmpty) {
      return 'No previous conversation.';
    }

    final recent = conversation.length > 20
        ? conversation.sublist(
            conversation.length - 20,
          )
        : conversation;

    return recent.map((message) {
      return '${message['role']}: ${message['text']}';
    }).join('\n');
  }

  // ============================================================
  // NORMALISE INTENT
  // ============================================================

  static Map<String, dynamic> _normaliseIntent(
    Map<String, dynamic> data,
  ) {
    final rawBudget = data['budget'];

    Map<String, dynamic> budget = {
      'min': null,
      'max': null,
    };

    if (rawBudget is Map) {
      budget = {
        'min': _numberOrNull(
          rawBudget['min'],
        ),
        'max': _numberOrNull(
          rawBudget['max'],
        ),
      };
    }

    final rawModification =
        data['searchModification'];

    Map<String, dynamic> searchModification = {
      'type': '',
      'value': '',
    };

    if (rawModification is Map) {
      searchModification = {
        'type': _stringOrEmpty(
          rawModification['type'],
        ),
        'value': _stringOrEmpty(
          rawModification['value'],
        ),
      };
    }

    return {
      'action': _normaliseAction(
        data['action'],
      ),

      'needsClarification':
          data['needsClarification'] == true,

      'clarificationQuestion':
          _stringOrEmpty(
        data['clarificationQuestion'],
      ),

      'category':
          _normaliseNullableString(
        data['category'],
      ),

      'subcategory':
          _normaliseNullableString(
        data['subcategory'],
      ),

      'productType':
          _normaliseNullableString(
        data['productType'],
      ),

      'material':
          _stringList(data['material']),

      'colour':
          _stringList(data['colour']),

      'style':
          _stringList(data['style']),

      'occasion':
          _stringList(data['occasion']),

      'budget': budget,

      'handmade':
          data['handmade'] == true,

      'keywords':
          _stringList(data['keywords']),

      'searchModification':
          searchModification,

      'reason':
          _stringOrEmpty(data['reason']),
    };
  }

  // ============================================================
  // ACTION
  // ============================================================

  static String _normaliseAction(
    dynamic value,
  ) {
    final action = value
        ?.toString()
        .trim()
        .toLowerCase();

    const allowed = {
      'search_products',
      'clarification',
      'normal_conversation',
      'modify_search',
    };

    if (allowed.contains(action)) {
      return action!;
    }

    return 'normal_conversation';
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static String? _normaliseNullableString(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();

    if (text.isEmpty ||
        text.toLowerCase() == 'null') {
      return null;
    }

    return text;
  }

  static String _stringOrEmpty(
    dynamic value,
  ) {
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  static List<String> _stringList(
    dynamic value,
  ) {
    if (value is! List) {
      return [];
    }

    return value
        .map(
          (item) => item
              .toString()
              .trim()
              .toLowerCase(),
        )
        .where(
          (item) => item.isNotEmpty,
        )
        .toSet()
        .toList();
  }

  static num? _numberOrNull(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value;
    }

    return num.tryParse(
      value.toString(),
    );
  }
}