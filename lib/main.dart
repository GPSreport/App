import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:typed_data';

// URLs de la API
const String kApiUrl = "http://3.148.29.34/reportes/";
const String kLoginUrl = "http://3.148.29.34/login";
const String kRegisterUrl = "http://3.148.29.34/usuarios/crear";

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

// Modelo para el estado del usuario
class UserStatus {
  final String nombre;
  final String email;
  final bool verificado;
  final String estadoTexto;

  UserStatus({
    required this.nombre,
    required this.email,
    required this.verificado,
    required this.estadoTexto,
  });

  factory UserStatus.fromJson(Map<String, dynamic> json) {
    return UserStatus(
      nombre: json['nombre'],
      email: json['email'],
      verificado: json['verificado'],
      estadoTexto: json['estado_texto'],
    );
  }
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
  
  // Si usas un emulador o una IP local, actualiza este valor según corresponda.
  
  // Controladores para login
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  
  // Estado de autenticación
  bool _isLoggedIn = false;
  bool _isLoggingIn = false;
  bool _isRegistering = false;
  String _loggedInUser = "";
  String _loggedInUserEmail = "";
  
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
            _loggedInUserEmail = responseData['email'] ?? '';
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
        // Credenciales incorrectas o cuenta no verificada
        setState(() {
          _isLoggingIn = false;
        });
        if (mounted) {
          try {
            final errorData = jsonDecode(response.body);
            final errorMessage = errorData['detail'] ?? "Usuario o contraseña incorrectos";
            
            if (errorMessage.contains("no verificada")) {
              _showVerificationDialog(usuario, password);
            } else {
              _showMessage(errorMessage);
            }
          } catch (e) {
            _showMessage("Usuario o contraseña incorrectos");
          }
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
      _loggedInUserEmail = "";
    });
    _userController.clear();
    _passController.clear();
    _showMessage("Sesión cerrada");
  }

  // Mostrar diálogo para cuenta no verificada
  Future<void> _showVerificationDialog(String usuario, String password) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.email_outlined, color: Colors.orange),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Cuenta no verificada',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tu cuenta aún no ha sido verificada. Necesitas verificar tu correo electrónico para poder iniciar sesión.',
                ),
                const SizedBox(height: 16),
                const Text(
                  '💡 Nuevo sistema de verificación:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('• Te enviaremos un código de 6 dígitos por email'),
                const Text('• El código expira en 15 minutos'),
                const Text('• Podrás verificar tu cuenta desde tu perfil'),
                const SizedBox(height: 8),
                const Text('• También revisa tu bandeja de spam'),
              ],
            ),
          ),
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await _resendVerificationEmail(usuario, password);
                    },
                    icon: const Icon(Icons.security),
                    label: const Text('Enviar código de verificación'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Entendido'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // Obtener email del usuario desde el backend
  Future<String?> _getUserEmail(String usuario, String password) async {
    try {
      final payload = {
        'usuario': usuario,
        'clave': password,
      };

      final response = await http.post(
        Uri.parse(kLoginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['email'];
        }
      } else if (response.statusCode == 403) {
        // Usuario no verificado, pero podemos obtener el email
        final data = jsonDecode(response.body);
        if (data['detail'] is Map && data['detail']['email'] != null) {
          return data['detail']['email'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Enviar código de verificación usando el nuevo endpoint
  Future<void> _sendVerificationCode(String usuario, String password) async {
    try {
      // Primero obtener el email del usuario
      final email = await _getUserEmail(usuario, password);
      
      if (email == null) {
        _showMessage('Error al obtener información del usuario');
        return;
      }

      final payload = {'email': email};

      final response = await http.post(
        Uri.parse('${kApiUrl.replaceAll('/reportes/', '')}/enviar-codigo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _showMessage('Código de verificación enviado a tu email. Expira en 15 minutos.', isSuccess: true);
      } else {
        final error = jsonDecode(response.body);
        _showMessage(error['detail'] ?? 'Error enviando código de verificación');
      }
    } catch (e) {
      _showMessage('Error de conexión al enviar código');
    }
  }

  // Reenviar correo de verificación (método legacy)
  Future<void> _resendVerificationEmail(String usuario, String password) async {
    // Usar el nuevo método de código de 6 dígitos
    await _sendVerificationCode(usuario, password);
  }

  // Mostrar diálogo para crear usuario
  Future<void> _openRegisterDialog() async {
    final nombresController = TextEditingController();
    final telefonoController = TextEditingController();
    final correoController = TextEditingController();
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
                      controller: correoController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
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
                            correoController.text.trim(),
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

  Future<void> _registerUser(String nombres, String telefono, String correo, String usuario, String clave) async {
    if (nombres.isEmpty || telefono.isEmpty || correo.isEmpty || usuario.isEmpty || clave.isEmpty) {
      _showMessage('Completa todos los campos');
      return;
    }
    
    // Validar formato de correo electrónico
    if (!_isValidEmail(correo)) {
      _showMessage('Ingresa un correo electrónico válido');
      return;
    }
    try {
      final payload = {
        'usuario': usuario,
        'clave': clave,
        'nombres': nombres,
        'telefono': telefono,
        'correo': correo,
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
    // Imagen dummy de 1x1 pixel PNG transparente (contenido base64 sin prefijo data:)
    return "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO2dZb8AAAAASUVORK5CYII=";
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



  // Validar formato de correo electrónico
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    );
    return emailRegex.hasMatch(email);
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
                  _openRecoverUserDialog();
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
                onPressed: () {
                  Navigator.of(context).pop(); // Cerrar drawer
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(
                        userEmail: _loggedInUserEmail,
                        userName: _loggedInUser,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.person),
                label: const Text('Mi Perfil'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
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

  // ======================= Recuperación de Usuario =======================
  Future<void> _openRecoverUserDialog() async {
    final emailController = TextEditingController();
    final codeController = TextEditingController();
    final newPasswordController = TextEditingController();
    bool codeSent = false;
    bool sending = false;
    bool verifying = false;

    await showDialog(
      context: context,
      barrierDismissible: !sending && !verifying,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> sendCode() async {
              final email = emailController.text.trim();
              if (!_isValidEmail(email)) {
                _showMessage('Email inválido');
                return;
              }
              setLocal(() { sending = true; });
              try {
                final resp = await http.post(
                  Uri.parse('${kApiUrl.replaceAll('/reportes/', '')}/recuperar-usuario/enviar-codigo'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({'email': email}),
                ).timeout(const Duration(seconds: 15));
                if (resp.statusCode == 200) {
                  final data = jsonDecode(resp.body);
                  if (data['success'] == true) {
                    setLocal(() { codeSent = true; });
                    _showMessage('Código enviado. Revisa tu correo', isSuccess: true);
                  } else {
                    _showMessage(data['message'] ?? 'Error enviando código');
                  }
                } else {
                  final err = jsonDecode(resp.body);
                  _showMessage(err['detail'] ?? 'Error enviando código');
                }
              } catch (e) {
                _showMessage('Error de conexión');
              } finally {
                setLocal(() { sending = false; });
              }
            }

            Future<void> verifyCode() async {
              final email = emailController.text.trim();
              final codigo = codeController.text.trim();
              final nuevaClave = newPasswordController.text.trim();
              if (nuevaClave.length < 6) {
                _showMessage('La nueva contraseña debe tener al menos 6 caracteres');
                return;
              }
              if (codigo.length != 6 || !RegExp(r'^\d{6}$').hasMatch(codigo)) { // simple safeguard
                _showMessage('Código inválido');
                return;
              }
              setLocal(() { verifying = true; });
              try {
                final resp = await http.post(
                  Uri.parse('${kApiUrl.replaceAll('/reportes/', '')}/recuperar-usuario/verificar'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({'email': email, 'codigo': codigo, 'nueva_clave': nuevaClave}),
                ).timeout(const Duration(seconds: 15));
                // Verificar que el contexto del diálogo siga activo
                if (!ctx.mounted) return;
                if (resp.statusCode == 200) {
                  final data = jsonDecode(resp.body);
                  if (data['success'] == true && data['usuario'] != null) {
                    if (Navigator.of(ctx).canPop()) {
                      Navigator.of(ctx).pop();
                    }
                    // Asegurar que el State principal siga montado antes de usar setState / overlay
                    if (!mounted) return;
                    setState(() { _userController.text = data['usuario']; });
                    _showMessage('Contraseña actualizada. Usuario: ${data['usuario']}', isSuccess: true);
                  } else {
                    _showMessage(data['message'] ?? 'No se pudo recuperar');
                  }
                } else {
                  final err = jsonDecode(resp.body);
                  _showMessage(err['detail'] ?? 'Error verificando código');
                }
              } catch (e) {
                _showMessage('Error de conexión');
              } finally {
                setLocal(() { verifying = false; });
              }
            }

            return AlertDialog(
              title: const Text('Recuperar Usuario'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: emailController,
                      enabled: !codeSent && !sending && !verifying,
                      decoration: const InputDecoration(
                        labelText: 'Correo registrado',
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPasswordController,
                      enabled: !verifying,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nueva contraseña',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (codeSent) ...[
                      TextField(
                        controller: codeController,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: 'Código de 6 dígitos',
                          prefixIcon: Icon(Icons.verified_user),
                          counterText: '',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (!codeSent)
                      const Text(
                        'Te enviaremos un código temporal para revelar tu nombre de usuario.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      )
                    else
                      const Text('Ingresa el código recibido para mostrar tu usuario.'),
                  ],
                ),
              ),
              actions: [
                if (!codeSent) ElevatedButton(
                  onPressed: sending ? null : sendCode,
                  child: sending
                      ? const SizedBox(height:16,width:16,child:CircularProgressIndicator(strokeWidth:2))
                      : const Text('Enviar Código'),
                ) else ElevatedButton(
                  onPressed: verifying ? null : verifyCode,
                  child: verifying
                      ? const SizedBox(height:16,width:16,child:CircularProgressIndicator(strokeWidth:2))
                      : const Text('Verificar'),
                ),
                TextButton(
                  onPressed: (sending || verifying) ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      }
    );
  }
}

// Pantalla de perfil de usuario
class UserProfileScreen extends StatefulWidget {
  final String userEmail;
  final String userName;

  const UserProfileScreen({
    super.key,
    required this.userEmail,
    required this.userName,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  UserStatus? _userStatus;
  bool _isLoading = true;
  bool _isSendingCode = false;
  bool _isVerifyingCode = false;
  final TextEditingController _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserStatus();
  }

  // Cargar estado del usuario
  Future<void> _loadUserStatus() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await http.get(
        Uri.parse('${kApiUrl.replaceAll('/reportes/', '')}/usuario-estado/${widget.userEmail}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _userStatus = UserStatus.fromJson(data);
          _isLoading = false;
        });
      } else {
        throw Exception('Error al cargar estado del usuario');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error al cargar estado del usuario: $e');
    }
  }

  // Enviar código de verificación
  Future<void> _sendVerificationCode() async {
    setState(() => _isSendingCode = true);
    
    try {
      final payload = {'email': widget.userEmail};
      
      final response = await http.post(
        Uri.parse('${kApiUrl.replaceAll('/reportes/', '')}/enviar-codigo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _showSuccessSnackBar('Código enviado a tu email. Expira en 15 minutos.');
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Error enviando código');
      }
    } catch (e) {
      _showErrorSnackBar('Error enviando código: $e');
    } finally {
      setState(() => _isSendingCode = false);
    }
  }

  // Verificar código
  Future<void> _verifyCode() async {
    final codigo = _codeController.text.trim();
    
    if (codigo.length != 6 || !RegExp(r'^\d{6}$').hasMatch(codigo)) {
      _showErrorSnackBar('Ingresa un código válido de 6 dígitos');
      return;
    }

    setState(() => _isVerifyingCode = true);
    
    try {
      final payload = {'codigo': codigo};
      
      final response = await http.post(
        Uri.parse('${kApiUrl.replaceAll('/reportes/', '')}/verificar-codigo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSuccessSnackBar('¡Cuenta verificada exitosamente!');
        _codeController.clear();
        await _loadUserStatus(); // Recargar estado
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Error verificando código');
      }
    } catch (e) {
      _showErrorSnackBar('Error verificando código: $e');
    } finally {
      setState(() => _isVerifyingCode = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de Usuario'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Información del usuario
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Información Personal',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow('Nombre:', _userStatus?.nombre ?? 'N/A'),
                          const SizedBox(height: 8),
                          _buildInfoRow('Email:', _userStatus?.email ?? 'N/A'),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Estado de verificación
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estado de Verificación',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                _userStatus?.verificado == true
                                    ? Icons.verified_user
                                    : Icons.warning,
                                color: _userStatus?.verificado == true
                                    ? Colors.green
                                    : Colors.orange,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _userStatus?.estadoTexto ?? 'Cargando...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _userStatus?.verificado == true
                                        ? Colors.green
                                        : Colors.orange,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Sección de verificación si no está verificado
                  if (_userStatus?.verificado != true) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Verificar Cuenta',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Para activar todas las funciones de la aplicación, necesitas verificar tu cuenta con el código de 6 dígitos que te enviaremos por email.',
                            ),
                            const SizedBox(height: 16),
                            
                            // Botón para enviar código
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isSendingCode ? null : _sendVerificationCode,
                                icon: _isSendingCode
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.email),
                                label: Text(_isSendingCode
                                    ? 'Enviando código...'
                                    : 'Enviar código de verificación'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Campo para ingresar código
                            TextField(
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: const InputDecoration(
                                labelText: 'Código de verificación',
                                hintText: 'Ingresa el código de 6 dígitos',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.security),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Botón para verificar código
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isVerifyingCode ? null : _verifyCode,
                                icon: _isVerifyingCode
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.check_circle),
                                label: Text(_isVerifyingCode
                                    ? 'Verificando...'
                                    : 'Verificar código'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}