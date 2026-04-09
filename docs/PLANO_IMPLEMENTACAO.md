# Plano de Implementação — Favo de Colorir

**Início:** 6 de Abril de 2026
**MVP previsto:** 10 sprints (~20 semanas)
**Equipe:** Marcus (infra/backend), Leonardo (Flutter M2/M3/M5), Luiz (Flutter M1/M6/Landing)

---

## Progresso Geral

| Sprint | Fase | Status | Início | Conclusão |
|--------|------|--------|--------|-----------|
| 0 | Infraestrutura e Fundação | **CONCLUÍDO** | 2026-04-06 | 2026-04-06 |
| 1 | M1 Auth Core | **CONCLUÍDO** | 2026-04-08 | 2026-04-08 |
| 2 | M2 Agenda Core | **CONCLUÍDO** | 2026-04-08 | 2026-04-08 |
| 3 | M2 Reposição + Lista Espera | **CONCLUÍDO** | 2026-04-08 | 2026-04-08 |
| 4 | M3 Materiais | **CONCLUÍDO** | 2026-04-08 | 2026-04-08 |
| 5 | M5 Feed Pessoal | **CONCLUÍDO** | 2026-04-08 | 2026-04-08 |
| 6 | M4 Cobrança Core | **CONCLUÍDO** | 2026-04-08 | 2026-04-08 |
| 7 | M4 Cobrança Completo | **CONCLUÍDO** | 2026-04-08 | 2026-04-08 |
| 8 | Integração + Polimento | **CONCLUÍDO** | 2026-04-08 | 2026-04-08 |
| 9 | Testes + Beta + Redesign | **CONCLUÍDO** | 2026-04-08 | 2026-04-08 |

---

## Sprint 0 — Infraestrutura e Fundação ✅

**Status:** CONCLUÍDO em 2026-04-06

| Tarefa | Dono | Status |
|--------|------|--------|
| Criar monorepo + `.gitignore` | Marcus | ✅ |
| `flutter create` (org: br.com.favodecolorir) | Luiz | ✅ |
| Adicionar dependências Flutter (11 pacotes) | Luiz | ✅ |
| `supabase init` + config.toml (buckets avatars/feed) | Marcus | ✅ |
| Flutter core: tema mel/terracota, GoRouter, Riverpod, Supabase client | Luiz | ✅ |
| Migration `001_initial_schema.sql` (17 tabelas + RLS + views + triggers) | Marcus | ✅ |
| Seed data (argilas, peças, planos, políticas) | Marcus | ✅ |
| Models base (8 models Dart com fromJson/toJson) | Leonardo | ✅ |
| Telas shell (Login, Signup, PolicyAcceptance, PendingApproval, Home) | Luiz | ✅ |
| GitHub Actions CI (flutter-ci.yml) | Marcus | ✅ |
| `.env.example` + flutter_dotenv | Marcus | ✅ |
| README.md | — | ✅ |
| `flutter analyze` = 0 issues | — | ✅ |
| `flutter test` = all passed | — | ✅ |

**Pendente p/ completar Sprint 0:**
- [ ] `flutterfire configure` (requer projeto Firebase criado)
- [ ] Criar projeto Supabase staging (cloud)
- [ ] Commit inicial + push para GitHub

---

## Sprint 1 — M1 Auth Core ⏳

**Status:** PENDENTE

| Tarefa | Dono | Status |
|--------|------|--------|
| Configurar Supabase Auth (email+senha) | Marcus | ⏳ |
| RLS em `profiles`, `policy_acceptances` | Marcus | ⏳ |
| Tela de Login (conectar ao Supabase) | Luiz | ⏳ |
| Tela de Cadastro (conectar ao Supabase) | Luiz | ⏳ |
| Tela de Aceite de Políticas (carregar do BD) | Luiz | ⏳ |
| Tela "Aguardando Aprovação" | Luiz | ⏳ |
| `AuthService` (login, signup, logout, session, refresh) | Luiz | ⏳ |
| `ProfileService` (CRUD perfil, upload avatar) | Luiz | ⏳ |
| Fluxo admin: lista pendentes + aprovar/rejeitar | Luiz | ⏳ |
| Guarda de rota por papel no GoRouter | Luiz | ⏳ |
| Models `Turma`, `Aula`, `Presenca` | Leonardo | ⏳ |
| `AgendaService` — CRUD turmas | Leonardo | ⏳ |
| Protótipo widget calendário | Leonardo | ⏳ |

---

## Sprint 2 — M2 Agenda Core ⏳

| Tarefa | Dono | Status |
|--------|------|--------|
| RLS em `turmas`, `aulas`, `presencas`, `turma_alunos` | Marcus | ⏳ |
| Home aluna (próxima aula, notificações, atalhos) | Leonardo | ⏳ |
| Tela "Minha Agenda" (calendário + lista) | Leonardo | ⏳ |
| Tela detalhe da aula | Leonardo | ⏳ |
| Fluxo confirmação presença ("Vou" / "Não vou") | Leonardo | ⏳ |
| Dashboard professora | Leonardo | ⏳ |
| Admin: CRUD turmas | Leonardo | ⏳ |
| Edge function `enviar-notificacao` + FCM | Marcus | ⏳ |
| Cron: notificação 24h antes da aula | Marcus | ⏳ |
| Lembrete 6h antes (não respondeu) | Marcus | ⏳ |
| Tela perfil + configurações | Luiz | ⏳ |

---

## Sprint 3 — M2 Reposição + Lista de Espera ⏳

