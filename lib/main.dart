import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dataset Scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const CategorySelectionScreen(),
    );
  }
}

class CategorySelectionScreen extends StatelessWidget {
  const CategorySelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = ['s1', 's2', 's3', 's4', 's5', 'laar'];
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выберите категорию'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            return ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NumberInputScreen(
                      category: categories[index],
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade100,
                foregroundColor: Colors.blue.shade800,
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Text(categories[index].toUpperCase()),
            );
          },
        ),
      ),
    );
  }
}

class NumberInputScreen extends StatefulWidget {
  final String category;
  
  const NumberInputScreen({super.key, required this.category});

  @override
  State<NumberInputScreen> createState() => _NumberInputScreenState();
}

class _NumberInputScreenState extends State<NumberInputScreen> {
  final TextEditingController _numberController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Категория: ${widget.category.toUpperCase()}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Введите номер:',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _numberController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Введите число',
                contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                if (_numberController.text.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CameraScreen(
                        category: widget.category,
                        number: _numberController.text,
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Пожалуйста, введите номер'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text(
                'Продолжить',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }
}

class CameraScreen extends StatefulWidget {
  final String category;
  final String number;
  
  const CameraScreen({super.key, required this.category, required this.number});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  int _photoCount = 1;
  String? _datasetPath;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _createDatasetDirectory();
  }

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) return;
    
    _controller = CameraController(
      cameras[0],
      ResolutionPreset.high,
    );
    
    try {
      await _controller!.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Ошибка инициализации камеры: $e');
    }
  }

  Future<void> _createDatasetDirectory() async {
    try {
      // Запрос разрешений
      await Permission.camera.request();

      // Получение пути к внешнему хранилищу (Pictures)
      Directory? directory;

      try {
        // Пытаемся получить папку Pictures
        final List<Directory>? externalDirs =
            await getExternalStorageDirectories(type: StorageDirectory.pictures);
        if (externalDirs != null && externalDirs.isNotEmpty) {
          directory = externalDirs.first;
        } else {
          // Если не удалось, используем основное хранилище приложения
          directory = await getExternalStorageDirectory();
        }
      } catch (e) {
        print('Ошибка получения директории: $e');
        directory = await getExternalStorageDirectory();
      }

      if (directory == null) {
        print('Не удалось получить доступ к хранилищу');
        return;
      }

      final datasetDir = Directory(path.join(directory.path, 'BERSERKDATASET'));

      if (!await datasetDir.exists()) {
        await datasetDir.create(recursive: true);
      }

      final categoryDir = Directory(path.join(datasetDir.path, widget.category));
      if (!await categoryDir.exists()) {
        await categoryDir.create(recursive: true);
      }

      final numberDir = Directory(path.join(categoryDir.path, widget.number));
      if (!await numberDir.exists()) {
        await numberDir.create(recursive: true);
      }

      _datasetPath = numberDir.path;
      print('Путь сохранения: $_datasetPath');
    } catch (e) {
      print('Ошибка создания директории: $e');
    }
  }

  Future<void> _takePicture() async {
    print('ФОТОГРАФИРУЕМ');
    if (_controller == null || !_controller!.value.isInitialized || _datasetPath == null) {
      return;
    }
    print('КАМЕРА ЕСТЬ');
    try {
      final fileName = '${widget.category}_${widget.number}_ver$_photoCount.jpg';
      final filePath = path.join(_datasetPath!, fileName);
      
      final XFile picture = await _controller!.takePicture();
      await picture.saveTo(filePath);
      
      setState(() {
        _photoCount++;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Фото сохранено: $fileName'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('Ошибка сохранения фото: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка сохранения фото'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category.toUpperCase()} - ${widget.number}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                'Фото: ${_photoCount - 1}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CameraPreview(_controller!),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Завершить'),
                ),
                FloatingActionButton(
                  onPressed: _takePicture,
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.camera_alt, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
