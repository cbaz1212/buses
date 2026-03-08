import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart'
    as bluetooth_printer;

void main() {
  runApp(const MyApp());
}

Future<void> requestBluetoothPermissions(BuildContext context) async {
  // Lista de permisos necesarios para Android 12+/15
  // IMPORTANTE: Android 15 requiere permisos específicos de Bluetooth
  List<Permission> permissionsToRequest = [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
  ];

  // Agregar permisos de ubicación si es necesario (para BLE scanning)
  permissionsToRequest.add(Permission.location);

  // En algunos casos, también puede ser necesario:
  if (await Permission.bluetoothAdvertise.status.isDenied) {
    permissionsToRequest.add(Permission.bluetoothAdvertise);
  }

  Map<Permission, PermissionStatus> statuses = await permissionsToRequest.request();

  // Verificar el estado de cada permiso y mostrar al usuario
  List<String> permisosNegados = [];
  bool hayPermisoPermanentementeDenegado = false;

  if ((statuses[Permission.bluetoothScan]?.isDenied ?? false) ||
      (statuses[Permission.bluetoothScan]?.isRestricted ?? false)) {
    permisosNegados.add("Escaneo de Bluetooth");
  }
  if (statuses[Permission.bluetoothScan]?.isPermanentlyDenied ?? false) {
    hayPermisoPermanentementeDenegado = true;
  }

  if ((statuses[Permission.bluetoothConnect]?.isDenied ?? false) ||
      (statuses[Permission.bluetoothConnect]?.isRestricted ?? false)) {
    permisosNegados.add("Conexión de Bluetooth");
  }
  if (statuses[Permission.bluetoothConnect]?.isPermanentlyDenied ?? false) {
    hayPermisoPermanentementeDenegado = true;
  }

  if ((statuses[Permission.location]?.isDenied ?? false) ||
      (statuses[Permission.location]?.isRestricted ?? false)) {
    permisosNegados.add("Ubicación (requerido para Android 12+)");
  }
  if (statuses[Permission.location]?.isPermanentlyDenied ?? false) {
    hayPermisoPermanentementeDenegado = true;
  }

  // Mostrar alerta al usuario si hay permisos denegados
  if (permisosNegados.isNotEmpty) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Permisos Requeridos"),
          content: Text(
            "Los siguientes permisos son necesarios para conectar a la impresora Bluetooth:\n\n${permisosNegados.join('\n')}\n\nSi los permisos están denegados permanentemente, abre la configuración de la aplicación.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Entendido"),
            ),
            if (hayPermisoPermanentementeDenegado)
              ElevatedButton.icon(
                onPressed: () {
                  openAppSettings();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.settings),
                label: const Text("Ir a Configuración"),
              ),
          ],
        );
      },
    );
  }
}

