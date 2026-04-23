import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/profile.dart';
import '../../services/agenda_service.dart';
import '../../services/profile_service.dart';

class TurmaDetailScreen extends ConsumerStatefulWidget {
  final String turmaId;
  final String turmaName;

  const TurmaDetailScreen({
    super.key,
    required this.turmaId,
    required this.turmaName,
  });

  @override
  ConsumerState<TurmaDetailScreen> createState() => _TurmaDetailScreenState();
}

class _TurmaDetailScreenState extends ConsumerState<TurmaDetailScreen> {
  List<Map<String, dynamic>>? _students;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final data = await ref
          .read(agendaServiceProvider)
          .getTurmaStudents(widget.turmaId);
      setState(() {
        _students = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.turmaName),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            tooltip: 'Fila de espera',
            onPressed: () => context.push('/admin/turma-waitlist', extra: {
              'turmaId': widget.turmaId,
              'turmaName': widget.turmaName,
            }),
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _addStudent,
            tooltip: 'Adicionar à turma',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _students == null || _students!.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 48,
                          color: FavoColors.onSurfaceVariant.withAlpha(80)),
                      const SizedBox(height: 16),
                      Text('Ninguém matriculado ainda',
                          style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _addStudent,
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Adicionar à Turma'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStudents,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: _students!.length,
                    itemBuilder: (context, index) {
                      final s = _students![index];
                      final profile =
                          s['profiles'] as Map<String, dynamic>? ?? {};
                      final name =
                          profile['full_name'] as String? ?? 'Sem nome';
                      final email =
                          profile['email'] as String? ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: FavoColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            UserAvatar(
                              avatarUrl: profile['avatar_url'] as String?,
                              name: name,
                              radius: 20,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall),
                                  Text(email,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  size: 20),
                              color: FavoColors.error,
                              tooltip: 'Remover da turma',
                              onPressed: () =>
                                  _removeStudent(s['student_id'] as String, name),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Future<void> _addStudent() async {
    // Buscar alunas ativas que NÃO estão nesta turma
    final allProfiles =
        await ref.read(profileServiceProvider).getAllProfiles();
    final enrolledIds =
        _students?.map((s) => s['student_id'] as String).toSet() ?? {};

    final available = allProfiles
        .where((p) =>
            p.isActive &&
            (p.isStudent || p.role == UserRole.assistant) &&
            !enrolledIds.contains(p.id))
        .toList();

    if (!mounted) return;

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Toda a turma ativa já está matriculada aqui')),
      );
      return;
    }

    final selected = await showDialog<Profile>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar à Turma'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: available.length,
            itemBuilder: (ctx, i) {
              final p = available[i];
              return ListTile(
                leading: UserAvatar(
                  avatarUrl: p.avatarUrl,
                  name: p.fullName,
                  radius: 18,
                ),
                title: Text(p.fullName),
                subtitle: Text(p.email),
                onTap: () => Navigator.pop(ctx, p),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (selected == null) return;

    try {
      await ref
          .read(agendaServiceProvider)
          .enrollStudent(widget.turmaId, selected.id);
      await _loadStudents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${selected.fullName} entrou na turma!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  Future<void> _removeStudent(String studentId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover da turma?'),
        content: Text('Remover $name desta turma?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: FavoColors.error),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(agendaServiceProvider)
          .unenrollStudent(widget.turmaId, studentId);
      await _loadStudents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name saiu da turma')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }
}
