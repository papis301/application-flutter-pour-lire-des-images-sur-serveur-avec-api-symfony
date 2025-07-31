import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:package_info_plus/package_info_plus.dart';


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
    initConnexion();
    checkForUpdate(context);
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

  Future<void> initConnexion() async {
    final userId = await getAnonymousUserId();

    try {
      await http.post(
        Uri.parse('http://infosutils.deydem.pro/api/log-connexion'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user': userId}),
      );
    } catch (e) {
      print('Erreur connexion: $e');
    }
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
              .reversed
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
              .reversed
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
          IconButton(
            icon: Icon(Icons.system_update),
            tooltip: "Versions APK",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ApkListScreen()),
              );
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

  Future<String> getAnonymousUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('anonymous_user_id');

    if (userId == null) {
      userId = const Uuid().v4(); // génère un UUID unique
      await prefs.setString('anonymous_user_id', userId);
    }

    return userId;
  }

  Future<void> checkForUpdate(BuildContext context) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    try {
      // Tu peux héberger ce fichier version.json côté Symfony ou sur un serveur
      final response = await http.get(Uri.parse('http://infosutils.deydem.pro/version.json'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestVersion = data['latest'];

        if (currentVersion != latestVersion) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text("Mise à jour disponible"),
              content: Text("Une nouvelle version est disponible. Voulez-vous la télécharger ?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text("Plus tard"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    launchUrl(Uri.parse(data['download_url'])); // lien vers le APK ou le Play Store
                  },
                  child: Text("Mettre à jour"),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print("Erreur lors de la vérification de version : $e");
    }
  }

  Future<void> fetchAllApkFiles() async {
    final response = await http.get(Uri.parse('http://infosutils.deydem.pro/api/apks'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final apks = data['apks'] as List;

      for (var apk in apks) {
        debugPrint('APK: ${apk['version']} => ${apk['url']}');
      }
    } else {
      debugPrint('Erreur lors de la récupération des fichiers APK');
    }
  }

}

class ApkListScreen extends StatefulWidget {
  const ApkListScreen({super.key});

  @override
  State<ApkListScreen> createState() => _ApkListScreenState();
}

class _ApkListScreenState extends State<ApkListScreen> {
  List<Map<String, dynamic>> apkFiles = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchApkFiles();
  }

  Future<void> fetchApkFiles() async {
    try {
      final response = await http.get(Uri.parse('http://infosutils.deydem.pro/api/apks'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> files = data['apks'];
        files.sort((a, b) => b['version'].compareTo(a['version'])); // ordre décroissant

        setState(() {
          apkFiles = files.cast<Map<String, dynamic>>();
          isLoading = false;
        });
      } else {
        throw Exception('Erreur serveur');
      }
    } catch (e) {
      print("Erreur API APKs : $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> downloadApk(String url) async {
    final fullUrl = 'http://infosutils.deydem.pro$url';
    if (await canLaunchUrl(Uri.parse(fullUrl))) {
      await launchUrl(Uri.parse(fullUrl), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lien de téléchargement non valide")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Versions disponibles")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
        itemCount: apkFiles.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final apk = apkFiles[index];
          return ListTile(
            title: Text("Version ${apk['version']}"),
            subtitle: Text(apk['filename']),
            trailing: ElevatedButton(
              onPressed: () => downloadApk(apk['url']),
              child: const Text("Télécharger"),
            ),
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





