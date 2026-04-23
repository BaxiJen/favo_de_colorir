-- Professora pode criar reposições quando aluna faltou na aula dela
-- (ex: aluna avisa por WhatsApp que faltou sem justificativa, professora
-- gera o crédito manual).

CREATE POLICY "Teachers create reposicoes for own-turma absences"
  ON public.reposicoes FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.aulas a
      JOIN public.turmas t ON t.id = a.turma_id
      WHERE a.id = reposicoes.original_aula_id
        AND t.teacher_id = auth.uid()
    )
  );

-- Professora também pode atualizar reposições das suas aulas
-- (ex: marcar completed manualmente, mudar makeup_aula_id).
CREATE POLICY "Teachers update own-turma reposicoes"
  ON public.reposicoes FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.aulas a
      JOIN public.turmas t ON t.id = a.turma_id
      WHERE (a.id = reposicoes.original_aula_id OR a.id = reposicoes.makeup_aula_id)
        AND t.teacher_id = auth.uid()
    )
  );
