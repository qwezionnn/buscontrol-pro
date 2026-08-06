import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  User? get _user => AuthService.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await AuthService.instance.loadProfile();
      final metadataName =
          _user?.userMetadata?['display_name']?.toString() ?? '';
      _nameController.text =
          profile?['display_name']?.toString() ?? metadataName;
    } catch (_) {
      _nameController.text =
          _user?.userMetadata?['display_name']?.toString() ?? '';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().length < 2) {
      _showMessage('Введите имя.');
      return;
    }

    setState(() => _saving = true);
    try {
      await AuthService.instance.updateDisplayName(
        _nameController.text,
      );
      if (mounted) _showMessage('Профиль сохранён.');
    } on AuthException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (error) {
      if (mounted) _showMessage('Не удалось сохранить профиль: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text(
          'Локальные данные останутся на устройстве. '
          'Для доступа к облачному профилю потребуется войти снова.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await AuthService.instance.signOut();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = _user?.email ?? 'Почта не указана';

    return Scaffold(
      appBar: AppBar(title: const Text('Облачный профиль')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 34,
                            child: Text(
                              (_nameController.text.trim().isEmpty
                                      ? email
                                      : _nameController.text.trim())
                                  .characters
                                  .first
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            email,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          const Text('Supabase Cloud'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Имя',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_done_outlined),
                    label: const Text('Сохранить профиль'),
                  ),
                  const SizedBox(height: 28),
                  OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Выйти из аккаунта'),
                  ),
                ],
              ),
      ),
    );
  }
}
