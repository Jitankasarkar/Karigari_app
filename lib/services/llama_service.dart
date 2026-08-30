import 'dart:convert';

import 'package:http/http.dart' as http;

class LlamaService {
  static const String _baseUrl =
      'http://10.242.159.181:11434';

  static const String _model =
      'llama3.2:3b';

  static Future<Map<String, dynamic>> understandRequest({
    required String userMessage,
    List<Map<String, String>> conversation = const [],
    Map<String, dynamic>? previousIntent,
  }) async {
    final conversationText = conversation.isEmpty
        ? 'No previous conversation.'
        : conversation
            .map(
              (message) =>
                  '${message['role']}: ${message['text']}',
            )
            .join('\n');

    final previousIntentText =
        previousIntent == null
            ? 'No previous intent.'
            : jsonEncode(previousIntent);

    final prompt = '''
You are the shopping-intent engine for Karigari, a marketplace for handmade products.

Your job is to understand the customer's COMPLETE shopping request from the current message AND the previous conversation.

You do NOT recommend products.
You do NOT invent products.
Your output will be used by the Flutter application to search Firestore.

The customer may speak casually, use incomplete sentences, spelling mistakes, short replies, confirmations, corrections, or multiple requirements.

IMPORTANT:

1. ALWAYS consider the previous conversation.

2. A short follow-up such as:
"yes"
"yes show"
"show me"
"okay"
"please"
"that's fine"
means the customer is continuing the previous request.

Do NOT treat these as a new shopping request.

3. If the customer corrects themselves, use the correction.

Example:
User: "I want jewellery."
User: "Actually I want bangles."
Final intent should be bangles, not general jewellery.

4. If the customer adds a preference, preserve the previous product request.

Example:
User: "I want bangles."
User: "For a wedding."
Final intent:
category = Jewellery
productType = Bangles
occasion = wedding

5. If the customer says:
"I want handmade jewellery"
use:
category = Jewellery
handmade = true

6. If the customer says:
"I want jewellery for a wedding"
use:
category = Jewellery
occasion = wedding

7. If the customer says:
"I want bangles for a wedding"
use:
category = Jewellery
productType = Bangles
occasion = wedding

8. If the customer says:
"I want a table runner"
use:
productType = Table Runner

Do not turn "table runner" into a general request for all home products.

9. If the customer says:
"I want something for my table"
the request is not specific enough.
Ask ONE useful clarification question.

10. If the customer then says:
"like a table cloth"
preserve the previous context and set:
productType = Table Cloth

11. If the customer then says:
"table runner"
update the productType to:
Table Runner

12. If the customer says:
"I want some cool handmade items"
there is no specific category.

This is NOT necessarily a clarification.
The application may show a broad selection of handmade products.

Use:
category = null
productType = null
handmade = true

13. If the customer says:
"I want something handmade"
and gives no product type, the application may show handmade products broadly.

14. If the customer explicitly gives a product category, ONLY return that category.

Example:
"I want handmade jewellery"
must not become:
Home Decor
Table Linen
Basket
Kitchenware

15. If the user says "jwellery", "jewellery", "jewlery", "jewllery", interpret it as Jewellery.

16. If the user says "bangles", interpret it as Bangles.

17. If the user says "necklace", interpret it as Necklace.

18. If the user says "earrings", interpret it as Earrings.

19. If the user says "table runner", interpret it as Table Runner.

20. If the user says "table cloth", interpret it as Table Cloth.

21. Never invent a category that the customer did not request.

22. Preserve useful preferences such as:
material
colour
style
occasion
budget
keywords

23. Do not ask unnecessary questions.

24. Ask ONE clarification question only when the product request genuinely cannot be searched meaningfully.

25. A confirmation such as "yes show" should normally result in:
needsClarification = false
and preserve the previous intent.

26. If the customer says "no" or rejects a suggestion, do not immediately invent another product category.
Use the previous conversation to understand what they want next.

27. If the customer asks for something unrelated to shopping, politely mark the request as unclear.

28. Return ONLY valid JSON.

Use exactly this structure:

{
  "needsClarification": true or false,
  "clarificationQuestion": "question or empty string",
  "category": "category or null",
  "subcategory": "subcategory or null",
  "productType": "product type or null",
  "material": [],
  "colour": [],
  "style": [],
  "occasion": [],
  "budget": null,
  "handmade": true or false,
  "keywords": [],
  "reason": "short explanation"
}

PREVIOUS CONVERSATION:
$conversationText

PREVIOUS INTENT:
$previousIntentText

CURRENT CUSTOMER MESSAGE:
$userMessage
''';

    final response = await http.post(
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
          'temperature': 0.1,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Llama request failed: ${response.statusCode}',
      );
    }

