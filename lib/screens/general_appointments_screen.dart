import 'package:flutter/material.dart'; // A correção é garantir que esta linha exista e esteja correta
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';

class GeneralAppointmentsScreen extends StatefulWidget {
  const GeneralAppointmentsScreen({super.key});

  @override
  State<GeneralAppointmentsScreen> createState() =>
      _GeneralAppointmentsScreenState();
}

class _GeneralAppointmentsScreenState extends State<GeneralAppointmentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _getAppointmentsForDay(DateTime day) {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return FirebaseFirestore.instance
        .collection('appointments')
        .where('appointmentDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('appointmentDate', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('appointmentDate')
        .snapshots();
  }

  void _showAppointmentOptions(BuildContext context, DocumentSnapshot doc) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('Reagendar'),
              onTap: () {
                Navigator.pop(context);
                _rescheduleAppointment(context, doc.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Excluir Agendamento',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteAppointment(context, doc.id);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAppointment(BuildContext context, String docId) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content:
            const Text('Tem a certeza de que deseja excluir este agendamento?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Excluir')),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(docId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Agendamento excluído.'),
          backgroundColor: Colors.green));
    }
  }

  Future<void> _rescheduleAppointment(
      BuildContext context, String docId) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reagendar Consulta'),
        content: const Text(
            'O agendamento atual será cancelado para que possa criar um novo. Deseja continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Não')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sim')),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(docId)
          .delete();
      Navigator.pushNamed(context, '/appointments');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultas Agendadas'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Pesquisar por nome ou CPF',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          TableCalendar(
            locale: 'pt_BR',
            headerStyle: const HeaderStyle(
                formatButtonVisible: false, titleCentered: true),
            focusedDay: _focusedDay,
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2030),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getAppointmentsForDay(_selectedDay),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('Erro ao carregar os dados.'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Nenhum agendamento para esta data.',
                        style: TextStyle(fontSize: 16)),
                  );
                }

                final appointments = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final patientName =
                      (data['patientName'] as String? ?? '').toLowerCase();
                  final patientCpf =
                      (data['patientCpf'] as String? ?? '').toLowerCase();
                  return patientName.contains(_searchQuery) ||
                      patientCpf.contains(_searchQuery);
                }).toList();

                if (appointments.isEmpty) {
                  return const Center(
                    child: Text(
                        'Nenhum resultado para a sua pesquisa nesta data.',
                        style: TextStyle(fontSize: 16)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: appointments.length,
                  itemBuilder: (context, index) {
                    final doc = appointments[index];
                    return _buildAppointmentTile(context, doc);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentTile(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              data['timeSlot'] ?? '??',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
        ),
        title: Text(data['patientName'] ?? 'N/A',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('CPF: ${data['patientCpf'] ?? 'N/A'}'),
        onTap: () => _showAppointmentOptions(context, doc),
      ),
    );
  }
}
