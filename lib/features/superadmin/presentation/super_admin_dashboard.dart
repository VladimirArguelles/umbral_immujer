import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';

class SuperAdminDashboardPage extends StatelessWidget {
  const SuperAdminDashboardPage({super.key, this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    return SuperAdminDashboard(profile: profile);
  }
}

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key, this.profile});

  final UserProfile? profile;

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  int _currentIndex = 0;
  bool _rlsEnabled = true;
  bool _notificationsEnabled = true;
  bool _maintenanceMode = false;

  Future<void> _handleSignOut() async {
    await SupabaseConfig.client.auth.signOut();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin'),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sin notificaciones pendientes')),
              );
            },
            icon: const Icon(Symbols.notifications),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Symbols.person),
            onSelected: (value) {
              if (value == 'logout') {
                _handleSignOut();
              }
            },
            itemBuilder: (context) => [
              if (widget.profile != null)
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    widget.profile!.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Symbols.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Cerrar sesión'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Sección de Configuración del Sistema
            _buildSystemConfigSection(),
            const SizedBox(height: 16),
            // Sección de Interruptores Operativos
            _buildOperationalSwitchesSection(),
            const SizedBox(height: 16),
            // Sección de Seguridad y Respaldos
            _buildSecuritySection(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Symbols.dashboard),
            label: 'General',
          ),
          BottomNavigationBarItem(icon: Icon(Symbols.school), label: 'Alumnos'),
          BottomNavigationBarItem(
            icon: Icon(Symbols.badge),
            label: 'Profesores',
          ),
          BottomNavigationBarItem(
            icon: Icon(Symbols.military_tech),
            label: 'Coord.',
          ),
          BottomNavigationBarItem(
            icon: Icon(Symbols.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }

  Widget _buildSystemConfigSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configuración del Sistema',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Parámetros institucionales, seguridad de accesos, notificaciones y mantenimiento global.',
            ),
            const SizedBox(height: 16),
            // Campos de configuración
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Nombre de la Plataforma',
              ),
              initialValue: 'UMBRAL IMMUJER',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Ciclo Académico Activo',
              ),
              items: const [
                DropdownMenuItem(
                  value: '2024-B',
                  child: Text('Ciclo 2024-B (Agosto - Diciembre)'),
                ),
                DropdownMenuItem(
                  value: '2025-A',
                  child: Text('Ciclo 2025-A (Enero - Junio)'),
                ),
              ],
              onChanged: (_) {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationalSwitchesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Políticas e Interruptores',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Interruptores
            SwitchListTile(
              title: const Text('Políticas Institucionales y RLS'),
              subtitle: const Text(
                'Reglas de acceso por sede institucional y cifrado en reposo activo.',
              ),
              value: _rlsEnabled,
              onChanged: (val) => setState(() => _rlsEnabled = val),
            ),
            SwitchListTile(
              title: const Text('Notificaciones Push y Alertas'),
              subtitle: const Text(
                'Avisos automáticos a facilitadores y alumnas por WhatsApp/Push.',
              ),
              value: _notificationsEnabled,
              onChanged: (val) => setState(() => _notificationsEnabled = val),
            ),
            SwitchListTile(
              title: const Text('Modo Mantenimiento'),
              subtitle: const Text(
                'Suspender temporalmente ingresos al portal de alumnas.',
              ),
              value: _maintenanceMode,
              onChanged: (val) => setState(() => _maintenanceMode = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seguridad y Respaldos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Snapshot automático
            const Row(
              children: [
                Icon(Symbols.history),
                SizedBox(width: 8),
                Text('Último Snapshot Automático'),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Hoy, 04:00 AM'),
            const SizedBox(height: 16),
            // Sesiones activas
            Row(
              children: [
                const Icon(Symbols.devices),
                const SizedBox(width: 8),
                const Text('Sesiones Super Admin'),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Cerrar Sesiones'),
                    content: const Text(
                      '¿Estás seguro de que deseas cerrar todas las sesiones remotas de Super Admin?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _handleSignOut();
                        },
                        child: const Text('Confirmar'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Symbols.logout),
              label: const Text('Cerrar Todas las Sesiones Remotas'),
            ),
          ],
        ),
      ),
    );
  }
}
