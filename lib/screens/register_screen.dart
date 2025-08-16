// =========================================================================
// ARQUIVO: lib/screens/register_screen.dart (VERSÃO AJUSTADA COM SANITIZAÇÃO)
// =========================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cpfController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  int _step = 1;
  String? _patientName;
  String? _patientEmail;
  String? _patientCpfFromDb;
  String? _patientDocId;

  // Função para padronizar CPF (só números)
  String _sanitizeCpf(String cpf) {
    return cpf.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Future<void> _verifyCpf() async {
    final cpfTypedByUser = _sanitizeCpf(_cpfController.text);

    if (cpfTypedByUser.length != 11) {
      _showErrorSnackBar('Por favor, insira um CPF válido com 11 dígitos.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;

      // ----------------- Verificação em USERS -----------------
      final userQuery = await firestore
          .collection('users')
          .where('cpf', isEqualTo: cpfTypedByUser)
          .limit(1)
          .get();

      debugPrint("CPF digitado: $cpfTypedByUser");
      debugPrint("Usuários encontrados: ${userQuery.docs.length}");

      if (userQuery.docs.isNotEmpty) {
        _showErrorSnackBar(
            'Este CPF já possui um cadastro ativo. Caso não lembre a senha, entre em contato com a clínica.');
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // ----------------- Verificação em PATIENTS -----------------
      final patientQuery = await firestore
          .collection('patients')
          .where('cpf', isEqualTo: cpfTypedByUser)
          .limit(1)
          .get();

      debugPrint("Pacientes encontrados: ${patientQuery.docs.length}");

      if (patientQuery.docs.isEmpty) {
        _showNotAllowedDialog();
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Se achou paciente
      final patientData = patientQuery.docs.first.data();
      setState(() {
        _patientName = patientData['name'];
        _patientEmail = patientData['email'];
        _patientCpfFromDb = _sanitizeCpf(patientData['cpf']);
        _patientDocId = patientQuery.docs.first.id;
        _step = 2;
      });
    } catch (e) {
      debugPrint("Erro ao verificar CPF: $e");
      _showErrorSnackBar('Ocorreu um erro ao verificar o CPF.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _patientEmail!,
        password: _passwordController.text,
      );

      final user = credential.user;
      if (user == null) throw Exception("Criação de usuário falhou.");

      final firestore = FirebaseFirestore.instance;

      // Salva usuário em USERS
      await firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': _patientName,
        'cpf': _patientCpfFromDb,
        'email': _patientEmail,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Remove da lista de PATIENTS
      await firestore.collection('patients').doc(_patientDocId!).delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Cadastro realizado com sucesso!'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ));
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String message = 'Ocorreu um erro desconhecido.';
      if (e.code == 'weak-password') {
        message = 'A senha é muito fraca. Use pelo menos 6 caracteres.';
      } else if (e.code == 'email-already-in-use') {
        message =
            'Este email já está em uso por outra conta. Por favor, contate a clínica.';
      } else if (e.code == 'invalid-email') {
        message = 'O formato do email cadastrado pela secretária é inválido.';
      }
      _showErrorSnackBar(message);
    } catch (e) {
      debugPrint("Erro no cadastro: $e");
      _showErrorSnackBar('Ocorreu um erro inesperado ao finalizar o cadastro.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ----------------- UI -----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crie sua Senha de Acesso')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: _step == 1 ? _buildCpfStep() : _buildPasswordStep(),
        ),
      ),
    );
  }

  Widget _buildCpfStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text(
          'Para começar, digite seu CPF para verificarmos se seu acesso foi liberado.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 40),
        TextFormField(
          controller: _cpfController,
          decoration: const InputDecoration(
              labelText: 'CPF', prefixIcon: Icon(Icons.person_outline_rounded)),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
        ),
        const SizedBox(height: 32),
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton(
                onPressed: _verifyCpf, child: const Text('Verificar CPF')),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Olá, $_patientName!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Seu acesso foi liberado. Agora, crie uma senha para acessar o aplicativo.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 40),
        TextFormField(
          controller: _passwordController,
          decoration: const InputDecoration(
              labelText: 'Crie uma Senha',
              prefixIcon: Icon(Icons.lock_outline_rounded)),
          obscureText: true,
          validator: (value) {
            if (value == null || value.length < 6) {
              return 'A senha deve ter no mínimo 6 caracteres.';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _confirmPasswordController,
          decoration: const InputDecoration(
              labelText: 'Confirme sua Senha',
              prefixIcon: Icon(Icons.lock_outline_rounded)),
          obscureText: true,
          validator: (value) {
            if (value != _passwordController.text) {
              return 'As senhas não coincidem.';
            }
            return null;
          },
        ),
        const SizedBox(height: 32),
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton(
                onPressed: _performRegister,
                child: const Text('Finalizar Cadastro')),
      ],
    );
  }

  // ----------------- Helpers -----------------
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error));
  }

  void _showNotAllowedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.info_outline,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          const Text('Acesso não liberado'),
        ]),
        content: const Text(
          'Seu CPF não foi encontrado ou já foi cadastrado. Por favor, entre em contato com a clínica.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendi'))
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cpfController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