// =================================================================
// WIDGET PRINCIPAL
// =================================================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expresso',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'ES'), // Inglés (por defecto)
        Locale('es', 'EN'), // Español (necesario para tu calendario)
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 108, 184, 250),
        ),
      ),
      home: const MyHomePage(title: 'Tiquete TransSandona'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // DECLARACIÓN DE TODOS LOS CONTROLADORES Y DATOS
  bluetooth_printer.ReceiptController? controller;
  final _formKey = GlobalKey<FormState>();
  final _destinoKey = GlobalKey<FormFieldState<String>>();
  // Variables para almacenar la fecha y hora seleccionadas
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // ------------------------------------------

  // Controlador para el campo de texto que mostrará la fecha y hora
  final TextEditingController _fechaHoraController = TextEditingController();
  // ... (Otros controladores como _cedulaController, _nombreController, etc.)
  final FocusNode _numeroPuestosFocusNode = FocusNode();

  // CONSTANTES DE TAMAÑO DE FUENTE
  static const double bigFont = 16.0;
  static const double mediumFont = 13.0;
  static const double smallFont = 11.0;

  final TextEditingController _cedulaController = TextEditingController();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _numeroPuestosController = TextEditingController(
    text: '1',
  );
  // Nuevo campo: Valor unitario (texto que acepta solo números)
  final TextEditingController _valorController = TextEditingController();
  int? _puestoSeleccionado = 1;

  // Lista de puestos ya asignados (no disponibles)
  final Set<int> _puestosAsignados = {};
  // bluetooth_printer.BluetoothDevice? _selectedDevice;
  // DATOS PARA ORIGEN/DESTINO
  final List<String> _cities = const [
    'Pasto',
    'San Lorenzo',
    'Ricaurte',
    'Túquerres',
    'Taminango',
    'Policarpa',
    'Unión',
  ];
  String? _selectedOrigen;
  String? _selectedDestino;

  // DATOS DEL TICKET COMPLETADO
  String? _ticketCedula;
  String? _ticketNombre;
  String? _ticketOrigen;
  String? _ticketDestino;
  List<int>? _ticketPuestos;
  String? _ticketPrecio;
  String? _ticketFechaHora;
  String? _ticketId;

  // Control de renderizado del ticket
  bool _ticketRendered = false;

  @override
  void initState() {
    super.initState();
    _numeroPuestosFocusNode.addListener(_handleNumeroPuestosFocusChange);
    // Precargar valor del ticket a 20000
    _valorController.text = '20.000';
    // Precargar fecha y hora actual
    final now = DateTime.now();
    final String formattedDate =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final String formattedTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _fechaHoraController.text = '$formattedDate - $formattedTime';
    _selectedDate = now;
    _selectedTime = TimeOfDay(hour: now.hour, minute: now.minute);
    // Mostrar el modal del formulario al abrir la app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showFormModal();
    });
  }

  // -----------------------------------------------------------------
  // FUNCIÓN QUE SE EJECUTA AL PERDER/GANAR FOCO
  void _handleNumeroPuestosFocusChange() {
    if (!_numeroPuestosFocusNode.hasFocus) {
      if (_numeroPuestosController.text.isEmpty) {
        setState(() {
          _numeroPuestosController.text = '1';
          _numeroPuestosController.selection = TextSelection.fromPosition(
            TextPosition(offset: _numeroPuestosController.text.length),
          );
        });
      }
    }
  }

  // -----------------------------------------------------------------
  // FUNCIÓN: Resetear Controladores del Formulario
  // -----------------------------------------------------------------
  void _resetFormControllers() {
    _cedulaController.clear();
    _nombreController.clear();
    _numeroPuestosController.text = '1';
    _valorController.clear();
    _fechaHoraController.clear();
    _selectedOrigen = null;
    _selectedDestino = null;
    _selectedDate = null;
    _selectedTime = null;
    final disponibles = _getPuestosDisponibles();
    _puestoSeleccionado = disponibles.isNotEmpty ? disponibles.first : 1;
  }

  // -----------------------------------------------------------------
  // FUNCIÓN: Resetear Controladores del Formulario
  // -----------------------------------------------------------------
  void _clearFormControllers() {
    _cedulaController.clear();
    _nombreController.clear();
    _numeroPuestosController.text = '1';
    final disponibles = _getPuestosDisponibles();
    _puestoSeleccionado = disponibles.isNotEmpty ? disponibles.first : 1;
  }

  @override
  void dispose() {
    _cedulaController.dispose();
    _nombreController.dispose();
    _numeroPuestosController.dispose();
    _valorController.dispose();
    _fechaHoraController.dispose();

    _numeroPuestosFocusNode.removeListener(_handleNumeroPuestosFocusChange);
    _numeroPuestosFocusNode.dispose();

    super.dispose();
  }

  // -----------------------------------------------------------------
  // FUNCIÓN: Resetear la aplicación (Nuevo Tiquete)
  // -----------------------------------------------------------------
  void _resetApp() {
    setState(() {
      // Limpiar datos del ticket actual
      _ticketCedula = null;
      _ticketNombre = null;
      _ticketOrigen = null;
      _ticketDestino = null;
      _ticketPuestos = null;
      _ticketPrecio = null;
      _ticketFechaHora = null;
      _ticketId = null;
      _ticketRendered = false; // Resetear flag de renderizado
    });

    _clearFormControllers();
    _showFormModal();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Listo para crear un nuevo tiquete.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // -----------------------------------------------------------------
  // FUNCIÓN AUXILIAR: Devuelve la lista dinámica de Destinos
  // -----------------------------------------------------------------
  List<String> _getDestinoOptions() {
    if (_selectedOrigen == 'Pasto') {
      return _cities.where((city) => city != 'Pasto').toList();
    } else if (_selectedOrigen != null) {
      return ['Pasto'];
    }
    return [];
  }

  // -----------------------------------------------------------------
  // FUNCIÓN AUXILIAR: Devuelve los puestos disponibles (no asignados)
  // -----------------------------------------------------------------
  List<int> _getPuestosDisponibles() {
    return List.generate(
      19,
      (i) => i + 1,
    ).where((puesto) => !_puestosAsignados.contains(puesto)).toList();
  }

  // -----------------------------------------------------------------
  // FUNCIÓN: Mostrar Modal del Formulario
  // -----------------------------------------------------------------
  void _showFormModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return Dialog(
              insetPadding: const EdgeInsets.all(12),
              child: AlertDialog(
                contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                content: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // 1. Cédula
                        _buildCedulaTextField(
                          controller: _cedulaController,
                          labelText: 'Cédula',
                        ),
                        const SizedBox(height: 10),

                        // 2. Nombre
                        _buildRequiredTextField(
                          controller: _nombreController,
                          labelText: 'Nombre',
                        ),
                        const SizedBox(height: 10),

                        // 3. Origen
                        _buildCityFormField(
                          labelText: 'Origen',
                          value: _selectedOrigen,
                          items: _cities,
                          onChanged: (newValue) {
                            setStateDialog(() {
                              _selectedOrigen = newValue;
                              final newDestinoOptions = _getDestinoOptions();
                              if (_selectedDestino != null &&
                                  !newDestinoOptions.contains(
                                    _selectedDestino,
                                  )) {
                                _selectedDestino = null;
                              }
                              if (newDestinoOptions.length == 1 &&
                                  newDestinoOptions.first == 'Pasto') {
                                _selectedDestino = 'Pasto';
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 10),

                        // 4. Destino
                        _buildCityFormField(
                          key: _destinoKey,
                          labelText: 'Destino',
                          value: _selectedDestino,
                          items: _getDestinoOptions(),
                          enabled: _selectedOrigen != null,
                          onChanged: (newValue) {
                            setStateDialog(() {
                              _selectedDestino = newValue;
                            });
                          },
                        ),
                        const SizedBox(height: 10),

                        // 5. Puesto
                        _buildPuestoFormField(setStateDialog),
                        const SizedBox(height: 10),

                        // 6. Número de Puestos
                        _buildNumeroPuestosCounter(),
                        const SizedBox(height: 10),

                        // 7. Valor
                        TextFormField(
                          controller: _valorController,
                          decoration: const InputDecoration(
                            labelText: 'Valor (enteros)',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (val) {
                            final onlyDigits = val.replaceAll(
                              RegExp(r'[^0-9]'),
                              '',
                            );
                            if (onlyDigits.isEmpty) return;

                            // Formatear el valor con separadores de miles sin multiplicar
                            final formatted = onlyDigits.replaceAllMapped(
                              RegExp(r'\B(?=(\d{3})+(?!\d))'),
                              (Match m) => '.',
                            );
                            _valorController.text = formatted;
                            _valorController.selection =
                                TextSelection.fromPosition(
                                  TextPosition(
                                    offset: _valorController.text.length,
                                  ),
                                );
                          },
                        ),
                        const SizedBox(height: 10),

                        // 8. Fecha y Hora
                        TextFormField(
                          controller: _fechaHoraController,
                          readOnly: true,
                          onTap: () => _selectDateTime(context),
                          decoration: const InputDecoration(
                            labelText: 'Fecha y Hora *',
                            suffixIcon: Icon(Icons.calendar_today, size: 20),
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Requerido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _completeFormModal();
                    },
                    child: const Text('Continuar'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // -----------------------------------------------------------------
  // FUNCIÓN: Completar el Formulario Modal
  // -----------------------------------------------------------------
  void _completeFormModal() async {
    if (_formKey.currentState!.validate() &&
        _getPuestosDisponibles().isNotEmpty) {
      final cedula = _cedulaController.text;
      final nombre = _nombreController.text;
      final origen = _selectedOrigen!;
      final destino = _selectedDestino!;
      final puesto = _puestoSeleccionado ?? 0;
      final numeroPuestos = int.tryParse(_numeroPuestosController.text) ?? 1;

      final rawValorText = _valorController.text.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      final unitValue =
          int.tryParse(rawValorText.isEmpty ? '0' : rawValorText) ?? 0;
      final totalValue = unitValue * numeroPuestos;
      final fechaHoraViaje = _fechaHoraController.text;

      final puestosAAsignar = <int>[];

      // Validar puestos - usar lista temporal de asignados sin los puestos previos
      final puestosDisponiblesTemp = List.generate(19, (i) => i + 1)
          .where(
            (puesto) =>
                !_puestosAsignados.contains(puesto) ||
                (_ticketPuestos?.contains(puesto) ?? false),
          )
          .toList();

      for (int i = 0; i < numeroPuestos; i++) {
        final puestoActual = puesto + i;
        if (puestoActual > 19) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay suficientes puestos (máximo 19).'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        if (!puestosDisponiblesTemp.contains(puestoActual)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('El puesto $puestoActual ya está asignado.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        puestosAAsignar.add(puestoActual);
      }

      try {
        final soldPuestos = <int>{...puestosAAsignar}.toList()..sort();

        // Generar ID del tiquete
        final random = Random();
        final randomNumber = random.nextInt(90000) + 10000;
        final tiqueteId = 'FPAS-$randomNumber';

        // Guardar datos del ticket
        setState(() {
          // Remover puestos anteriores de los asignados
          if (_ticketPuestos != null) {
            _puestosAsignados.removeAll(_ticketPuestos!);
          }

          _ticketCedula = cedula;
          _ticketNombre = nombre;
          _ticketOrigen = origen;
          _ticketDestino = destino;
          _ticketPuestos = soldPuestos;
          _ticketPrecio = totalValue.toString();
          _ticketFechaHora = fechaHoraViaje;
          _ticketId = tiqueteId;
          _ticketRendered = false; // Marcar como no renderizado

          // Marcar puestos como asignados
          _puestosAsignados.addAll(puestosAAsignar);
        });

        // Cerrar el modal
        Navigator.of(context).pop();

        if (mounted) {
          setState(() {
            _ticketRendered = true; // Marcar como renderizado
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Puestos asignados: ${puestosAAsignar.join(", ")}'),
            backgroundColor: Colors.green,
          ),
        );
        // Esperar a que el ticket se renderice completamente
        await Future.delayed(const Duration(milliseconds: 1000));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } else {
      String mensaje = '¡Ya no hay puestos!';
      if (_getPuestosDisponibles().isNotEmpty) {
        mensaje = '¡Hay campos requeridos sin llenar!';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
      );
    }
  }

  // -----------------------------------------------------------------
  // WIDGET AUXILIAR: Dropdown de Ciudad
  // -----------------------------------------------------------------
  Widget _buildCityFormField({
    Key? key,
    required String labelText,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    return FormField<String>(
      key: key,
      initialValue: value,
      validator: (val) {
        if (val == null || val.isEmpty) {
          return 'Requerido';
        }
        return null;
      },
      builder: (FormFieldState<String> state) {
        return InputDecorator(
          decoration: InputDecoration(
            labelText: '$labelText *',
            labelStyle: TextStyle(
              color: state.hasError ? Colors.red : Colors.black,
              fontSize: smallFont + 1,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 10,
            ),
            errorText: state.errorText,
            errorStyle: const TextStyle(fontSize: smallFont),
            border: state.hasError
                ? const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2.0),
                  )
                : const OutlineInputBorder(),
            errorBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 2.0),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 2.0),
            ),
          ),
          isEmpty: value == null,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items
                  .map(
                    (city) => DropdownMenuItem<String>(
                      value: city,
                      child: Text(
                        city,
                        style: const TextStyle(fontSize: mediumFont),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (items.isEmpty || !enabled)
                  ? null
                  : (String? newValue) {
                      onChanged(newValue);
                      state.didChange(newValue);
                    },
            ),
          ),
        );
      },
    );
  }

  // -----------------------------------------------------------------
  // WIDGET AUXILIAR: Dropdown de Puesto (con lista dinámica)
  // -----------------------------------------------------------------
  Widget _buildPuestoFormField(StateSetter? setStateDialog) {
    final puestosDisponibles = _getPuestosDisponibles();

    if (puestosDisponibles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'No hay puestos',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: smallFont + 1,
          ),
        ),
      );
    }

    // Si el puesto seleccionado no está disponible, elegir el primero de la lista
    int puestoAMostrar = _puestoSeleccionado ?? puestosDisponibles.first;
    if (!puestosDisponibles.contains(puestoAMostrar)) {
      puestoAMostrar = puestosDisponibles.first;
    }

    return InputDecorator(
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: 'Puesto',
        labelStyle: TextStyle(fontSize: smallFont + 1),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: puestoAMostrar,
          isExpanded: true,
          items: puestosDisponibles.map((puesto) {
            return DropdownMenuItem<int>(
              value: puesto,
              child: Text(
                puesto.toString(),
                style: const TextStyle(fontSize: mediumFont),
              ),
            );
          }).toList(),
          onChanged: (v) {
            setState(() {
              _puestoSeleccionado = v;
            });
            setStateDialog?.call(() {});
          },
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // WIDGET AUXILIAR: Campo Cédula (Solo Números)
  // -----------------------------------------------------------------
  Widget _buildCedulaTextField({
    required TextEditingController controller,
    required String labelText,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: '$labelText *',
        labelStyle: const TextStyle(
          color: Colors.black,
          fontSize: smallFont + 1,
        ),
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 2.0),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 2.0),
        ),
        errorStyle: const TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
          fontSize: smallFont,
        ),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Requerido';
        }
        return null;
      },
    );
  }

  // -----------------------------------------------------------------
  // WIDGET AUXILIAR: Campo de Texto Requerido (General)
  // -----------------------------------------------------------------
  Widget _buildRequiredTextField({
    required TextEditingController controller,
    required String labelText,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: '$labelText *',
        labelStyle: const TextStyle(
          color: Colors.black,
          fontSize: smallFont + 1,
        ),
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 2.0),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 2.0),
        ),
        errorStyle: const TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
          fontSize: smallFont,
        ),
      ),
      keyboardType: TextInputType.text,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Requerido';
        }
        return null;
      },
    );
  }

  // -----------------------------------------------------------------
  // FUNCIÓN: Manejar la selección de Fecha y Hora
  // -----------------------------------------------------------------
  Future<void> _selectDateTime(BuildContext context) async {
    // 1. Mostrar Selector de Fecha
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(), // No se permiten fechas pasadas
      lastDate: DateTime(2030),
      locale: const Locale('es', 'ES'), // Para español
    );

    if (pickedDate != null) {
      // 2. Mostrar Selector de Hora, solo si se seleccionó una fecha
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        // 3. Combinar Fecha y Hora
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          _selectedTime = pickedTime;

          // Formatear el texto para mostrarlo en el TextField
          final date = _selectedDate!;
          final time = _selectedTime!;

          final String formattedDate =
              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
          final String formattedTime =
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

          _fechaHoraController.text = '$formattedDate - $formattedTime';
        });
      }
    }
  }

  // -----------------------------------------------------------------
  // WIDGET AUXILIAR: Campo Número de Puestos con Contador
  // -----------------------------------------------------------------
  Widget _buildNumeroPuestosCounter() {
    return StatefulBuilder(
      builder: (context, setStateLocal) {
        int numeroPuestos = int.tryParse(_numeroPuestosController.text) ?? 1;

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Text(
                  'Número de Puestos',
                  style: TextStyle(
                    fontSize: smallFont + 1,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: numeroPuestos > 1
                        ? () {
                            setStateLocal(() {
                              numeroPuestos--;
                              _numeroPuestosController.text = numeroPuestos
                                  .toString();
                            });
                          }
                        : null,
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Text(
                    numeroPuestos.toString(),
                    style: const TextStyle(
                      fontSize: bigFont + 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      setStateLocal(() {
                        numeroPuestos++;
                        _numeroPuestosController.text = numeroPuestos
                            .toString();
                      });
                    },
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_ticketPuestos != null && _ticketPuestos!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Nuevo Tiquete',
              onPressed: _resetApp,
            ),
        ],
      ),
      body: bluetooth_printer.Receipt(
        builder: (context) => _buildTicketContent(),
        onInitialized: (controller) {
          this.controller = controller;
        },
      ),
      bottomNavigationBar: _ticketPuestos != null && _ticketPuestos!.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_ticketRendered)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Renderizando tiquete...',
                            style: TextStyle(fontSize: smallFont),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _ticketRendered
                              ? () {
                                  // PRIMERO: Remover los puestos anteriores de los asignados
                                  if (_ticketPuestos != null) {
                                    _puestosAsignados.removeAll(
                                      _ticketPuestos!,
                                    );
                                  }

                                  // SEGUNDO: Cargar los valores actuales del ticket en los controladores
                                  _cedulaController.text = _ticketCedula ?? '';
                                  _nombreController.text = _ticketNombre ?? '';
                                  _numeroPuestosController.text =
                                      _ticketPuestos?.length.toString() ?? '1';

                                  // Calcular el valor unitario dividiendo total por número de puestos
                                  final totalPrecio =
                                      int.tryParse(_ticketPrecio ?? '0') ?? 0;
                                  final numPuestos =
                                      _ticketPuestos?.length ?? 1;
                                  final valorUnitario = numPuestos > 0
                                      ? totalPrecio ~/ numPuestos
                                      : 0;
                                  final valorFormatted = valorUnitario
                                      .toString()
                                      .replaceAllMapped(
                                        RegExp(r'\B(?=(\d{3})+(?!\d))'),
                                        (Match m) => '.',
                                      );
                                  _valorController.text = valorFormatted;

                                  _fechaHoraController.text =
                                      _ticketFechaHora ?? '';
                                  _selectedOrigen = _ticketOrigen;
                                  _selectedDestino = _ticketDestino;
                                  if (_ticketPuestos != null &&
                                      _ticketPuestos!.isNotEmpty) {
                                    _puestoSeleccionado = _ticketPuestos!.first;
                                  }

                                  setState(() {
                                    _ticketCedula = null;
                                    _ticketNombre = null;
                                    _ticketOrigen = null;
                                    _ticketDestino = null;
                                    _ticketPuestos = null;
                                    _ticketPrecio = null;
                                    _ticketFechaHora = null;
                                    _ticketId = null;
                                    _ticketRendered = false;
                                  });
                                  // Resetear solo el estado del formulario para limpiar errores
                                  _formKey.currentState?.reset();
                                  _showFormModal();
                                }
                              : null,
                          icon: const Icon(Icons.edit),
                          label: const Text('Regresar'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _ticketRendered
                              ? () async {
                                  await requestBluetoothPermissions(context);
                                  final address =
                                      await bluetooth_printer
                                          .FlutterBluetoothPrinter.selectDevice(
                                        context,
                                      );

                                  if (address != null) {
                                    await controller?.print(
                                      address: address.address,
                                      keepConnected: true,
                                      addFeeds: 4,
                                    );
                                    // Mostrar el formulario nuevamente después de imprimir
                                    if (mounted) {
                                      _resetApp();
                                    }
                                  } else {
                                    throw Exception("No funciono..!.");
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.print),
                          label: const Text('Imprimir'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : null,
    );
  }
  // -----------------------------------------------------------------
  // WIDGET AUXILIAR: Contenido del Ticket
  // -----------------------------------------------------------------
  Widget _buildTicketContent() {
    if (_ticketPuestos == null || _ticketPuestos!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No hay tiquete para mostrar',
              style: TextStyle(fontSize: bigFont + 2, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _resetFormControllers();
                _showFormModal();
              },
              child: const Text('Crear Nuevo Tiquete'),
            ),
          ],
        ),
      );
    }

    final puestosDisplay = _ticketPuestos!.join(', ');
    final valorTotal = int.tryParse(_ticketPrecio!) ?? 0;
    final valorUnitarioWithSeparator =
        (valorTotal ~/ (_ticketPuestos?.length ?? 1))
            .toString()
            .replaceAllMapped(
              RegExp(r'\B(?=(\d{3})+(?!\d))'),
              (Match m) => '.',
            );
    final valorWithSeparator = valorTotal.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (Match m) => '.',
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // CABECERA CON LOGO
          const Text(
            'TransSandona S.A ',
            style: TextStyle(fontSize: bigFont, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          const Text('891.200.297-1', style: TextStyle(fontSize: mediumFont)),
          const Divider(height: 16, thickness: 1),

          // TIQUETE Y DATOS BÁSICOS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TIQUETE:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: bigFont - 1,
                ),
              ),
              Text(
                _ticketId ?? '',
                style: const TextStyle(fontSize: bigFont - 1),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Fecha viaje: ${_ticketFechaHora ?? ''}',
            style: const TextStyle(fontSize: mediumFont),
          ),
          const SizedBox(height: 6),
          const Text(
            'Vehículo: SAV119 # 196',
            style: TextStyle(fontSize: mediumFont),
          ),
          const SizedBox(height: 6),
          Text(
            'Valor: \$$valorUnitarioWithSeparator',
            style: const TextStyle(fontSize: bigFont),
          ),
          if (_ticketPuestos!.length > 1)
            Text(
              'Total: \$$valorWithSeparator',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: bigFont,
              ),
            ),
          const Divider(height: 16, thickness: 1),

          // PUESTOS
          const Text(
            'Puesto:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: bigFont),
          ),
          Text(
            '[$puestosDisplay]',
            style: const TextStyle(fontSize: mediumFont),
          ),
          const Divider(height: 16, thickness: 1),

          // RUTA
          Text(
            'Origen Destino: ${(_ticketOrigen ?? '').toUpperCase()}-${(_ticketDestino ?? '').toUpperCase()}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: bigFont - 1,
            ),
            textAlign: TextAlign.center,
          ),
          const Text('LÍNEA MICROBUS', style: TextStyle(fontSize: mediumFont)),
          const Divider(height: 16, thickness: 1),

          // ADQUIRENTE
          const Text(
            'ADQUIRENTE',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: mediumFont,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nombre: ${_ticketNombre ?? ''}',
            style: const TextStyle(
              fontSize: mediumFont,
            ),
          ),
          Text(
            'Cédula: ${_ticketCedula ?? ''}',
            style: const TextStyle(
              fontSize: mediumFont,
            ),
          ),
          // QR REAL
          Container(
            padding: const EdgeInsets.all(1),
            margin: const EdgeInsets.symmetric(vertical: 1),
            color: Colors.white,
            child: QrImageView(
              data:
                  'https://drive.google.com/file/d/15ED0epFpA9Wlcr28KbPfAm18KA4Z5fiL/view?usp=drivesdk',
              version: QrVersions.auto,
              size: 120,
              gapless: true,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Debe presentarse antes de salida. No se hacen devoluciones. Para aplazar el tiquete, se debe presentar una hora antes de la salida.',
            style: TextStyle(fontSize: smallFont),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Elaboró: YAMID PANTOJA',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: smallFont + 1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          const Text(
            'Terminal de Transportes - Contacto: 3107148450',
            style: TextStyle(fontSize: smallFont - 1),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
