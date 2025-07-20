import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ✅ for compression

class SellerDashboard extends StatefulWidget {
  @override
  _SellerDashboardState createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  File? _image;
  bool _isLoading = false;

  final String cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME']!;
  final String uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET']!;

  // ✅ Pick and compress image
  Future<void> _pickImage() async {
    final pickedImage = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      final originalFile = File(pickedImage.path);
      final bytes = await originalFile.readAsBytes();
      final decodedImage = img.decodeImage(bytes);

      if (decodedImage != null) {
        // Resize to 800px width, maintaining aspect ratio
        final resized = img.copyResize(decodedImage, width: 800);

        // Compress to JPG with quality 70
        final compressedBytes = img.encodeJpg(resized, quality: 70);

        // Save to temporary file
        final tempDir = Directory.systemTemp;
        final compressedFile = await File('${tempDir.path}/compressed_image.jpg')
            .writeAsBytes(compressedBytes);

        setState(() {
          _image = compressedFile;
        });
      }
    }
  }

  Future<String?> _uploadToCloudinary(File imageFile) async {
    final url = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();

    final resString = await response.stream.bytesToString();
    print("Cloudinary response: $resString");

    if (response.statusCode == 200) {
      final data = jsonDecode(resString);
      return data['secure_url'];
    } else {
      print("Cloudinary upload failed: ${response.statusCode}");
      return null;
    }
  }

  Future<void> _uploadProduct() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final price = _priceController.text.trim();

    if (_image == null || title.isEmpty || description.isEmpty || price.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all fields and pick an image")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final imageUrl = await _uploadToCloudinary(_image!);
      if (imageUrl == null) {
        throw Exception("Image upload failed");
      }

      await FirebaseFirestore.instance.collection('products').add({
        'title': title,
        'description': description,
        'price': price,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _titleController.clear();
      _descriptionController.clear();
      _priceController.clear();
      setState(() {
        _image = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Product uploaded successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Seller Dashboard"),
        backgroundColor: const Color.fromARGB(255, 228, 128, 47),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: "Product Title"),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(labelText: "Description"),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "Price"),
            ),
            SizedBox(height: 20),
            _image != null
                ? Image.file(_image!, height: 200)
                : Text("No image selected"),
            TextButton.icon(
              icon: Icon(Icons.image),
              label: Text("Pick Image"),
              onPressed: _pickImage,
            ),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton.icon(
                    icon: Icon(Icons.upload),
                    label: Text("Upload Product"),
                    onPressed: _uploadProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  )
          ],
        ),
      ),
    );
  }
}
