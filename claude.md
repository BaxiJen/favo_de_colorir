# Claude.md — Favo de Colorir

## Instruções para Claude Code

**Skill obrigatória para UI/frontend:** sempre usar a skill oficial [`frontend-design`](https://github.com/anthropics/skills/tree/main/skills/frontend-design) (`frontend-design@claude-plugins-official`) em qualquer trabalho que envolva:

- Landing page (Astro/Vercel)
- Componentes Flutter novos ou refatorações visuais do app
- Telas admin / dashboards
- Qualquer HTML/CSS/componente web
- Tematização, tipografia, paleta, animações, layout

Carregue a skill antes de gerar código de UI. A intenção é evitar estética genérica de "AI slop" e manter coerência com o Design System **Artisanal Modernism** (Epilogue + Manrope, tonal surfaces) já aplicado no app Flutter. Tipografia distintiva, paleta comprometida com acentos fortes, composição espacial com asymmetry/overlap, motion intencional via CSS. Proibido: fontes genéricas (Inter, Roboto, Arial, Space Grotesk), paletas "roxo em branco", layouts previsíveis.

**Skill obrigatória para código Flutter/Dart:** sempre usar a skill `flutter-favo` (local, em `.claude/skills/flutter-favo/SKILL.md`) em qualquer trabalho que envolva código em `app/lib/` ou `app/test/`. Ela contém stack travada, arquitetura de pastas, regras de Riverpod/go_router/Supabase, padrões de teste (TDD obrigatório) e antipadrões do projeto. Para UI nova no app, combine com `frontend-design`.

---

## Visão Geral do Produto

**Produto:** App Favo de Colorir (Ateliê de Cerâmica)  
**Cliente:** Débora — Favo de Colorir (Tijuca, RJ)  
**Equipe:** Marcus, Luis Barbedo, Leonardo Camilo — BaxiJen  
**Versão PRD:** 1.2 (Março de 2026)  
**Status:** Para desenvolvimento

### Problema

Ateliê com ~80 alunas ativas gerenciado manualmente via WhatsApp, bloco de notas e papel. Cobrança mensal consome 2 dias inteiros; vagas são perdidas por falta de controle de presença; sem comunidade digital.

### Solução

App mobile-first (Android prioritário) que centraliza: gestão de agenda/turmas, registro de materiais, cobrança automática, feed pessoal de evolução, comunidade exclusiva.

### Definição de Sucesso

- 100% das alunas usando o app (obrigatório)
- Cobrança mensal: 2 dias → minutos
- Zero vagas perdidas por falta de controle
- Pagamentos fluindo sem intervenção manual

---

## Stack Técnica

| Camada | Tecnologia | Justificativa |
|--------|------------|---------------|
| **App (Android + iOS + Web)** | Flutter (Dart) | Codebase única, experiência do Luiz |
| **Backend/BaaS** | Supabase | PostgreSQL relacional (ideal para cobranças), Auth, Storage, Realtime, Edge Functions |
| **Banco de dados** | PostgreSQL (via Supabase) | Totalizações de cobrança: `SELECT SUM() GROUP BY` simples |
| **Autenticação** | Supabase Auth | E-mail + senha, Row Level Security (RLS) para permissões |
| **Storage (fotos)** | Supabase Storage | Fotos das peças, buckets por aluna |
| **Realtime** | Supabase Realtime | Chat professora ↔ aluna, atualizações presença |
| **Edge Functions** | Supabase (Deno) | Totalização mensal, notificações, moderação IA |
| **Notificações push** | Firebase Cloud Messaging (FCM) | Gratuito, Android + iOS |
| **Pagamento Pix** | Mercado Pago API | Sem taxas, QR code automático |
| **Pagamento cartão** | Nuvemshop | Já integrado (parcela 2-3x) |
| **Landing page** | Astro | Estático, leve, SEO excelente |
| **Hospedagem landing** | Vercel | Deploy automático em push |
| **Repositório** | GitHub monorepo | Flutter, Supabase, landing e docs |

### Por que Supabase?
- Relacional perfeit para somas/grupos (argilas+queimas por aluna/mês)
- Row Level Security resolve permissões (admin vê financeiro, professora não)
- SQL real para relatórios, CSV, PDF
- Free tier suficiente (500MB, 1GB storage, 50k users)
- PostgreSQL padrão = migração fácil

---

## Arquitetura de Módulos

| Módulo | Descrição | Usuários |
|--------|-----------|----------|
| **M1 — Auth** | Login, cadastro, perfis, aceite obrigatório de políticas | Todos |
| **M2 — Agenda** | Turmas, confirmação presença, reposição, lista espera | Todos |
| **M3 — Materiais** | Registro argila, queimas, totalização por aluna | Professoras + Admin |
| **M4 — Cobrança** | Painel financeiro, cobranças, Pix/cartão | Admin (Débora) |
| **M5 — Feed pessoal** | Histórico, fotos, anotações | Alunas |
| **M6 — Comunidade** | Feed social, posts, moderação, chat | Todos |
| **M7 — Estoque** | Controle argilas, alertas | Admin + Professoras |

---

## Papéis e Permissões

| Papel | Acesso | Prioridade |
|-------|--------|-----------|
| **Admin (Débora)** | Tudo: agenda, materiais, financeiro, comunidade, estoque, usuários | Alta |
| **Professora** | Agenda, materiais, comunidade, mensagens, estoque. Sem financeiro. | Alta |
| **Assistente** | Agenda (viz), materiais | Média |
| **Aluna** | Agenda pessoal, feed pessoal, comunidade, histórico, pagamentos | Alta |

---

## M1 — Autenticação e Políticas

### Fluxo de Cadastro

1. **Triagem prévia (fora do app):** Débora confirma vaga via Instagram/WhatsApp antes de enviar link
2. **Cadastro no app:** Nome, e-mail, telefone, data de nascimento, foto (opcional)
3. **Aceite obrigatório de políticas:** 
   - Regras de reposição (máx 1/mês, aviso 1 dia, não remarca se faltar)
   - Política de faltas (confirmação obrigatória)
   - Cobrança de argilas e queimas (por consumo, fim do mês)
   - Cancelamento por plano (mensal: 10-15 dias; tri/semi: multa 20%)
   - Regras comunidade (respeito, moderação, sem política)
4. **Aprovação:** Admin aprova e vincula à turma

**Crítico:** Cadastro só conclui após aceite. Registro de data/hora no BD para conformidade legal.

---

## M2 — Agenda e Agendamentos

### Estrutura de Turmas

- **Modalidades:** Regular (semanal, 2h), Oficina/Workshop, Aula avulsa
- **Capacidade:** Regular 8, Oficina 10
- **Horários:** Fixos semanais (seg-sáb)
- **Níveis:** Sem progressão
- **Pré-requisitos:** Nenhum

### Confirmação de Presença (Crítico)

**Regra:** 1 dia antes de cada aula, notificação push: "Vou" ou "Não vou"

| Cenário | Comportamento |
|---------|---------------|
| Confirma "Vou" | Presença pré-registrada |
| Informa "Não vou" | Vaga liberada, falta registrada |
| Não responde | Lembrete 6h antes; se não responder, conta como esperada |

### Sistema de Reposição

- **Máx 1 reposição/mês** (admin pode liberar extras)
- **Não reagenda:** faltou, perdeu
- **Aviso 1 dia antes**
- **Fluxo:** Informa falta → Vaga liberada → Notifica alunas com reposição pendente → Aluna seleciona turma → Confirmação automática

### Lista de Espera

- Turma cheia → fila de interessadas
- Vaga abre → notificação (24h para aceitar)

### Aulas Avulsas

- Aluna experiente compra aula única, escolhe turma com vaga, paga e agenda

---

## M3 — Registro de Materiais

### Registro de Argila

1. Professora seleciona turma/aula
2. Para cada aluna: tipo argila (dropdown) + kg usados
3. Registra devolução (se houver)
4. Cálculo automático: usado − devolvido
5. Tipos configuráveis pela admin

### Registro de Queimas

- **Biscoito (1ª queima):** não cobrada
- **Esmalte (2ª queima):** cobrada por peça
  - Caneca: ~R$5-6
  - Prato: ~R$8-15
  - (Valores configuráveis)

**Fluxo:** Professora seleciona aluna + tipo peça + tamanho → Sistema aplica preço → Registra etapa (modelou/pintou/queima esmalte)

### Campos Opcionais (Insight Ceramik)

- Dimensões (altura, diâmetro) — opcional
- Peso — opcional

> Campos opcionais não bloqueiam fluxo.

---

## M4 — Cobrança e Pagamentos

### Planos

| Plano | Descrição | Cancelamento |
|-------|-----------|--------------|
| **Mensal** | Valor cheio, renova automático | Aviso 10-15 dias |
| **Trimestral** | Desconto | Multa 20% restante |
| **Semestral** | Maior desconto | Multa 20% restante |
| **Avulsa** | Pagamento único | N/A |
| **Oficina** | Pagamento único, tudo incluso | N/A |

### Composição da Cobrança

**Total = Mensalidade + Argilas do mês + Queimas de esmalte do mês**

### Fluxo

1. **1º dia útil:** Sistema totaliza argilas + queimas por aluna
2. **Painel de cobrança:** Valores discriminados (admin revisa)
3. **Notificação:** Cada aluna recebe aviso
4. **Pagamento:** Aluna paga pelo app (Pix ou cartão)
5. **Status:** pendente → pago

### Métodos de Pagamento

- **Pix:** Preferencial, sem taxas, QR code automático
- **Cartão:** Via Nuvemshop, parcelamento 2-3x

### Painel Financeiro (Admin)

- Visão geral (total a receber, recebido, pendente)
- Lista por aluna (plano, argilas, queimas, total, status)
- Filtros e exportação (CSV/PDF)

---

## M5 — Feed Pessoal / Histórico da Aluna

Timeline de evolução na cerâmica.

| ID | Funcionalidade | Prioridade |
|----|----|-----------|
| **FP-01** | Timeline por aula (data, turma, o que fez) | Alta |
| **FP-02** | Foto(s) da peça em cada etapa | Alta |
| **FP-03** | Registro de argila usada | Alta |
| **FP-04** | Anotações livres + notas rápidas com cores | Alta |
| **FP-05** | Privado por padrão, opção publicar na comunidade | Média |
| **FP-06** | Filtro por tipo peça, argila, período | Baixa |
| **FP-07** | Campos opcionais: dimensões e peso | Baixa |

---

## M6 — Comunidade

Feed social exclusivo (modelo: grupo Facebook clássico).

| ID | Funcionalidade | Prioridade |
|----|----|-----------|
| **CM-01** | Feed único (sem separação por turma) | Alta |
| **CM-02** | Post com foto/vídeo/texto | Alta |
| **CM-03** | Comentários e curtidas | Alta |
| **CM-04** | Sem compartilhamento externo | Alta |
| **CM-05** | Sem DM entre alunas | Alta |
| **CM-06** | Chat professora ↔ aluna | Alta |
| **CM-07** | Enquetes e desafios criativos | Média |
| **CM-08** | Blog/dicas das professoras | Média |
| **CM-09** | Acesso só alunas ativas | Alta |

### Moderação

- Filtro automático (IA) para conteúdo político/inadequado
- Flagados → fila de aprovação
- Sem flag → direto no feed
- Admin/professoras podem excluir manualmente

### Notificações

| Tipo | Comportamento | Configurável? |
|------|---------------|----------------|
| Recado geral | Obrigatório | Não |
| Confirmação presença | Obrigatório | Não |
| Lembrete reposição | Obrigatório | Não |
| Cobrança | Obrigatório | Não |
| Nova postagem | Opcional | Sim |
| Resposta comentário | Opcional | Sim |
| Mensagem direta | Obrigatório | Não |

---

## M7 — Controle de Estoque

| ID | Funcionalidade | Prioridade |
|----|----|-----------|
| **ES-01** | Cadastro de argilas com estoque (kg) | Média |
| **ES-02** | Baixa automática conforme uso | Média |
| **ES-03** | Alerta nível mínimo (~2 sacos) | Média |
| **ES-04** | Registro de compras | Baixa |
| **ES-05** | Histórico de consumo mensal | Baixa |

> Prazo reposição: ~5 dias. Alerta deve considerar janela + consumo médio.

---

## Mapa de Telas

### Aluna

| Tela | Descrição | Módulo |
|------|-----------|--------|
| Login/Cadastro | Entrada + aceite políticas obrigatório | M1 |
| Home | Próxima aula, notificações, atalhos | M2 |
| Minha agenda | Calendário, confirmação, reposições | M2 |
| Repor aula | Turmas com vaga | M2 |
| Meu feed | Timeline pessoal + notas rápidas | M5 |
| Comunidade | Feed social | M6 |
| Mensagens | Chat com professoras | M6 |
| Meus pagamentos | Cobrança, histórico, pagar | M4 |
| Perfil | Dados, notificações, plano | M1 |

### Professora

| Tela | Descrição | Módulo |
|------|-----------|--------|
| Dashboard | Turmas do dia, confirmadas, pendências | M2 |
| Turma do dia | Lista presentes + registro rápido | M3 |
| Registrar materiais | Aluna → argila + peças | M3 |
| Comunidade | Feed + blog/dicas | M6 |
| Mensagens | Chat com alunas | M6 |
| Estoque | Visão argilas, alertas | M7 |

### Admin (Débora)

| Tela | Descrição | Módulo |
|------|-----------|--------|
| Dashboard admin | Agenda, cobranças, moderação, alertas | Todos |
| Gestão de turmas | Criar, editar, abrir/fechar | M2 |
| Gestão de alunas | Cadastros, planos, histórico | M1 |
| Políticas do ateliê | Editar texto, forçar re-aceite | M1 |
| Painel financeiro | Cobranças, status, exportar | M4 |
| Moderar posts | Fila de posts flagados | M6 |
| Notificações gerais | Recados para todas | M6 |
| Configurações | Preços queima, tipos argila | M3/M7 |

---

## MVP (Fase 1)

**Prioridades:**
1. Gestão de pagamentos e cobrança automática (argilas + queimas)
2. Sistema de reposição (confirmação presença + reagendamento)
3. Feed pessoal / histórico da aluna

**Inclui:** M1 (com políticas), M2, M3, M4, M5

---

## Fase 2 — Comunidade

M6 completo

---

## Fase 3 — Extras

- M7 — Estoque
- Enquetes e desafios
- Blog das professoras

---

## Design

**Diretrizes:** Criativo • Artesanal • Acolhedor

- **Estilo:** Minimalista e limpo
- **Formas:** Cantos arredondados, orgânicas
- **Fotos:** Reais do ateliê
- **Paleta:** Tons quentes (mel, terracota)
- **Tom:** Informal, acolhedor, textos diretos
- **Mobile-first:** Design para celular, web como espelho

---

## Requisitos Não-Funcionais

| Categoria | Requisito |
|-----------|-----------|
| Performance | Telas carregam < 2s em 4G |
| Performance | Registro de materiais offline |
| Segurança | Auth segura (e-mail + senha ou OAuth) |
| Segurança | Financeiro só admin (RLS no BD) |
| Segurança | LGPD: consentimento + opção excluir conta |
| Disponibilidade | 99.5% uptime |
| Escala | Até 200 usuários simultâneos |
| Backup | Diário automático |
| Notificações | Push (FCM ou equivalente) |
| Analytics | DAU/MAU, telas mais acessadas |

---

## Estrutura do Monorepo

```
favo-platform/
├── app/                        ← Flutter (Android + iOS + web)
│   ├── lib/
│   │   ├── core/               ← tema, constantes, utils, Supabase client
│   │   ├── models/             ← Aluna, Turma, Aula, etc.
│   │   ├── services/           ← acesso Supabase (repos)
│   │   ├── modules/
│   │   │   ├── auth/           ← M1
│   │   │   ├── agenda/         ← M2
│   │   │   ├── materiais/      ← M3
│   │   │   ├── cobranca/       ← M4
│   │   │   ├── feed_pessoal/   ← M5
│   │   │   ├── comunidade/     ← M6
│   │   │   └── estoque/        ← M7
│   │   └── main.dart
│   ├── pubspec.yaml
│   └── test/
│
├── landing/                    ← Astro (landing page)
│   ├── src/pages/
│   ├── astro.config.mjs
│   └── package.json
│
├── supabase/                   ← Backend
│   ├── migrations/             ← schema SQL versionado
│   ├── functions/              ← Edge Functions (Deno/TS)
│   │   ├── totalizar-cobranca/
│   │   ├── enviar-notificacao/
│   │   └── moderar-post/
│   ├── seed.sql
│   └── config.toml
│
├── docs/
│   ├── prd_v1.2.md
│   └── requisitos.md
│
├── .github/workflows/          ← CI/CD
├── .gitignore
└── README.md
```

---

## Divisão de Trabalho

| Pessoa | Foco | Módulos |
|--------|------|---------|
| **Marcus** | Arquitetura, Supabase, edge functions, integrações (Pix, FCM) | M4 (Cobrança), infra |
| **Leonardo** | Flutter — telas e lógica | M2 (Agenda), M3 (Materiais), M5 (Feed) |
| **Luiz** | Flutter — auth, comunidade, landing | M1 (Auth), M6 (Comunidade), Landing |

---

## Análise Competitiva — Ceramik

O Ceramik (ceramik.app/pt) é a referência do mercado. Diferenças e insights:

### Diferenciais do Favo de Colorir

- **Sistema de reposição automática** com liberação de vagas em tempo real
- **Cobrança automática de argila por consumo** (maior dor, não encontrada no Ceramik)
- **Confirmação de presença proativa** (notificação 1 dia antes)
- **Moderação com filtro IA**
- **Políticas do ateliê integradas ao onboarding**
- **100% em português BR**

### Insights para Incorporar

- Kiln tracking com dimensões e peso (campos opcionais)
- Notas rápidas com cores (já planejado em FP-04)
- Studio analytics com gráficos visuais

---

## Próximos Passos (Do PRD)

| # | Ação | Resp. | Prazo |
|---|------|-------|-------|
| 1 | Débora aprovar PRD v1.2 | Débora | 1 semana |
| 2 | Enviar formulário cadastro (Google Forms) | Débora | 1 semana |
| 3 | Enviar fotos controle manual | Débora | 1 semana |
| 4 | Enviar referências visuais + identidade | Débora | 15 dias |
| 5 | Analisar app Ceramik em detalhe | BaxiJen | 1 semana |
| 6 | ✅ Definir stack técnica | BaxiJen | Concluído |
| 7 | Redigir políticas do ateliê | Débora | 2 semanas |
| 8 | Criar wireframes MVP | BaxiJen | 2 semanas |
| 9 | Apresentar wireframes | Todos | Reunião #2 |
| 10 | Configurar repositório (monorepo Flutter) | BaxiJen | 1 semana |
| 11 | Recrutar grupo de testes | Débora | Antes do beta |

---

## Comandos CLI Essenciais

```bash
# Setup Flutter (Android + iOS + Web)
flutter create --org br.com.favodecolorir --project-name favo app

# Adicionar dependências
cd app && flutter pub add supabase_flutter firebase_messaging image_picker cached_network_image go_router flutter_riverpod intl

# Setup Supabase
supabase init
supabase start
supabase db reset

# Setup Firebase para FCM
flutterfire configure --project=favo-de-colorir

# Setup Astro
npm create astro@latest landing -- --template minimal

# Build & Deploy
cd app && flutter build apk --release     # Android
cd app && flutter build appbundle --release # Android (Play Store)
cd app && flutter build ipa --release     # iOS
cd app && flutter build web --release     # Web
cd landing && npm run build              # Landing
supabase functions deploy                # Edge Functions
```

---

## Princípios de Trabalho com IA

> Baseado em: [Do Zero à Pós-Produção em 1 Semana — Akita](https://akitaonrails.com/2026/02/20/do-zero-a-pos-producao-em-1-semana-como-usar-ia-em-projetos-de-verdade-bastidores-do-the-m-akita-chronicles/)

### 1. Pair Programming com IA

O desenvolvedor é o piloto; a IA é copiloto. Você toma as decisões arquiteturais, a IA ajuda a executar. Nunca delegue o entendimento — se você não entende o que foi gerado, não aceite.

### 2. Iteração Curta

Trabalhe em ciclos de 1-2 horas: implementar → revisar → testar → commit. Nada de planejar 2 semanas antes de escrever código. Qualidade emerge de ciclos curtos com feedback rápido.

### 3. CLAUDE.md como Especificação Viva

Este arquivo deve evoluir junto com o projeto:
- Documentar decisões arquiteturais tomadas
- Registrar padrões estabelecidos
- Evitar que a IA repita erros ou desvios anteriores
- Atualizar conforme novas descobertas surgem

### 4. Testes Obrigatórios

Código sem testes não é código de produção. Exija testes para cada feature. Valide cobertura. Execute a suite completa antes de cada deploy.

### 5. Code Review Sempre

Nunca aceite código gerado pela IA sem revisar. Procure por:
- Lógica que parece certa mas está errada
- Edge cases não tratados
- Performance inadequada
- Segurança comprometida

### 6. Princípios XP (Extreme Programming)

- **Simplicidade** — design simples que resolve o problema de hoje
- **Feedback rápido** — testes automatizados, deploy frequente
- **Mudança incremental** — pequenos passos, não big bangs
- **Qualidade incorporada** — qualidade não é adicionada depois, faz parte do processo

### 7. Contexto Explícito

A IA precisa de contexto abundante. Não assuma que ela vai "entender" implicitamente. Sempre defina:
- Padrões de código preferidos
- Estrutura de diretórios e convenções
- Dependências e versões
- Filosofia e restrições do projeto

### 8. Não Confie em One-Shot

Nenhum prompt perfeito gera código pronto para produção. Sempre será necessário:
- Múltiplas iterações
- Correções do desenvolvedor
- Refinamentos baseados em testes que falham
- Ajustes quando a IA toma decisões equivocadas

### 9. Entenda o Que Foi Gerado

"O teste passou" não é suficiente. Você precisa compreender completamente o que foi gerado. Se não entende, não mergeia.

### 10. Segurança em Código Gerado

Código da IA pode ter vulnerabilidades sutis. Revise especialmente:
- Tratamento de entrada do usuário
- Autenticação e autorização (RLS, tokens)
- Injeção de dados (SQL, XSS)
- Exposição de informações sensíveis

### 11. Testes Primeiro, Commits Sempre

- **Testes antes de commitar** — escreva ou atualize testes antes de considerar uma feature pronta
- **Commit ao terminar cada unidade de trabalho** — não acumule mudanças. Terminou um service? Commit. Terminou uma tela? Commit. Cada commit deve ser atômico e funcional.
- **Mensagens de commit descritivas** — explique o "porquê", não só o "o quê"
- **Nunca commitar código que quebra testes existentes**

---

## Decisões Arquiteturais (Sprint 1-6)

### Padrão de Services + Providers
- Cada módulo tem um `Service` (acesso Supabase) + `Provider` (Riverpod)
- Services: `auth_service.dart`, `profile_service.dart`, `policy_service.dart`, `agenda_service.dart`, `reposition_service.dart`, `material_service.dart`, `feed_service.dart`, `billing_service.dart`, `community_service.dart`, `stock_service.dart`
- Providers ficam no próprio arquivo do service (não em arquivo separado)
- Telas usam `ConsumerWidget` ou `ConsumerStatefulWidget` para acessar providers

### Trigger handle_new_user
- Ao registrar no Supabase Auth, um trigger auto-cria o profile com status `pending`
- Metadata do signup (full_name, phone, birth_date) é passada via `raw_user_meta_data`

### Fluxo de Auth
- Signup → Policies → Pending → Admin aprova → Home
- Login verifica: blocked? → erro. pending? → /pending. policies aceitas? → / ou /policies
- Router usa `refreshListenable` que escuta `authStateProvider`

### Reposição e Lista de Espera
- DB function `can_request_reposition` limita 1/mês (com admin override)
- Trigger `on_presence_declined` auto-avança lista de espera
- DB function `advance_waitlist` notifica próxima da fila com 24h para aceitar
- pg_cron não habilitado ainda — crons comentados nas migrations

### Cobrança
- Edge function `totalizar-cobranca` calcula: mensalidade + argila (view) + queimas (view)
- Cria cobranças e itens automaticamente por aluna
- Fluxo: draft → admin confirma → notifica → aluna paga

### M6 Comunidade
- Tabelas: community_posts, community_comments, community_likes, chat_messages
- RLS: users read all, authors manage own, admin/teacher can delete
- Feed social com curtidas e comentários
- Chat 1:1 professora ↔ aluna (sender/receiver only)

### M7 Estoque
- Tabelas: estoque_argila (qty + nível mínimo), estoque_compras
- Trigger `handle_clay_usage`: baixa automática ao registrar argila
- Trigger `handle_clay_purchase`: soma ao registrar compra (upsert)
- Alerta visual quando estoque abaixo do nível mínimo

### Landing Page (Astro 5 + Vercel)
- Diretório: `landing/`. Stack: Astro 5 estático + Vanilla CSS (sem Tailwind) + TypeScript strict.
- Tokens em `landing/src/styles/tokens.css` espelham `app/lib/core/theme.dart` (paleta, fontes, radii) — fonte de verdade do Design System.
- Fontes via Google Fonts: Epilogue (display, italic 500 para acentos) + Manrope (body/labels).
- Componentes: `Hero`, `ValueProps`, `Features`, `Plans`, `Studio`, `ContactCTA`, `Footer` + primitivos `ui/Button` e `ui/Card`.
- Hero com title fluid (`clamp`), brushstroke SVG terracota animado, orb radial-gradient orgânico flutuando.
- TDD: Vitest com Astro Container API (`Button`, `Plans`, `Hero` cobertos via unit) + Playwright chromium para 5 smoke E2E (carga, planos, âncora, mobile 375px, anchors).
- CI: `.github/workflows/landing-ci.yml` separado do `flutter-ci.yml`, dispara em mudanças `landing/**`. Roda check + vitest + build + playwright.
- Deploy Vercel (`vercel.json`) — falta `vercel link && vercel --prod` (manual).
- Conteúdo placeholder marcado com `data-todo` no markup. Lista do que pedir à Débora: `docs/landing_assets_todo.md`.

### Edge Functions (5 deployed)
- `enviar-notificacao`: confirmação 24h, lembrete 6h, aprovação
- `totalizar-cobranca`: calcula mensalidade + argila + queimas
- `exportar-cobranca`: CSV de cobranças do mês
- `gerar-aulas`: gera aulas recorrentes N semanas a partir das turmas
- `criar-aluna`: admin cria conta ativa com senha temporária

### Design System — "Artisanal Modernism"
- Fontes: Epilogue (display/headlines) + Manrope (body/labels) via `google_fonts`
- Paleta: surface hierarchy (#FFF8F4 → #EAE1D9), primary #8D4B00, secondary #C75B39
- No-line philosophy: sem borders, profundidade via tonal shifts
- Cards rounded 20-24px, buttons rounded-full 48px, inputs sem border
- Bottom navigation: NavigationBar com `StatefulShellRoute.indexedStack`
- Rotas admin em fullscreen (fora do shell), tabs preservam estado

### Admin Features
- Gestão de usuários: listar, filtrar por role/status, mudar role/status inline
- Criar aluna: edge function `criar-aluna` gera conta ativa com senha temporária
- Gerar aulas: edge function `gerar-aulas` cria aulas recorrentes N semanas
- Config preços: editar preço argila/kg e queima esmalte/peça
- Aprovação de cadastros: aprovar/rejeitar com 1 clique
- Painel financeiro: totalizar, filtrar, confirmar, notificar, export CSV

### Bugs Corrigidos
- RLS recursão infinita em profiles → função `auth_role()` SECURITY DEFINER
- `authStateProvider` stream bloqueava providers no web → removido, lê direto do session
- `total_amount` é generated column → removido do INSERT na edge function
- `flutter_dotenv` não aceita aspas no `.env`
- `.env` precisa estar em `pubspec.yaml` assets para web

### Dados de Teste (Supabase Cloud)
- Admin: debora@favodecolorir.com.br / FavoAdmin2026!
- Alunas: ana@teste.com, maria@teste.com, julia@teste.com (senha: Teste123!)
- 5 turmas (Ter-Sáb), 18+ aulas geradas, 3 assinaturas mensal
- 3 cobranças totalizadas (R$350-376), 1 post comunidade, 1 chat message

### Deploy
- Supabase cloud: projeto `fhqklezevuqtqenbhsja` (sa-east-1)
- 7 migrations aplicadas, 5 edge functions deployed
- Migrations via `supabase db push`
- Edge functions via `supabase functions deploy <nome>`
- `.env` sem aspas (flutter_dotenv não aceita)
- `.env` listado em `pubspec.yaml` assets (necessário para web)
- Web dev: `flutter run -d web-server --web-port=5555`
- Web build: `flutter build web`
- Android build: `flutter build appbundle --release`

### Testes
- 66 testes unitários (6 arquivos): models, error handler, community, stock, reposition
- 22 endpoints REST testados via curl (com RLS validation)
- 5 edge functions testadas end-to-end
- `flutter analyze` = 0 issues

---

## Implementado (além do MVP)

- [x] Build Android APK (55MB, release)
- [x] Registro de materiais offline (SQLite + sync automático)
- [x] Upload de fotos (Feed, Perfil avatar, Comunidade posts)
- [x] Admin: editar políticas + forçar re-aceite
- [x] Admin: notificações gerais (edge function enviar-recado)
- [x] Admin: gestão de alunas em turmas (TurmaDetailScreen)
- [x] Admin: criar aluna pelo app (edge function criar-aluna)
- [x] Moderação de posts (edge function moderar-post, keyword matching)
- [x] CI/CD (flutter-ci.yml com build web + Android)
- [x] Ícones customizados Android + iOS
- [x] Design System "Artisanal Modernism" completo
- [x] Boilerplate removido, tudo em pt-BR
- [x] 107 testes, 7 edge functions, 9 migrations

## Bugs Corrigidos (sessão de fixes)
- Navegação admin: go→push (menu sumia)
- ProfileService.getProfile: single→maybeSingle (crashava)
- Reposição: seleção da aula original (ambos IDs eram iguais)
- Community N+1 queries → batch (3 queries ao invés de N*2)
- Dashboard do dia: provider dentro do build + admin vê todas turmas
- Rota turma/materiais: path params → extra (UTF-8 encoding error)
- Botões vazios: notification bell, settings, help center
- RLS notifications: edge function enviar-recado (bypass RLS)
- totalizar-cobranca: total_amount é generated column

## Pendências (dívida técnica — pós-sessão 22-23 Abr)

### Alta (bloqueado por credenciais/hardware)
- [ ] **FCM push real** — código pronto em `PushService.initialize()` com comentários marcando o que descomentar; edge function `enviar-push` deployada fail-open. Precisa: Firebase project + `google-services.json` + `FCM_SERVER_KEY` nas secrets.
- [ ] **Mercado Pago em produção** — SDK + edge functions `criar-pagamento-pix` e `webhook-mercadopago` deployadas. Falta: `MP_ACCESS_TOKEN` nas secrets + URL do webhook no dashboard MP.
- [ ] **Build iOS** — macOS + Xcode + Apple Developer ($99/ano).
- [ ] **Universal Links / App Links** — migração da bridge HTML pra abrir app direto quando tiver domínio próprio. Checklist completo em `.claude/projects/-home-marcus-desenvolvimento-favo-de-colorir/memory/project_dominio_universal_links.md`.

### Média
- [ ] Integração Nuvemshop (cartão, parcelamento)
- [ ] Analytics (DAU/MAU)
- [ ] `pg_cron` pra expirar waitlist após 24h (precisa Supabase Pro)
- [ ] Links reais das stores nos botões da bridge `auth-bridge` e da landing

### Baixa
- [ ] Enquetes e desafios criativos
- [ ] Blog/dicas das professoras
- [ ] Relatório financeiro com gráficos temporais (tendência mensal)

---

## Sessão 22-23 Abril 2026 — "App Completo"

Maratona de 32 commits pushados pra levar o app de "funcional" pra "pronto
pra alunas reais". Começou com o user dizendo "o app não tem foto em
nenhum lugar, precisa ser um app completo" e acabou com todas as dívidas
críticas pagas + Supabase em sync (migrations/buckets/functions aplicados
no remoto).

### Infraestrutura

**Migrations novas (7):**
- `20260422000001_app_completo.sql` — peca_fotos + attendance_status enum + moderation_status + community_comments.image_url + chat_messages.image_url + cobrancas.comprovante_url + audit_logs + aulas.cancelled_{at,reason,by} + profiles.{bio,rejection_reason} + app_config
- `20260422000002_feriados.sql` — tabela feriados (14 seed de 2026) + UNIQUE(turma_id, scheduled_date)
- `20260422000003_rls_refinement.sql` — teacher só mexe em turma/aula/presenca dela (antes: qualquer teacher mexia em qualquer)
- `20260423000001_onboarding.sql` — profiles.onboarded_at
- `20260423000002_teacher_repositions.sql` — RLS permite teacher INSERT/UPDATE reposições de suas aulas
- `20260423000003_turma_location.sql` — turmas.location + address + studio_address/maps_url em app_config
- `20260423000004_storage_policies.sql` — policies RLS pros 6 buckets de storage

**Buckets novos (6, todos criados em prod):** avatars (public 5MB), feed (public 10MB), pecas (public 10MB), posts (public 10MB), chat (privado 10MB), pagamentos (privado 5MB, aceita PDF).

**Edge functions novas (6, todas deployadas):**
- `reset-senha-usuario` — admin gera nova senha temporária
- `enviar-credenciais` — magic link com `redirectTo: favo://auth-callback`
- `enviar-push` — persiste notifications sempre; chama FCM se `FCM_SERVER_KEY` configurado
- `criar-pagamento-pix` — MP API Pix → QR + copia-e-cola
- `webhook-mercadopago` — auto-confirma cobrança quando MP aprova
- `auth-bridge` — HTML no Supabase que tenta `favo://` e cai em fallback pra stores (Site URL = `https://<proj>.supabase.co/functions/v1/auth-bridge`)

**Edge functions atualizadas:** `gerar-aulas` (pula feriados + transação), `enviar-recado` (segmentação: all/turma/role/users), `moderar-post` (categoria exposta).

### Features novas por módulo

**Módulo agenda**
- Chamada real pela professora (chips P/A/F em `_AttendanceRow`) — gera `attendance_status` + auto-completa reposição se `is_makeup`
- Cancelar aula com cascata (status=cancelled + marca todos absent + cria créditos de reposição pra quem tinha confirmado + audit + notifica)
- Feriados: CRUD admin em `/admin/feriados` + gerador de aulas respeita com breakdown (`X geradas · Y pulados · Z já existiam`)
- Calendário mensal em `my_agenda_screen` (toggle Semana/Mês, grid 6x7, dots por dia, aulas canceladas com line-through)
- Lista de espera UI: aluna vê posição e aceita vaga sozinha (`_MyFilaTile` com botão verde quando status=notified); admin em `/admin/turma-waitlist` promove manual
- Editar turma via form reaproveitado (dialog pré-populado); aula pontual via `createSingleAula`; detector de `checkScheduleConflict` antes de mutações
- Dashboard professora mostra badge "REPOSIÇÃO" com "de Turma X · 15/04"; botão "Todos faltaram" com dialog explicando vs "Cancelar aula"
- Professora pode criar crédito de reposição ao marcar falta (RLS permite agora)

**Módulo materiais**
- Foto de peça no registro (`image_picker` + upload bucket `pecas`, múltiplas, best-effort)
- Model `PecaFoto` + service `uploadPecaPhoto/getPecaPhotos/deletePecaPhoto`

**Módulo cobrança**
- Comprovante de pagamento: aluna envia (bucket `pagamentos` privado, signed URL 30d); admin vê em `InteractiveViewer` + confirma ou rejeita
- Pgto manual com método (dinheiro/pix externo/cartão) + observações + admin_confirmed
- Pix real: `_PixDialog` renderiza QR via `Image.memory(base64Decode(...))` + copia-e-cola selecionável + "confirmação chega automática"
- Breakdown de cobrança lê de `cobranca_itens` (antes era hardcoded "3 kg / 2 peças")
- Export CSV real: `share_plus` em mobile (share sheet com arquivo), clipboard em web

**Módulo comunidade**
- Moderação síncrona: post fica `moderation_status=pending` até edge function responder; aprovado → feed, rejeitado → dialog com `ModerationResult.friendlyMessage` categorizado (political/hate/violence/sexual/self-harm/illicit/keyword)
- Comentários com foto (CommunityComment.imageUrl + UI com preview)
- Avatars reais em comentários + clicáveis pro perfil público
- Chat 1-1 completo: `/chat` lista conversas (getConversations agrupa por peer), `/chat/:peerId` com realtime (Supabase channel `onPostgresChanges INSERT`) + foto via bucket `chat`
- Perfil público em `/profile/:userId` com avatar, bio, peças públicas e botão "Mandar mensagem"

**Módulo auth**
- Validators BR: `validateEmail` (regex), `PhoneBRFormatter` (máscara dinâmica), `validatePasswordStrength`, `parseBirthDateBR`
- Edit profile em `/profile/edit` (nome/telefone/data nasc/bio)
- Signup com confirm senha, data BR
- Reset senha via deep link: `/auth/reset` em `ResetPasswordScreen` (chega via `DeepLinkService`)
- Deep link service em `main.dart`: `app_links` listener captura `favo://auth-callback?code=...` (PKCE) ou `?type=recovery&token=...`

**Módulo admin**
- Audit logs: service + tela `/admin/audit` com histórico filtrado por ação
- Reset de senha via edge function `reset-senha-usuario`
- Busca server-side debounced + paginação infinita (`searchProfiles(query, role, limit, offset)`)
- Broadcast segmentado (todos/turma específica/papel específico)
- Rejeição de cadastro com dialog de motivo → `rejectProfileWithReason` + notification
- Confirm dialogs em destrutivas (mudar status, desativar turma, mudança de preço >30%, broadcast "todos")
- Feriados admin em `/admin/feriados`

**Módulo onboarding**
- Tour de 6 slides PageView em `/onboarding` (Bem-vindo → Próxima aula → Reposição → Cobrança → Comunidade → Perfil)
- Redirect automático em `home_screen` via `ref.listen` quando aluna student não tem `onboarded_at`
- "Rever tutorial" no menu do perfil chama `resetOnboarding`

**Core**
- `UserAvatar` widget com `CachedNetworkImage` + fallback robusto (migrado em profile_screen, admin_users, admin_approval, turma_detail, community_feed, chat_list, chat_detail, public_profile)
- `errorBuilder` + `loadingBuilder` em `Image.network` restantes
- Validators BR consolidados em `core/validators.dart`

**Landing**
- Copy mais aconchegante em ValueProps, Studio, Plans, ContactCTA (tom "ateliê da vizinhança")
- Página `/auth-callback` como fallback alternativo à bridge do Supabase

**iOS + Android nativo**
- Android: intent-filter com `android:scheme="favo"` em `AndroidManifest.xml`
- iOS: `CFBundleURLSchemes` com "favo" em `Info.plist`

### Neutralização de linguagem
Commit `9d60608` removeu "alunas" como genérico em strings visíveis — substituído por "a turma", "quem faz aula", "estudante", "participantes". Policy test `app/test/inclusive_language_test.dart` garante não-regressão.

### Dependências novas no `pubspec.yaml`
- `share_plus: ^10.1.2` (CSV + compartilhamento)
- `app_links: ^6.3.2` (deep link handler)

### Stack final confirmada
- **Flutter**: 156 testes verdes, `flutter analyze` sem novos issues
- **Landing**: 13 testes Vitest verdes
- **Supabase remoto** (projeto `fhqklezevuqtqenbhsja`): 17 migrations aplicadas, 12 edge functions ativas, 6 buckets com RLS
- **Auth bridge** respondendo em `https://fhqklezevuqtqenbhsja.supabase.co/functions/v1/auth-bridge`

### Memórias criadas/atualizadas
- `project_favo_sprint_status.md` (estado completo)
- `project_agenda_divida.md` (PAGA — histórico)
- `project_landing_copy.md` (PAGA — diretrizes)
- `project_onboarding_divida.md` (PAGA — escopo)
- `project_dominio_universal_links.md` (aberta — aguarda domínio)

---

---

## TL;DR — Estado do Projeto (23 de Abril de 2026)

App **Favo de Colorir** para ateliê de cerâmica da Débora (Tijuca, RJ).
MVP construído em 8-9 Abr 2026; sessão maratona em 22-23 Abr pagou todas
as dívidas críticas. Projeto agora "app completo" — pronto pra alunas reais.

### Números
- **72+ commits**, **~75 arquivos Dart**, **~14.000 linhas de código**
- **156 testes Flutter** + **13 testes Vitest landing** (verdes)
- **17 migrations** aplicadas no Supabase remoto
- **12 edge functions** ativas (7 novas na sessão)
- **6 buckets** criados com RLS
- **APK Android**: ~55MB (release)
- **CI/CD**: GitHub Actions (analyze + test + web build + APK) + Vercel (landing)

### O que funciona (end-to-end)
- Auth completo com magic link + deep link (favo://auth-callback) + bridge HTML no Supabase + reset senha in-app
- Onboarding de 6 slides no primeiro acesso + "Rever tutorial" no perfil
- Agenda com toggle Semana/Mês + week strip + calendário grid + aulas canceladas com line-through
- Reposição de aulas com fluxo aluna completo + lista de espera UI (aceitar vaga sozinha)
- Chamada real pela professora (chips P/A/F) + auto-completa reposição + "Todos faltaram"
- Cancelar aula com cascata (marca absent + cria créditos + notifica + audit)
- Feriados com CRUD admin + gerador respeita
- Registro de materiais com **foto da peça** + offline sync SQLite
- Cobrança: Pix real via MP (QR + copia-e-cola) OU comprovante upload + admin confirma
- Feed pessoal + comunidade com moderação síncrona + motivos categorizados
- Chat 1-1 com realtime Supabase + foto
- Perfil público `/profile/:userId` + perfil editável
- Admin: criar aluna (envia credencial via magic link) + reset senha + busca paginada + audit log + broadcast segmentado + rejeição com motivo + editar turma + aula pontual + detector de conflito
- Estoque de argilas (níveis + alertas + compras)
- Design System "Artisanal Modernism" (Epilogue + Manrope, tonal surfaces)
- Bottom navigation com 5 tabs + rotas admin fullscreen
- RLS refinada (teacher só mexe em turma dela; assistant ajuda chamada; admin tudo)
- Linguagem inclusiva (policy test garante "alunas" como genérico não volta)

### Supabase em produção
- **Projeto**: `fhqklezevuqtqenbhsja` (sa-east-1)
- **Site URL**: `https://fhqklezevuqtqenbhsja.supabase.co/functions/v1/auth-bridge`
- **Redirect URLs allowlist**: `favo://auth-callback`, `favo://auth`, bridge URL
- **Buckets**: avatars, feed, pecas, posts (públicos); chat, pagamentos (privados)
- **Storage RLS**: ownership por convenção `<userId>/...`

### Contas de teste
- **Admin**: debora@favodecolorir.com.br / FavoAdmin2026!
- **Alunas**: ana@teste.com, maria@teste.com, julia@teste.com (Teste123!)

---

## Próximos Passos

### Para a Débora testar (imediato)
1. Acessar via web (flutter run -d web-server) ou instalar APK
2. Logar como admin, criar turmas, gerar aulas, criar alunas
3. Logar como aluna, confirmar presença, ver agenda, criar notas no feed
4. Logar como admin, registrar materiais, totalizar cobranças

### Dívidas técnicas restantes (bloqueadas por credenciais/hardware)

Tudo que é código acabou. Dívidas restantes dependem 100% de acesso externo:

1. **Mercado Pago** — plugar `MP_ACCESS_TOKEN` nas secrets da edge function:
   ```bash
   supabase secrets set MP_ACCESS_TOKEN=xxx --project-ref fhqklezevuqtqenbhsja
   ```
   Depois configurar URL do webhook no dashboard MP apontando pra
   `https://fhqklezevuqtqenbhsja.supabase.co/functions/v1/webhook-mercadopago`.
   Sandbox funciona pra testar. Código Dart + edge functions já prontos
   (commit `c9a7a81`).

2. **FCM push real** — requer:
   - Projeto Firebase criado
   - `flutterfire configure` no root do app (gera `firebase_options.dart`
     + `google-services.json` + Runner/GoogleService-Info.plist)
   - Descomentar chamadas em `lib/services/push_service.dart` (marcadas
     com comentários `// 1. await Firebase.initializeApp...`)
   - `supabase secrets set FCM_SERVER_KEY=xxx` pra edge function `enviar-push`
     chamar FCM API real

3. **iOS App Store** — Mac + Xcode + Apple Developer ($99/ano).

4. **Domínio próprio** — abre caminho pra Universal Links / App Links
   (ver `project_dominio_universal_links.md` na memória).

5. **pg_cron pra waitlist expirar 24h** — requer Supabase Pro plan.

### Dívidas operacionais (UI de 1 clique)

- **Links reais das stores** na bridge `auth-bridge` (hoje `href="#"`):
  atualizar a edge function quando apps forem publicados.
- **Desligar Vercel Authentication** da landing pra ela ficar pública.
- **Placeholders** da landing (fotos, contatos reais) — lista em
  `docs/landing_assets_todo.md`.

---

**Última atualização:** 23 de Abril de 2026
**Status:** App completo ponta-a-ponta. Supabase remoto em sync
(17 migrations, 12 edge functions, 6 buckets). 156 testes Flutter +
13 testes landing verdes. `flutter analyze` sem novos issues.
72+ commits pushados em `origin/main` (BaxiJen/favo_de_colorir).
