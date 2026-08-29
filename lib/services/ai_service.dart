
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

Analyze the following product.

PRODUCT TITLE:
$title

PRODUCT DESCRIPTION:
$description

Generate structured catalog information that can be used for
product search, filtering, recommendations, and future AI-powered
shopping.

Return ONLY valid JSON.

Use exactly this structure:

{
  "category": "",
  "subcategory": "",
  "tags": [],
  "keywords": [],
  "shortDescription": "",
  "searchTerms": []
}

Rules:

1. category:
   Use a broad product category such as:
   "Home & Kitchen", "Clothing", "Jewellery",
   "Home Decor", "Handicrafts", etc.

2. subcategory:
   Make it more specific to the actual product.

3. tags:
   Include useful attributes and characteristics.
   Examples:
   "handmade", "wooden", "eco-friendly", "traditional",
   "kitchen", "lightweight".

4. keywords:
   Include individual words or short phrases that buyers
   might use when searching for this product.

5. shortDescription:
   Write a concise, attractive description for a buyer.
   Keep it under 40 words.

6. searchTerms:
   Include natural phrases that a customer might type
   into a search box.

7. Do not invent specific facts that are not present in the
   title or description.

8. Do not include markdown.

9. Return JSON only.
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
      print('GEMINI RESPONSE');
      print(responseText);
      print('========================================');

      // =======================================================
      // CLEAN GEMINI RESPONSE
      // =======================================================

      String cleanJson = responseText;

      // Remove ```json ... ```
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson
            .replaceFirst('```json', '')
            .trim();

        if (cleanJson.endsWith('```')) {
          cleanJson = cleanJson
              .substring(
                0,
                cleanJson.length - 3,
              )
              .trim();
        }
      }

      // Remove ``` ... ```
      else if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson
            .replaceFirst('```', '')
            .trim();

        if (cleanJson.endsWith('```')) {
          cleanJson = cleanJson
              .substring(
                0,
                cleanJson.length - 3,
              )
              .trim();
        }
      }

      // =======================================================
      // PARSE JSON
      // =======================================================

      final decoded = jsonDecode(cleanJson);

      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'Gemini returned an invalid catalog format.',
        );
      }

      // =======================================================
      // NORMALIZE AI DATA
      // =======================================================

      final category =
          decoded['category']?.toString().trim() ?? '';

      final subcategory =
          decoded['subcategory']?.toString().trim() ?? '';

      final shortDescription =
          decoded['shortDescription']?.toString().trim() ?? '';

      final tags = _convertToStringList(
        decoded['tags'],
      );

      final keywords = _convertToStringList(
        decoded['keywords'],
      );

      final searchTerms = _convertToStringList(
        decoded['searchTerms'],
      );

      // =======================================================
      // RETURN STRUCTURED DATA
      // =======================================================

      return {
        'category': category,
        'subcategory': subcategory,
        'tags': tags,
        'keywords': keywords,
        'shortDescription': shortDescription,
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
  // CONVERT AI VALUE TO STRING LIST
  // =========================================================

  static List<String> _convertToStringList(
    dynamic value,
  ) {
    if (value is! List) {
      return <String>[];
    }

    return value
        .map(
          (item) => item.toString().trim(),
        )
        .where(
          (item) => item.isNotEmpty,
        )
        .toList();
  }
}
