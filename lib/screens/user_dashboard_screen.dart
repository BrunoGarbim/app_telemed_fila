// ======================================================================================
// ARQUIVO: lib/screens/user_dashboard_screen.dart (VERSÃO CORRIGIDA)
// ======================================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';

// -------------------- MODELOS --------------------
class Appointment {
  final String patientName;
  final DateTime date;
  final String time;
  final String status;

  Appointment({
    required this.patientName,
    required this.date,
    required this.time,
    required this.status,
  });

  factory Appointment.fromMap(Map<String, dynamic> map) {
    String status = 'scheduled';

    if (map['status'] == 'cancelled_by_delay') {
      status = 'cancelled_by_delay';
    } else {
      if (map['endConsultationTime'] != null) {
        status = 'finished';
      } else if (map['startConsultationTime'] != null) {
        status = 'in_progress';
      } else if (map['checkInTime'] != null) {
        status = 'checked_in';
      }
    }

    return Appointment(
      patientName: map['patientName'] ?? 'N/A',
      date: (map['appointmentDate'] as Timestamp).toDate(),
      time: map['timeSlot'] ?? 'N/A',
      status: status,
    );
  }
}

class UserDashboardData {
  final String userName;
  final Appointment? appointment;
  final int? queuePosition;

  UserDashboardData({
    required this.userName,
    this.appointment,
    this.queuePosition,
  });
}

