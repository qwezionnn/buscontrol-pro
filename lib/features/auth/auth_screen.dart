import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _registerMode = false;
  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Введите электронную почту';
    if (!email.contains('@') || !email.contains('.')) {
      return 'Введите корректный адрес почты';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Введите пароль';
    if (password.length < 6) return 'Минимум 6 символов';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      if (_registerMode) {
        final response = await AuthService.instance.signUp(
          email: _emailController.text,
          password: _passwordController.text,
          displayName: _nameController.text,
        );

        if (!mounted) return;

        if (response.session == null) {
          _showMessage(
            'Аккаунт создан. Подтвердите почту и затем войдите.',
          );
        } else {
          _showMessage('Аккаунт создан. Добро пожаловать!');
        }
      } else {
        await AuthService.instance.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
    } on AuthException catch (error) {
      if (mounted) _showMessage(_friendlyAuthError(error.message));
    } catch (error) {
      if (mounted) _showMessage('Не удалось выполнить вход: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final controller = TextEditingController(
      text: _emailController.text.trim(),
    );

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Восстановление пароля'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Электронная почта',
            prefixIcon: Icon(Icons.mail_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('Отправить'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (email == null || !mounted) return;

    setState(() => _loading = true);

    try {
      final redirectTo = kIsWeb
          ? '${Uri.base.origin}${Uri.base.path}'
          : 'io.supabase.buscontrolpro://reset-password';

      await AuthService.instance.sendPasswordReset(
        email: email,
        redirectTo: redirectTo,
      );

      if (mounted) {
        _showMessage('Ссылка для восстановления отправлена на почту.');
      }
    } on AuthException catch (error) {
      if (mounted) _showMessage(_friendlyAuthError(error.message));
    } catch (error) {
      if (mounted) _showMessage('Не удалось отправить письмо: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Неверная почта или пароль.';
    }
    if (lower.contains('user already registered')) {
      return 'Пользователь с такой почтой уже зарегистрирован.';
    }
    if (lower.contains('password')) {
      return 'Проверьте пароль. Он должен содержать минимум 6 символов.';
    }
    if (lower.contains('email')) {
      return 'Проверьте адрес электронной почты.';
    }
    return message;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(
                          Icons.directions_bus_rounded,
                          size: 40,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'BusControl PRO',
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _registerMode
                            ? 'Создайте личный облачный аккаунт'
                            : 'Войдите, чтобы открыть свои данные',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 28),
                      if (_registerMode) ...[
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.name],
                          decoration: const InputDecoration(
                            labelText: 'Ваше имя',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if ((value?.trim().length ?? 0) < 2) {
                              return 'Введите имя';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Электронная почта',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: [
                          _registerMode
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        onFieldSubmitted: (_) => _loading ? null : _submit(),
                        decoration: InputDecoration(
                          labelText: 'Пароль',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: _validatePassword,
                      ),
                      if (!_registerMode)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading ? null : _resetPassword,
                            child: const Text('Забыли пароль?'),
                          ),
                        )
                      else
                        const SizedBox(height: 18),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _registerMode
                                      ? 'Создать аккаунт'
                                      : 'Войти',
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () {
                                setState(() {
                                  _registerMode = !_registerMode;
                                });
                              },
                        child: Text(
                          _registerMode
                              ? 'Уже есть аккаунт? Войти'
                              : 'Нет аккаунта? Зарегистрироваться',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'У каждого пользователя отдельные автобусы, '
                        'кредиты, заказы и финансы.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
