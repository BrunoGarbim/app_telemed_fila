import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/summary_panel.dart';
import '../widgets/dashboard_card.dart';

class SecretaryDashboardScreen extends StatefulWidget {
  const SecretaryDashboardScreen({super.key});

  @override
  State<SecretaryDashboardScreen> createState() =>
      _SecretaryDashboardScreenState();
}

class _SecretaryDashboardScreenState extends State<SecretaryDashboardScreen> {
  Future<Map<String, dynamic>>? _dashboardDataFuture;

  @override
  void initState() {
    super.initState();
    _dashboardDataFuture = _fetchDashboardData();
  }

  Future<Map<String, dynamic>> _fetchDashboardData() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final firestore = FirebaseFirestore.instance;

    final querySnapshot = await firestore
        .collection('appointments')
        .where('appointmentDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('appointmentDate', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('appointmentDate')
        .get();

    final appointments = querySnapshot.docs;
    final totalCount = appointments.length;

    String nextAppointmentInfo = 'Nenhum próximo agendamento.';
    QueryDocumentSnapshot? nextAppointmentDoc;

    for (final doc in appointments) {
      if ((doc['appointmentDate'] as Timestamp).toDate().isAfter(now)) {
        nextAppointmentDoc = doc;
        break;
      }
    }

    if (nextAppointmentDoc != null) {
      final nextData = nextAppointmentDoc.data() as Map<String, dynamic>;
      nextAppointmentInfo =
          '${nextData['patientName']} às ${nextData['timeSlot']}';
    }

    return {'totalCount': totalCount, 'nextAppointment': nextAppointmentInfo};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel da Secretária'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/role_selection',
                  (route) => false,
                );
              }
            },
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _dashboardDataFuture = _fetchDashboardData();
          });
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            FutureBuilder<Map<String, dynamic>>(
              future: _dashboardDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const SummaryPanel(
                    error: 'Não foi possível carregar os dados',
                  );
                }
                final data = snapshot.data!;
                return SummaryPanel(
                  totalCount: data['totalCount'],
                  nextAppointment: data['nextAppointment'],
                );
              },
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                DashboardCard(
                  icon: Icons.person_add_alt_1_outlined,
                  label: 'Liberar Acesso',
                  onTap: () =>
                      Navigator.pushNamed(context, '/patient_registration'),
                ),
                DashboardCard(
                  icon: Icons.calendar_month_outlined,
                  label: 'Agendar Consulta',
                  onTap: () => Navigator.pushNamed(context, '/appointments'),
                ),
                DashboardCard(
                  icon: Icons.groups_outlined,
                  label: 'Gerenciar Fila do Dia',
                  onTap: () =>
                      Navigator.pushNamed(context, '/queue_management'),
                ),
                DashboardCard(
                  icon: Icons.list_alt_rounded,
                  label: 'Consultas Agendadas',
                  onTap: () =>
                      Navigator.pushNamed(context, '/general_appointments'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
