import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

class GestionAlumnosPage extends StatefulWidget {
  const GestionAlumnosPage({super.key});

  @override
  State<GestionAlumnosPage> createState() => _GestionAlumnosPageState();
}

class _GestionAlumnosPageState extends State<GestionAlumnosPage> {
  final SupabaseClient _supabase = SupabaseConfig.client;

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _cursos = [];
  List<Map<String, dynamic>> _alumnos = [];
  List<Map<String, dynamic>> _filteredAlumnos = [];

  String? _selectedCurso; // null means 'Todos'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cursosResponse = await _supabase
          .from('cursos')
          .select('id, nombre')
          .order('nombre');

      final alumnosResponse = await _supabase
          .from('alumnos')
          .select('id, nombre_completo, cedula, telefono, correo, curso, user_id, created_at')
          .order('nombre_completo');

      if (mounted) {
        setState(() {
          _cursos = List<Map<String, dynamic>>.from(cursosResponse as List);
          _alumnos = List<Map<String, dynamic>>.from(alumnosResponse as List);
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar datos: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredAlumnos = _alumnos.where((al) {
        final matchesCurso = _selectedCurso == null ||
            (al['curso'] != null &&
                al['curso'].toString().toLowerCase() == _selectedCurso!.toLowerCase());

        final nombre = (al['nombre_completo'] ?? '').toString().toLowerCase();
        final cedula = (al['cedula'] ?? '').toString().toLowerCase();
        final telefono = (al['telefono'] ?? '').toString().toLowerCase();

        final matchesQuery = query.isEmpty ||
            nombre.contains(query) ||
            cedula.contains(query) ||
            telefono.contains(query);

        return matchesCurso && matchesQuery;
      }).toList();
    });
  }