| Tarefa | Dono | Status |
|--------|------|--------|
| Fluxo reposição: falta → liberar vaga → notificar | Leonardo | ⏳ |
| Tela "Repor Aula" | Leonardo | ⏳ |
| Limite 1 reposição/mês (+ override admin) | Leonardo | ⏳ |
| Lista de espera (fila, notificação, 24h para aceitar) | Leonardo | ⏳ |
| Fluxo aula avulsa | Leonardo | ⏳ |
| Realtime subscription presença | Marcus | ⏳ |
| Edge function `liberar-vaga` | Marcus | ⏳ |
| DB function `check_reposition_limit` | Marcus | ⏳ |
| Data layer M5 Feed | Luiz | ⏳ |

---

## Sprint 4 — M3 Materiais ⏳

| Tarefa | Dono | Status |
|--------|------|--------|
| Tela "Registrar Materiais" | Leonardo | ⏳ |
| Registro argila (tipo + kg + devolução) | Leonardo | ⏳ |
| Registro queima (peça + tipo + preço) | Leonardo | ⏳ |
| Etapas da peça (modelou/pintou/biscoito/esmalte) | Leonardo | ⏳ |
| Campos opcionais (dimensões, peso) | Leonardo | ⏳ |
| Fila offline (SQLite + sync) | Leonardo | ⏳ |
| Admin: config tipos argila + preços queima | Leonardo | ⏳ |
| RLS tabelas materiais | Marcus | ⏳ |
| View `v_consumo_mensal_aluna` | Marcus | ⏳ |
| Seed data tipos | Marcus | ⏳ |

---

## Sprint 5 — M5 Feed Pessoal ⏳

| Tarefa | Dono | Status |
|--------|------|--------|
| Tela timeline (scroll infinito) | Leonardo | ⏳ |
| Upload fotos (multi-imagem, Storage) | Luiz | ⏳ |
| Auto-popular feed de registros materiais | Leonardo | ⏳ |
| Notas livres + notas rápidas com cores | Luiz | ⏳ |
| Toggle privacidade | Luiz | ⏳ |
| Filtros (tipo peça, argila, período) | Leonardo | ⏳ |
| Storage buckets com RLS | Marcus | ⏳ |
| Edge function otimização imagem | Marcus | ⏳ |
| Funções DB totalização cobrança | Marcus | ⏳ |

---

## Sprint 6 — M4 Cobrança Core ⏳

| Tarefa | Dono | Status |
|--------|------|--------|
| Edge function `totalizar-cobranca` | Marcus | ⏳ |
| População `cobrancas` + itens | Marcus | ⏳ |
| Integração Mercado Pago (Pix QR) | Marcus | ⏳ |
| Integração Nuvemshop (cartão) | Marcus | ⏳ |
| Webhook pagamento | Marcus | ⏳ |
| Tela "Meus Pagamentos" (aluna) | Leonardo | ⏳ |
| Dashboard financeiro (admin) | Leonardo | ⏳ |
| Lista cobranças por aluna | Leonardo | ⏳ |

---

## Sprint 7 — M4 Cobrança Completo ⏳

| Tarefa | Dono | Status |
|--------|------|--------|
| Admin: revisar + confirmar cobranças | Marcus | ⏳ |
| Notificação "cobrança pronta" | Marcus | ⏳ |
| Status real-time pagamento | Marcus | ⏳ |
| Exportação CSV | Marcus | ⏳ |
| Exportação PDF (edge function) | Marcus | ⏳ |
| Filtros admin (mês, status, aluna) | Leonardo | ⏳ |
| Histórico pagamentos (aluna) | Leonardo | ⏳ |
| Registro manual pagamento | Leonardo | ⏳ |

---

## Sprint 8 — Integração + Polimento ⏳

| Tarefa | Dono | Status |
|--------|------|--------|
| Offline sync robusto | Leonardo | ⏳ |
| LGPD: exclusão de conta | Luiz | ⏳ |
| Consentimento com timestamp + re-aceite | Luiz | ⏳ |
| Performance (lazy loading, cache, paginação) | Leonardo | ⏳ |
| Error handling global | Luiz | ⏳ |
| Deep linking | Luiz | ⏳ |
| Dashboard admin combinado | Leonardo | ⏳ |
| Analytics (DAU/MAU) | Marcus | ⏳ |

---

## Sprint 9 — Testes + Beta ⏳

| Tarefa | Dono | Status |
|--------|------|--------|
| Testes end-to-end | Todos | ⏳ |
| Bug fixes QA | Todos | ⏳ |
| Deploy beta (APK) | Marcus | ⏳ |
| Coleta feedback | Todos | ⏳ |
| Prep Play Store | Luiz | ⏳ |
| Config Supabase produção | Marcus | ⏳ |
| Landing page (Astro + Vercel) | Luiz | ⏳ |
| Migração dados existentes | Marcus | ⏳ |

---

## Legenda

- ✅ Concluído
- 🔄 Em progresso
- ⏳ Pendente
- ❌ Bloqueado
- 🚫 Cancelado

---

## Critérios de Verificação por Sprint

| Sprint | Como verificar |
|--------|---------------|
| 0 | `flutter run` mostra app shell, `flutter analyze` sem erros |
| 1 | Cadastro + login + aceite de políticas funciona end-to-end |
| 2-3 | Confirmar presença, push 24h antes, repor aula, lista espera |
| 4 | Professora registra argila/queima offline e synca |
| 5 | Aluna vê timeline com fotos e notas |
| 6-7 | Admin totaliza, aluna paga Pix, exporta CSV/PDF |
| 8 | Offline funciona, LGPD ok, performance <2s |
| 9 | Beta com usuárias reais confirma todos os fluxos |
