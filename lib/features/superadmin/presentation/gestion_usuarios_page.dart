import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/widgets/skeleton_loader.dart';

class GestionUsuariosPage extends StatefulWidget {
  const GestionUsuariosPage({super.key});

  @override
  State<GestionUsuariosPage> createState() => _GestionUsuariosPageState();
}

class _GestionUsuariosPageState extends State<GestionUsuariosPage> {
  final SupabaseClient _supabase = SupabaseConfig.client;

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _usuarios = [];
  List<Map<String, dynamic>> _filteredUsuarios = [];

  String? _selectedRole; // null means 'Todos'
  final TextEditingController _searchController = TextEditingController();

  String? get _currentUserId => _supabase.auth.currentUser?.id;

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
      List<Map<String, dynamic>> usersList = [];

      try {
        final rpcResponse = await _supabase.rpc('obtener_usuarios_registrados');
        if (rpcResponse is List) {
          usersList = List<Map<String, dynamic>>.from(rpcResponse);
        }
      } catch (_) {
        // Fallback directo a perfiles si el RPC aún no estuviese disponible
        final perfilesResponse = await _supabase
            .from('perfiles')
            .select('id, user_id, nombre_completo, cedula, telefono, correo, email, rol, created_at, avatar_url')
            .order('created_at', ascending: false);

        usersList = List<Map<String, dynamic>>.from(perfilesResponse as List).map((p) {
          return {
            'user_id': p['user_id'] ?? p['id'],
            'email': p['correo'] ?? p['email'] ?? '',
            'nombre_completo': p['nombre_completo'] ?? 'Usuario',
            'cedula': p['cedula'],
            'telefono': p['telefono'],
            'rol': p['rol'] ?? 'alumno',
            'created_at': p['created_at'],
            'last_sign_in_at': null,
            'email_confirmed_at': null,
            'avatar_url': p['avatar_url'],
          };
        }).toList();
      }

      if (mounted) {
        setState(() {
          _usuarios = usersList;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar usuarios: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredUsuarios = _usuarios.where((u) {
        final rawRole = (u['rol'] ?? '').toString().toLowerCase();
        final matchesRole = _selectedRole == null || rawRole == _selectedRole!.toLowerCase();

        final nombre = (u['nombre_completo'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        final cedula = (u['cedula'] ?? '').toString().toLowerCase();
        final telefono = (u['telefono'] ?? '').toString().toLowerCase();

        final matchesQuery = query.isEmpty ||
            nombre.contains(query) ||
            email.contains(query) ||
            cedula.contains(query) ||
            telefono.contains(query);

        return matchesRole && matchesQuery;
      }).toList();
    });
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return 'No registrado';
    try {
      final dt = DateTime.parse(dateVal.toString()).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    } catch (_) {
      return dateVal.toString();
    }
  }

  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'super_admin':
      case 'superadmin':
        return AppTheme.primary;
      case 'coordinador':
      case 'coordinator':
      case 'admin':
      case 'administrador':
        return const Color(0xFF38BDF8); // Sky blue
      case 'profesor':
      case 'teacher':
        return AppTheme.tertiary; // Mint green
      case 'alumno':
      case 'student':
      default:
        return const Color(0xFFFACC15); // Yellow/Amber
    }
  }

  String _getRoleLabel(String? role) {
    switch (role?.toLowerCase()) {
      case 'super_admin':
      case 'superadmin':
        return 'Super Admin';
      case 'coordinador':
      case 'coordinator':
      case 'admin':
      case 'administrador':
        return 'Coordinador';
      case 'profesor':
      case 'teacher':
        return 'Profesor';
      case 'alumno':
      case 'student':
      default:
        return 'Alumno';
    }
  }

