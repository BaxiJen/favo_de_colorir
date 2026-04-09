import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/peca.dart';
import '../../services/material_service.dart';

class RegisterMaterialsScreen extends ConsumerStatefulWidget {
  final String aulaId;
  final String studentId;
  final String studentName;

  const RegisterMaterialsScreen({
    super.key,
    required this.aulaId,
    required this.studentId,
    required this.studentName,
  });

  @override
  ConsumerState<RegisterMaterialsScreen> createState() =>
      _RegisterMaterialsScreenState();
}

class _RegisterMaterialsScreenState
    extends ConsumerState<RegisterMaterialsScreen> {
  bool _isLoading = false;

  // Argila
  String? _selectedArgilaId;
  final _kgUsedCtrl = TextEditingController();
  final _kgReturnedCtrl = TextEditingController(text: '0');

  // Peça
  String? _selectedPecaId;
  PecaStage _selectedStage = PecaStage.modeled;
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _kgUsedCtrl.dispose();
    _kgReturnedCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tiposArgila = ref.watch(tiposArgilaProvider);
    final tiposPeca = ref.watch(tiposPecaProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.studentName)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header
          Text('Registrar Materiais',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Registre o uso de argila e peças desta aluna.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 28),

          // ── Argila ──
          _SectionTitle('ARGILA'),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: FavoColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                tiposArgila.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Erro: $e'),
                  data: (tipos) => DropdownButtonFormField<String>(
                    decoration:
                        const InputDecoration(labelText: 'Tipo de argila'),
                    items: tipos
                        .map((t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(
                                  '${t.name} (R\$${t.pricePerKg.toStringAsFixed(2)}/kg)'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedArgilaId = v),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _kgUsedCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Kg usado', suffixText: 'kg'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _kgReturnedCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Devolvido', suffixText: 'kg'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _registerClay,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Registrar Argila'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Peça ──
          _SectionTitle('PEÇA'),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: FavoColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                tiposPeca.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Erro: $e'),
                  data: (tipos) => DropdownButtonFormField<String>(
                    decoration:
                        const InputDecoration(labelText: 'Tipo de peça'),
                    items: tipos
                        .map((t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(
                                  '${t.name} (esmalte: R\$${t.glazeFiringPrice.toStringAsFixed(2)})'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedPecaId = v),
                  ),
                ),
                const SizedBox(height: 16),

                // Stage chips
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Etapa',
                      style: Theme.of(context).textTheme.labelMedium),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Modelou'),
                      selected: _selectedStage == PecaStage.modeled,
                      onSelected: (_) =>
                          setState(() => _selectedStage = PecaStage.modeled),
                    ),
                    ChoiceChip(
                      label: const Text('Pintou'),
                      selected: _selectedStage == PecaStage.painted,
                      onSelected: (_) =>
                          setState(() => _selectedStage = PecaStage.painted),
                    ),
                    ChoiceChip(
                      label: const Text('Biscoito'),
                      selected: _selectedStage == PecaStage.bisqueFired,
                      onSelected: (_) => setState(
                          () => _selectedStage = PecaStage.bisqueFired),
                    ),
                    ChoiceChip(
                      label: const Text('Esmalte'),
                      selected: _selectedStage == PecaStage.glazeFired,
                      onSelected: (_) => setState(
                          () => _selectedStage = PecaStage.glazeFired),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Notas (opcional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _registerPiece,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Registrar Peça'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _registerClay() async {
    if (_selectedArgilaId == null || _kgUsedCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione argila e informe o peso')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(materialServiceProvider).registerClay(
            aulaId: widget.aulaId,
            studentId: widget.studentId,
            tipoArgilaId: _selectedArgilaId!,
            kgUsed: double.parse(_kgUsedCtrl.text),
            kgReturned: double.tryParse(_kgReturnedCtrl.text) ?? 0,
            registeredBy: SupabaseConfig.auth.currentUser!.id,
          );
      _kgUsedCtrl.clear();
      _kgReturnedCtrl.text = '0';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Argila registrada!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerPiece() async {
    if (_selectedPecaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o tipo de peça')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(materialServiceProvider).registerPiece(
            studentId: widget.studentId,
            aulaId: widget.aulaId,
            tipoPecaId: _selectedPecaId!,
            stage: _selectedStage,
            notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
            registeredBy: SupabaseConfig.auth.currentUser!.id,
          );
      _notesCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Peça registrada!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.5,
            color: FavoColors.onSurfaceVariant,
          ),
    );
  }
}
