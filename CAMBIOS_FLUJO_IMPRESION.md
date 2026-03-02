# Cambios en el Flujo de Impresión

## Resumen de cambios implementados

El flujo de la aplicación ha sido modificado para **mostrar una vista previa antes de imprimir**. Esto soluciona el problema de que la impresión se cortaba porque ahora el usuario puede:

1. ✅ Llenar el formulario
2. ✅ Ver una previa completa del ticket
3. ✅ Editar si algo no está correcto
4. ✅ Imprimir cuando esté seguro

## Flujo anterior ❌

```
Formulario → Imprimir → Puestos vendidos (aunque falle la impresión)
```

## Flujo nuevo ✅

```
Formulario → [Botón "Siguiente"] → Vista Previa del Ticket
                                        ↓
                    ┌───────────────────┼───────────────────┐
                    ↓                   ↓                   ↓
              [Editar]            [Imprimir]          [Cancelar]
                  ↓                   ↓                   ↓
            Volver al          Confirmar venta        Volver a
            formulario          Asignar puestos       intentar
                              Limpiar formulario
```

## Cambios en el código

### 1. **Nuevas variables de estado** (línea 150-154)
```dart
bool _showingTicketPreview = false;  // Indica si estamos en previa
List<int> _puestosAProcesar = [];     // Puestos pendientes de confirmar
```

### 2. **Botón del diálogo cambió** (línea ~965)
- **Antes**: Icono de impresora (Icons.print) → Ejecutaba `_printDocument()`
- **Ahora**: Icono de flecha (Icons.arrow_forward) → Ejecuta `_goToTicketPreview()`

### 3. **Nueva función `_goToTicketPreview()`** (línea 268)
- Valida el formulario
- Prepara los datos del ticket
- Guarda los puestos en `_puestosAProcesar`
- Establece `_showingTicketPreview = true`
- **No imprime todavía**

### 4. **Nueva función `_editTicket()`** (línea 360)
- Permite volver al formulario desde la previa
- Limpia la previa pero mantiene los datos del formulario
- Útil para corregir datos antes de confirmar

### 5. **Nueva función `_cancelTicketPreview()`** (línea 372)
- Cancela completamente la operación
- Limpia todo: previa, puestos pendientes, datos del ticket

### 6. **Función `_printDocument()` simplificada** (línea 250)
- Ahora solo se llama desde la vista previa
- Ejecuta `_performPrint()` con los puestos guardados

### 7. **Función `_performPrint()` actualizada** (línea 383)
- **Antes**: Limpiaba/confirmaba la venta ANTES de imprimir
- **Ahora**: **Solo después de impresión exitosa**:
  - Limpia el formulario
  - Asigna los puestos
  - Resetea la previa
  - Muestra mensaje de éxito

### 8. **Vista principal actualizada** (línea ~1120)
- Detecta si estamos en previa (`_showingTicketPreview`)
- **En previa**: Muestra ticket + 3 botones (Editar, Imprimir, Cancelar)
- **Sin previa**: Muestra el mensaje "No hay ticket para imprimir"

## Beneficios

✅ **No se pierden datos**: Si algo falla al imprimir, puede reintentar  
✅ **Control total**: Usuario ve exactamente qué se va a imprimir  
✅ **Edición fácil**: Puede corregir datos sin perder formulario  
✅ **Impresión completa**: Con más tiempo de renderizado visible  
✅ **Confirmación real**: Puestos solo se venden cuando impresión es exitosa

## Para probar

1. Llenar el formulario completamente
2. Hacer clic en el botón de flecha (Siguiente)
3. Ver la previa completa del ticket
4. Usar los botones para:
   - **Editar**: Volver a cambiar datos
   - **Imprimir**: Imprimir cuando esté listo
   - **Cancelar**: Descartar sin hacer nada
