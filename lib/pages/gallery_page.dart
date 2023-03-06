import 'dart:io';
import 'package:flutter/material.dart';

class GalleryPage extends StatefulWidget {
  final List<String> imagePaths;
  const GalleryPage({Key? key, required this.imagePaths}) : super(key: key);

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.0,
      ),
      body: Container(
          height: double.infinity,
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 20),
          child: widget.imagePaths.isNotEmpty
              ? ListView.builder(
                  itemCount: widget.imagePaths.length,
                  itemBuilder: (BuildContext context, int index) {
                    final path = widget.imagePaths[index];
                    return GestureDetector(
                      onDoubleTap: () {
                        setState(() {
                          File file = File(path);
                          file.delete();
                          widget.imagePaths.removeAt(index);
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.file(File(path)),
                      ),
                    );
                  },
                )
              : const Center(
                  child: Text('No Images'),
                )),
    );
  }
}
