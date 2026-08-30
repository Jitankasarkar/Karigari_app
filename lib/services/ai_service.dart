import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

class AIService {
  // =========================================================
  // GEMINI MODEL
  // =========================================================
  //
  // App Check is explicitly passed because this project is
  // using an older firebase_ai version (2.3.0) and App Check
  // is enforced for Firebase AI Logic.
  //
  // =========================================================

  static final GenerativeModel _model =
      FirebaseAI.googleAI(
        appCheck: FirebaseAppCheck.instance,
      ).generativeModel(
        model: 'gemini-3.6-flash',
      );

  // =========================================================
  // GENERATE AI PRODUCT CATALOG DATA
  // =========================================================

  static Future<Map<String, dynamic>> generateProductCatalogData({
    required String title,
    required String description,
  }) async {
    final prompt = '''
You are an AI catalog assistant for Karigari, a marketplace
for local artisans and handmade products.

Your job is to understand a product and create structured,
accurate metadata that can later be used by:

- Product search
- Filters
- Recommendations
- AI shopping assistant
- Natural language product discovery

IMPORTANT:
Only use information that can reasonably be determined from
the product title and description.

Do NOT invent facts.

------------------------------------------------------------
PRODUCT TITLE
------------------------------------------------------------

$title

------------------------------------------------------------
PRODUCT DESCRIPTION
------------------------------------------------------------

$description

------------------------------------------------------------
RETURN FORMAT
------------------------------------------------------------

Return ONLY valid JSON.

Use exactly this structure:

{
  "category": "",
  "subcategory": "",
  "productType": "",
  "material": [],
  "colour": [],
  "style": [],
  "occasion": [],
  "useCases": [],
  "tags": [],
  "keywords": [],
  "shortDescription": "",
  "searchTerms": []
}

------------------------------------------------------------
FIELD RULES
------------------------------------------------------------

1. category

Choose ONE broad category.

Examples:

"Home & Kitchen"
"Clothing"
"Jewellery"
"Home Decor"
"Handicrafts"
"Accessories"
"Bags"
"Footwear"
"Art"
"Gifts"

Choose the category that best represents the actual product.

------------------------------------------------------------

2. subcategory

Choose a more specific category.

Examples:

"Table Cloth"
"Bangles"
"Wall Hanging"
"Wooden Utensils"
"Handwoven Saree"
"Pottery"
"Handmade Bag"

The subcategory should describe the actual product,
not merely its material.

------------------------------------------------------------

3. productType

Identify the actual item being sold.

Examples:

"Table Cloth"
"Bangles"
"Wall Hanging"
"Kitchen Utensils"
"Saree"
"Handbag"

This field is extremely important for AI-powered shopping.

Keep it concise.

------------------------------------------------------------

4. material

List the materials explicitly mentioned or clearly stated
in the title or description.

Examples:

["cotton"]
["wood"]
["silk", "thread"]
["clay"]
["terracotta"]

If the material is unknown, return:

[]

Do not guess the material.

------------------------------------------------------------

5. colour

List colours explicitly mentioned in the title or description.

Examples:

["red"]
["blue", "gold"]
["green"]

If colour is not known, return:

[]

Do not guess colours from assumptions.

------------------------------------------------------------

6. style

Describe the visual or cultural style only when supported
by the product information.

Examples:

["traditional"]
["minimalist"]
["rustic"]
["ethnic"]
["modern"]
["handwoven"]

If no style can reasonably be determined, return:

[]

Do not invent a style.

------------------------------------------------------------

7. occasion

List occasions for which the product is explicitly intended
or strongly indicated by the description.

Examples:

["wedding"]
["birthday"]
["festival"]
["housewarming"]
["daily use"]

If there is no clear occasion, return:

[]

Do not invent occasions.

------------------------------------------------------------

8. useCases

Describe practical situations where the product can be used.

Examples:

["dining table"]
["kitchen"]
["home decoration"]
["gift"]
["daily wear"]

Only include use cases supported by the product information.

------------------------------------------------------------

9. tags

Generate useful descriptive tags.

Examples:

"handmade"
"handwoven"
"traditional"
"eco-friendly"
"wooden"
"lightweight"
"decorative"
"artisan-made"

Tags should describe genuine characteristics of the product.

Do not create unrelated tags.

------------------------------------------------------------

10. keywords

Generate words and short phrases that a customer might use
when searching for this product.

For example, for a handmade cotton table cloth:

[
  "table cloth",
  "table cover",
  "cotton table cloth",
  "handmade table cloth",
  "dining table cloth"
]

Include both common product names and useful variations.

Do not add unrelated products.

------------------------------------------------------------

11. shortDescription

Write a concise, attractive description for a buyer.

Maximum 40 words.

Do not add facts that are not present in the original
product information.

------------------------------------------------------------

12. searchTerms

Generate natural phrases a customer might type when looking
for this exact type of product.

For example:

[
  "handmade table cloth",
  "cotton table cloth",
  "traditional table cloth",
  "table cover for dining table"
]

Search terms should represent the actual product.

Do not include unrelated products.

------------------------------------------------------------
IMPORTANT SEARCH RULE
------------------------------------------------------------

The metadata will be used by an AI shopping assistant.

Therefore, product identity is more important than generic
similarity.

For example:

If the product is a table cloth:

GOOD:
"table cloth"
"table cover"
"dining table cloth"
"handmade table cloth"

BAD:
"bangles"
"jewellery"
"kitchen utensils"

Do NOT add related but different products.

------------------------------------------------------------
IMPORTANT ACCURACY RULE
------------------------------------------------------------

If something is not present or cannot reasonably be determined
from the title and description, use:

[]
or

""

Do not hallucinate information.

------------------------------------------------------------
OUTPUT RULES
------------------------------------------------------------

1. Return JSON only.
2. Do not use markdown.
3. Do not add explanations.
4. Do not add comments.
5. Use exactly the requested field names.
6. Keep lists concise and relevant.
7. Avoid duplicate values.
8. Do not include unrelated products.
''';

    try {
      // =======================================================
      // SEND REQUEST TO GEMINI
      // =======================================================

      final response = await _model.generateContent([
        Content.text(prompt),
      ]);

      final responseText = response.text?.trim();

      // =======================================================
      // CHECK EMPTY RESPONSE
      // =======================================================

      if (responseText == null || responseText.isEmpty) {
        throw Exception(
          'Gemini returned an empty response.',
        );
      }

      print('========================================');
      print('GEMINI CATALOG RESPONSE');
      print(responseText);
      print('========================================');

      // =======================================================
      // CLEAN GEMINI RESPONSE
      // =======================================================

      final cleanJson = _cleanJsonResponse(
        responseText,
      );

      // =======================================================
      // PARSE JSON
      // =======================================================

      final decoded = jsonDecode(cleanJson);

      if (decoded is! Map) {
        throw Exception(
          'Gemini returned an invalid catalog format.',
        );
      }

      // =======================================================
      // NORMALIZE AI DATA
      // =======================================================

      final category =
          decoded['category']
              ?.toString()
              .trim() ??
          '';

      final subcategory =
          decoded['subcategory']
              ?.toString()
              .trim() ??
          '';

      final productType =
          decoded['productType']
              ?.toString()
              .trim() ??
          '';

      final shortDescription =
          decoded['shortDescription']
              ?.toString()
              .trim() ??
          '';

      final material =
          _convertToStringList(
        decoded['material'],
      );

      final colour =
          _convertToStringList(
        decoded['colour'],
      );

      final style =
          _convertToStringList(
        decoded['style'],
      );

      final occasion =
          _convertToStringList(
        decoded['occasion'],
      );

      final useCases =
          _convertToStringList(
        decoded['useCases'],
      );

      final tags =
          _convertToStringList(
        decoded['tags'],
      );

      final keywords =
          _convertToStringList(
        decoded['keywords'],
      );

      final searchTerms =
          _convertToStringList(
        decoded['searchTerms'],
      );

      // =======================================================
      // RETURN STRUCTURED DATA
      // =======================================================

      return {
        'category': category,
        'subcategory': subcategory,
        'productType': productType,

        'material': material,
        'colour': colour,
        'style': style,
        'occasion': occasion,
        'useCases': useCases,

        'tags': tags,
        'keywords': keywords,

        'shortDescription':
            shortDescription,

        'searchTerms': searchTerms,
      };
    } catch (e, stackTrace) {
      // =======================================================
      // DEBUG INFORMATION
      // =======================================================

      print('========================================');
      print('AI CATALOG GENERATION FAILED');
      print('ERROR: $e');
      print('STACK TRACE: $stackTrace');
      print('========================================');

      // =======================================================
      // RE-THROW ERROR
      // =======================================================

      throw Exception(
        'Unable to generate AI product information: $e',
      );
    }
  }

