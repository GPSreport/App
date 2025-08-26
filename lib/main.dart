import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:typed_data';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Reporter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const GPSReporterScreen(),
    );
  }
}

class GPSReporterScreen extends StatefulWidget {
  const GPSReporterScreen({super.key});

  @override
  State<GPSReporterScreen> createState() => _GPSReporterScreenState();
}

class _GPSReporterScreenState extends State<GPSReporterScreen> {
  // Variables de estado
  Position? _currentPosition;
  bool _isLoading = false;
  bool _locationPermissionGranted = false;
  String _statusMessage = "Presiona 'Obtener Ubicación' para comenzar";
  Uint8List? _selectedImageBytes; // imagen seleccionada (comprimida)
  final TextEditingController _descripcionController = TextEditingController();
  
  // URL de tu API (cambiar por tu IP local si usas dispositivo físico)
  // Dirección de la API (ajustada a la IP pública y puerto 5000 del usuario)
  static const String kApiUrl = "http://186.168.206.201:5000/reportes/";
  // Si usas un emulador o una IP local, actualiza este valor según corresponda.
  
  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  // Verificar permisos de ubicación
  Future<void> _checkPermissions() async {
    final status = await Permission.location.status;
    setState(() {
      _locationPermissionGranted = status.isGranted;
      if (!_locationPermissionGranted) {
        _statusMessage = "Se necesitan permisos de ubicación";
      }
    });
  }

  // Solicitar permisos de ubicación
  Future<void> _requestPermissions() async {
    final status = await Permission.location.request();
    setState(() {
      _locationPermissionGranted = status.isGranted;
      if (_locationPermissionGranted) {
        _statusMessage = "Permisos concedidos. Presiona 'Obtener Ubicación'";
      } else {
        _statusMessage = "Permisos de ubicación denegados";
      }
    });
  }

