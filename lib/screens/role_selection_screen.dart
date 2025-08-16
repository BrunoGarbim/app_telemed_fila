// =========================================================================
// ARQUIVO: lib/screens/role_selection_screen.dart
// =========================================================================

import 'package:flutter/material.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecione seu Perfil'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Como você gostaria de entrar?',
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_outline_rounded),
              label: const Text('Sou Usuário'),
              onPressed: () {
                Navigator.pushNamed(context, '/login', arguments: 'user');
              },
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon:
                  Icon(Icons.work_outline_rounded, color: colorScheme.primary),
              label: Text(
                'Sou Secretária',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/login', arguments: 'secretary');
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colorScheme.primary, width: 2),
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