  Future<void> _confirmDeleteUser(Map<String, dynamic> user) async {
    final userId = (user['user_id'] ?? user['id']) as String;
    final nombre = user['nombre_completo'] ?? 'Usuario';
    final email = user['email'] ?? '';

    // Seguridad: Evitar que el Super Admin elimine su propia cuenta
    if (userId == _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operación denegada: no puedes eliminar tu propia cuenta de Super Admin en uso.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Symbols.delete_forever, color: AppTheme.errorRed, size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Eliminar Usuario',
                style: TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro de que deseas eliminar permanentemente a este usuario?',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                  if (user['cedula'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Cédula: ${user['cedula']}',
                      style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Esta acción revocará inmediatamente su acceso, eliminando su cuenta autenticada y su perfil en Supabase. No se puede deshacer.',
              style: TextStyle(color: AppTheme.errorRed, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Symbols.delete, size: 18),
            label: const Text('Eliminar Definitivamente'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        try {
          await _supabase.rpc('admin_delete_user', params: {'p_user_id': userId});
        } catch (_) {
          // Fallback directo a perfiles
          await _supabase.from('perfiles').delete().eq('id', userId);
        }

        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Usuario "$nombre" eliminado exitosamente.'),
              backgroundColor: AppTheme.tertiary,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error al eliminar usuario: $e'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    }
  }

  Future<void> _showUserDetailsModal(Map<String, dynamic> user) async {
    final roleColor = _getRoleColor(user['rol'] as String?);
    final roleLabel = _getRoleLabel(user['rol'] as String?);
    final email = user['email'] ?? 'Sin correo';
    final nombre = user['nombre_completo'] ?? 'Usuario';
    final userId = (user['user_id'] ?? user['id']) as String?;
    final isCurrentUser = userId == _currentUserId;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: roleColor.withAlpha(35),
                        foregroundColor: roleColor,
                        radius: 24,
                        child: Text(
                          nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.onSurface,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: roleColor.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: roleColor.withAlpha(80)),
                            ),
                            child: Text(
                              roleLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: roleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: AppTheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: AppTheme.outlineVariant),
              const SizedBox(height: 12),
              _buildDetailItem(Symbols.badge, 'Cédula de Identidad', user['cedula'] ?? 'No registrada'),
              _buildDetailItem(Symbols.mail, 'Correo Electrónico', email),
              _buildDetailItem(Symbols.call, 'Teléfono', user['telefono'] ?? 'No registrado'),
              _buildDetailItem(Symbols.key, 'ID de Cuenta (UUID)', userId ?? '—'),
              _buildDetailItem(Symbols.calendar_today, 'Fecha de Registro', _formatDate(user['created_at'])),
              _buildDetailItem(Symbols.login, 'Último Inicio de Sesión', _formatDate(user['last_sign_in_at'])),
              const SizedBox(height: 20),
              if (!isCurrentUser)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmDeleteUser(user);
                    },
                    icon: const Icon(Symbols.delete, size: 20),
                    label: const Text('Eliminar Usuario Definitivamente', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.outlineVariant),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Symbols.lock, size: 16, color: AppTheme.onSurfaceVariant),
                      SizedBox(width: 8),
                      Text(
                        'Tu cuenta activa de Super Admin (protegida)',
                        style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.onSurface, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Conteos por rol
    final total = _usuarios.length;
    final totalSuperAdmin = _usuarios.where((u) => (u['rol'] ?? '').toString().toLowerCase() == 'super_admin').length;
    final totalCoord = _usuarios.where((u) => ['coordinador', 'coordinator', 'admin'].contains((u['rol'] ?? '').toString().toLowerCase())).length;
    final totalProf = _usuarios.where((u) => ['profesor', 'teacher'].contains((u['rol'] ?? '').toString().toLowerCase())).length;
    final totalAlumnos = _usuarios.where((u) => ['alumno', 'student'].contains((u['rol'] ?? '').toString().toLowerCase())).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainerLow,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestión de Usuarios Registrados',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppTheme.onSurface,
              ),
            ),
            Text(
              'Consulta y eliminación de cuentas autenticadas en Supabase',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back, color: AppTheme.onSurface),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/superadmin');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Symbols.refresh, color: AppTheme.onSurface),
            tooltip: 'Actualizar usuarios',
            onPressed: _loadData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Tarjetas métricas superiores de roles
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              border: const Border(bottom: BorderSide(color: AppTheme.outlineVariant)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatBadge('Total', total.toString(), AppTheme.onSurface, Symbols.group),
                  const SizedBox(width: 8),
                  _buildStatBadge('Super Admins', totalSuperAdmin.toString(), AppTheme.primary, Symbols.shield_person),
                  const SizedBox(width: 8),
                  _buildStatBadge('Coordinadores', totalCoord.toString(), const Color(0xFF38BDF8), Symbols.military_tech),
                  const SizedBox(width: 8),
                  _buildStatBadge('Profesores', totalProf.toString(), AppTheme.tertiary, Symbols.badge),
                  const SizedBox(width: 8),
                  _buildStatBadge('Alumnos', totalAlumnos.toString(), const Color(0xFFFACC15), Symbols.school),
                ],
              ),
            ),
          ),

          // Barra de controles y filtros
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              border: const Border(bottom: BorderSide(color: AppTheme.outlineVariant)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Filtro por Rol
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String?>(
                        initialValue: _selectedRole,
                        dropdownColor: AppTheme.surfaceContainer,
                        style: const TextStyle(color: AppTheme.onSurface),
                        decoration: const InputDecoration(
                          labelText: 'Filtrar por Rol Institucional',
                          prefixIcon: Icon(Symbols.filter_alt, size: 20),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Todos los Roles'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'super_admin',
                            child: Text('Super Admin'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'coordinador',
                            child: Text('Coordinadores'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'profesor',
                            child: Text('Profesores'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'alumno',
                            child: Text('Alumnos'),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedRole = val;
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Búsqueda
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: AppTheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre, correo, cédula o teléfono...',
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
                        'Total: ${_filteredUsuarios.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lista de Usuarios
          Expanded(
            child: _isLoading
                ? const AttendanceSkeleton()
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
                    : _filteredUsuarios.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Symbols.group_off, size: 64, color: AppTheme.outline),
                                const SizedBox(height: 12),
                                Text(
                                  'No se encontraron usuarios con los criterios seleccionados.',
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
                            itemCount: _filteredUsuarios.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final user = _filteredUsuarios[index];
                              final nombre = user['nombre_completo'] ?? 'Usuario';
                              final email = user['email'] ?? 'Sin correo';
                              final cedula = user['cedula'] ?? 'Sin Cédula';
                              final telefono = user['telefono'] ?? 'Sin Teléfono';
                              final roleColor = _getRoleColor(user['rol'] as String?);
                              final roleLabel = _getRoleLabel(user['rol'] as String?);
                              final userId = (user['user_id'] ?? user['id']) as String?;
                              final isCurrentUser = userId == _currentUserId;

                              return Card(
                                elevation: 0,
                                color: AppTheme.surfaceContainerLow,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(color: AppTheme.outlineVariant),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _showUserDetailsModal(user),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: roleColor.withAlpha(35),
                                          foregroundColor: roleColor,
                                          radius: 22,
                                          child: Text(
                                            nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      nombre,
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 15,
                                                        color: AppTheme.onSurface,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: roleColor.withAlpha(30),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: roleColor.withAlpha(80)),
                                                    ),
                                                    child: Text(
                                                      roleLabel,
                                                      style: TextStyle(
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: roleColor,
                                                      ),
                                                    ),
                                                  ),
                                                  if (isCurrentUser) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.surfaceContainerHighest,
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: const Text(
                                                        'Tú',
                                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.onSurfaceVariant),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                email,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppTheme.onSurfaceVariant,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: 12,
                                                runSpacing: 4,
                                                children: [
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Symbols.badge, size: 14, color: AppTheme.outline),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        cedula,
                                                        style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Symbols.call, size: 14, color: AppTheme.outline),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        telefono,
                                                        style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Symbols.calendar_today, size: 14, color: AppTheme.outline),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        _formatDate(user['created_at']),
                                                        style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!isCurrentUser)
                                          IconButton(
                                            icon: const Icon(Symbols.delete, size: 22, color: AppTheme.errorRed),
                                            tooltip: 'Eliminar usuario',
                                            onPressed: () => _confirmDeleteUser(user),
                                          )
                                        else
                                          const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 12),
                                            child: Tooltip(
                                              message: 'Tu cuenta actual de Super Admin (no eliminable)',
                                              child: Icon(Symbols.lock, size: 20, color: AppTheme.outline),
                                            ),
                                          ),
                                      ],
                                    ),
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

  Widget _buildStatBadge(String title, String count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$title: ',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            count,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
