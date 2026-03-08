# Solución: Permisos de Bluetooth en Android 15

## Problema
La aplicación no solicita los permisos de Bluetooth en Android 15, aunque sí solicita ubicación y proximidad.

## Soluciones Aplicadas

### 1. ✅ AndroidManifest.xml Actualizado
Se han actualizado los permisos para Android 15:
- Agregados permisos BLUETOOTH y BLUETOOTH_ADMIN sin límite de SDK
- BLUETOOTH_SCAN ahora usa `usesPermissionFlags="neverForLocation"` (Android 15)
- Agregado ACCESS_COARSE_LOCATION además de ACCESS_FINE_LOCATION

### 2. ✅ Código Dart Mejorado
- Método `requestBluetoothPermissions()` ahora maneja mejor Android 15
- Se agrega verificación de estados `isDenied` e `isRestricted`
- Se solicitan permisos de forma más selectiva

### 3. Pasos Manuales Necesarios

#### A. Limpiar y reconstruir el proyecto:
```bash
flutter clean
cd android && ./gradlew clean && cd ..
flutter pub get
flutter run
```

#### B. Si aún no funcionan los permisos:

1. **Desinstalar la app completamente:**
   ```bash
   flutter uninstall
   ```

2. **Ir a Configuración > Aplicaciones > Buses:**
   - Limpiar almacenamiento/caché
   - Desinstalar completamente
   - Reiniciar el dispositivo

3. **Reinstalar la app:**
   ```bash
   flutter run
   ```

#### C. Verificar permisos en Configuración:
1. Abrir Configuración de Android 15
2. Ir a Aplicaciones > Buses
3. Permisos
4. Verificar que estos permisos aparezcan:
   - ✓ Bluetooth: Permitir
   - ✓ Ubicación: Permitir (requerido para BLE)
   - ✓ Proximidad (si aparece): Permitir

### 4. Verificación del Código

Si después de esto los permisos aún no se solicitan, verifica en tu código que `requestBluetoothPermissions(context)` se llame ANTES de intentar usar Bluetooth.

En tu caso, se llama en el botón de imprimir:
```dart
onPressed: _ticketRendered ? () async {
  await requestBluetoothPermissions(context);  // ✓ Se llama aquí
  final address = await bluetooth_printer.FlutterBluetoothPrinter.selectDevice(context);
  ...
}
```

### 5. Debug (si el problema persiste)

Ejecuta en terminal:
```bash
# Ver todos los permisos del manifest
aapt dump permissions build/app/outputs/bundle/release/app.aab

# O durante el desarrollo
flutter run -v  # para ver logs detallados
```

## Resumen de Cambios

| Archivo | Cambio |
|---------|--------|
| `AndroidManifest.xml` | Actualizado permisos para Android 15 |
| `main.dart` | Mejorado manejo de permisos runtime |
| `pubspec.yaml` | Sin cambios (dependencias OK) |

## Notas Importantes

- Android 15 requiere que BLUETOOTH_SCAN incluya `usesPermissionFlags`
- Los permisos de ubicación son OBLIGATORIOS para BLE scanning en Android 12+
- La app debe solicitar permisos en tiempo de ejecución (no es automático desde el manifest)
- Si el usuario deniega permisos permanentemente, la app le mostrará un botón para ir a Configuración
