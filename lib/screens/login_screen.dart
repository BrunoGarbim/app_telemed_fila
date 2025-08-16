// =========================================================================
// ARQUIVO: lib/screens/login_screen.dart (VERSÃO FINAL E SEGURA)
// =========================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _performLogin(bool intendedAsSecretary) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String emailToLogin;
      final firestore = FirebaseFirestore.instance;

      // ETAPA 1: DETERMINAR O EMAIL PARA AUTENTICAÇÃO
      if (intendedAsSecretary) {
        emailToLogin = _loginController.text.trim();
      } else {
        final userQuery = await firestore
            .collection('users')
            .where('cpf', isEqualTo: _loginController.text.trim())
            .limit(1)
            .get();

        if (userQuery.docs.isEmpty) {
          _showErrorSnackBar('CPF não encontrado ou inválido.');
          setState(() => _isLoading = false);
          return;
        }
        emailToLogin = userQuery.docs.first.data()['email'];
      }

      // ETAPA 2: AUTENTICAR NO FIREBASE AUTH
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailToLogin,
        password: _passwordController.text,
      );

      final user = credential.user;
      if (user == null) {
        _showErrorSnackBar('Ocorreu um erro durante o login.');
        setState(() => _isLoading = false);
        return;
      }

      // ================== ETAPA 3: AUTORIZAÇÃO (A CORREÇÃO DE SEGURANÇA) ==================
      // Buscar o perfil REAL do usuário no Firestore após o login bem-sucedido.
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        _showErrorSnackBar('Perfil de usuário não encontrado.');
        await FirebaseAuth.instance.signOut(); // Desconecta o usuário
        setState(() => _isLoading = false);
        return;
      }

      final String actualRole = userDoc.data()?['role'] ?? 'user';

      // Verificar se o perfil real corresponde à tentativa de login.
      if (intendedAsSecretary && actualRole != 'secretary') {
        _showErrorSnackBar(
            'Acesso negado. Esta conta não tem permissões de secretária.');
        await FirebaseAuth.instance.signOut(); // Desconecta imediatamente
      } else if (!intendedAsSecretary && actualRole != 'user') {
        _showErrorSnackBar(
            'Esta conta é de secretária. Use a tela de acesso restrito.');
        await FirebaseAuth.instance.signOut(); // Desconecta imediatamente
      } else {
        // Autorização bem-sucedida, redirecionar para o painel correto.
        if (!mounted) return;
        final newRoute = actualRole == 'secretary'
            ? '/secretary_dashboard'
            : '/user_dashboard';
        Navigator.pushNamedAndRemoveUntil(context, newRoute, (route) => false);
      }
      // =================================================================================
    } on FirebaseAuthException {
      _showErrorSnackBar('Login ou senha inválidos.');
    } catch (e) {
      _showErrorSnackBar('Ocorreu um erro inesperado.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role =
        ModalRoute.of(context)?.settings.arguments as String? ?? 'user';
    final isSecretaryAttempt = role == 'secretary';

    final String loginLabel = isSecretaryAttempt ? 'Email' : 'CPF';
    final TextInputType keyboardType =
        isSecretaryAttempt ? TextInputType.emailAddress : TextInputType.number;

    return Scaffold(
      appBar: AppBar(
        title:
            Text(isSecretaryAttempt ? 'Acesso Restrito' : 'Acesse sua Conta'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text('Bem-vindo(a) de volta!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Insira suas credenciais para continuar.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 40),
              TextFormField(
                controller: _loginController,
                decoration: InputDecoration(
                  labelText: loginLabel,
                  prefixIcon: Icon(isSecretaryAttempt
                      ? Icons.email_outlined
                      : Icons.person_outline_rounded),
                ),
                keyboardType: keyboardType,
                inputFormatters: isSecretaryAttempt
                    ? []
                    : [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11)
                      ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Campo obrigatório.';
                  }
                  if (!isSecretaryAttempt && value.length != 11) {
                    return 'CPF deve conter 11 dígitos.';
                  }
                  if (isSecretaryAttempt &&
                      !RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                    return 'Por favor, insira um email válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: Icon(Icons.lock_outline_rounded)),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira sua senha.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: () => _performLogin(isSecretaryAttempt),
                  child: const Text('Entrar'),
                ),
              if (!isSecretaryAttempt)
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: const Text('Não tem uma conta? Crie sua senha'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
