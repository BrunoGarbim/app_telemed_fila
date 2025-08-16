// lib/widgets/summary_panel.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SummaryPanel extends StatelessWidget {
  final int? totalCount;
  final String? nextAppointment;
  final String? error;

  const SummaryPanel({
    super.key,
    this.totalCount,
    this.nextAppointment,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedDate =
        DateFormat.yMMMMEEEEd('pt_BR').format(DateTime.now()).toUpperCase();

    return Card(
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              Color.lerp(theme.colorScheme.primary, Colors.black, 0.2)!
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formattedDate,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: Colors.white70, letterSpacing: 1.5),
            ),
            const SizedBox(height: 16),
            if (error != null)
              Row(
                children: [
                  const Icon(Icons.warning, color: Colors.yellow),
                  const SizedBox(width: 8),
                  Text(error!,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: Colors.white)),
                ],
              )
            else
              IntrinsicHeight(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.groups_2_outlined,
                              color: Colors.white70, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            totalCount?.toString() ?? '0',
                            style: theme.textTheme.displayMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Agendados Hoje',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const VerticalDivider(
                        color: Colors.white38,
                        thickness: 1,
                        indent: 8,
                        endIndent: 8),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PRÓXIMO PACIENTE',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      const Color.fromARGB(155, 255, 255, 255),
                                  letterSpacing: 1),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              nextAppointment ?? 'Nenhum',
                              style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