    final responseBody =
        jsonDecode(response.body);

    final llamaResponse =
        responseBody['response'];

    if (llamaResponse == null) {
      throw Exception(
        'Llama returned an empty response.',
      );
    }

    final decoded =
        jsonDecode(llamaResponse.toString());

    if (decoded is! Map) {
      throw Exception(
        'Llama returned invalid intent data.',
      );
    }

    return _normaliseIntent(
      Map<String, dynamic>.from(decoded),
    );
  }

  static Future<String> generateResponse({
    required String userMessage,
    required List<Map<String, dynamic>> products,
    required Map<String, dynamic> intent,
    List<Map<String, String>> conversation = const [],
  }) async {
    final productsJson =
        jsonEncode(products);

    final intentJson =
        jsonEncode(intent);

    final prompt = '''
You are Karigari, a friendly shopping assistant for a handmade marketplace.

Respond naturally and conversationally.

The Flutter application has already searched the Firestore database.

IMPORTANT:
You MUST only talk about products contained in the supplied product list.

Never invent products.

Never mention a product category that is not represented by the supplied product list.

If products are available:
- acknowledge what the customer asked for
- say that you found matching products
- keep the response short and natural
- do not list product names because Flutter displays product cards separately
- do not invent product features

If products are empty:
- politely explain that matching products were not found
- suggest one useful way to broaden or modify the search
- do not recommend unrelated categories

If the customer is simply confirming a previous request:
respond naturally and indicate that you found the matching products.

Conversation:
${conversation.map((e) => '${e['role']}: ${e['text']}').join('\n')}

Customer:
$userMessage

Detected intent:
$intentJson

Products found:
$productsJson

Return ONLY the response text.
''';

    final response = await http.post(
      Uri.parse('$_baseUrl/api/generate'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'prompt': prompt,
        'stream': false,
        'options': {
          'temperature': 0.4,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Llama response generation failed: ${response.statusCode}',
      );
    }

    final responseBody =
        jsonDecode(response.body);

    final text =
        responseBody['response']
            ?.toString()
            .trim();

    if (text == null || text.isEmpty) {
      throw Exception(
        'Llama returned an empty response.',
      );
    }

    return text;
  }

  static Map<String, dynamic> _normaliseIntent(
    Map<String, dynamic> data,
  ) {
    return {
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
          _stringList(
        data['material'],
      ),

      'colour':
          _stringList(
        data['colour'],
      ),

      'style':
          _stringList(
        data['style'],
      ),

      'occasion':
          _stringList(
        data['occasion'],
      ),

      'budget':
          data['budget'],

      'handmade':
          data['handmade'] == true,

      'keywords':
          _stringList(
        data['keywords'],
      ),

      'reason':
          _stringOrEmpty(
        data['reason'],
      ),
    };
  }

  static String _stringOrEmpty(
    dynamic value,
  ) {
    if (value == null) {
      return '';
    }

    return value
        .toString()
        .trim();
  }

  static String? _normaliseNullableString(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final text =
        value.toString().trim();

    if (text.isEmpty ||
        text.toLowerCase() == 'null') {
      return null;
    }

    return text;
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
}