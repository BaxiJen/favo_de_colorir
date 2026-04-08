-- ============================================
-- Fix: recursão infinita nas RLS policies de profiles
-- Cria função SECURITY DEFINER para buscar role sem RLS
-- ============================================

-- Função que busca o role do user autenticado sem passar pelo RLS
CREATE OR REPLACE FUNCTION public.auth_role()
RETURNS TEXT AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid()
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Dropar policies problemáticas
DROP POLICY IF EXISTS "Admin views all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Teachers view student profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admin updates all profiles" ON public.profiles;

-- Recriar sem recursão (usando a função SECURITY DEFINER)
CREATE POLICY "Admin views all profiles"
  ON public.profiles FOR SELECT
  USING (public.auth_role() = 'admin');

CREATE POLICY "Teachers view all profiles"
  ON public.profiles FOR SELECT
  USING (public.auth_role() IN ('admin', 'teacher'));

CREATE POLICY "Admin updates all profiles"
  ON public.profiles FOR UPDATE
  USING (public.auth_role() = 'admin');

-- Corrigir também policies de outras tabelas que referenciam profiles
-- (elas não são recursivas, mas usar auth_role() é mais eficiente)

-- Admin manages policies
DROP POLICY IF EXISTS "Admin manages policies" ON public.policies;
CREATE POLICY "Admin manages policies"
  ON public.policies FOR ALL
  USING (public.auth_role() = 'admin');
