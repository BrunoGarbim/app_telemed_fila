// ======================================================================================
// ARQUIVO: lib/screens/queue_management_screen.dart (VERSÃO COM LAYOUT AJUSTADO)
// ======================================================================================
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QueueManagementScreen extends StatefulWidget {
  const QueueManagementScreen({super.key});

  @override
  State<QueueManagementScreen> createState() => _QueueManagementScreenState();
}

class _QueueManagementScreenState extends State<QueueManagementScreen> {
  // Busca os agendamentos para o dia de hoje em tempo real
  Stream<QuerySnapshot> _getTodaysAppointmentsStream() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    return FirebaseFirestore.instance
        .collection('appointments')
        .where('appointmentDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
        .where('appointmentDate', isLessThan: Timestamp.fromDate(endOfToday))
        .orderBy('appointmentDate')
        .snapshots();
  }

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _checkInPatient(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(docId)
          .update({
        'checkInTime': Timestamp.now(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Check-in do paciente confirmado!'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Erro ao confirmar o check-in.'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Map<String, dynamic> _getAppointmentStatus(Map<String, dynamic> data) {
    final scheduledTimestamp = data['appointmentDate'] as Timestamp?;
    final checkInTimestamp = data['checkInTime'] as Timestamp?;
    final startTimestamp = data['startConsultationTime'] as Timestamp?;
    final endTimestamp = data['endConsultationTime'] as Timestamp?;

    if (endTimestamp != null) {
      return {
        'status': 'Atendimento Finalizado',
        'color': Colors.grey,
        'state': 'finished'
      };
    }
    if (startTimestamp != null) {
      return {
        'status': 'Em Atendimento',
        'color': Colors.purple.shade700,
        'state': 'in_progress'
      };
    }

    if (checkInTimestamp != null) {
      final scheduledTime = scheduledTimestamp?.toDate() ?? DateTime.now();
      final checkInTime = checkInTimestamp.toDate();
      final delay = checkInTime.difference(scheduledTime);

      if (delay.isNegative || delay.inMinutes == 0) {
        return {
          'status': 'Chegou no horário',
          'color': Colors.green.shade700,
          'state': 'waiting_room'
        };
      }
      if (delay.inMinutes <= 10) {
        return {
          'status': 'Atraso leve (${delay.inMinutes} min)',
          'color': Colors.yellow.shade800,
          'state': 'waiting_room'
        };
      }
      if (delay.inMinutes <= 20) {
        return {
          'status': 'Atrasado (${delay.inMinutes} min)',
          'color': Colors.orange.shade800,
          'state': 'waiting_room'
        };
      }
      return {
        'status': 'Atraso crítico (${delay.inMinutes} min)',
        'color': Colors.red.shade800,
        'state': 'waiting_room'
      };
    }

    if (scheduledTimestamp != null) {
      final scheduledTime = scheduledTimestamp.toDate();
      final now = DateTime.now();
      final delay = now.difference(scheduledTime);

      if (delay.isNegative) {
        return {
          'status': 'Aguardando Check-in',
          'color': Colors.green.shade700,
          'state': 'awaiting_check_in'
        };
      }
      final minutes = delay.inMinutes;
      if (minutes <= 10) {
        return {
          'status': 'Atrasado p/ Check-in ($minutes min)',
          'color': Colors.yellow.shade800,
          'state': 'awaiting_check_in'
        };
      }
      if (minutes <= 20) {
        return {
          'status': 'Atrasado p/ Check-in ($minutes min)',
          'color': Colors.orange.shade800,
          'state': 'awaiting_check_in'
        };
      }
      return {
        'status': 'Atraso crítico p/ Check-in ($minutes min)',
        'color': Colors.red.shade800,
        'state': 'awaiting_check_in'
      };
    }

    return {
      'status': 'Horário Inválido',
      'color': Colors.blue.shade700,
      'state': 'awaiting_check_in'
    };
  }

  Future<void> _deleteAppointment(String docId) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content:
            const Text('Você tem certeza que deseja excluir este agendamento?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child:
                  const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(docId)
          .delete();
    }
  }

  Future<void> _rescheduleAppointment(String docId) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reagendar Consulta'),
        content: const Text(
            'O agendamento atual será cancelado e você será redirecionado. Deseja continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Não')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sim')),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(docId)
          .delete();
      if (mounted) Navigator.pushNamed(context, '/appointments');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fila de Hoje'),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: StreamBuilder<QuerySnapshot>(
          stream: _getTodaysAppointmentsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Erro ao carregar a fila.'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return LayoutBuilder(builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 60, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('Nenhum paciente na fila para hoje.',
                              style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                );
              });
            }

            final appointments = snapshot.data!.docs;

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8.0),
              itemCount: appointments.length,
              itemBuilder: (context, index) {
                final doc = appointments[index];
                final data = doc.data() as Map<String, dynamic>;

                final statusInfo = _getAppointmentStatus(data);
                final statusColor = statusInfo['color'] as Color;
                final statusText = statusInfo['status'] as String;
                final currentState = statusInfo['state'] as String;

                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 6.0),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: statusColor, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: statusColor,
                                    child: Text(
                                      data['timeSlot'] ?? '??',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      data['patientName'] ?? 'N/A',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 40.0, top: 4.0),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildActionButtons(currentState, doc.id),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionButtons(String state, String docId) {
    switch (state) {
      case 'awaiting_check_in':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.login, color: Colors.blueAccent),
              tooltip: 'Check-in',
              onPressed: () => _checkInPatient(docId),
            ),
            IconButton(
              icon: const Icon(Icons.edit_calendar_outlined,
                  color: Colors.blueAccent),
              tooltip: 'Reagendar',
              onPressed: () => _rescheduleAppointment(docId),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Excluir',
              onPressed: () => _deleteAppointment(docId),
            ),
          ],
        );
      case 'waiting_room':
        return ElevatedButton.icon(
          icon: const Icon(Icons.doorbell_outlined, size: 18),
          label: const Text('Chamar'),
          onPressed: () => _updateAppointmentStatus(
              docId, {'startConsultationTime': Timestamp.now()}),
          style:
              ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
        );
      case 'in_progress':
        return ElevatedButton.icon(
          icon: const Icon(Icons.done, size: 18),
          label: const Text('Finalizar'),
          onPressed: () => _updateAppointmentStatus(
              docId, {'endConsultationTime': Timestamp.now()}),
          style:
              ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700),
        );
      case 'finished':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_calendar_outlined,
                  color: Colors.blueAccent),
              tooltip: 'Reagendar',
              onPressed: () => _rescheduleAppointment(docId),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Excluir registro',
              onPressed: () => _deleteAppointment(docId),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _updateAppointmentStatus(
      String docId, Map<String, dynamic> data) async {
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(docId)
          .update(data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Erro ao atualizar o status.'),
        backgroundColor: Colors.red,
      ));
    }
  }
}