  // =========================================================
  // CLEAN JSON RESPONSE
  // =========================================================

  static String _cleanJsonResponse(
    String responseText,
  ) {
    String cleanJson =
        responseText.trim();

    // ---------------------------------------------------------
    // Remove ```json
    // ---------------------------------------------------------

    if (cleanJson.startsWith(
      '```json',
    )) {
      cleanJson = cleanJson
          .replaceFirst(
            '```json',
            '',
          )
          .trim();

      if (cleanJson.endsWith(
        '```',
      )) {
        cleanJson = cleanJson.substring(
          0,
          cleanJson.length - 3,
        ).trim();
      }
    }

    // ---------------------------------------------------------
    // Remove generic ```
    // ---------------------------------------------------------

    else if (cleanJson.startsWith(
      '```',
    )) {
      cleanJson = cleanJson
          .replaceFirst(
            '```',
            '',
          )
          .trim();

      if (cleanJson.endsWith(
        '```',
      )) {
        cleanJson = cleanJson.substring(
          0,
          cleanJson.length - 3,
        ).trim();
      }
    }

    return cleanJson.trim();
  }

  // =========================================================
  // CONVERT AI VALUE TO STRING LIST
  // =========================================================

  static List<String> _convertToStringList(
    dynamic value,
  ) {
    if (value is! List) {
      return <String>[];
    }

    final result = <String>[];

    for (final item in value) {
      final text =
          item.toString().trim();

      if (text.isEmpty) {
        continue;
      }

      // -------------------------------------------------------
      // Avoid duplicate values
      // -------------------------------------------------------

      if (!result.contains(text)) {
        result.add(text);
      }
    }

    return result;
  }
}