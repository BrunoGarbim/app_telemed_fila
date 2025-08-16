// =========================================================================
// ARQUIVO: lib/screens/user_dashboard_screen.dart (VERSÃO COMPLETA E CORRIGIDA)
// =========================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

// Modelos de dados
class Appointment {
  final String patientName;
  final DateTime date;
  final String time;
  final String status;
  final DateTime? checkInTime;

  Appointment({
    required this.patientName,
    required this.date,
    required this.time,
    required this.status,
    this.checkInTime,
  });

  factory Appointment.fromMap(Map<String, dynamic> map) {
    String status = 'scheduled';
    if (map['endConsultationTime'] != null) {
      status = 'finished';
    } else if (map['startConsultationTime'] != null)
      status = 'in_progress';
    else if (map['checkInTime'] != null) status = 'checked_in';

    return Appointment(
      patientName: map['patientName'] ?? 'N/A',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      time: map['time'] ?? 'N/A',
      status: status,
      checkInTime: map['checkInTime'] != null
          ? DateTime.parse(map['checkInTime'])
          : null,
    );
  }
}

class UserDashboardData {
  final String userName;
  final Appointment? nextAppointment;
  final int? estimatedWaitTime;
  final int? positionInQueue;

  UserDashboardData({
    required this.userName,
    this.nextAppointment,
    this.estimatedWaitTime,
    this.positionInQueue,
  });
}

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});
  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  Future<UserDashboardData?>? _dashboardDataFuture;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _dashboardDataFuture = _fetchDashboardData();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {
          _dashboardDataFuture = _fetchDashboardData();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<UserDashboardData?> _fetchDashboardData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      FirebaseFunctions functions =
          FirebaseFunctions.instanceFor(region: "us-central1");
      final HttpsCallable callable = functions.httpsCallable('getWaitingTime');
      final result = await callable.call();
      final data = Map<String, dynamic>.from(result.data);
      return UserDashboardData(
        userName: data['userName'],
        nextAppointment: data['appointment'] != null
            ? Appointment.fromMap(
                Map<String, dynamic>.from(data['appointment']))
            : null,
        estimatedWaitTime: data['estimatedTime'],
        positionInQueue: data['queuePosition'],
      );
    } catch (e) {
      debugPrint("Erro no dashboard: $e");
      return Future.error(e);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, '/role_selection', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Painel'),
        actions: [
          IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sair',
              onPressed: () => _logout(context))
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _dashboardDataFuture = _fetchDashboardData();
          });
        },
        child: FutureBuilder<UserDashboardData?>(
          future: _dashboardDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return _buildErrorState(context, snapshot.error);
            }
            final dashboardData = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                Text('Olá, ${dashboardData.userName}!',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Acompanhe o estado da sua consulta.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 32),
                if (dashboardData.nextAppointment != null)
                  _buildAppointmentCard(context, dashboardData)
                else
                  _buildNoAppointmentCard(context),
              ],
            );
          },
        ),
      ),
    );
  }

  // ============== IMPLEMENTAÇÕES COMPLETAS DAS FUNÇÕES AUXILIARES ==============

  Widget _buildErrorState(BuildContext context, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: Colors.grey, size: 60),
            const SizedBox(height: 16),
            const Text(
              'Não foi possível carregar os dados do painel',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Ocorreu um erro ao comunicar com o servidor. Tente novamente mais tarde.\n\nDetalhes: ${error.toString()}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(BuildContext context, UserDashboardData data) {
    final theme = Theme.of(context);
    final appointment = data.nextAppointment!;
    final formattedDate =
        DateFormat.yMMMMEEEEd('pt_BR').format(appointment.date);
    Widget statusWidget;

    switch (appointment.status) {
      case 'in_progress':
        statusWidget = _buildStatusSection(theme,
            icon: Icons.medical_services_rounded,
            title: 'Em Atendimento',
            value: 'A sua consulta já começou!',
            subtitle: 'Por favor, aguarde ser chamado pelo nome.');
        break;
      case 'finished':
        statusWidget = _buildStatusSection(theme,
            icon: Icons.check_circle_rounded,
            title: 'Atendimento Finalizado',
            value: 'Consulta concluída com sucesso!',
            subtitle: 'Agradecemos a sua visita.');
        break;
      case 'checked_in':
        if (data.estimatedWaitTime != null && data.estimatedWaitTime! <= 0) {
          statusWidget = _buildStatusSection(theme,
              icon: Icons.doorbell_rounded,
              title: 'Você é o próximo!',
              value: 'Aguarde ser chamado',
              subtitle: 'A sua posição na fila: ${data.positionInQueue ?? 1}');
        } else {
          statusWidget = _buildStatusSection(theme,
              icon: Icons.hourglass_top_rounded,
              title: 'Tempo de Espera Estimado:',
              value: '${data.estimatedWaitTime ?? '--'} min',
              subtitle:
                  'A sua posição na fila: ${data.positionInQueue ?? 'A calcular...'}');
        }
        break;
      default: // 'scheduled'
        statusWidget = _buildStatusSection(theme,
            icon: Icons.timer_outlined,
            title: 'Agendado para:',
            value: appointment.time,
            subtitle: 'Faça o check-in ao chegar na clínica');
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.9),
              theme.colorScheme.primary
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              statusWidget,
              if (appointment.status != 'finished') ...[
                const Divider(color: Colors.white38, height: 32),
                _buildInfoRow(context,
                    icon: Icons.calendar_today_outlined,
                    label: 'Data',
                    value: formattedDate),
                const SizedBox(height: 16),
                _buildInfoRow(context,
                    icon: Icons.person_outline_rounded,
                    label: 'Paciente',
                    value: appointment.patientName),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection(ThemeData theme,
      {required IconData icon,
      required String title,
      required String value,
      required String subtitle}) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 40),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white70)),
              Text(value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              if (subtitle.isNotEmpty)
                Text(subtitle,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white70)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildNoAppointmentCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 20.0),
        child: Column(
          children: [
            Icon(Icons.event_available,
                size: 48, color: theme.colorScheme.secondary),
            const SizedBox(height: 16),
            Text('Nenhuma consulta futura encontrada!',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                'Você está em dia. Para marcar uma nova consulta, entre em contato com a clínica.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context,
      {required IconData icon, required String label, required String value}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 16),
        Text('$label:',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
        const Spacer(),
        Text(value,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
