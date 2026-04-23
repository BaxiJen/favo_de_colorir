import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const mpAccessToken = Deno.env.get("MP_ACCESS_TOKEN");

/**
 * Webhook do Mercado Pago pra notificação de pagamento.
 *
 * Configurar no dashboard MP:
 *   URL = https://<seu-projeto>.supabase.co/functions/v1/webhook-mercadopago
 *   Eventos = payment
 *
 * O MP manda { type: "payment", data: { id: "..." } }. Buscamos o pagamento
 * pela API, checamos se é "approved", marcamos cobranca.status = paid.
 */
Deno.serve(async (req) => {
  try {
    if (!mpAccessToken) {
      return new Response("MP não configurado", { status: 503 });
    }

    const body = await req.json().catch(() => ({}));
    const type = body?.type ?? body?.topic;
    const paymentId = body?.data?.id ?? body?.resource?.split?.("/")?.pop();

    if (type !== "payment" || !paymentId) {
      return new Response("ok");
    }

    const mpResp = await fetch(
      `https://api.mercadopago.com/v1/payments/${paymentId}`,
      { headers: { "Authorization": `Bearer ${mpAccessToken}` } },
    );
    if (!mpResp.ok) {
      return new Response("falha ao consultar MP", { status: 502 });
    }
    const payment = await mpResp.json();

    const externalRef = payment.external_reference as string | undefined;
    const status = payment.status as string;

    if (!externalRef) return new Response("sem external_reference");

    const supabase = createClient(supabaseUrl, supabaseKey);

    if (status === "approved") {
      await supabase.from("cobrancas").update({
        status: "paid",
        paid_at: new Date().toISOString(),
        payment_reference: paymentId.toString(),
        admin_confirmed: false, // webhook — não é admin
      }).eq("id", externalRef);

      // Busca student_id pra notificar
      const { data: bill } = await supabase
        .from("cobrancas")
        .select("student_id, month_year")
        .eq("id", externalRef)
        .single();

      if (bill) {
        await supabase.from("notifications").insert({
          user_id: bill.student_id,
          title: "Pagamento confirmado",
          body: `Recebemos seu Pix de ${bill.month_year}. Obrigado!`,
          type: "billing",
          data: { cobranca_id: externalRef },
        });
      }
    } else if (status === "rejected" || status === "cancelled") {
      await supabase.from("cobrancas").update({
        status: "pending", // volta pro pending pra aluna tentar de novo
      }).eq("id", externalRef);
    }

    return new Response("ok");
  } catch (error: any) {
    return new Response(error.message, { status: 500 });
  }
});
