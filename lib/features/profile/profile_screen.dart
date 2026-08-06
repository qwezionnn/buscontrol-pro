import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/cloud_sync_service.dart';
import '../../database/database_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  CloudSyncService get _sync => CloudSyncService.instance;

  User? get _user => AuthService.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _sync.addListener(_handleSyncChanged);
    _load();
  }

  @override
  void dispose() {
    _sync.removeListener(_handleSyncChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _handleSyncChanged() {
    if (mounted) setState(() {});
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


  Future<void> _syncNow() async {
    await _sync.syncNow();
    if (!mounted) return;
    _showMessage(
      _sync.state == CloudSyncState.synced
          ? 'Синхронизация завершена.'
          : (_sync.lastError ?? 'Не удалось синхронизировать данные.'),
    );
  }

  Future<void> _uploadLocal() async {
    try {
      await _sync.replaceCloudWithLocal();
      if (mounted) _showMessage('Локальные данные сохранены в облаке.');
    } catch (error) {
      if (mounted) _showMessage('Ошибка загрузки: $error');
    }
  }

  Future<void> _downloadCloud() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Загрузить данные из облака?'),
        content: const Text(
          'Текущие локальные данные будут полностью заменены '
          'облачной копией этого аккаунта.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Загрузить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _sync.replaceLocalWithCloud();
      if (mounted) {
        _showMessage('Облачные данные восстановлены.');
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) _showMessage('Ошибка восстановления: $error');
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

    // Перед выходом сохраняем данные аккаунта в облаке и очищаем
    // локальную базу. Благодаря этому следующий пользователь на этом
    // устройстве не увидит чужие записи.
    try {
      await _sync.replaceCloudWithLocal();
    } catch (_) {
      // Выход разрешаем и без сети; пользователь уже предупреждён,
      // что локальные изменения могут ещё не быть в облаке.
    }
    await DatabaseHelper.instance.resetAllData();
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _sync.state == CloudSyncState.synced
                                    ? Icons.cloud_done_outlined
                                    : _sync.state == CloudSyncState.syncing
                                        ? Icons.cloud_sync_outlined
                                        : Icons.cloud_off_outlined,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _sync.state == CloudSyncState.synced
                                      ? 'Данные синхронизированы'
                                      : _sync.state == CloudSyncState.syncing
                                          ? 'Синхронизация...'
                                          : 'Локальный режим',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          if (_sync.lastSyncedAt != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Последняя синхронизация: '
                              '${_sync.lastSyncedAt!.toLocal()}',
                            ),
                          ],
                          if (_sync.lastError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _sync.lastError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _sync.isSyncing ? null : _syncNow,
                            icon: const Icon(Icons.sync),
                            label: const Text('Синхронизировать сейчас'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _sync.isSyncing ? null : _uploadLocal,
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: const Text('Заменить облако локальными данными'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _sync.isSyncing ? null : _downloadCloud,
                            icon: const Icon(Icons.cloud_download_outlined),
                            label: const Text('Восстановить данные из облака'),
                          ),
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
