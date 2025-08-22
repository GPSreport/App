import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';

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
  
  // URL de tu API (cambiar por tu IP local si usas dispositivo físico)
  static const String API_URL = "http://192.168.1.2:8000/reportes/"; // Para emulador
  // static const String API_URL = "http://TU_IP_LOCAL:8000/reportes/"; // Para dispositivo físico
  
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
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

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
    return "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==";
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
      final dummyPhoto = _generateDummyPhoto();
      
      final data = {
        "latitud": _currentPosition!.latitude,
        "longitud": _currentPosition!.longitude,
        "timestamp": timestamp,
        "foto_base64": dummyPhoto,
        "descripcion": "Reporte enviado desde app móvil",
        "tipo_reporte": "mobile_app"
      };

      final response = await http.post(
        Uri.parse(API_URL),
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
      body: Padding(
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
                                DateTime.fromMillisecondsSinceEpoch(_currentPosition!.timestamp?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch)
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
                    const Text('• Se incluye una foto dummy automáticamente'),
                    Text('• API: $API_URL'),
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