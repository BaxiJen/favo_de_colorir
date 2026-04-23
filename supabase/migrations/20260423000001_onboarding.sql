-- Onboarding de aluna no primeiro acesso.
-- Timestamp = quando ela terminou o tutorial. NULL = ainda não viu.

ALTER TABLE public.profiles
  ADD COLUMN onboarded_at TIMESTAMPTZ;

CREATE INDEX idx_profiles_onboarded_at ON public.profiles(onboarded_at);
