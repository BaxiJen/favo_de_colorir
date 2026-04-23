-- ============================================
-- Refinamento de RLS — restringe acesso de professora
-- à sua própria turma, não todas.
-- ============================================

-- AULAS: professora só edita aulas de turmas em que ela é teacher_id;
-- admin continua podendo tudo.
DROP POLICY IF EXISTS "Admin and teachers manage aulas" ON public.aulas;

CREATE POLICY "Admin manages all aulas"
  ON public.aulas FOR ALL
  USING (public.auth_role() = 'admin');

CREATE POLICY "Teachers manage own-turma aulas"
  ON public.aulas FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.turmas t
      WHERE t.id = aulas.turma_id AND t.teacher_id = auth.uid()
    )
  );

-- PRESENCAS: professora só toca em presencas de aulas de turma dela;
-- aluna só atualiza SUA confirmation; admin tudo.
DROP POLICY IF EXISTS "Admin and teachers manage presencas" ON public.presencas;

CREATE POLICY "Admin manages all presencas"
  ON public.presencas FOR ALL
  USING (public.auth_role() = 'admin');

CREATE POLICY "Teachers manage own-turma presencas"
  ON public.presencas FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.aulas a
      JOIN public.turmas t ON t.id = a.turma_id
      WHERE a.id = presencas.aula_id AND t.teacher_id = auth.uid()
    )
  );

-- Assistente ajuda professora a marcar chamada/materiais (mesmo escopo).
CREATE POLICY "Assistants manage presencas"
  ON public.presencas FOR ALL
  USING (public.auth_role() = 'assistant');

-- REPOSICOES: admin continua com tudo; aluna só vê e cria as próprias
-- (policies existentes já cobrem). Teacher pode ver reposições de sua
-- turma (pra dashboard), não editar.
CREATE POLICY "Teachers see own-turma repositions"
  ON public.reposicoes FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.aulas a
      JOIN public.turmas t ON t.id = a.turma_id
      WHERE a.id = reposicoes.original_aula_id
        AND t.teacher_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.aulas a
      JOIN public.turmas t ON t.id = a.turma_id
      WHERE a.id = reposicoes.makeup_aula_id
        AND t.teacher_id = auth.uid()
    )
  );

-- LISTA_ESPERA: policy atual permite admin; adicionar teacher pra ver
-- lista da própria turma.
CREATE POLICY "Teachers see own-turma waitlist"
  ON public.lista_espera FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.turmas t
      WHERE t.id = lista_espera.turma_id AND t.teacher_id = auth.uid()
    )
  );
