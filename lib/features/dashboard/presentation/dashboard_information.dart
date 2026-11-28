import 'package:flutter/material.dart';

class DashboardInformation extends StatelessWidget {
  const DashboardInformation({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFF0EDFB), Color(0xFFF7F8FD)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFDED8F4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF6354D9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.info_outline,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Datos informativos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Lectura responsable de los datos',
                    style: TextStyle(color: Color(0xFF656078)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 960
                ? 3
                : constraints.maxWidth >= 620
                ? 2
                : 1;
            final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
            const notes = [
              (
                icon: Icons.favorite_outline,
                title: 'Criterio de seguimiento',
                text:
                    'Tres ausencias consecutivas o como máximo una presencia en las últimas tres convocatorias. Se requieren al menos tres convocatorias registradas para evaluar el seguimiento.',
              ),
              (
                icon: Icons.event_note_outlined,
                title: 'Fechas que se consideran',
                text:
                    'Solo se consideran sesiones guardadas, desde el 28 de noviembre y hasta hoy, dentro del rango seleccionado. Las fechas futuras no generan alertas.',
              ),
              (
                icon: Icons.groups_outlined,
                title: 'Contexto de cada integrante',
                text:
                    'Una sesión sin registrar no equivale a una falta. Cada persona se evalúa según sus convocatorias y su historial de grupo. La participación se calcula sobre las personas convocadas en las sesiones guardadas.',
              ),
            ];
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: notes
                  .map(
                    (note) => SizedBox(
                      width: width,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              note.icon,
                              color: const Color(0xFF6354D9),
                              size: 22,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              note.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF39314F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              note.text,
                              style: const TextStyle(
                                color: Color(0xFF656078),
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    ),
  );
}