// -------------------- DASHBOARD --------------------
class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});
  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  Future<UserDashboardData?>? _dashboardDataFuture;

  @override
  void initState() {
    super.initState();
    _dashboardDataFuture = _fetchAndProcessQueueData();
  }

  // ===== Buscar tempo estimado (Cloud Function) =====
  Future<int?> _fetchEstimatedTime() async {
    try {
      // ✅ MELHORIA: Instância do Functions pode ser reutilizada.
      final callable =
          FirebaseFunctions.instance.httpsCallable('getWaitingTime');
      final result = await callable();

      // ✅ MELHORIA: Tratamento seguro do retorno.
      if (result.data is Map) {
        final data = Map<String, dynamic>.from(result.data);
        // O valor pode ser nulo, e o cast 'as int?' lida com isso.
        return data['estimatedTime'] as int?;
      }
      return null;
    } catch (e, st) {
      debugPrint("Erro ao buscar tempo estimado: $e");
      debugPrintStack(stackTrace: st);
      return null; // Retorna nulo em caso de erro.
    }
  }

  // ===== Buscar dados da fila/consulta =====
  Future<UserDashboardData?> _fetchAndProcessQueueData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final firestore = FirebaseFirestore.instance;

    try {
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) throw Exception("Usuário não encontrado.");
      final userName = userDoc.data()?['name'] ?? 'Usuário';
      final userCpf = userDoc.data()?['cpf'];

      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      final appointmentQuery = await firestore
          .collection('appointments')
          .where('patientCpf', isEqualTo: userCpf)
          .where('appointmentDate', isGreaterThanOrEqualTo: startOfToday)
          .orderBy('appointmentDate')
          .limit(1)
          .get();

      if (appointmentQuery.docs.isEmpty) {
        return UserDashboardData(userName: userName);
      }

      final userAppointmentData = appointmentQuery.docs.first.data();
      final userAppointment = Appointment.fromMap(userAppointmentData);

      int? queuePosition;
      final appointmentDate = userAppointment.date;
      final isToday = appointmentDate.year == now.year &&
          appointmentDate.month == now.month &&
          appointmentDate.day == now.day;

      if (isToday) {
        if (userAppointment.status == 'checked_in') {
          final waitingQueueSnapshot = await firestore
              .collection('appointments')
              .where('appointmentDate', isGreaterThanOrEqualTo: startOfToday)
              .where('appointmentDate',
                  isLessThan: startOfToday.add(const Duration(days: 1)))
              .where('checkInTime', isNotEqualTo: null)
              .where('startConsultationTime', isEqualTo: null)
              .orderBy('checkInTime')
              .get();

          final index = waitingQueueSnapshot.docs
              .indexWhere((doc) => doc.data()['patientCpf'] == userCpf);
          if (index != -1) queuePosition = index + 1;
        } else if (userAppointment.status == 'scheduled') {
          final scheduledQueueSnapshot = await firestore
              .collection('appointments')
              .where('appointmentDate', isGreaterThanOrEqualTo: startOfToday)
              .where('appointmentDate',
                  isLessThan: startOfToday.add(const Duration(days: 1)))
              .orderBy('appointmentDate')
              .orderBy('timeSlot') // Adicionado para desempate
              .get();

          final index = scheduledQueueSnapshot.docs
              .indexWhere((doc) => doc.data()['patientCpf'] == userCpf);
          if (index != -1) queuePosition = index + 1;
        }
      }

      return UserDashboardData(
        userName: userName,
        appointment: userAppointment,
        queuePosition: queuePosition,
      );
    } catch (e) {
      debugPrint("Erro ao calcular dados da fila: $e");
      throw Exception('Falha ao carregar dados do painel.');
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _dashboardDataFuture = _fetchAndProcessQueueData();
    });
    await _dashboardDataFuture;
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, '/role_selection', (route) => false);
    }
  }

  // -------------------- UI --------------------
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
        onRefresh: _handleRefresh,
        child: FutureBuilder<UserDashboardData?>(
          future: _dashboardDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data == null) {
              return _buildErrorState();
            }
            final dashboardData = snapshot.data!;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              children: [
                Text('Olá, ${dashboardData.userName}!',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Acompanhe o estado da sua próxima consulta.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 32),
                if (dashboardData.appointment != null) ...[
                  _buildAppointmentCard(context, dashboardData),
                  const SizedBox(height: 20),
                  _buildEstimatedTimeCard(dashboardData),
                ] else
                  _buildNoAppointmentCard(context),
              ],
            );
          },
        ),
      ),
    );
  }

  // -------------------- CARD DE TEMPO ESTIMADO (COM CORREÇÃO) --------------------
  Widget _buildEstimatedTimeCard(UserDashboardData data) {
    final now = DateTime.now();
    final appointment = data.appointment!;
    final appointmentDate = appointment.date;
    final isToday = appointmentDate.year == now.year &&
        appointmentDate.month == now.month &&
        appointmentDate.day == now.day;

    // Só chama a função se a consulta for hoje
    final futureToCall = isToday ? _fetchEstimatedTime() : Future.value(null);

    return FutureBuilder<int?>(
      future: futureToCall,
      builder: (context, snapshot) {
        // Se a consulta não é hoje, mostra a mensagem informativa.
        if (!isToday) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "O tempo estimado ficará disponível apenas no dia da consulta.",
                style: TextStyle(fontSize: 16),
              ),
            ),
          );
        }

        // Enquanto espera a resposta da função
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        // Se deu erro na chamada OU se o tempo retornado for nulo
        final estimatedTime = snapshot.data;
        if (snapshot.hasError || estimatedTime == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Tempo de espera indisponível no momento."),
            ),
          );
        }

        // ✅ SUCESSO: Mostra o tempo estimado.
        return Card(
          color: Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Tempo estimado para sua consulta:",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900])),
                const SizedBox(height: 8),
                Text("$estimatedTime minutos",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700])),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppointmentCard(BuildContext context, UserDashboardData data) {
    final theme = Theme.of(context);
    final appointment = data.appointment!;
    final formattedDate =
        DateFormat('dd/MM/yyyy', 'pt_BR').format(appointment.date);

    final now = DateTime.now();
    final appointmentDate = appointment.date;
    final isToday = appointmentDate.year == now.year &&
        appointmentDate.month == now.month &&
        appointmentDate.day == now.day;

    String mainStatusTitle;
    String mainStatusValue;
    String? mainStatusSubtitle;
    IconData mainStatusIcon;
    Color borderColor = Colors.transparent;

    if (isToday) {
      switch (appointment.status) {
        case 'cancelled_by_delay':
          mainStatusIcon = Icons.event_busy_rounded;
          mainStatusTitle = 'Consulta Cancelada';
          mainStatusValue = 'Devido ao seu atraso';
          mainStatusSubtitle = 'Por favor, entre em contato com a recepção.';
          borderColor = Colors.red.shade800;
          break;
        case 'in_progress':
          mainStatusIcon = Icons.medical_services_rounded;
          mainStatusTitle = 'Em Atendimento';
          mainStatusValue = 'Sua consulta começou!';
          mainStatusSubtitle = 'Aguarde ser chamado pelo nome.';
          borderColor = Colors.purple.shade700;
          break;
        case 'finished':
          mainStatusIcon = Icons.check_circle_rounded;
          mainStatusTitle = 'Atendimento Finalizado';
          mainStatusValue = 'Consulta concluída!';
          mainStatusSubtitle = 'Agradecemos a sua visita.';
          borderColor = Colors.grey;
          break;
        case 'checked_in':
          mainStatusIcon = Icons.event_seat_rounded;
          mainStatusTitle = 'Você está na Fila de Espera';
          mainStatusValue = 'Sua posição: ${data.queuePosition ?? '...'}';
          mainStatusSubtitle = 'Aguarde, sua vez está próxima.';
          borderColor = Colors.blue.shade700;
          break;
        default: // 'scheduled'
          mainStatusIcon = Icons.timer_outlined;
          mainStatusTitle = 'Sua consulta é hoje';
          mainStatusValue = 'Aguardando sua Chegada';
          mainStatusSubtitle = 'Faça o check-in ao chegar na clínica.';
          borderColor = Colors.green.shade700;

          // Combinando a data da consulta com o horário (timeSlot)
          final timeParts = appointment.time.split(':');
          final appointmentDateTime = DateTime(
            appointment.date.year,
            appointment.date.month,
            appointment.date.day,
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );

          if (now.isAfter(appointmentDateTime)) {
            final delayInMinutes =
                now.difference(appointmentDateTime).inMinutes;
            if (delayInMinutes > 20) {
              borderColor = Colors.red.shade800;
              mainStatusTitle = 'Atraso Crítico!';
              mainStatusValue = '$delayInMinutes min de atraso';
              mainStatusSubtitle = 'Sua consulta pode ser cancelada.';
            } else if (delayInMinutes > 10) {
              borderColor = Colors.orange.shade800;
              mainStatusTitle = 'Você está Atrasado';
              mainStatusValue = '$delayInMinutes min de atraso';
              mainStatusSubtitle = 'Você corre o risco de perder a posição.';
            } else {
              borderColor = Colors.yellow.shade800;
              mainStatusTitle = 'Você está Atrasado';
              mainStatusValue = '$delayInMinutes min de atraso';
              mainStatusSubtitle = 'Por favor, apresse-se.';
            }
          }
      }
    } else {
      mainStatusIcon = Icons.calendar_month_rounded;
      mainStatusTitle = 'Próxima Consulta Agendada';
      mainStatusValue = 'Consulte os detalhes abaixo';
      mainStatusSubtitle = null;
      borderColor = theme.colorScheme.primary;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 3),
      ),
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
              _buildStatusSection(
                theme,
                icon: mainStatusIcon,
                title: mainStatusTitle,
                value: mainStatusValue,
                subtitle: mainStatusSubtitle,
              ),
              const Divider(color: Colors.white38, height: 32),
              _buildInfoRow(
                context,
                icon: Icons.calendar_today_outlined,
                label: 'Data',
                value: formattedDate,
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                context,
                icon: Icons.access_time_filled_rounded,
                label: 'Horário Agendado',
                value: appointment.time,
              ),
              if (isToday &&
                  (appointment.status == 'scheduled' ||
                      appointment.status == 'checked_in') &&
                  data.queuePosition != null) ...[
                const SizedBox(height: 14),
                _buildInfoRow(
                  context,
                  icon: Icons.format_list_numbered_rounded,
                  label: appointment.status == 'scheduled'
                      ? 'Posição na Agenda'
                      : 'Posição na Fila',
                  value: '${data.queuePosition}º',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, color: Colors.grey, size: 60),
            SizedBox(height: 16),
            Text(
              'Não foi possível carregar os dados',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Verifique sua conexão e puxe para baixo para tentar novamente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
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
            Text('Nenhuma consulta futura encontrada',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Você não tem agendamentos futuros. Para marcar uma nova consulta, entre em contato com a clínica.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(ThemeData theme,
      {required IconData icon,
      required String title,
      required String value,
      String? subtitle}) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 45),
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
              if (subtitle != null && subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(subtitle,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.white70)),
                ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context,
      {required IconData icon, required String label, required String value}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Text('$label:',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
        const Spacer(),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
