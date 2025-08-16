import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';

class SchedulablePatient {
  final String name;
  final String cpf;
  final String status;
  SchedulablePatient(
      {required this.name, required this.cpf, required this.status});
}

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});
  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _cpfSearchController = TextEditingController();
  SchedulablePatient? _foundPatient;
  bool _isSearching = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String? _selectedTimeSlot;
  bool _isScheduling = false;
  List<String> _timeSlots = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _generateTimeSlots();
  }

  @override
  void dispose() {
    _cpfSearchController.dispose();
    super.dispose();
  }

  void _generateTimeSlots() {
    List<String> slots = [];
    TimeOfDay startTime = const TimeOfDay(hour: 5, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 23, minute: 30);
    int interval = 30;
    int currentMinute = startTime.hour * 60 + startTime.minute;
    int endMinute = endTime.hour * 60 + endTime.minute;
    while (currentMinute <= endMinute) {
      final hour = (currentMinute ~/ 60).toString().padLeft(2, '0');
      final minute = (currentMinute % 60).toString().padLeft(2, '0');
      slots.add('$hour:$minute');
      currentMinute += interval;
    }
    _timeSlots = slots;
  }

  Future<void> _searchPatientByCpf() async {
    final cpf = _cpfSearchController.text.trim();
    if (cpf.length != 11) {
      _showSnackBar('Por favor, insira um CPF válido com 11 dígitos.',
          isError: true);
      return;
    }
    setState(() {
      _isSearching = true;
      _foundPatient = null;
    });
    FocusScope.of(context).unfocus();
    final firestore = FirebaseFirestore.instance;
    try {
      var querySnapshot = await firestore
          .collection('users')
          .where('cpf', isEqualTo: cpf)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        setState(() => _foundPatient = SchedulablePatient(
            name: data['name'] ?? 'N/A',
            cpf: data['cpf'] ?? 'N/A',
            status: 'Registado'));
      } else {
        querySnapshot = await firestore
            .collection('patients')
            .where('cpf', isEqualTo: cpf)
            .limit(1)
            .get();
        if (querySnapshot.docs.isNotEmpty) {
          final data = querySnapshot.docs.first.data();
          setState(() => _foundPatient = SchedulablePatient(
              name: data['name'] ?? 'N/A',
              cpf: data['cpf'] ?? 'N/A',
              status: 'Pendente'));
        } else {
          _showSnackBar('Paciente não encontrado. Libere o acesso primeiro.',
              isError: true);
        }
      }
    } catch (e) {
      _showSnackBar('Ocorreu um erro ao buscar o paciente.', isError: true);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _scheduleAppointment() async {
    if (_foundPatient == null ||
        _selectedDay == null ||
        _selectedTimeSlot == null) {
      _showSnackBar('Busque por um paciente e selecione data e horário.',
          isError: true);
      return;
    }
    setState(() => _isScheduling = true);
    final firestore = FirebaseFirestore.instance;
    final startOfDay =
        DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    try {
      final timeSlotQuery = await firestore
          .collection('appointments')
          .where('appointmentDate', isGreaterThanOrEqualTo: startOfDay)
          .where('appointmentDate', isLessThan: endOfDay)
          .where('timeSlot', isEqualTo: _selectedTimeSlot)
          .limit(1)
          .get();
      if (timeSlotQuery.docs.isNotEmpty) {
        _showSnackBar(
            'Este horário já está agendado. Por favor, escolha outro.',
            isError: true);
        setState(() => _isScheduling = false);
        return;
      }
      final patientQuery = await firestore
          .collection('appointments')
          .where('patientCpf', isEqualTo: _foundPatient!.cpf)
          .where('appointmentDate', isGreaterThanOrEqualTo: startOfDay)
          .where('appointmentDate', isLessThan: endOfDay)
          .limit(1)
          .get();
      if (patientQuery.docs.isNotEmpty) {
        _showSnackBar(
            'Este paciente já possui uma consulta agendada para este dia.',
            isError: true);
        setState(() => _isScheduling = false);
        return;
      }
      final timeParts = _selectedTimeSlot!.split(':');
      final appointmentDateTime = DateTime(
        _selectedDay!.year,
        _selectedDay!.month,
        _selectedDay!.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );
      await firestore.collection('appointments').add({
        'patientCpf': _foundPatient!.cpf,
        'patientName': _foundPatient!.name,
        'appointmentDate': Timestamp.fromDate(appointmentDateTime),
        'timeSlot': _selectedTimeSlot,
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _showSnackBar('Agendamento realizado com sucesso!', isError: false);
      setState(() {
        _cpfSearchController.clear();
        _foundPatient = null;
        _selectedTimeSlot = null;
      });
    } catch (e) {
      _showSnackBar(
          'Ocorreu um erro ao realizar o agendamento. Verifique se os índices do Firestore foram criados.',
          isError: true);
    } finally {
      if (mounted) setState(() => _isScheduling = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Theme.of(context).colorScheme.error : Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSchedulingEnabled = _foundPatient != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Agendar Consulta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPatientSearchCard(theme),
            const SizedBox(height: 16),
            _buildSchedulingCard(theme, isSchedulingEnabled),
            const SizedBox(height: 24),
            if (_isScheduling)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirmar Agendamento'),
                onPressed: isSchedulingEnabled &&
                        _selectedDay != null &&
                        _selectedTimeSlot != null
                    ? _scheduleAppointment
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientSearchCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Buscar Paciente', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cpfSearchController,
                    decoration: const InputDecoration(
                        labelText: 'Digite o CPF do Paciente',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11)
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _isSearching ? null : _searchPatientByCpf,
                    style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
            if (_isSearching)
              const Padding(
                  padding: EdgeInsets.only(top: 16.0),
                  child: Center(child: CircularProgressIndicator())),
            if (_foundPatient != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: ListTile(
                  leading: const CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.check, color: Colors.white)),
                  title: Text(_foundPatient!.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      'CPF: ${_foundPatient!.cpf}\nStatus: ${_foundPatient!.status}'),
                  tileColor: Colors.green.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulingCard(ThemeData theme, bool isEnabled) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: IgnorePointer(
        ignoring: !isEnabled,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isEnabled ? 1.0 : 0.4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('2. Escolher Data e Horário',
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                _buildCalendar(theme),
                const SizedBox(height: 24),
                _buildTimePicker(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar(ThemeData theme) {
    return TableCalendar(
      locale: 'pt_BR',
      headerStyle:
          const HeaderStyle(formatButtonVisible: false, titleCentered: true),
      focusedDay: _focusedDay,
      firstDay: DateTime.now().subtract(const Duration(days: 365)),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
          _selectedTimeSlot = null;
        });
      },
      calendarStyle: CalendarStyle(
        selectedDecoration: BoxDecoration(
            color: theme.colorScheme.primary, shape: BoxShape.circle),
        todayDecoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.5),
            shape: BoxShape.circle),
      ),
    );
  }

  Widget _buildTimePicker(ThemeData theme) {
    return DropdownButtonFormField<String>(
      value: _selectedTimeSlot,
      decoration: const InputDecoration(
        labelText: 'Horário da Consulta',
        prefixIcon: Icon(Icons.access_time_outlined),
        border: OutlineInputBorder(),
      ),
      items: _timeSlots.map((String time) {
        return DropdownMenuItem<String>(
          value: time,
          child: Text(time),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedTimeSlot = newValue;
        });
      },
      validator: (value) => value == null ? 'Selecione um horário' : null,
    );
  }
}
