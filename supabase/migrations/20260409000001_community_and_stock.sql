-- ============================================
-- M6: COMUNIDADE (Feed Social + Chat)
-- ============================================

CREATE TABLE public.community_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content TEXT,
  image_urls TEXT[] DEFAULT '{}',
  is_flagged BOOLEAN NOT NULL DEFAULT false,
  flag_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.community_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.community_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(post_id, user_id)
);

CREATE TABLE public.chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES public.profiles(id),
  receiver_id UUID NOT NULL REFERENCES public.profiles(id),
  content TEXT NOT NULL,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_community_posts_author ON public.community_posts(author_id);
CREATE INDEX idx_community_posts_created ON public.community_posts(created_at DESC);
CREATE INDEX idx_community_comments_post ON public.community_comments(post_id);
CREATE INDEX idx_community_likes_post ON public.community_likes(post_id);
CREATE INDEX idx_chat_messages_participants ON public.chat_messages(sender_id, receiver_id);
CREATE INDEX idx_chat_messages_created ON public.chat_messages(created_at DESC);

-- RLS
ALTER TABLE public.community_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- Posts: active users read, authors manage own, admin manages all
CREATE POLICY "Active users read posts"
  ON public.community_posts FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users create posts"
  ON public.community_posts FOR INSERT
  WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Authors update own posts"
  ON public.community_posts FOR UPDATE
  USING (auth.uid() = author_id);

CREATE POLICY "Authors or admin delete posts"
  ON public.community_posts FOR DELETE
  USING (auth.uid() = author_id OR public.auth_role() IN ('admin', 'teacher'));

-- Comments
CREATE POLICY "Active users read comments"
  ON public.community_comments FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users create comments"
  ON public.community_comments FOR INSERT
  WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Authors or admin delete comments"
  ON public.community_comments FOR DELETE
  USING (auth.uid() = author_id OR public.auth_role() IN ('admin', 'teacher'));

-- Likes
CREATE POLICY "Active users read likes"
  ON public.community_likes FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users manage own likes"
  ON public.community_likes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users remove own likes"
  ON public.community_likes FOR DELETE
  USING (auth.uid() = user_id);

-- Chat: only sender/receiver can read
CREATE POLICY "Users read own messages"
  ON public.chat_messages FOR SELECT
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Users send messages"
  ON public.chat_messages FOR INSERT
  WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users update read status"
  ON public.chat_messages FOR UPDATE
  USING (auth.uid() = receiver_id);

-- ============================================
-- M7: ESTOQUE
-- ============================================

CREATE TABLE public.estoque_argila (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo_argila_id UUID NOT NULL REFERENCES public.tipos_argila(id),
  quantidade_kg NUMERIC(8,3) NOT NULL DEFAULT 0,
  nivel_minimo_kg NUMERIC(8,3) NOT NULL DEFAULT 10,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.estoque_compras (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo_argila_id UUID NOT NULL REFERENCES public.tipos_argila(id),
  quantidade_kg NUMERIC(8,3) NOT NULL,
  preco_total NUMERIC(10,2),
  fornecedor TEXT,
  data_compra DATE NOT NULL DEFAULT CURRENT_DATE,
  registrado_por UUID NOT NULL REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_estoque_argila_tipo ON public.estoque_argila(tipo_argila_id);

ALTER TABLE public.estoque_argila ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estoque_compras ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Auth users read estoque"
  ON public.estoque_argila FOR SELECT
  USING (public.auth_role() IN ('admin', 'teacher', 'assistant'));

CREATE POLICY "Admin manages estoque"
  ON public.estoque_argila FOR ALL
  USING (public.auth_role() = 'admin');

CREATE POLICY "Auth users read compras"
  ON public.estoque_compras FOR SELECT
  USING (public.auth_role() IN ('admin', 'teacher'));

CREATE POLICY "Admin manages compras"
  ON public.estoque_compras FOR INSERT
  WITH CHECK (public.auth_role() IN ('admin', 'teacher'));

-- Trigger: baixa automática de estoque ao registrar argila
CREATE OR REPLACE FUNCTION public.handle_clay_usage()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.estoque_argila
  SET quantidade_kg = quantidade_kg - NEW.kg_used + NEW.kg_returned,
      updated_at = now()
  WHERE tipo_argila_id = NEW.tipo_argila_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_clay_registered
  AFTER INSERT ON public.registros_argila
  FOR EACH ROW EXECUTE FUNCTION public.handle_clay_usage();

-- Trigger: adicionar estoque ao registrar compra
CREATE OR REPLACE FUNCTION public.handle_clay_purchase()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.estoque_argila (tipo_argila_id, quantidade_kg)
  VALUES (NEW.tipo_argila_id, NEW.quantidade_kg)
  ON CONFLICT (tipo_argila_id) DO UPDATE
  SET quantidade_kg = public.estoque_argila.quantidade_kg + NEW.quantidade_kg,
      updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Precisa de unique constraint para ON CONFLICT funcionar
ALTER TABLE public.estoque_argila ADD CONSTRAINT uq_estoque_tipo UNIQUE (tipo_argila_id);

CREATE TRIGGER on_clay_purchased
  AFTER INSERT ON public.estoque_compras
  FOR EACH ROW EXECUTE FUNCTION public.handle_clay_purchase();
