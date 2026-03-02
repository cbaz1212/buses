# Guía de Uso - Sistema de Impresión de Tiquetes

## Flujo Completo

### Paso 1: Llenar el Formulario
El usuario verá la pantalla principal con los siguientes campos:

- **Cédula** (obligatorio, solo números)
- **Nombre** (obligatorio)
- **Origen** (obligatorio, dropdown)
- **Destino** (obligatorio, dropdown dinámico según origen)
- **Puesto** (dropdown con puestos disponibles)
- **Número de Puestos** (obligatorio, mínimo 1)
- **Valor** (en pesos)
- **Fecha y Hora del Viaje** (obligatorio, selector con calendario y hora)

### Paso 2: Vista Previa
Al presionar "Vista Previa & Imprimir":

1. Se validan todos los campos
2. Se verifica que haya puestos disponibles
3. Se abre la pantalla de **vista previa del tiquete**
4. El usuario puede ver:
   - Logo/Encabezado de la empresa
   - ID del tiquete (generado aleatoriamente)
   - Puestos vendidos
   - Fecha y hora de salida
   - Ruta (origen - destino)
   - Valor total
   - Datos del adquirente (nombre y cédula)
   - QR
   - Pie de página

### Paso 3: Confirmación
El usuario tiene dos opciones:

- **"Imprimir Ahora"**: Confirma la impresión
- **"Cancelar"**: Vuelve al formulario

### Paso 4: Selección de Impresora
Si presiona "Imprimir Ahora":

1. Se abre un diálogo para seleccionar la impresora Bluetooth
2. Se valida la conexión
3. Se envía el tiquete a imprimir

### Paso 5: Finalización
Una vez impreso:

1. El puesto se marca como asignado (no disponible para otro cliente)
2. Se limpian los campos del formulario (excepto origen y destino)
3. El número de puestos vuelve a 1
4. Los puestos disponibles en el dropdown se actualizan

## Funcionalidades Importantes

### Vista Previa
- Muestra exactamente lo que se va a imprimir
- Permite al usuario revisar antes de gastar papel
- Puede cancelar si hay un error

### Validaciones
- Todos los campos obligatorios deben estar llenos
- La cédula solo acepta números
- El número de puestos debe ser mayor a 0
- Los puestos consecutivos se verifican automáticamente
- No se permite exceder el puesto 19

### Puestos Consecutivos
- Si selecciona puesto 5 y número de puestos 3, se asignan puestos 5, 6, 7
- Si alguno ya está ocupado, muestra error
- Se valida antes de ir a la vista previa

### Reiniciar Viaje
- Botón "Reiniciar viaje" en la pantalla principal
- Libera todos los puestos
- Limpia el formulario
- Regresa a estado inicial

## Impresora

### Requisitos
- Impresora térmica compatible con ESC/POS
- Conexión Bluetooth habilitada
- Permisos de Bluetooth configurados en Android

### Formato de Impresión
- Ancho: 80mm (estándar)
- Formato: ESC/POS nativo (no es screenshot)
- Incluye texto, líneas divisoras y QR

### Datos que se Imprimen
1. Nombre y NIT de la empresa
2. ID único del tiquete
3. Puestos vendidos
4. Fecha y hora de salida
5. Ruta completa
6. Valor del tiquete
7. Datos del pasajero (nombre y cédula)
8. QR con enlace a detalles
9. Nombre del taquillero

## Troubleshooting

### "No hay puestos disponibles"
- Presione "Reiniciar viaje" para liberar todos los puestos
- O reinicie la aplicación

### "El puesto X ya está asignado"
- Ese puesto ya fue vendido
- Seleccione otro puesto en el dropdown

### No se puede seleccionar impresora
- Verifique que Bluetooth esté encendido
- Compruebe que la impresora esté pareada
- Reinicie la aplicación

### La impresora no recibe el tiquete
- Verifique la conexión Bluetooth
- Intente de nuevo
- Compruebe que la impresora sea compatible con ESC/POS
