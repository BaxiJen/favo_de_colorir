import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface ResetSenhaPayload {
  user_id: string;
}

/**
 * Gera nova senha temporária pra uma aluna/aluno. Só admin pode chamar.
 *
 * Retorna a senha em texto plano pro admin copiar. A senha existente é
 * sobrescrita — aluno usa a nova no próximo login.
 */
Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Faltando Authorization header" }),
        { status: 401 },
      );
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    // Verifica se quem chamou é admin
    const caller = await supabase.auth.getUser(authHeader.replace("Bearer ", ""));
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

    const payload: ResetSenhaPayload = await req.json();
    if (!payload.user_id) {
      return new Response(JSON.stringify({ error: "user_id obrigatório" }), {
        status: 400,
      });
    }

    const newPassword = `Favo${Math.random().toString(36).slice(-8)}!`;

    const { error } = await supabase.auth.admin.updateUserById(payload.user_id, {
      password: newPassword,
    });

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 400,
      });
    }

    // Registra na auditoria
    await supabase.from("audit_logs").insert({
      actor_id: caller.data.user.id,
      action: "reset_password",
      resource_type: "profile",
      resource_id: payload.user_id,
    });

    return new Response(
      JSON.stringify({ user_id: payload.user_id, password: newPassword }),
    );
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
    });
  }
});
