import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart'; // needed for MimeType declarations
import 'package:open_file/open_file.dart';

import '../../client/client.dart';

class UploadScreen extends StatefulWidget {
  final String url;
  final String name;
  final String status;
  const UploadScreen({super.key, required this.url, required this.name, required this.status});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  late Future _future;
  final ValueNotifier<int> _addedFiles = ValueNotifier(0); // Could also use a stream

  final List<MultipartFile> _multipartFiles = [];
  final List<ListTile> _fileWidgets = [];

  @override
  void initState() {
    _future = client.getUploadInfo(widget.url);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          print(snapshot.data["own_files"]);
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.name),
            ),
            floatingActionButton: ValueListenableBuilder(
              valueListenable: _addedFiles,
              builder: (_, value, __) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (value != 0) ...[
                      Column(
                        children: [
                          FloatingActionButton(
                            onPressed: () async {
                              await client.uploadFile(
                                course: snapshot.data["course_id"],
                                entry: snapshot.data["entry_id"],
                                upload: snapshot.data["upload_id"],
                                file1: _multipartFiles[0],
                                file2: _multipartFiles.elementAtOrNull(1),
                                file3: _multipartFiles.elementAtOrNull(2),
                                file4: _multipartFiles.elementAtOrNull(3),
                                file5: _multipartFiles.elementAtOrNull(4),
                              );
                            },
                            child: const Icon(Icons.upload),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                        ],
                      ),
                    ],
                    if (value < 5 && snapshot.data["course_id"] != null) ...[
                      FloatingActionButton(
                        onPressed: () async {
                          FilePickerResult? file = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: snapshot.data["allowed_file_types"],
                          );

                          final PlatformFile firstFile = file!.files.first;

                          if (!snapshot.data["allowed_file_types"].contains(firstFile.extension?.toUpperCase())) {
                            return;
                          }

                          num maxFileSize = num.parse(snapshot.data["max_file_size"].replaceAll("MB", "").replaceAll(",", ".")) * 1000000;

                          if (firstFile.size > maxFileSize) {
                            return;
                          }

                          // Only check for filename like Lanis.
                          for (final element in _multipartFiles) {
                            if (element.filename == firstFile.name) {
                              return;
                            }
                          }

                          // firstFile.extension only returns characters after the dot of the file name, not the MimeType
                          final String? mimeType = lookupMimeType(firstFile.path!);

                          if (mimeType == null) {
                            return;
                          }

                          // MultipartFile doesn't accept a String, only MediaType
                          final MediaType parsedMimeType = MediaType.parse(mimeType);

                          final MultipartFile multipartFile = await MultipartFile.fromFile(
                              firstFile.path!,
                              filename: firstFile.name,
                              contentType: parsedMimeType
                          );

                          _multipartFiles.add(multipartFile);
                          _fileWidgets.add(
                              ListTile(
                                title: Text(firstFile.name),
                                trailing: const Icon(Icons.remove),
                                onTap: () {
                                  // We need to calculate the index dynamically because you can remove every tile at any index.
                                  // Maybe there is a better way.
                                  int tileIndex = _fileWidgets.indexWhere((ListTile element) {
                                      final Text textWidget = element.title as Text;
                                      final String text = textWidget.data!;

                                      return text == firstFile.name;
                                  });
                                  _fileWidgets.removeAt(tileIndex);
                                  _multipartFiles.removeAt(tileIndex);
                                  _addedFiles.value -= 1;
                                },
                              ));
                          _addedFiles.value += 1;
                        },
                        child: const Icon(Icons.add),
                      ),
                    ]
                  ],
                );
              }
            ),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ListTile(
                    title: Text("Ab ${snapshot.data["start"]}"),
                    leading: const Icon(Icons.hourglass_top),
                  ),
                  ListTile(
                    title: Text("Bis ${snapshot.data["deadline"]}"),
                    leading: const Icon(Icons.hourglass_bottom),
                  ),
                  ListTile(
                    title: Text("Hochladen mehrerer Dateien ${snapshot.data["upload_multiple_files"] ? 'möglich' : 'nicht möglich'}"),
                    leading: snapshot.data["upload_multiple_files"] ? const Icon(Icons.file_upload) : const Icon(Icons.file_upload_off),
                  ),
                  ListTile(
                    title: Text("Beliebig häufig hochladen ${snapshot.data["upload_any_number_of_times"] ? 'möglich' : 'nicht möglich'}"),
                    leading: snapshot.data["upload_any_number_of_times"] ? const Icon(Icons.file_upload) : const Icon(Icons.file_upload_off),
                  ),
                  ListTile(
                    title: Text("Dateien sichtbar für ${snapshot.data["visibility"]}"),
                    leading: const Icon(Icons.visibility),
                  ),
                  ListTile(
                    title: Text("Automatische Löschung am ${snapshot.data["automatic_deletion"]}"),
                    leading: const Icon(Icons.delete_forever),
                  ),
                  ListTile(
                    title: Text("Erlaubte Dateitypen: ${snapshot.data["allowed_file_types"].toString().substring(1, snapshot.data["allowed_file_types"].toString().length - 1)}"),
                    leading: const Icon(Icons.description),
                  ),
                  ListTile(
                    title: Text("Maximale Dateigröße: ${snapshot.data["max_file_size"]}"),
                    leading: const Icon(Icons.description),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: snapshot.data["own_files"].length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(snapshot.data["own_files"][index].name),
                        subtitle: snapshot.data["own_files"][index].comment != null ? Text(snapshot.data["own_files"][index].comment) : null,
                        trailing: IconButton(
                            onPressed: () async {
                              final TextEditingController passwordController = TextEditingController();

                              showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text("Gebe dein Passwort ein"),
                                      content: TextField(
                                        obscureText: true,
                                        enableSuggestions: false,
                                        autocorrect: false,
                                        controller: passwordController,
                                      ),
                                      actions: [
                                        ElevatedButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text("Zurück")
                                        ),
                                        ElevatedButton(
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              await client.deleteUploadedFile(
                                                course: snapshot.data["course_id"],
                                                entry: snapshot.data["entry_id"],
                                                upload: snapshot.data["upload_id"],
                                                file: snapshot.data["own_files"][index].index,
                                                userPasswordEncrypted: client.cryptor.encryptString(passwordController.text),
                                              );
                                            },
                                            child: const Text("Löschen")
                                        ),
                                      ],
                                    );
                                  }
                              );
                            },
                            icon: const Icon(Icons.delete)
                        ),
                        onTap: () {
                          showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (BuildContext context) {
                                return const AlertDialog(
                                  title: Text("Download..."),
                                  content: Center(
                                    heightFactor: 1.1,
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              });
                          client.downloadFile(snapshot.data["own_files"][index].url, snapshot.data["own_files"][index].name).then((filepath) {
                            Navigator.of(context).pop();

                            if (filepath == "") {
                              showDialog(context: context, builder: (context) => AlertDialog(
                                title: const Text("Fehler!"),
                                content: Text("Beim Download der Datei ${snapshot.data["own_files"][index].name} ist ein unerwarteter Fehler aufgetreten. Wenn dieses Problem besteht, senden Sie uns bitte einen Fehlerbericht."),
                                actions: [TextButton(
                                  child: const Text('OK'),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),],
                              ));
                            } else {
                              OpenFile.open(filepath);
                            }
                          });
                        },
                      );
                    }
                  ),
                  ValueListenableBuilder(
                      valueListenable: _addedFiles,
                      builder: (context, value, _) {
                        if (value == 0 && snapshot.data["course_id"] == null) {
                          return Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                                color: Theme
                                    .of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12)
                            ),
                            child: const Text(
                                "Die Abgabe ist noch nicht/nicht mehr möglich."),
                          );
                        } else if (value == 0) {
                          return Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                                color: Theme
                                    .of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12)
                            ),
                            child: const Text(
                                "Du hast noch keine Dateien hinzugefügt!"),
                          );
                        } else {
                          return Container(
                              margin: const EdgeInsets.only(
                                top: 8,
                                bottom: 8,
                                left: 20,
                                right: 20
                              ),
                              decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12)
                              ),
                              child: Column(
                                children: [
                                  ..._fileWidgets,
                                  if (value != 5) ...[
                                    Text(
                                      "Noch ${5 - value} von 5 hinzufügbar",
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.labelLarge,
                                    )
                                  ]
                                ],
                              )
                          );
                        }
                      }
                  )
                ],
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.name),
          ),
          body: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
    );
  }
}
