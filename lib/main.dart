import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:escribo_2_ebook/model/book_model.dart';
import 'package:escribo_2_ebook/repository/book_repository.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vocsy_epub_viewer/epub_viewer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<BookModel> booksList = [];
  BookRepository repository = BookRepository();
  bool firstLoading = true;
  final platform = MethodChannel('my_channel');
  bool loading = false;
  Dio dio = Dio();
  String filePath = "";

  @override
  void initState() {
    carregamentoInicial();
    super.initState();
  }

  carregamentoInicial() async {
    booksList = await repository.getBooks();
    setState(() {
      firstLoading = false;
    });
  }

  // ---------------------------------------------------------------------------

  // FROM VOCSY DOCUMENTATION:

  /// ANDROID VERSION
  Future<void> fetchAndroidVersion(String bookUrl3) async {
    final String? version = await getAndroidVersion();
    if (version != null) {
      String? firstPart;
      if (version.toString().contains(".")) {
        int indexOfFirstDot = version.indexOf(".");
        firstPart = version.substring(0, indexOfFirstDot);
      } else {
        firstPart = version;
      }
      int intValue = int.parse(firstPart);
      if (intValue >= 13) {
        await startDownload(bookUrl3);
      } else {
        final PermissionStatus status = await Permission.storage.request();
        if (status == PermissionStatus.granted) {
          await startDownload(bookUrl3);
        } else {
          await Permission.storage.request();
        }
      }
      print("ANDROID VERSION: $intValue");
    }
  }

  Future<String?> getAndroidVersion() async {
    try {
      final String version = await platform.invokeMethod('getAndroidVersion');
      return version;
    } on PlatformException catch (e) {
      print("FAILED TO GET ANDROID VERSION: ${e.message}");
      return null;
    }
  }

  download(String bookUrl1) async {
    if (Platform.isIOS) {
      final PermissionStatus status = await Permission.storage.request();
      if (status == PermissionStatus.granted) {
        await startDownload(bookUrl1);
      } else {
        await Permission.storage.request();
      }
    } else if (Platform.isAndroid) {
      await fetchAndroidVersion(bookUrl1);
    } else {
      PlatformException(code: '500');
    }
  }

  startDownload(String bookUrl2) async {
    setState(() {
      loading = true;
    });
    Directory? appDocDir = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();

    String path = appDocDir!.path + '/sample.epub';
    File file = File(path);
    await file.create();
    await dio.download(
      bookUrl2,
      path,
      deleteOnError: true,
      onReceiveProgress: (receivedBytes, totalBytes) {
        print('Download --- ${(receivedBytes / totalBytes) * 100}');
        setState(() {
          loading = true;
        });
      },
    ).whenComplete(() {
      setState(() {
        loading = false;
        filePath = path;
      });
    });
  }

  // END OF VOCSY DOCUMENTATION

  // ---------------------------------------------------------------------------

  showEbook(String bookUrl4) async {
    print("=====filePath======$filePath");
    await download(bookUrl4);
    VocsyEpub.setConfig(
      themeColor: Theme.of(context).primaryColor,
      identifier: "iosBook",
      scrollDirection: EpubScrollDirection.ALLDIRECTIONS,
      allowSharing: true,
      enableTts: true,
      nightMode: true,
    );

    // get current locator
    VocsyEpub.locatorStream.listen((locator) {
      print('LOCATOR: $locator');
    });

    setState(() {
      VocsyEpub.open(filePath);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Ebook Reader"),
      ),
      body: firstLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: booksList.length,
                    itemBuilder: (context, index) {
                      return Column(
                        children: [
                          InkWell(
                            onTap: () async {
                              var snackBar = SnackBar(
                                content: Text(
                                    "Estamos obtendo os dados da API, aguarde... Abrindo: ${booksList[index].title}"),
                                duration: const Duration(seconds: 5),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);

                              // Executando a lib VocsyEpub:
                              await showEbook(booksList[index].downloadUrl);
                              setState(() {});
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 20, horizontal: 20),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 25, horizontal: 10),
                              decoration: BoxDecoration(
                                  color: Colors.blue[200],
                                  borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                children: [
                                  Image.network(
                                    booksList[index].coverUrl,
                                    height: 250,
                                    width: 250,
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    "Título: ${booksList[index].title}",
                                    textAlign: TextAlign.justify,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  Text("Autor: ${booksList[index].author}",
                                      textAlign: TextAlign.justify,
                                      style: const TextStyle(fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
