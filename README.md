# Favo de Colorir

App para o ateliê de cerâmica Favo de Colorir (Tijuca, RJ). Centraliza gestão de agenda, registro de materiais, cobrança automática, feed pessoal e comunidade para ~80 alunas ativas.

## Stack

| Camada | Tecnologia |
|--------|------------|
| App (Android + iOS + Web) | Flutter (Dart) |
| Backend/BaaS | Supabase (PostgreSQL, Auth, Storage, Realtime, Edge Functions) |
| Notificações push | Firebase Cloud Messaging |
| Pagamento Pix | Mercado Pago API |
| Pagamento cartão | Nuvemshop |
| Landing page | Astro + Vercel |

## Estrutura

```
favo_de_colorir/
├── app/                  ← Flutter (Android + iOS + Web)
│   ├── lib/
│   │   ├── core/         ← Tema, constantes, router, Supabase client, error handler
│   │   ├── models/       ← 8 models Dart (Profile, Turma, Aula, Presenca, etc.)
│   │   ├── services/     ← 8 services Supabase + Riverpod providers
│   │   └── modules/
│   │       ├── auth/     ← Login, Signup, Policies, Pending, Profile, Admin Approval
│   │       ├── agenda/   ← Home, MyAgenda, AulaDetail, TeacherDashboard, AdminTurmas, Reposition
│   │       ├── materiais/← RegisterMaterials
│   │       ├── cobranca/ ← MyPayments, AdminBilling
│   │       └── feed/     ← FeedScreen
│   └── test/             ← 40 testes (models, serialization)
├── supabase/
│   ├── migrations/       ← 5 migrations (schema, auth trigger, cron, reposition, LGPD)
│   ├── functions/        ← 3 edge functions (notificação, totalização, exportação CSV)
│   ├── seed.sql
│   └── config.toml
├── docs/
│   ├── prd_favo_v1.2.md
│   └── PLANO_IMPLEMENTACAO.md
└── claude.md             ← Spec técnica + princípios de trabalho com IA
```

## Módulos (MVP Completo)

| Módulo | Descrição | Status |
|--------|-----------|--------|
| M1 — Auth | Login, cadastro, aceite de políticas, papéis, aprovação admin | ✅ |
| M2 — Agenda | Turmas, confirmação presença, reposição, lista espera | ✅ |
| M3 — Materiais | Registro argila/queimas, totalização por aluna | ✅ |
| M4 — Cobrança | Painel financeiro, Pix/cartão, exportação CSV, filtros | ✅ |
| M5 — Feed pessoal | Timeline, fotos, notas coloridas, privacidade | ✅ |
| M8 — LGPD | Exclusão de conta, consentimento, error handling | ✅ |
| M6 — Comunidade | Feed social, chat, moderação | Fase 2 |
| M7 — Estoque | Controle de argilas, alertas | Fase 3 |

## Setup

### Pré-requisitos

- Flutter SDK 3.11+
- Supabase CLI 2.75+
- Projeto Supabase (cloud ou local)

### Passos

```bash
# 1. Clonar
git clone <repo-url>
cd favo_de_colorir

# 2. Configurar Supabase
supabase login
supabase link --project-ref SEU-PROJECT-ID
supabase db push     # aplica migrations
# Rodar seed.sql via SQL Editor no dashboard

# 3. Configurar app
cp app/.env.example app/.env
# Editar app/.env com suas credenciais (sem aspas!)

# 4. Rodar
cd app
flutter pub get
flutter run -d web-server --web-port=5555   # Web
flutter run -d linux                         # Linux desktop
flutter run -d android                       # Android (requer Android SDK)
```

### Comandos úteis

```bash
flutter analyze          # Análise estática (deve ser 0 issues)
flutter test             # Testes (40 testes)
supabase db push         # Aplicar migrations na cloud
supabase functions deploy # Deploy edge functions
flutter build appbundle --release  # Build Android
flutter build web --release        # Build Web
```

## Equipe

| Pessoa | Foco |
|--------|------|
| Marcus | Arquitetura, Supabase, Edge Functions, integrações |
| Leonardo | Flutter — Agenda, Materiais, Feed |
| Luiz | Flutter — Auth, Comunidade, Landing |

## Licença

Proprietário — Favo de Colorir / BaxiJen.
