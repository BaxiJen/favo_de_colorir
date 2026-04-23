-- ============================================
-- APP COMPLETO — features pra produção
-- ============================================
-- 1. Fotos de peça (bucket pecas)
-- 2. Chamada real (attendance_status em presencas)
-- 3. Foto em community_comments e chat_messages
-- 4. Comprovante de pagamento em cobrancas
-- 5. Audit logs (ações admin)
-- 6. Perfil: bio, rejection_reason, notification_prefs
-- ============================================

-- ----- 1. Fotos de peça -----
CREATE TABLE public.peca_fotos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  peca_id UUID NOT NULL REFERENCES public.pecas(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,
  caption TEXT,
  uploaded_by UUID NOT NULL REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_peca_fotos_peca ON public.peca_fotos(peca_id);

ALTER TABLE public.peca_fotos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Aluna vê fotos das próprias peças, admin/teacher vê tudo"
  ON public.peca_fotos FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.pecas p WHERE p.id = peca_id AND p.student_id = auth.uid())
    OR public.auth_role() IN ('admin', 'teacher', 'assistant')
  );

CREATE POLICY "Admin/teacher/assistant ou aluna dona da peça insere foto"
  ON public.peca_fotos FOR INSERT
  WITH CHECK (
    public.auth_role() IN ('admin', 'teacher', 'assistant')
    OR EXISTS (SELECT 1 FROM public.pecas p WHERE p.id = peca_id AND p.student_id = auth.uid())
  );

CREATE POLICY "Admin/teacher deleta foto de peça"
  ON public.peca_fotos FOR DELETE
  USING (public.auth_role() IN ('admin', 'teacher') OR uploaded_by = auth.uid());

-- ----- 2. Chamada real -----
ALTER TABLE public.presencas
  ADD COLUMN attendance_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (attendance_status IN ('pending', 'attended', 'absent', 'late'));

-- Backfill de quem já tinha attended=true
UPDATE public.presencas SET attendance_status = 'attended' WHERE attended = true;
UPDATE public.presencas SET attendance_status = 'absent' WHERE attended = false;

CREATE INDEX idx_presencas_attendance_status ON public.presencas(attendance_status);

-- ----- 3. Fotos em comments e chat -----
ALTER TABLE public.community_comments
  ADD COLUMN image_url TEXT;

ALTER TABLE public.chat_messages
  ADD COLUMN image_url TEXT;

-- Moderação síncrona: novo campo pra status
ALTER TABLE public.community_posts
  ADD COLUMN moderation_status TEXT NOT NULL DEFAULT 'approved'
    CHECK (moderation_status IN ('pending', 'approved', 'rejected'));

CREATE INDEX idx_posts_moderation_status ON public.community_posts(moderation_status);

-- Leitores só veem aprovados (autor vê os próprios pendentes/rejeitados)
DROP POLICY IF EXISTS "Active users read posts" ON public.community_posts;
CREATE POLICY "Usuários leem posts aprovados; autor lê os próprios"
  ON public.community_posts FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND (
      moderation_status = 'approved'
      OR author_id = auth.uid()
      OR public.auth_role() IN ('admin', 'teacher')
    )
  );

-- ----- 4. Comprovante de pagamento -----
ALTER TABLE public.cobrancas
  ADD COLUMN comprovante_url TEXT,
  ADD COLUMN comprovante_uploaded_at TIMESTAMPTZ,
  ADD COLUMN payment_notes TEXT;

-- ----- 5. Audit logs -----
CREATE TABLE public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID REFERENCES public.profiles(id),
  action TEXT NOT NULL,
  resource_type TEXT NOT NULL,
  resource_id UUID,
  changes JSONB,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_logs_actor ON public.audit_logs(actor_id, created_at DESC);
CREATE INDEX idx_audit_logs_resource ON public.audit_logs(resource_type, resource_id);
CREATE INDEX idx_audit_logs_action ON public.audit_logs(action, created_at DESC);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admin lê auditoria"
  ON public.audit_logs FOR SELECT
  USING (public.auth_role() = 'admin');

CREATE POLICY "Admin/teacher/assistant grava auditoria"
  ON public.audit_logs FOR INSERT
  WITH CHECK (public.auth_role() IN ('admin', 'teacher', 'assistant'));

-- ----- 6. Perfil: bio, rejection_reason -----
-- (notification_preferences já existe desde o schema inicial)
ALTER TABLE public.profiles
  ADD COLUMN bio TEXT,
  ADD COLUMN rejection_reason TEXT;

-- ----- 7. Cancelamento de aula com feriado -----
ALTER TABLE public.aulas
  ADD COLUMN cancelled_at TIMESTAMPTZ,
  ADD COLUMN cancellation_reason TEXT,
  ADD COLUMN cancelled_by UUID REFERENCES public.profiles(id);

-- ----- 8. Preços e limites (admin_config) -----
-- Tabela de config global
CREATE TABLE IF NOT EXISTS public.app_config (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  description TEXT,
  updated_by UUID REFERENCES public.profiles(id),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Todos leem config"
  ON public.app_config FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admin edita config"
  ON public.app_config FOR ALL
  USING (public.auth_role() = 'admin');

INSERT INTO public.app_config (key, value, description) VALUES
  ('max_reposicoes_mes', '1', 'Máximo de reposições que cada aluna pode fazer por mês'),
  ('cancelamento_antecedencia_horas', '4', 'Antecedência mínima (em horas) pra cancelar presença sem perder a aula'),
  ('estoque_alerta_pct', '20', 'Percentual mínimo de estoque antes de alertar admin')
ON CONFLICT (key) DO NOTHING;
