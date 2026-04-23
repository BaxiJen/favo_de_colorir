import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface RecadoPayload {
  title: string;
  body: string;
  // Segmentação (opcional). Sem nada = todos ativos.
  target?: "all" | "turma" | "role" | "users";
  turma_id?: string;
  role?: "admin" | "teacher" | "assistant" | "student";
  user_ids?: string[];
}

Deno.serve(async (req) => {
  try {
    // Auth check: só admin pode disparar broadcast. Sem isso, qualquer
    // cliente com anon key conseguiria enviar notificações pra toda turma.
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

    const payload: RecadoPayload = await req.json();

    const target = payload.target ?? "all";
    let recipientIds: string[] = [];

    if (target === "users" && payload.user_ids && payload.user_ids.length > 0) {
      recipientIds = payload.user_ids;
    } else if (target === "turma" && payload.turma_id) {
      const { data } = await supabase
        .from("turma_alunos")
        .select("student_id")
        .eq("turma_id", payload.turma_id)
        .eq("status", "active");
      recipientIds = (data ?? []).map((r: any) => r.student_id);
    } else if (target === "role" && payload.role) {
      const { data } = await supabase
        .from("profiles")
        .select("id")
        .eq("role", payload.role)
        .eq("status", "active");
      recipientIds = (data ?? []).map((r: any) => r.id);
    } else {
      // Fallback "all" ativos
      const { data } = await supabase
        .from("profiles")
        .select("id")
        .eq("status", "active");
      recipientIds = (data ?? []).map((r: any) => r.id);
    }

    if (recipientIds.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }));
    }

    const notifications = recipientIds.map((id) => ({
      user_id: id,
      title: payload.title,
      body: payload.body,
      type: "general",
      data: {},
    }));

    await supabase.from("notifications").insert(notifications);

    // Audit
    try {
      await supabase.from("audit_logs").insert({
        actor_id: caller.data.user.id,
        action: "broadcast_recado",
        resource_type: "notifications",
        changes: {
          target,
          count: recipientIds.length,
          title: payload.title,
        },
      });
    } catch (_) { /* não trava o envio se audit falhar */ }

    return new Response(
      JSON.stringify({ sent: recipientIds.length }),
    );
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
    });
  }
});
