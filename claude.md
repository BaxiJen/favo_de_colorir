# Claude.md — Favo de Colorir

## Instruções para Claude Code

**Skill obrigatória para UI/frontend:** sempre usar a skill oficial [`frontend-design`](https://github.com/anthropics/skills/tree/main/skills/frontend-design) (`frontend-design@claude-plugins-official`) em qualquer trabalho que envolva:

- Landing page (Astro/Vercel)
- Componentes Flutter novos ou refatorações visuais do app
- Telas admin / dashboards
- Qualquer HTML/CSS/componente web
- Tematização, tipografia, paleta, animações, layout

Carregue a skill antes de gerar código de UI. A intenção é evitar estética genérica de "AI slop" e manter coerência com o Design System **Artisanal Modernism** (Epilogue + Manrope, tonal surfaces) já aplicado no app Flutter. Tipografia distintiva, paleta comprometida com acentos fortes, composição espacial com asymmetry/overlap, motion intencional via CSS. Proibido: fontes genéricas (Inter, Roboto, Arial, Space Grotesk), paletas "roxo em branco", layouts previsíveis.

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

## Pendências (dívida técnica)

### Alta
- [ ] Push notifications reais (Firebase Cloud Messaging) — requer projeto Firebase
- [ ] Integração Mercado Pago (Pix QR code real + webhook)

### Média
- [ ] Integração Nuvemshop (cartão, parcelamento)
- [ ] Moderação IA real (Claude/OpenAI API ao invés de keyword)
- [ ] Landing page (Astro + Vercel)
- [ ] Analytics (DAU/MAU)

### Baixa
- [ ] Enquetes e desafios criativos
- [ ] Blog/dicas das professoras
- [ ] Build iOS (requer macOS + Xcode)

---

---

## TL;DR — Estado do Projeto (9 de Abril de 2026)

App **Favo de Colorir** para ateliê de cerâmica da Débora (Tijuca, RJ).
Construído em ~1 dia (8-9 Abril 2026) usando Flutter + Supabase.

### Números
- **40 commits**, **51 arquivos Dart**, **~10.000 linhas de código**
- **107 testes** (13 arquivos), **10 migrations**, **7 edge functions**
- **APK Android**: 55MB (release), **Web build**: OK
- **CI/CD**: GitHub Actions (analyze + test + web build + APK)

### O que funciona (end-to-end)
- Login/cadastro com aprovação admin + aceite de políticas
- Agenda semanal com confirmação presença (Vou/Não Vou)
- Reposição de aulas (selecionar falta → agendar makeup)
- Registro de materiais (argila kg + peças) com **offline sync** (SQLite)
- Cobrança automática (totalizar mensalidade + argila + queimas)
- Feed pessoal com upload de fotos (galeria/câmera)
- Comunidade (posts + curtidas + comentários + foto)
- Chat professora ↔ aluna
- Estoque de argilas (níveis + alertas + compras)
- Moderação automática de posts (keyword matching)
- Admin completo: gestão usuários, turmas, alunas, preços, políticas, notificações, billing
- Design System "Artisanal Modernism" (Epilogue + Manrope, tonal surfaces)
- Bottom navigation com 5 tabs + rotas admin fullscreen
- Push: `context.push()` para admin (preserva bottom nav)

### Contas de teste
- **Admin**: debora@favodecolorir.com.br / FavoAdmin2026!
- **Alunas**: ana@teste.com, maria@teste.com, julia@teste.com (Teste123!)
- **Supabase**: projeto `fhqklezevuqtqenbhsja` (sa-east-1)

---

## Próximos Passos

### Para a Débora testar (imediato)
1. Acessar via web (flutter run -d web-server) ou instalar APK
2. Logar como admin, criar turmas, gerar aulas, criar alunas
3. Logar como aluna, confirmar presença, ver agenda, criar notas no feed
4. Logar como admin, registrar materiais, totalizar cobranças

### Dívidas técnicas (próximas sessões)
1. **Firebase Cloud Messaging** — push notifications reais
   - Criar projeto em console.firebase.google.com
   - `flutterfire configure` + registrar tokens
   - Edge function envia push via FCM API

2. **Mercado Pago Pix** — pagamento real
   - Criar conta sandbox em mercadopago.com.br/developers
   - Edge function gera QR code Pix
   - Webhook recebe confirmação → atualiza cobrança

3. **Moderação IA real** — Claude/OpenAI
   - Trocar keyword matching por API de moderação
   - Precisa de API key

4. **Landing page** — Astro + Vercel
   - Apresentação do ateliê, fotos, planos, contato

5. **Build iOS** — precisa de Mac com Xcode

---

**Última atualização:** 9 de Abril de 2026  
**Versão PRD:** 1.2  
**Status:** App funcional (Web + Android APK). 51 arquivos Dart, 107 testes, 10 migrations, 7 edge functions. 40 commits.
