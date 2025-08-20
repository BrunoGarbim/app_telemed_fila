import 'package:flutter/material.dart';
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
      // Usamos .trim() para remover espaços em branco e garantir que a busca não seja acionada por engano
      final query = _searchController.text.trim().toLowerCase();
      if (_searchQuery != query) {
        setState(() {
          _searchQuery = query;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Função original: busca agendamentos para um dia específico
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

  // Nova função: busca TODOS os agendamentos para a pesquisa global
  Stream<QuerySnapshot> _getAllAppointments() {
    return FirebaseFirestore.instance
        .collection('appointments')
        .orderBy('appointmentDate') // É bom manter uma ordenação
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
                _rescheduleAppointment(
                    context, doc.id, doc.data() as Map<String, dynamic>);
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
      BuildContext context, String docId, Map<String, dynamic> data) async {
    // Lógica de reagendamento aprimorada (opcional, mas recomendado)
    // Aqui você pode navegar para a tela de agendamento passando os dados do paciente
    Navigator.pushNamed(context, '/appointments', arguments: {
      'patientId': data['patientId'],
      'patientName': data['patientName'],
      'patientCpf': data['patientCpf'],
      'appointmentIdToCancel':
          docId, // Passa o ID do agendamento a ser cancelado
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isSearching = _searchQuery.isNotEmpty;

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
                // Adiciona um botão para limpar a busca
                suffixIcon: isSearching
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),
          // Esconde o calendário quando uma busca está ativa
          if (!isSearching)
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
              // Lógica condicional: se está buscando, usa a nova função. Senão, usa a antiga.
              stream: isSearching
                  ? _getAllAppointments()
                  : _getAppointmentsForDay(_selectedDay),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('Erro ao carregar os dados.'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  // Mensagem personalizada se não houver agendamentos na data ou na busca
                  return Center(
                    child: Text(
                        isSearching
                            ? 'Nenhum agendamento encontrado.'
                            : 'Nenhum agendamento para esta data.',
                        style: const TextStyle(fontSize: 16)),
                  );
                }

                // A lógica de filtro do lado do cliente é aplicada em ambos os casos
                final appointments = snapshot.data!.docs.where((doc) {
                  if (!isSearching)
                    return true; // Se não está buscando, mostra todos do dia

                  final data = doc.data() as Map<String, dynamic>;
                  final patientName =
                      (data['patientName'] as String? ?? '').toLowerCase();
                  final patientCpf = (data['patientCpf'] as String? ?? '')
                      .replaceAll(RegExp(r'[\.\-]'), ''); // Remove . e - do CPF

                  final searchQuery =
                      _searchQuery.replaceAll(RegExp(r'[\.\-]'), '');

                  return patientName.contains(searchQuery) ||
                      patientCpf.contains(searchQuery);
                }).toList();

                if (appointments.isEmpty) {
                  return Center(
                    child: Text(
                        isSearching
                            ? 'Nenhum resultado para a sua pesquisa.'
                            : 'Nenhum agendamento para esta data.',
                        style: const TextStyle(fontSize: 16)),
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
    final timestamp = data['appointmentDate'] as Timestamp?;
    String formattedDate = 'Data não disponível';
    if (timestamp != null) {
      final date = timestamp.toDate();
      formattedDate = "${date.day}/${date.month}/${date.year}";
    }

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
        // Exibe a data do agendamento, útil na busca global
        subtitle:
            Text('Data: $formattedDate\nCPF: ${data['patientCpf'] ?? 'N/A'}'),
        isThreeLine: true,
        onTap: () => _showAppointmentOptions(context, doc),
      ),
    );
  }
}
