import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
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
  final _heightCtrl = TextEditingController();
  final _diameterCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _kgUsedCtrl.dispose();
    _kgReturnedCtrl.dispose();
    _heightCtrl.dispose();
    _diameterCtrl.dispose();
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tiposArgila = ref.watch(tiposArgilaProvider);
    final tiposPeca = ref.watch(tiposPecaProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Materiais — ${widget.studentName}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Argila ──
            Text('Registro de Argila',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),

            tiposArgila.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Erro: $e'),
              data: (tipos) => DropdownButtonFormField<String>(
                initialValue: _selectedArgilaId,
                decoration:
                    const InputDecoration(labelText: 'Tipo de argila'),
                items: tipos
                    .map((t) => DropdownMenuItem(
                          value: t.id,
                          child: Text('${t.name} (R\$${t.pricePerKg.toStringAsFixed(2)}/kg)'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedArgilaId = v),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _kgUsedCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Kg usado',
                      suffixText: 'kg',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _kgReturnedCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Kg devolvido',
                      suffixText: 'kg',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _registerClay,
                icon: const Icon(Icons.add),
                label: const Text('Registrar Argila'),
              ),
            ),

            const Divider(height: 40),

            // ── Peça ──
            Text('Registro de Peça',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),

            tiposPeca.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Erro: $e'),
              data: (tipos) => DropdownButtonFormField<String>(
                initialValue: _selectedPecaId,
                decoration: const InputDecoration(labelText: 'Tipo de peça'),
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
            const SizedBox(height: 12),

            DropdownButtonFormField<PecaStage>(
              initialValue: _selectedStage,
              decoration: const InputDecoration(labelText: 'Etapa'),
              items: const [
                DropdownMenuItem(
                    value: PecaStage.modeled, child: Text('Modelou')),
                DropdownMenuItem(
                    value: PecaStage.painted, child: Text('Pintou')),
                DropdownMenuItem(
                    value: PecaStage.bisqueFired,
                    child: Text('Queima biscoito')),
                DropdownMenuItem(
                    value: PecaStage.glazeFired,
                    child: Text('Queima esmalte')),
              ],
              onChanged: (v) =>
                  setState(() => _selectedStage = v ?? PecaStage.modeled),
            ),
            const SizedBox(height: 12),

            // Campos opcionais
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _heightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Altura (cm)',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _diameterCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Diâmetro (cm)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Peso (g)',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notas',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _registerPiece,
                icon: const Icon(Icons.add),
                label: const Text('Registrar Peça'),
              ),
            ),
          ],
        ),
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
        heightCm: double.tryParse(_heightCtrl.text),
        diameterCm: double.tryParse(_diameterCtrl.text),
        weightG: double.tryParse(_weightCtrl.text),
        notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
        registeredBy: SupabaseConfig.auth.currentUser!.id,
      );

      _heightCtrl.clear();
      _diameterCtrl.clear();
      _weightCtrl.clear();
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
