Setup rápido para desarrolladores

Sigue estos pasos después de clonar el repositorio para configurar tu entorno local:

1) Instala Flutter
   - Descarga y extrae Flutter en una ruta local, por ejemplo: `C:\dev\flutter`

2) Configura `FLUTTER_ROOT` (opcional, recomendado)
   - En Windows PowerShell (persistente):
     setx FLUTTER_ROOT "C:\dev\flutter"
   - Abre un nuevo terminal después de ejecutar `setx`.

3) Crea `local.properties` desde el ejemplo
   - Copia `local.properties.example` a `local.properties` en la raíz del proyecto:
     - Windows PowerShell: `cp local.properties.example local.properties`
   - Edita `local.properties` y descomenta/ajusta la línea con `flutter.sdk` apuntando al path donde instalaste Flutter. Ejemplo:
     flutter.sdk=C:\dev\flutter
   - (Opcional) Ajusta `sdk.dir` si tu Android SDK está en una ubicación no estándar.

4) Recupera dependencias y analiza
   - flutter pub get
   - flutter analyze

Notas
- `local.properties` no se debe commitear: se ignorará por Git.
- Si prefieres no crear `local.properties`, asegúrate de que `FLUTTER_ROOT` apunte correctamente al SDK de Flutter.
- Si ves errores relacionados con rutas de otro desarrollador (ej. `C:\Users\jjddd\...`), ejecutar `flutter clean` y luego `flutter pub get` ayuda a regenerar archivos con tus rutas locales.

Contacto
- Si algo falla, pega aquí la salida de `flutter analyze` y lo reviso.