  // Verificar si el GPS está habilitado
  Future<bool> _checkGPSEnabled() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _statusMessage = "GPS deshabilitado. Habilita la ubicación en configuración";
      });
      return false;
    }
    return true;
  }

  // Obtener ubicación GPS
  Future<void> _getCurrentLocation() async {
    if (!_locationPermissionGranted) {
      await _requestPermissions();
      return;
    }

    if (!await _checkGPSEnabled()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Obteniendo ubicación GPS...";
    });

    try {
      // Use LocationSettings and wrap with timeout to replicate timeLimit
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 10));

      setState(() {
        _currentPosition = position;
        _statusMessage = "Ubicación obtenida exitosamente";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Error al obtener ubicación: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  // Generar foto dummy en base64
  String _generateDummyPhoto() {
    // Imagen dummy de 1x1 pixel en base64 (PNG transparente)
    return "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==";
  }

  // Seleccionar imagen desde cámara o galería
  Future<void> _pickImage(ImageSource source) async {
  // Solicitar permisos según origen
  final ok = await _ensureImagePermission(source);
  if (!ok) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source);
      if (picked == null) return;

      // Comprimir la imagen al 50% de calidad
      final compressed = await FlutterImageCompress.compressWithFile(
        picked.path,
        quality: 50, // reducir a la mitad la calidad
      );

      if (compressed != null) {
        setState(() {
          _selectedImageBytes = Uint8List.fromList(compressed);
        });
      }
    } catch (e) {
      _showMessage('Error al seleccionar imagen: ${e.toString()}');
    }
  }

  // Solicitar permisos necesarios antes de abrir cámara/galería
  Future<bool> _ensureImagePermission(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final status = await Permission.camera.request();
        return status.isGranted;
      } else {
        // galería: solicitar photos (iOS) o storage (Android)
        if (Theme.of(context).platform == TargetPlatform.iOS) {
          final status = await Permission.photos.request();
          return status.isGranted;
        } else {
          // Android: manejar READ_MEDIA_IMAGES (Android 13+) o storage
          final status = await Permission.photos.request();
          if (status.isGranted) return true;
          final storage = await Permission.storage.request();
          return storage.isGranted;
        }
      }
    } catch (e) {
      _showMessage('Error al solicitar permisos: ${e.toString()}');
      return false;
    }
  }

  // Enviar datos al servidor
  Future<void> _sendDataToServer() async {
    if (_currentPosition == null) {
      _showMessage("Primero obtén la ubicación GPS");
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Enviando datos al servidor...";
    });

    try {
      final timestamp = DateTime.now().toIso8601String();
      final fotoBase64 = _selectedImageBytes != null
      ? base64Encode(_selectedImageBytes!)
      : _generateDummyPhoto();

      final descripcion = _descripcionController.text.trim().isEmpty
        ? "Reporte enviado desde app móvil"
        : _descripcionController.text.trim();
      
      final data = {
        "latitud": _currentPosition!.latitude,
        "longitud": _currentPosition!.longitude,
        "timestamp": timestamp,
        "foto_base64": fotoBase64,
        "descripcion": descripcion,
        "tipo_reporte": "mobile_app"
      };

      final response = await http.post(
        Uri.parse(kApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        setState(() {
          _statusMessage = "¡Datos enviados exitosamente!";
          _isLoading = false;
        });
        _showMessage("Reporte enviado correctamente", isSuccess: true);
      } else {
        throw Exception("Error del servidor: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Error al enviar datos: ${e.toString()}";
        _isLoading = false;
      });
      _showMessage("Error al enviar datos: ${e.toString()}");
    }
  }

  // Mostrar mensaje emergente
  void _showMessage(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Formatear coordenadas para mostrar
  String _formatCoordinate(double coordinate) {
    return coordinate.toStringAsFixed(6);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Reporter'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tarjeta de estado
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      _locationPermissionGranted ? Icons.gps_fixed : Icons.gps_off,
                      size: 48,
                      color: _locationPermissionGranted ? Colors.green : Colors.red,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Información de ubicación
            if (_currentPosition != null) ...[
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📍 Ubicación Actual',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text('Latitud: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(_formatCoordinate(_currentPosition!.latitude)),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('Longitud: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(_formatCoordinate(_currentPosition!.longitude)),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('Precisión: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('${_currentPosition!.accuracy.toStringAsFixed(1)} m'),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('Timestamp: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              DateFormat('dd/MM/yyyy HH:mm:ss').format(
                                DateTime.fromMillisecondsSinceEpoch(_currentPosition!.timestamp.millisecondsSinceEpoch)
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // Botones
            if (!_locationPermissionGranted)
              ElevatedButton.icon(
                onPressed: _requestPermissions,
                icon: const Icon(Icons.security),
                label: const Text('Solicitar Permisos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            
            const SizedBox(height: 10),
            // Image selector and preview
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📷 Foto (opcional):', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Cámara'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Galería'),
                        ),
                        if (_selectedImageBytes != null)
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: Image.memory(
                              _selectedImageBytes!,
                              fit: BoxFit.cover,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descripcionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Descripción (opcional)',
                        hintText: 'Escribe detalles del reporte...',
                        border: OutlineInputBorder(),
                      ),
                    ),

                  ],
                ),
              ),
            ),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _getCurrentLocation,
              icon: _isLoading 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                  )
                : const Icon(Icons.my_location),
              label: Text(_isLoading ? 'Obteniendo...' : 'Obtener Ubicación GPS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            const SizedBox(height: 10),
            
            ElevatedButton.icon(
              onPressed: (_currentPosition != null && !_isLoading) ? _sendDataToServer : null,
              icon: _isLoading 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                  )
                : const Icon(Icons.send),
              label: Text(_isLoading ? 'Enviando...' : 'Enviar al Servidor'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Información adicional
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ℹ️ Información:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text('• Los datos se envían a tu servidor local'),
                    Text('• API: $kApiUrl'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}