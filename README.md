# gps_reporter

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Comportamiento de autenticación

- El botón "Enviar" solo está habilitado cuando existe una sesión iniciada en la app.
- Si no hay sesión activa, el botón aparece deshabilitado y se muestra un mensaje indicando que debes iniciar sesión para habilitarlo.
- Además, antes de iniciar el proceso de envío, se verifica nuevamente que el usuario esté autenticado.
