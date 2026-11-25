import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../shared/widgets/async_panel.dart';
import '../../../shared/widgets/empty_state.dart';

class AccessGate extends ConsumerWidget {
  const AccessGate({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(startupErrorProvider);
    if (error != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Conexión pendiente',
        message: error,
      );
    }
    final client = ref.watch(supabaseClientProvider);
    ref.watch(authStateProvider);
    if (client == null) return child;
    if (client.auth.currentSession == null) return const _LoginForm();
    return AsyncPanel(
      value: ref.watch(profileProvider),
      onRetry: () => ref.invalidate(profileProvider),
      builder: (profile) => profile == null
          ? const EmptyState(
              icon: Icons.lock_person_outlined,
              title: 'Tu acceso está pendiente',
              message:
                  'Solicita al administrador del concilio que habilite tu cuenta.',
            )
          : child,
    );
  }
}

class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm();
  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(supabaseClientProvider)!
          .auth
          .signInWithPassword(
            email: _email.text.trim(),
            password: _password.text,
          );
    } on AuthException {
      if (mounted) {
        setState(
          () => _error =
              'No pudimos iniciar sesión. Revisa tu correo y contraseña.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No hay conexión. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.waving_hand_outlined, size: 38),
                const SizedBox(height: 16),
                Text(
                  'Bienvenido a Dreamrs',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ingresa con la cuenta habilitada por tu concilio.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                  ),
                  validator: (value) => value == null || !value.contains('@')
                      ? 'Ingresa un correo válido.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Ingresa tu contraseña.'
                      : null,
                  onFieldSubmitted: (_) {
                    if (!_busy) _submit();
                  },
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Ingresando…' : 'Iniciar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
