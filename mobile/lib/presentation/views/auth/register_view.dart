import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../core/config/mobile_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/retro_ui.dart';

class RegisterView extends ConsumerStatefulWidget {
  const RegisterView({super.key});

  @override
  ConsumerState<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends ConsumerState<RegisterView> {
  String? _selectedRole;
  String _selectedGrade = '5to de primaria';
  String _selectedSubject = 'Matemática';
  bool _isLoading = false;
  String? _error;

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _schoolNameController = TextEditingController();
  final _regionController = TextEditingController();
  final _schoolCodeController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _schoolNameController.dispose();
    _regionController.dispose();
    _schoolCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (MobileConfig.hasSupabase) {
        final isPersonalStudent = _selectedRole == 'personal_student';
        final isSchoolStudent = _selectedRole == 'school_student';
        final result = await ref
            .read(authProvider.notifier)
            .register(
              fullName:
                  '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
              email: _emailController.text,
              password: _passwordController.text,
              role: isPersonalStudent || isSchoolStudent
                  ? 'student'
                  : _selectedRole!,
              studentMode: isPersonalStudent ? 'personal' : 'school',
              grade: isPersonalStudent ? _selectedGrade : '',
              subject: isPersonalStudent ? _selectedSubject : '',
              schoolCode: _schoolCodeController.text,
              schoolName: _schoolNameController.text,
              region: _regionController.text,
            );
        if (!mounted) return;
        if (result == null) {
          setState(() {
            _error =
                ref.read(authProvider).error ?? 'No se pudo crear la cuenta';
          });
          return;
        }
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.deepBackground,
            title: const Text('Registro recibido'),
            content: Text(result),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CONTINUAR'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        final isStudent =
            _selectedRole == 'personal_student' ||
            _selectedRole == 'school_student';
        context.go(
          ref.read(authProvider).isAuthenticated
              ? (isStudent ? '/student-app' : '/lobby')
              : '/login',
        );
        return;
      }
      final client = ApiClient();
      final data = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'password': _passwordController.text,
      };

      if (_selectedRole == 'personal_student') {
        setState(() {
          _error =
              'La cuenta personal requiere la conexión segura de BattleGraph.';
        });
        return;
      }

      final isSchoolStudent = _selectedRole == 'school_student';
      final role = isSchoolStudent ? 'student' : _selectedRole;
      String endpoint;
      if (_selectedRole == 'director') {
        endpoint = '/auth/register/director';
        data['school_name'] = _schoolNameController.text.trim();
        data['region'] = _regionController.text.trim();
      } else {
        endpoint = '/auth/register/$role';
        data['school_code'] = _schoolCodeController.text.trim();
      }

      final response = await client.dio.post(endpoint, data: data);

      if (!mounted) return;

