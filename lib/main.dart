import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() {
  runApp(ImageGalleryApp());
}

class ImageGalleryApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Infos Utils',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
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
  List<String> previousImageUrls = [];
  bool isLoading = true;
  Timer? _timer;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initNotifications();
    fetchImages();
    startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
    InitializationSettings(android: androidSettings);

    await flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  void startPolling() {
    _timer = Timer.periodic(Duration(seconds: 30), (timer) async {
      try {
        final response =
        await http.get(Uri.parse("http://infosutils.deydem.pro/api/images"));
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final List<String> newImageUrls = data
              .map((e) => "http://infosutils.deydem.pro" + e["url"])
              .toList()
              .cast<String>();

          if (previousImageUrls.isNotEmpty &&
              newImageUrls.length > previousImageUrls.length) {
            _showNotification("Une nouvelle image a été ajoutée !");
          }

          setState(() {
            imageUrls = newImageUrls;
            previousImageUrls = newImageUrls;
            isLoading = false;
          });
        }
      } catch (e) {
        print("Erreur polling : $e");
      }
    });
  }

  Future<void> fetchImages() async {
    try {
      final response =
      await http.get(Uri.parse("http://infosutils.deydem.pro/api/images"));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          imageUrls = data
              .map((e) => "http://infosutils.deydem.pro" + e["url"])
              .toList()
              .cast<String>();
          previousImageUrls = imageUrls;
          isLoading = false;
        });
      } else {
        throw Exception("Erreur récupération images");
      }
    } catch (e) {
      print("Erreur: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _showNotification(String message) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'nouvelle_image_channel',
      'Nouvelles Images',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails =
    NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Galerie Symfony',
      message,
      platformDetails,
    );
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
              setState(() => isLoading = true);
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
                        builder: (context) =>
                            ImageDetailScreen(imageUrl: imageUrl),
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
