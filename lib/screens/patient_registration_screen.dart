// =========================================================================
// ARQUIVO: lib/screens/patient_registration_screen.dart (VERSÃO CORRIGIDA)
// =========================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PatientRegistrationScreen extends StatefulWidget {
  const PatientRegistrationScreen({super.key});

  @override
  State<PatientRegistrationScreen> createState() =>
      _PatientRegistrationScreenState();
}

class _PatientRegistrationScreenState extends State<PatientRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cpfController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _registerPatient() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    // ================== MUDANÇA PRINCIPAL AQUI ==================
    // Limpamos os dados de qualquer espaço em branco antes de usar
    final name = _nameController.text.trim();
    final cpf = _cpfController.text.trim();
    final email = _emailController.text.toLowerCase().trim();
    // ============================================================

    try {
      final patientsCollection =
          FirebaseFirestore.instance.collection('patients');
      final usersCollection = FirebaseFirestore.instance.collection('users');

      final existingCpfPatient =
          await patientsCollection.where('cpf', isEqualTo: cpf).limit(1).get();
      final existingCpfUser =
          await usersCollection.where('cpf', isEqualTo: cpf).limit(1).get();

      if (existingCpfPatient.docs.isNotEmpty ||
          existingCpfUser.docs.isNotEmpty) {
        _showSnackBar('Este CPF já foi liberado ou cadastrado.', isError: true);
        return;
      }

      final existingEmailPatient = await patientsCollection
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      final existingEmailUser =
          await usersCollection.where('email', isEqualTo: email).limit(1).get();

      if (existingEmailPatient.docs.isNotEmpty ||
          existingEmailUser.docs.isNotEmpty) {
        _showSnackBar('Este email já está em uso.', isError: true);
        return;
      }

      await patientsCollection.add({
        'name': name, // Usando a variável limpa
        'cpf': cpf, // Usando a variável limpa
        'email': email, // Usando a variável limpa
        'accessReleasedAt': FieldValue.serverTimestamp(),
      });

      _showSnackBar('Paciente liberado para cadastro com sucesso!',
          isError: false);
      _formKey.currentState?.reset();
      _nameController.clear();
      _cpfController.clear();
      _emailController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      _showSnackBar('Ocorreu um erro ao liberar o paciente.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Theme.of(context).colorScheme.error : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cpfController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liberar Acesso de Paciente'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                'Insira os dados do paciente para permitir que ele crie uma senha no aplicativo.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 40),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome Completo do Paciente',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                keyboardType: TextInputType.name,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O nome é obrigatório.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _cpfController,
                decoration: const InputDecoration(
                  labelText: 'CPF do Paciente',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                validator: (value) {
                  if (value == null || value.length != 11) {
                    return 'Insira um CPF válido com 11 dígitos.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email do Paciente',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null ||
                      !RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                    return 'Por favor, insira um email válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _registerPatient,
                  child: const Text('Liberar Acesso'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
