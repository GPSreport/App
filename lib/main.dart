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
  String _statusMessage = "Presiona 'Enviar' luego de introducir los datos de su reporte";
  Uint8List? _selectedImageBytes; // imagen seleccionada (comprimida)
  final TextEditingController _descripcionController = TextEditingController();
  
  // Overlay para mensajes emergentes sobre el Drawer
  OverlayEntry? _overlayEntry;
  
  // URL de tu API (cambiar por tu IP local si usas dispositivo físico)
  // Dirección de la API (ajustada a la IP pública y puerto 8000 del usuario)
  static const String kApiUrl = "http://3.148.29.34/reportes/";
  static const String kLoginUrl = "http://3.148.29.34/login";
  static const String kRegisterUrl = "http://3.148.29.34/usuarios/crear";
  // Si usas un emulador o una IP local, actualiza este valor según corresponda.
  
  // Controladores para login
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  
  // Estado de autenticación
  bool _isLoggedIn = false;
  bool _isLoggingIn = false;
  bool _isRegistering = false;
  String _loggedInUser = "";
  
  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    // Limpiar overlay si quedara activo
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
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

  // Función de login
  Future<void> _performLogin() async {
    final usuario = _userController.text.trim();
    final password = _passController.text.trim();
    
    if (usuario.isEmpty || password.isEmpty) {
      _showMessage("Por favor completa usuario y contraseña");
      return;
    }

    setState(() {
      _isLoggingIn = true;
    });

    try {
      final loginData = {
        "usuario": usuario,
        "clave": password,  // Cambiado de "password" a "clave" para coincidir con el backend
      };

      final response = await http.post(
        Uri.parse(kLoginUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(loginData),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Parsear respuesta JSON
        final responseData = jsonDecode(response.body);
        
        if (responseData['success'] == true) {
          // Login exitoso
          setState(() {
            _isLoggedIn = true;
            _loggedInUser = responseData['usuario'] ?? usuario;
            _isLoggingIn = false;
          });
          
          // Limpiar campos de contraseña por seguridad
          _passController.clear();
          
          if (mounted) {
            _showMessage("¡Bienvenido $_loggedInUser!", isSuccess: true);
            Navigator.of(context).pop(); // Cerrar drawer
          }
        } else {
          // Login fallido según respuesta del servidor
          setState(() {
            _isLoggingIn = false;
          });
          if (mounted) {
            _showMessage(responseData['message'] ?? "Error de autenticación");
          }
        }
      } else if (response.statusCode == 401) {
        // Credenciales incorrectas
        setState(() {
          _isLoggingIn = false;
        });
        if (mounted) {
          _showMessage("Usuario o contraseña incorrectos");
        }
      } else if (response.statusCode == 400) {
        // Error de validación
        setState(() {
          _isLoggingIn = false;
        });
        if (mounted) {
          _showMessage("Datos de login inválidos");
        }
      } else {
        // Otros errores del servidor
        setState(() {
          _isLoggingIn = false;
        });
        if (mounted) {
          _showMessage("Error del servidor: ${response.statusCode}");
        }
      }
    } catch (e) {
      setState(() {
        _isLoggingIn = false;
      });
      if (mounted) {
        if (e.toString().contains('TimeoutException')) {
          _showMessage("Tiempo de espera agotado. Verifica tu conexión.");
        } else {
          _showMessage("Error de conexión. Verifica tu red.");
        }
      }
      debugPrint("Error de login: $e");
    }
  }

  // Función de logout
  void _performLogout() {
    setState(() {
      _isLoggedIn = false;
      _loggedInUser = "";
    });
    _userController.clear();
    _passController.clear();
    _showMessage("Sesión cerrada");
  }

  // Mostrar diálogo para crear usuario
  Future<void> _openRegisterDialog() async {
    final nombresController = TextEditingController();
    final telefonoController = TextEditingController();
    final usuarioController = TextEditingController();
    final claveController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: !_isRegistering,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              title: const Text('Crear usuario'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombresController,
                      decoration: const InputDecoration(
                        labelText: 'Nombres',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: telefonoController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usuarioController,
                      decoration: const InputDecoration(
                        labelText: 'Usuario',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: claveController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isRegistering ? null : () { Navigator.of(ctx).pop(); },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  onPressed: _isRegistering
                      ? null
                      : () async {
                          setLocalState(() { _isRegistering = true; });
                          await _registerUser(
                            nombresController.text.trim(),
                            telefonoController.text.trim(),
                            usuarioController.text.trim(),
                            claveController.text.trim(),
                          );
                          if (mounted) {
                            setLocalState(() { _isRegistering = false; });
                          }
                        },
                  icon: _isRegistering
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.person_add),
                  label: Text(_isRegistering ? 'Creando...' : 'Crear'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _registerUser(String nombres, String telefono, String usuario, String clave) async {
    if (nombres.isEmpty || telefono.isEmpty || usuario.isEmpty || clave.isEmpty) {
      _showMessage('Completa todos los campos');
      return;
    }
    try {
      final payload = {
        'usuario': usuario,
        'clave': clave,
        'nombres': nombres,
        'telefono': telefono,
      };
      final resp = await http
          .post(
            Uri.parse(kRegisterUrl),
            headers: { 'Content-Type': 'application/json' },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final numero = data['numero_usuario'];
        _showMessage('Usuario creado. Nº: ${numero ?? '-'}', isSuccess: true);
        // Prefill login con el nuevo usuario
        _userController.text = usuario;
        _passController.text = clave;
        if (!mounted) return; // Evitar usar context si el widget fue desmontado
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } else {
        // Intentar extraer mensaje de error
        String msg = 'No se pudo crear el usuario';
        try {
          final err = jsonDecode(resp.body);
          msg = err['detail']?.toString() ?? msg;
        } catch (_) {}
        _showMessage(msg);
      }
    } catch (e) {
      final isTimeout = e.toString().contains('TimeoutException');
      _showMessage(isTimeout ? 'Tiempo de espera agotado' : 'Error de conexión');
      debugPrint('Register error: $e');
    }
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
    return "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";
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
        if (mounted && Theme.of(context).platform == TargetPlatform.iOS) {
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
        _statusMessage = "Error al enviar datos, no se pudo conectar con el servidor";
        _isLoading = false;
      });
      _showMessage("Error al enviar datos");
      debugPrint("Error al enviar datos: $e");
    }
  }

  // Mostrar mensaje emergente por encima del Drawer usando Overlay
  void _showMessage(String message, {bool isSuccess = false}) {
    if (!mounted) return;

    // Si hay un mensaje visible, eliminarlo antes de mostrar el nuevo
    _overlayEntry?.remove();
    _overlayEntry = null;

  final overlay = Overlay.of(context, rootOverlay: true);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: (isSuccess ? Colors.green : Colors.red).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSuccess ? Icons.check_circle : Icons.error,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);

    // Retirar automáticamente después de 3 segundos
    Future.delayed(const Duration(seconds: 3)).then((_) {
      if (mounted) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }

  Future<void> _getLocationAndSendData() async {
  // Seguridad adicional: no permitir enviar si no hay sesión activa
  if (!_isLoggedIn) {
    _showMessage("Debes iniciar sesión para enviar el reporte");
    return;
  }
  await _getCurrentLocation(); // obtiene ubicación

  if (_currentPosition != null) {
    await _sendDataToServer(); // si se obtuvo, envía al servidor
  } else {
    _showMessage("No se pudo obtener la ubicación");
  }
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
      drawer: Drawer(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          children: [
            if (!_isLoggedIn) ...[
              // Interfaz de login
              const Text(
                '🔒 Iniciar Sesión',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _userController,
                decoration: const InputDecoration(
                  labelText: 'Usuario',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isLoggingIn ? null : _performLogin,
                icon: _isLoggingIn 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: Text(_isLoggingIn ? 'Autenticando...' : 'Entrar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _openRegisterDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('Crear usuario'),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  _showMessage('Contacta al administrador para recuperar tu usuario');
                },
                child: const Text(
                  'Recuperar Usuario',
                  style: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else ...[
              // Interfaz cuando está logueado
              const Icon(
                Icons.account_circle,
                size: 64,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              Text(
                '¡Hola $_loggedInUser!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Sesión activa',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _performLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar Sesión'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ],
        ),
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

                        if (_selectedImageBytes != null) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                              width: 250,
                              height: 192,
                              child: Image.memory(
                                      _selectedImageBytes!,
                                      fit: BoxFit.cover,
                                    )
                              ),
                            )                           
                          ),
                        ]
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
              onPressed: (_isLoading || !_isLoggedIn) ? null : _getLocationAndSendData,
              icon: _isLoading 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.send),
              label: Text(_isLoading ? 'Procesando...' : 'Enviar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            if (!_isLoggedIn) ...[
              const SizedBox(height: 8),
              const Text(
                'Debes iniciar sesión para habilitar el botón de envío.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
            
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
                    
                    Text('• Al envíar se obtiene la ubicación de su dispositivo móvil'),
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