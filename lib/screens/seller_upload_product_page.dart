import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_dotenv/flutter_dotenv.dart';

//import 'package:ai_service.dart';
//import 'package:/services/ai_service.dart';
import '../services/ai_service.dart';
class SellerUploadProductPage extends StatefulWidget {
  const SellerUploadProductPage({super.key});

  @override
  State<SellerUploadProductPage> createState() =>
      _SellerUploadProductPageState();
}

class _SellerUploadProductPageState
    extends State<SellerUploadProductPage> {

  // =========================================================
  // SELLER THEME
  // =========================================================

  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color primaryDark = Color(0xFF3730A3);
  static const Color accentColor = Color(0xFF7C3AED);

  static const Color backgroundColor = Color(0xFFF6F7FB);
  static const Color cardColor = Colors.white;

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  static const Color borderColor = Color(0xFFE5E7EB);

  // =========================================================
  // TEXT CONTROLLERS
  // =========================================================

  final TextEditingController _titleController =
      TextEditingController();

  final TextEditingController _descriptionController =
      TextEditingController();

  final TextEditingController _priceController =
      TextEditingController();

  // =========================================================
  // IMAGE
  // =========================================================

  File? _image;

  // =========================================================
  // LOADING
  // =========================================================

  bool _isLoading = false;

  // =========================================================
  // CLOUDINARY
  // =========================================================

  final String cloudName =
      dotenv.env['CLOUDINARY_CLOUD_NAME']!;

  final String uploadPreset =
      dotenv.env['CLOUDINARY_UPLOAD_PRESET']!;

  // =========================================================
  // INIT STATE
  // =========================================================

  @override
  void initState() {
    super.initState();
  }

  // =========================================================
  // PICK IMAGE
  // =========================================================

  Future<void> _pickImage() async {
    if (_isLoading) return;

    try {
      final pickedImage =
          await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );

      if (pickedImage == null) {
        return;
      }

      final originalFile =
          File(pickedImage.path);

      final bytes =
          await originalFile.readAsBytes();

      final decodedImage =
          img.decodeImage(bytes);

      if (decodedImage == null) {
        if (!mounted) return;

        _showMessage(
          "Unable to process selected image.",
          isError: true,
        );

        return;
      }

      // -------------------------------------------------------
      // Resize image
      // -------------------------------------------------------

      final resized =
          img.copyResize(
        decodedImage,
        width: 1000,
      );

      // -------------------------------------------------------
      // Compress image
      // -------------------------------------------------------

      final compressedBytes =
          img.encodeJpg(
        resized,
        quality: 78,
      );

      // -------------------------------------------------------
      // Save temporary image
      // -------------------------------------------------------

      final tempDir =
          Directory.systemTemp;

      final compressedFile =
          await File(
        '${tempDir.path}/seller_product_image.jpg',
      ).writeAsBytes(
        compressedBytes,
      );

      if (!mounted) return;

      setState(() {
        _image = compressedFile;
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        "Image selection failed.",
        isError: true,
      );

      debugPrint(
        "Image selection error: $e",
      );
    }
  }

  // =========================================================
  // UPLOAD IMAGE TO CLOUDINARY
  // =========================================================

  Future<String?> _uploadToCloudinary(
    File imageFile,
  ) async {
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final request =
        http.MultipartRequest(
      'POST',
      url,
    );

    request.fields['upload_preset'] =
        uploadPreset;

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
      ),
    );

    final response =
        await request.send();

    final responseString =
        await response.stream.bytesToString();

    debugPrint(
      "Cloudinary response: $responseString",
    );

    if (response.statusCode == 200) {
      final data =
          jsonDecode(responseString);

      return data['secure_url'];
    }

    debugPrint(
      "Cloudinary upload failed: "
      "${response.statusCode}",
    );

    return null;
  }

  // =========================================================
  // PROCESS PRODUCT WITH AI
  // =========================================================
  //
  // Gemini logic is NOT written here anymore.
  //
  // This page simply calls AIService.
  // =========================================================

  Future<void> _processProductWithAI(
    String productId, {
    required String title,
    required String description,
  }) async {

    try {
      // -------------------------------------------------------
      // CALL AI SERVICE
      // -------------------------------------------------------

      final aiData =
          await AIService.generateProductCatalogData(
        title: title,
        description: description,
      );

      // -------------------------------------------------------
      // SAVE AI DATA TO FIRESTORE
      // -------------------------------------------------------

      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .update({
        'category':
            aiData['category'] ?? '',

        'subcategory':
            aiData['subcategory'] ?? '',

        'tags':
            aiData['tags'] ?? [],

        'keywords':
            aiData['keywords'] ?? [],

        'shortDescription':
            aiData['shortDescription'] ?? '',

        'searchTerms':
            aiData['searchTerms'] ?? [],

        'aiProcessed':
            true,

        'aiProcessingError':
            false,

        'aiProcessedAt':
            FieldValue.serverTimestamp(),
      });

      debugPrint(
        "AI catalog data saved for product: $productId",
      );

    } catch (e) {
      // -------------------------------------------------------
      // AI FAILED
      //
      // Product remains published.
      // -------------------------------------------------------

      debugPrint(
        "AI processing failed: $e",
      );

      try {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .update({
          'aiProcessed': false,
          'aiProcessingError': true,
        });
      } catch (firestoreError) {
        debugPrint(
          "Failed to update AI error status: "
          "$firestoreError",
        );
      }
    }
  }

  // =========================================================
  // UPLOAD PRODUCT
  // =========================================================

  Future<void> _uploadProduct() async {

    final title =
        _titleController.text.trim();

    final description =
        _descriptionController.text.trim();

    final price =
        _priceController.text.trim();

    // =======================================================
    // VALIDATION
    // =======================================================

    if (_image == null ||
        title.isEmpty ||
        description.isEmpty ||
        price.isEmpty) {

      _showMessage(
        "Please complete all fields and add a product image.",
        isError: true,
      );

      return;
    }

    // =======================================================
    // VALIDATE PRICE
    // =======================================================

    final parsedPrice =
        double.tryParse(price);

    if (parsedPrice == null ||
        parsedPrice <= 0) {

      _showMessage(
        "Please enter a valid product price.",
        isError: true,
      );

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {

      // =====================================================
      // 1. CURRENT SELLER
      // =====================================================

      final User? currentUser =
          FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw Exception(
          "No seller is currently logged in.",
        );
      }

      final String sellerId =
          currentUser.uid;

      // =====================================================
      // 2. GET SELLER DOCUMENT
      // =====================================================

      final sellerDoc =
          await FirebaseFirestore.instance
              .collection('sellers')
              .doc(sellerId)
              .get();

      if (!sellerDoc.exists) {
        throw Exception(
          "Seller profile not found.",
        );
      }

      final sellerData =
          sellerDoc.data();

      // =====================================================
      // 3. SELLER INFORMATION
      // =====================================================

      final String sellerName =
          sellerData?['shopName']
                  ?.toString()
                  .trim()
              ?? "Unknown Seller";

      final String sellerCategory =
          sellerData?['category']
                  ?.toString()
                  .trim()
              ?? "";

      // =====================================================
      // 4. UPLOAD IMAGE
      // =====================================================

      final imageUrl =
          await _uploadToCloudinary(
        _image!,
      );

      if (imageUrl == null ||
          imageUrl.isEmpty) {

        throw Exception(
          "Image upload failed.",
        );
      }

      // =====================================================
      // 5. CREATE PRODUCT
      // =====================================================

      final productRef =
          await FirebaseFirestore.instance
              .collection('products')
              .add({

        // ---------------------------------------------------
        // BASIC PRODUCT INFORMATION
        // ---------------------------------------------------

        'title':
            title,

        'description':
            description,

        'price':
            price,

        'imageUrl':
            imageUrl,

        // ---------------------------------------------------
        // SELLER INFORMATION
        // ---------------------------------------------------

        'sellerId':
            sellerId,

        'sellerName':
            sellerName,

        'sellerCategory':
            sellerCategory,

        // ---------------------------------------------------
        // AI-READY PRODUCT INFORMATION
        // ---------------------------------------------------
        //
        // These fields are initially empty.
        //
        // AIService will populate them after the
        // product is created.
        // ---------------------------------------------------

        'category':
            sellerCategory,

        'subcategory':
            '',

        'tags':
            [],

        'keywords':
            [],

        'shortDescription':
            '',

        'searchTerms':
            [],

        'aiProcessed':
            false,

        'aiProcessingError':
            false,

        // ---------------------------------------------------
        // PRODUCT STATUS
        // ---------------------------------------------------

        'isAvailable':
            true,

        'timestamp':
            FieldValue.serverTimestamp(),
      });

      // =====================================================
      // 6. SAVE PRODUCT ID
      // =====================================================

      await productRef.update({
        'productId':
            productRef.id,
      });

      // =====================================================
      // 7. PROCESS PRODUCT WITH AI
      // =====================================================
      //
      // The product is already saved successfully.
      //
      // Now AIService sends the title and description
      // to Gemini and returns structured catalog data.
      //
      // If Gemini fails, the product remains published.
      // =====================================================

      await _processProductWithAI(
        productRef.id,
        title: title,
        description: description,
      );

      // =====================================================
      // 8. CLEAR FORM
      // =====================================================

      _titleController.clear();
      _descriptionController.clear();
      _priceController.clear();

      if (mounted) {
        setState(() {
          _image = null;
        });
      }

      // =====================================================
      // 9. SUCCESS
      // =====================================================

      if (!mounted) return;

      _showMessage(
        "Product published successfully!",
      );

    } catch (e) {

      debugPrint(
        "Product upload error: $e",
      );

      if (!mounted) return;

      _showMessage(
        "Upload failed. Please try again.",
        isError: true,
      );

    } finally {

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  // =========================================================
  // MESSAGE
  // =========================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [

            Icon(
              isError
                  ? Icons.error_outline
                  : Icons.check_circle_outline,
              color: Colors.white,
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight:
                      FontWeight.w500,
                ),
              ),
            ),
          ],
        ),

        behavior:
            SnackBarBehavior.floating,

        margin:
            const EdgeInsets.all(16),

        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(14),
        ),

        backgroundColor:
            isError
                ? const Color(0xFFDC2626)
                : const Color(0xFF059669),
      ),
    );
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {

    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();

    super.dispose();
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {

    return Container(
      color: backgroundColor,

      child: SingleChildScrollView(
        physics:
            const BouncingScrollPhysics(),

        padding:
            const EdgeInsets.fromLTRB(
          18,
          18,
          18,
          32,
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            _buildIntro(),

            const SizedBox(height: 22),

            _buildImageSection(),

            const SizedBox(height: 22),

            _buildProductDetailsCard(),

            const SizedBox(height: 22),

            _buildUploadButton(),

            const SizedBox(height: 12),

            Center(
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,

                children: [

                  const Icon(
                    Icons.lock_outline,
                    size: 13,
                    color: textMuted,
                  ),

                  const SizedBox(width: 5),

                  const Text(
                    "Your product information is securely saved.",
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // INTRO
  // =========================================================

  Widget _buildIntro() {

    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 16,
      ),

      decoration:
          BoxDecoration(
        gradient:
            LinearGradient(
          colors: [
            primaryColor.withOpacity(0.08),
            accentColor.withOpacity(0.04),
          ],
          begin:
              Alignment.centerLeft,
          end:
              Alignment.centerRight,
        ),

        borderRadius:
            BorderRadius.circular(18),

        border:
            Border.all(
          color:
              primaryColor.withOpacity(0.10),
        ),
      ),

      child: Row(
        children: [

          Container(
            width: 44,
            height: 44,

            decoration:
                BoxDecoration(
              gradient:
                  const LinearGradient(
                colors: [
                  primaryColor,
                  accentColor,
                ],
              ),

              borderRadius:
                  BorderRadius.circular(13),

              boxShadow: [
                BoxShadow(
                  color:
                      primaryColor
                          .withOpacity(0.18),
                  blurRadius: 12,
                  offset:
                      const Offset(0, 5),
                ),
              ],
            ),

            child: const Icon(
              Icons.inventory_2_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),

          const SizedBox(width: 13),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Text(
                  "Create a new listing",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        textPrimary,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  "Add your product details and publish it to your shop.",
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // IMAGE SECTION
  // =========================================================

  Widget _buildImageSection() {

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        _buildSectionTitle(
          "Product Image",
          "Use a clear, well-lit image of your product.",
          Icons.image_outlined,
        ),

        const SizedBox(height: 12),

        GestureDetector(
          onTap:
              _isLoading
                  ? null
                  : _pickImage,

          child: AnimatedContainer(
            duration:
                const Duration(
              milliseconds: 250,
            ),

            width: double.infinity,
            height: 245,

            decoration:
                BoxDecoration(
              color: cardColor,

              borderRadius:
                  BorderRadius.circular(20),

              border:
                  Border.all(
                color:
                    _image != null
                        ? primaryColor
                        : borderColor,

                width:
                    _image != null
                        ? 1.5
                        : 1,
              ),

              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black
                          .withOpacity(0.035),
                  blurRadius: 22,
                  offset:
                      const Offset(0, 8),
                ),
              ],
            ),

            child:
                _image != null
                    ? _buildSelectedImage()
                    : _buildImagePlaceholder(),
          ),
        ),

        const SizedBox(height: 11),

        SizedBox(
          width: double.infinity,

          child: OutlinedButton.icon(
            onPressed:
                _isLoading
                    ? null
                    : _pickImage,

            icon: const Icon(
              Icons.photo_library_outlined,
              size: 18,
            ),

            label: Text(
              _image == null
                  ? "Choose Image"
                  : "Change Image",
            ),

            style:
                OutlinedButton.styleFrom(
              foregroundColor:
                  primaryColor,

              backgroundColor:
                  Colors.white,

              side:
                  BorderSide(
                color:
                    primaryColor
                        .withOpacity(0.25),
              ),

              padding:
                  const EdgeInsets.symmetric(
                vertical: 13,
              ),

              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(13),
              ),

              textStyle:
                  const TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // SELECTED IMAGE
  // =========================================================

  Widget _buildSelectedImage() {

    return Stack(
      fit: StackFit.expand,

      children: [

        ClipRRect(
          borderRadius:
              BorderRadius.circular(19),

          child: Image.file(
            _image!,
            fit: BoxFit.cover,
          ),
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 80,

          child: Container(
            decoration:
                BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(
                bottom:
                    Radius.circular(19),
              ),

              gradient:
                  LinearGradient(
                begin:
                    Alignment.topCenter,
                end:
                    Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black
                      .withOpacity(0.65),
                ],
              ),
            ),
          ),
        ),

        Positioned(
          left: 12,
          bottom: 12,

          child: Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),

            decoration:
                BoxDecoration(
              color:
                  Colors.black
                      .withOpacity(0.55),

              borderRadius:
                  BorderRadius.circular(10),
            ),

            child: const Row(
              mainAxisSize:
                  MainAxisSize.min,

              children: [

                Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 16,
                ),

                SizedBox(width: 6),

                Text(
                  "Image selected",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        Positioned(
          right: 12,
          top: 12,

          child: Material(
            color: Colors.white,
            shape:
                const CircleBorder(),

            elevation: 3,

            child: InkWell(
              customBorder:
                  const CircleBorder(),

              onTap:
                  _isLoading
                      ? null
                      : _pickImage,

              child: const SizedBox(
                width: 40,
                height: 40,

                child: Icon(
                  Icons.edit_outlined,
                  color:
                      primaryColor,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // IMAGE PLACEHOLDER
  // =========================================================

  Widget _buildImagePlaceholder() {

    return Column(
      mainAxisAlignment:
          MainAxisAlignment.center,

      children: [

        Container(
          width: 68,
          height: 68,

          decoration:
              BoxDecoration(
            gradient:
                LinearGradient(
              colors: [
                primaryColor.withOpacity(0.10),
                accentColor.withOpacity(0.08),
              ],
            ),

            borderRadius:
                BorderRadius.circular(19),
          ),

          child: const Icon(
            Icons.cloud_upload_outlined,
            size: 32,
            color:
                primaryColor,
          ),
        ),

        const SizedBox(height: 15),

        const Text(
          "Upload product image",
          style: TextStyle(
            fontSize: 16,
            fontWeight:
                FontWeight.w700,
            color:
                textPrimary,
          ),
        ),

        const SizedBox(height: 5),

        const Text(
          "Tap anywhere here to choose an image",
          style: TextStyle(
            fontSize: 12,
            color:
                textSecondary,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          "JPG or PNG  •  Recommended 1000px",
          style: TextStyle(
            fontSize: 10,
            color:
                textMuted,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // PRODUCT DETAILS CARD
  // =========================================================

  Widget _buildProductDetailsCard() {

    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(18),

      decoration:
          BoxDecoration(
        color:
            cardColor,

        borderRadius:
            BorderRadius.circular(20),

        border:
            Border.all(
          color:
              borderColor,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black
                    .withOpacity(0.035),
            blurRadius: 22,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          _buildSectionTitle(
            "Product Details",
            "Information customers will see in your shop.",
            Icons.description_outlined,
          ),

          const SizedBox(height: 22),

          _buildFieldLabel(
            "Product Title",
            required: true,
          ),

          const SizedBox(height: 8),

          _buildTextField(
            controller:
                _titleController,

            hintText:
                "e.g. Premium Cotton Shirt",

            prefixIcon:
                Icons.inventory_2_outlined,

            enabled:
                !_isLoading,
          ),

          const SizedBox(height: 19),

          _buildFieldLabel(
            "Description",
            required: true,
          ),

          const SizedBox(height: 8),

          _buildTextField(
            controller:
                _descriptionController,

            hintText:
                "Describe your product, features and details...",

            enabled:
                !_isLoading,

            maxLines: 5,
          ),

          const SizedBox(height: 19),

          _buildFieldLabel(
            "Price",
            required: true,
          ),

          const SizedBox(height: 8),

          _buildPriceField(),
        ],
      ),
    );
  }

  // =========================================================
  // SECTION TITLE
  // =========================================================

  Widget _buildSectionTitle(
    String title,
    String subtitle,
    IconData icon,
  ) {

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        Container(
          width: 38,
          height: 38,

          decoration:
              BoxDecoration(
            color:
                primaryColor
                    .withOpacity(0.08),

            borderRadius:
                BorderRadius.circular(11),
          ),

          child: Icon(
            icon,
            size: 19,
            color:
                primaryColor,
          ),
        ),

        const SizedBox(width: 11),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              Text(
                title,
                style:
                    const TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w700,
                  color:
                      textPrimary,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitle,
                style:
                    const TextStyle(
                  fontSize: 11,
                  color:
                      textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================
  // FIELD LABEL
  // =========================================================

  Widget _buildFieldLabel(
    String label, {
    bool required = false,
  }) {

    return Row(
      children: [

        Text(
          label,
          style:
              const TextStyle(
            fontSize: 13,
            fontWeight:
                FontWeight.w700,
            color:
                textPrimary,
          ),
        ),

        if (required) ...[
          const SizedBox(width: 3),

          const Text(
            "*",
            style: TextStyle(
              color:
                  Color(0xFFEF4444),
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  // =========================================================
  // TEXT FIELD
  // =========================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    IconData? prefixIcon,
    required bool enabled,
    int maxLines = 1,
  }) {

    return TextField(
      controller:
          controller,

      enabled:
          enabled,

      maxLines:
          maxLines,

      textCapitalization:
          TextCapitalization.sentences,

      style:
          const TextStyle(
        fontSize: 14,
        color:
            textPrimary,
        fontWeight:
            FontWeight.w500,
      ),

      decoration:
          InputDecoration(
        hintText:
            hintText,

        hintStyle:
            const TextStyle(
          color:
              textMuted,
          fontSize: 13,
          fontWeight:
              FontWeight.w400,
        ),

        prefixIcon:
            prefixIcon != null
                ? Icon(
                    prefixIcon,
                    size: 19,
                    color:
                        textSecondary,
                  )
                : null,

        filled:
            true,

        fillColor:
            const Color(0xFFF9FAFB),

        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(13),

          borderSide:
              const BorderSide(
            color:
                borderColor,
          ),
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(13),

          borderSide:
              const BorderSide(
            color:
                borderColor,
          ),
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(13),

          borderSide:
              const BorderSide(
            color:
                primaryColor,
            width: 1.5,
          ),
        ),

        disabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(13),

          borderSide:
              const BorderSide(
            color:
                borderColor,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // PRICE FIELD
  // =========================================================

  Widget _buildPriceField() {

    return TextField(
      controller:
          _priceController,

      enabled:
          !_isLoading,

      keyboardType:
          const TextInputType.numberWithOptions(
        decimal: true,
      ),

      style:
          const TextStyle(
        fontSize: 15,
        color:
            textPrimary,
        fontWeight:
            FontWeight.w600,
      ),

      decoration:
          InputDecoration(
        hintText:
            "Enter product price",

        hintStyle:
            const TextStyle(
          color:
              textMuted,
          fontSize: 13,
          fontWeight:
              FontWeight.w400,
        ),

        prefixIcon:
            const Icon(
          Icons.currency_rupee,
          size: 19,
          color:
              primaryColor,
        ),

        suffixText:
            "INR",

        suffixStyle:
            const TextStyle(
          color:
              textSecondary,
          fontSize: 11,
          fontWeight:
              FontWeight.w600,
        ),

        filled:
            true,

        fillColor:
            const Color(0xFFF9FAFB),

        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(13),

          borderSide:
              const BorderSide(
            color:
                borderColor,
          ),
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(13),

          borderSide:
              const BorderSide(
            color:
                borderColor,
          ),
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(13),

          borderSide:
              const BorderSide(
            color:
                primaryColor,
            width: 1.5,
          ),
        ),

        disabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(13),

          borderSide:
              const BorderSide(
            color:
                borderColor,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // UPLOAD BUTTON
  // =========================================================

  Widget _buildUploadButton() {

    return SizedBox(
      width: double.infinity,
      height: 56,

      child: DecoratedBox(
        decoration:
            BoxDecoration(
          gradient:
              const LinearGradient(
            colors: [
              primaryColor,
              accentColor,
            ],

            begin:
                Alignment.centerLeft,

            end:
                Alignment.centerRight,
          ),

          borderRadius:
              BorderRadius.circular(15),

          boxShadow: [
            BoxShadow(
              color:
                  primaryColor
                      .withOpacity(0.22),

              blurRadius: 18,

              offset:
                  const Offset(0, 7),
            ),
          ],
        ),

        child: ElevatedButton(
          onPressed:
              _isLoading
                  ? null
                  : _uploadProduct,

          style:
              ElevatedButton.styleFrom(
            backgroundColor:
                Colors.transparent,

            disabledBackgroundColor:
                Colors.transparent,

            shadowColor:
                Colors.transparent,

            foregroundColor:
                Colors.white,

            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(15),
            ),
          ),

          child:
              _isLoading
                  ? const Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,

                      children: [

                        SizedBox(
                          width: 21,
                          height: 21,

                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color:
                                Colors.white,
                          ),
                        ),

                        SizedBox(width: 12),

                        Text(
                          "Publishing product...",
                          style:
                              TextStyle(
                            fontSize: 14,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ],
                    )

                  : const Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,

                      children: [

                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 21,
                        ),

                        SizedBox(width: 9),

                        Text(
                          "Publish Product",
                          style:
                              TextStyle(
                            fontSize: 15,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}