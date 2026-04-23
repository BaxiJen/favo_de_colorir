import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface CriarAlunaPayload {
  email: string;
  full_name: string;
  phone?: string;
  password?: string;
  role?: string;
  turma_ids?: string[];
}

Deno.serve(async (req) => {
  try {
    // Auth check: criar user é operação de admin. Sem isso, anon key +
    // URL pública permitiriam qualquer um criar conta arbitrária.
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Sem auth" }), {
        status: 401,
      });
    }
    const supabase = createClient(supabaseUrl, supabaseKey);
    const caller = await supabase.auth.getUser(
      authHeader.replace("Bearer ", ""),
    );
    if (caller.error || !caller.data.user) {
      return new Response(JSON.stringify({ error: "Sessão inválida" }), {
        status: 401,
      });
    }
    const { data: callerProfile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", caller.data.user.id)
      .single();
    if (!callerProfile || callerProfile.role !== "admin") {
      return new Response(JSON.stringify({ error: "Apenas admin" }), {
        status: 403,
      });
    }

    const payload: CriarAlunaPayload = await req.json();

    // Gerar senha temporária se não fornecida
    const password = payload.password ?? `Favo${Math.random().toString(36).slice(-8)}!`;

    // Criar user via admin API
    const { data: user, error: authError } =
      await supabase.auth.admin.createUser({
        email: payload.email,
        password,
        email_confirm: true,
        user_metadata: {
          full_name: payload.full_name,
          phone: payload.phone ?? null,
        },
      });

    if (authError) {
      return new Response(
        JSON.stringify({ error: authError.message }),
        { status: 400 },
      );
    }

    // O trigger handle_new_user já cria o profile como student/pending
    // Vamos ativar e setar o role
    const role = payload.role ?? "student";
    await supabase
      .from("profiles")
      .update({ status: "active", role })
      .eq("id", user.user.id);

    // Aceitar todas as policies ativas automaticamente
    const { data: policies } = await supabase
      .from("policies")
      .select("id")
      .eq("is_active", true);

    if (policies && policies.length > 0) {
      const acceptances = policies.map((p: any) => ({
        user_id: user.user.id,
        policy_id: p.id,
      }));
      await supabase.from("policy_acceptances").insert(acceptances);
    }

    // Matricular nas turmas se fornecidas
    if (payload.turma_ids && payload.turma_ids.length > 0) {
      const enrollments = payload.turma_ids.map((turmaId: string) => ({
        turma_id: turmaId,
        student_id: user.user.id,
        status: "active",
      }));
      await supabase.from("turma_alunos").insert(enrollments);
    }

    // Audit
    try {
      await supabase.from("audit_logs").insert({
        actor_id: caller.data.user.id,
        action: "create_user",
        resource_type: "profile",
        resource_id: user.user.id,
        changes: {
          email: payload.email,
          role,
          turmas: payload.turma_ids?.length ?? 0,
        },
      });
    } catch (_) { /* não trava o fluxo */ }

    return new Response(
      JSON.stringify({
        user_id: user.user.id,
        email: payload.email,
        password,
        role,
        turmas: payload.turma_ids?.length ?? 0,
      }),
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
    });
  }
});
