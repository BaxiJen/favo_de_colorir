import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface TotalizarPayload {
  month_year: string; // "2026-04"
}

Deno.serve(async (req) => {
  try {
    const payload: TotalizarPayload = await req.json();
    const { month_year } = payload;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Buscar consumo de argila do mês (via view)
    const { data: clayData } = await supabase
      .from("v_consumo_mensal_aluna")
      .select("*")
      .eq("month_year", month_year);

    // Buscar queimas do mês (via view)
    const { data: firingData } = await supabase
      .from("v_queimas_mensal_aluna")
      .select("*")
      .eq("month_year", month_year);

    // Buscar assinaturas ativas
    const { data: subscriptions } = await supabase
      .from("assinaturas")
      .select("*, planos(*)")
      .eq("status", "active");

    if (!subscriptions) {
      return new Response(JSON.stringify({ created: 0 }));
    }

    let created = 0;

    for (const sub of subscriptions) {
      const studentId = sub.student_id;
      const planAmount = (sub as any).planos?.price ?? 0;

      // Argila
      const studentClay = clayData?.find(
        (c: any) => c.student_id === studentId,
      );
      const clayAmount = studentClay?.total_cost ?? 0;

      // Queimas
      const studentFiring = firingData?.find(
        (f: any) => f.student_id === studentId,
      );
      const firingAmount = studentFiring?.total_cost ?? 0;

      const totalAmount = planAmount + clayAmount + firingAmount;

      // Verificar se já existe cobrança
      const { data: existing } = await supabase
        .from("cobrancas")
        .select("id")
        .eq("student_id", studentId)
        .eq("month_year", month_year)
        .maybeSingle();

      if (existing) continue;

      // Criar cobrança
      const { data: cobranca } = await supabase
        .from("cobrancas")
        .insert({
          student_id: studentId,
          month_year,
          plan_amount: planAmount,
          clay_amount: clayAmount,
          firing_amount: firingAmount,
          total_amount: totalAmount,
          status: "draft",
          admin_confirmed: false,
        })
        .select()
        .single();

      if (!cobranca) continue;

      // Criar itens
      const items = [];

      if (planAmount > 0) {
        items.push({
          cobranca_id: cobranca.id,
          type: "plan",
          description: `Mensalidade - ${(sub as any).planos?.name ?? "Plano"}`,
          total: planAmount,
        });
      }

      if (clayAmount > 0) {
        items.push({
          cobranca_id: cobranca.id,
          type: "clay",
          description: "Argila consumida no mês",
          quantity: studentClay?.total_kg,
          unit_price: studentClay?.avg_price_per_kg,
          total: clayAmount,
        });
      }

      if (firingAmount > 0) {
        items.push({
          cobranca_id: cobranca.id,
          type: "firing",
          description: "Queimas de esmalte no mês",
          quantity: studentFiring?.total_pieces,
          total: firingAmount,
        });
      }

      if (items.length > 0) {
        await supabase.from("cobranca_itens").insert(items);
      }

      created++;
    }

    return new Response(JSON.stringify({ created, month_year }));
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
    });
  }
});