  Future<void> _showAddAlumnoDialog() async {
    final nombreCtrl = TextEditingController();
    final cedulaCtrl = TextEditingController();
    final telfCtrl = TextEditingController();
    final correoCtrl = TextEditingController();
    String? selectedCourse = _selectedCurso ?? (_cursos.isNotEmpty ? _cursos.first['nombre'] as String? : null);

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Añadir Nuevo Alumno',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombreCtrl,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Nombre Completo *',
                      prefixIcon: Icon(Symbols.person),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: cedulaCtrl,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Cédula de Identidad *',
                      prefixIcon: Icon(Symbols.badge),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: telfCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      prefixIcon: Icon(Symbols.call),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: correoCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Correo Electrónico',
                      prefixIcon: Icon(Symbols.mail),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCourse,
                    dropdownColor: AppTheme.surfaceContainer,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Curso de Origen / Asignado',
                      prefixIcon: Icon(Symbols.school),
                    ),
                    items: _cursos.map((c) {
                      final n = c['nombre'] as String;
                      return DropdownMenuItem<String>(value: n, child: Text(n));
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedCourse = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final cleanCedula = cedulaCtrl.text.trim().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');
                  final cleanEmail = correoCtrl.text.trim().isNotEmpty ? correoCtrl.text.trim() : null;

                  await _supabase.from('alumnos').insert({
                    'nombre_completo': nombreCtrl.text.trim(),
                    'cedula': cleanCedula,
                    'telefono': telfCtrl.text.trim().isNotEmpty ? telfCtrl.text.trim() : null,
                    'correo': cleanEmail,
                    'curso': selectedCourse,
                  });

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Alumno añadido con éxito.')),
                    );
                    _loadData();
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error al añadir: $e'), backgroundColor: AppTheme.errorRed),
                    );
                  }
                }
              },
              icon: const Icon(Symbols.check),
              label: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditAlumnoDialog(Map<String, dynamic> alumno) async {
    final nombreCtrl = TextEditingController(text: alumno['nombre_completo'] ?? '');
    final cedulaCtrl = TextEditingController(text: alumno['cedula'] ?? '');
    final telfCtrl = TextEditingController(text: alumno['telefono'] ?? '');
    final correoCtrl = TextEditingController(text: alumno['correo'] ?? '');
    String? selectedCourse = alumno['curso'] as String?;

    // Asegurar que si el curso ya no está en la lista activa, se pueda seleccionar igual
    if (selectedCourse != null && !_cursos.any((c) => c['nombre'] == selectedCourse)) {
      _cursos.add({'id': 'custom', 'nombre': selectedCourse});
    }

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Editar Alumno',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombreCtrl,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Nombre Completo *',
                      prefixIcon: Icon(Symbols.person),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: cedulaCtrl,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Cédula de Identidad *',
                      prefixIcon: Icon(Symbols.badge),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: telfCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      prefixIcon: Icon(Symbols.call),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: correoCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Correo Electrónico',
                      prefixIcon: Icon(Symbols.mail),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCourse,
                    dropdownColor: AppTheme.surfaceContainer,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Curso de Origen / Asignado',
                      prefixIcon: Icon(Symbols.school),
                    ),
                    items: _cursos.map((c) {
                      final n = c['nombre'] as String;
                      return DropdownMenuItem<String>(value: n, child: Text(n));
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedCourse = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final cleanCedula = cedulaCtrl.text.trim().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');
                  final cleanEmail = correoCtrl.text.trim().isNotEmpty ? correoCtrl.text.trim() : null;

                  await _supabase.from('alumnos').update({
                    'nombre_completo': nombreCtrl.text.trim(),
                    'cedula': cleanCedula,
                    'telefono': telfCtrl.text.trim().isNotEmpty ? telfCtrl.text.trim() : null,
                    'correo': cleanEmail,
                    'curso': selectedCourse,
                    'updated_at': DateTime.now().toIso8601String(),
                  }).eq('id', alumno['id']);

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Cambios guardados con éxito.')),
                    );
                    _loadData();
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error al guardar: $e'), backgroundColor: AppTheme.errorRed),
                    );
                  }
                }
              },
              icon: const Icon(Symbols.check),
              label: const Text('Guardar Cambios'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAlumno(Map<String, dynamic> alumno) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar Eliminación', style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold)),
        content: Text(
          '¿Estás seguro de que deseas eliminar al alumno "${alumno['nombre_completo']}" (C.I. ${alumno['cedula']})?\n\nEsta acción no se puede deshacer.',
          style: const TextStyle(color: AppTheme.onSurface),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase.from('alumnos').delete().eq('id', alumno['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alumno eliminado correctamente.')),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: AppTheme.errorRed),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainerLow,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestión de Alumnos',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.onSurface,
              ),
            ),
            Text(
              'Super Admin • Filtrado, edición y registro de alumnas',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            tooltip: 'Guardar y Sincronizar Cambios',
            icon: const Icon(Symbols.sync, color: AppTheme.primary),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Barra de controles y filtros superiores
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              border: Border(bottom: BorderSide(color: AppTheme.outlineVariant)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Selector de Curso con Filtro
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String?>(
                        initialValue: _selectedCurso,
                        dropdownColor: AppTheme.surfaceContainer,
                        style: const TextStyle(color: AppTheme.onSurface),
                        decoration: const InputDecoration(
                          labelText: 'Filtrar por Curso',
                          prefixIcon: Icon(Symbols.filter_alt, size: 20),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Todos los Cursos'),
                          ),
                          ..._cursos.map((c) {
                            final n = c['nombre'] as String;
                            return DropdownMenuItem<String?>(value: n, child: Text(n));
                          }),
                        ],
                        onChanged: (val) {
                          _selectedCurso = val;
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Botón Añadir Alumno
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _showAddAlumnoDialog,
                      icon: const Icon(Symbols.person_add, size: 20),
                      label: const Text('Añadir Alumno'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Barra de Búsqueda por Texto
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: AppTheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre, cédula o teléfono...',
                          prefixIcon: const Icon(Symbols.search, size: 20),
                          isDense: true,
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Symbols.close, size: 18),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Chip(
                      backgroundColor: AppTheme.surfaceContainer,
                      label: Text(
                        'Total: ${_filteredAlumnos.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Cuerpo de la Lista
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Symbols.error, color: AppTheme.errorRed, size: 48),
                            const SizedBox(height: 12),
                            Text(_errorMessage!, style: const TextStyle(color: AppTheme.errorRed)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadData, child: const Text('Reintentar')),
                          ],
                        ),
                      )
                    : _filteredAlumnos.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Symbols.school, size: 64, color: AppTheme.outline),
                                const SizedBox(height: 12),
                                Text(
                                  'No hay alumnos registrados con estos criterios.',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.onSurfaceVariant,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredAlumnos.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final al = _filteredAlumnos[index];
                              final nombre = al['nombre_completo'] ?? 'Sin Nombre';
                              final cedula = al['cedula'] ?? 'Sin Cédula';
                              final telefono = al['telefono'] ?? 'Sin Teléfono';
                              final correo = al['correo'] ?? 'Sin Correo';
                              final curso = al['curso'] ?? 'Sin Curso Asignado';

                              return Card(
                                elevation: 0,
                                color: AppTheme.surfaceContainerLow,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(color: AppTheme.outlineVariant),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppTheme.primaryContainer.withAlpha(50),
                                        foregroundColor: AppTheme.primary,
                                        radius: 22,
                                        child: Text(
                                          nombre.isNotEmpty ? nombre[0].toUpperCase() : 'A',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              nombre,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: AppTheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 4,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Symbols.badge, size: 14, color: AppTheme.onSurfaceVariant),
                                                    const SizedBox(width: 4),
                                                    Text(cedula, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                                                  ],
                                                ),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Symbols.call, size: 14, color: AppTheme.onSurfaceVariant),
                                                    const SizedBox(width: 4),
                                                    Text(telefono, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                                                  ],
                                                ),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Symbols.mail, size: 14, color: AppTheme.onSurfaceVariant),
                                                    const SizedBox(width: 4),
                                                    Text(correo, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppTheme.tertiary.withAlpha(30),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'Curso: $curso',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.tertiary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Botones de acción: Editar y Eliminar
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Symbols.edit, color: AppTheme.primary, size: 20),
                                            tooltip: 'Editar Alumno',
                                            onPressed: () => _showEditAlumnoDialog(al),
                                          ),
                                          IconButton(
                                            icon: const Icon(Symbols.delete, color: AppTheme.errorRed, size: 20),
                                            tooltip: 'Eliminar Alumno',
                                            onPressed: () => _confirmDeleteAlumno(al),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
