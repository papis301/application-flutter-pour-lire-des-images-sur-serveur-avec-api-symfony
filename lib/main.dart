import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(ImageGalleryApp());
}

class ImageGalleryApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Galerie Symfony',
      home: ImageGalleryScreen(),
    );
  }
}

class ImageGalleryScreen extends StatefulWidget {
  @override
  _ImageGalleryScreenState createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<ImageGalleryScreen> {
  List<String> imageUrls = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchImages();
  }

  Future<void> fetchImages() async {
    try {
      final response = await http.get(Uri.parse("http://10.55.133.71:8001/api/images"));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          imageUrls = data.map((e) => "http://10.55.133.71:8001/" + e["url"]).toList().cast<String>();
          isLoading = false;
        });
      } else {
        throw Exception("Erreur lors de la récupération des images");
      }
    } catch (e) {
      print("Erreur: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Infos Utils'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                isLoading = true;
              });
              fetchImages();
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : imageUrls.isEmpty
          ? Center(child: Text("Aucune image disponible"))
          : ListView.separated(
        itemCount: imageUrls.length,
        separatorBuilder: (context, index) => Divider(
          color: Colors.grey,
          thickness: 1,
          height: 24,
        ),
        itemBuilder: (context, index) {
          final imageUrl = imageUrls[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.network(
                imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ImageDetailScreen(imageUrl: imageUrl),
                      ),
                    );
                  },
                  child: Text("Afficher"),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ImageDetailScreen extends StatelessWidget {
  final String imageUrl;

  const ImageDetailScreen({Key? key, required this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Image")),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}