      if (_selectedRole == 'director') {
        final schoolCode = response.data['school_code'] ?? 'BG-XXXX';
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.deepBackground,
            title: const Text(
              'Registro exitoso',
              style: TextStyle(color: AppColors.offWhite),
            ),
            content: Text(
              'Tu código de colegio es:\n$schoolCode\nGuárdalo para tus profesores y alumnos.',
              style: const TextStyle(color: AppColors.gold),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/login');
                },
                child: const Text(
                  'ENTENDIDO',
                  style: TextStyle(color: AppColors.cyan),
                ),
              ),
            ],
          ),
        );
      } else {
        context.go('/login');
      }
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['detail'] ?? 'Error de conexión';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _registerWithGoogle() async {
    if (_selectedRole == null || !MobileConfig.hasSupabase) return;
    final isPersonalStudent = _selectedRole == 'personal_student';
    final isSchoolStudent = _selectedRole == 'school_student';
    if ((isSchoolStudent || _selectedRole == 'professor') &&
        _schoolCodeController.text.trim().length < 3) {
      setState(() => _error = 'Escribe un código de colegio válido.');
      return;
    }
    if (_selectedRole == 'director' &&
        _schoolNameController.text.trim().length < 2) {
      setState(() => _error = 'Escribe el nombre de tu colegio.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final started = await ref
          .read(authProvider.notifier)
          .loginWithGoogle(
            role: isPersonalStudent || isSchoolStudent
                ? 'student'
                : _selectedRole == 'professor'
                ? 'teacher'
                : _selectedRole,
            studentMode: isPersonalStudent ? 'personal' : 'school',
            schoolCode: _schoolCodeController.text,
            schoolName: _schoolNameController.text,
            region: _regionController.text,
            grade: _selectedGrade,
            subject: _selectedSubject,
          );
      if (!mounted || started) return;
      setState(
        () => _error =
            ref.read(authProvider).error ?? 'No se pudo iniciar Google.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildRoleSelection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const HudLabel('SELECCIONA TU ROL', color: AppColors.gold),
        const SizedBox(height: 24),
        _RoleCard(
          title: 'DIRECTOR',
          subtitle: 'Registra tu colegio',
          icon: Icons.shield,
          color: AppColors.gold,
          onTap: () => setState(() => _selectedRole = 'director'),
        ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2),
        const SizedBox(height: 16),
        _RoleCard(
          title: 'PROFESOR',
          subtitle: 'Únete a un colegio',
          icon: Icons.book,
          color: AppColors.cyan,
          onTap: () => setState(() => _selectedRole = 'professor'),
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms).slideX(begin: -0.2),
        const SizedBox(height: 16),
        if (MobileConfig.hasSupabase) ...[
          _RoleCard(
            title: 'ALUMNO · PERSONAL',
            subtitle: 'Cuenta gratuita con una ruta propia',
            icon: Icons.gamepad,
            color: AppColors.oro500,
            onTap: () => setState(() => _selectedRole = 'personal_student'),
          ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2),
          const SizedBox(height: 16),
        ],
        _RoleCard(
          title: 'ALUMNO · COLEGIO',
          subtitle: 'Vincula el código de tu institución',
          icon: Icons.account_balance,
          color: AppColors.brightRed,
          onTap: () => setState(() => _selectedRole = 'school_student'),
        ).animate(delay: 300.ms).fadeIn(duration: 400.ms).slideX(begin: -0.2),
        const SizedBox(height: 32),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text(
            'VOLVER AL LOGIN',
            style: TextStyle(color: AppColors.offWhite),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.offWhite),
                onPressed: () => setState(() => _selectedRole = null),
              ),
              const Expanded(
                child: HudLabel('REGISTRO', color: AppColors.gold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _firstNameController,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: (v) => v!.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _lastNameController,
            decoration: const InputDecoration(labelText: 'Apellido'),
            validator: (v) => v!.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Correo electrónico'),
            validator: (v) => v!.isEmpty ? 'Requerido' : null,
          ),
          if (!MobileConfig.hasSupabase) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Celular'),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Contraseña'),
            validator: (v) => v!.length < 8 ? 'Mínimo 8 caracteres' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirmar contraseña',
            ),
            validator: (v) => v!.isEmpty ? 'Requerido' : null,
          ),
          if (_selectedRole == 'director') ...[
            const SizedBox(height: 24),
            const HudLabel('DATOS DEL COLEGIO', color: AppColors.cyan),
            const SizedBox(height: 12),
            TextFormField(
              controller: _schoolNameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del colegio',
              ),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _regionController,
              decoration: const InputDecoration(labelText: 'Región'),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
          ] else if (_selectedRole == 'personal_student') ...[
            const SizedBox(height: 24),
            const HudLabel('TU RUTA DE APRENDIZAJE', color: AppColors.gold),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedGrade,
              decoration: const InputDecoration(labelText: 'Grado'),
              items:
                  const [
                        '1ro de primaria',
                        '2do de primaria',
                        '3ro de primaria',
                        '4to de primaria',
                        '5to de primaria',
                        '6to de primaria',
                        '1ro de secundaria',
                        '2do de secundaria',
                        '3ro de secundaria',
                        '4to de secundaria',
                        '5to de secundaria',
                      ]
                      .map(
                        (grade) =>
                            DropdownMenuItem(value: grade, child: Text(grade)),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedGrade = value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedSubject,
              decoration: const InputDecoration(labelText: 'Materia inicial'),
              items:
                  const [
                        'Matemática',
                        'Comunicación',
                        'Ciencia y tecnología',
                        'Historia',
                        'General',
                      ]
                      .map(
                        (subject) => DropdownMenuItem(
                          value: subject,
                          child: Text(subject),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedSubject = value);
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Tu avance personal se guarda en tu cuenta y también queda disponible sin conexión.',
              style: TextStyle(color: AppColors.crema500, fontSize: 12),
            ),
          ] else ...[
            const SizedBox(height: 24),
            const HudLabel('DATOS DEL COLEGIO', color: AppColors.cyan),
            const SizedBox(height: 12),
            TextFormField(
              controller: _schoolCodeController,
              maxLength: 8,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Código del colegio',
                hintText: 'BG-XXXX',
              ),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
          ],
          const SizedBox(height: 24),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.brightRed),
                textAlign: TextAlign.center,
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.offWhite,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('REGISTRAR'),
            ),
          ),
          if (MobileConfig.hasSupabase) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _registerWithGoogle,
                icon: const Icon(Icons.login),
                label: const Text('REGISTRAR CON GOOGLE'),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BattleBackdrop(
        intense: true,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: PixelPanel(
                        accent: _selectedRole == null
                            ? AppColors.gold
                            : AppColors.neonPurple,
                        glow: true,
                        child: _selectedRole == null
                            ? _buildRoleSelection()
                            : _buildForm(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(8),
          color: AppColors.panelBackground,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'VcrOsdMono',
                      color: color,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.offWhite,
                      fontFamily: 'VcrOsdMono',
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}
