import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const mpAccessToken = Deno.env.get("MP_ACCESS_TOKEN");
// Secret key compartilhada com Mercado Pago pra HMAC do webhook.
// Configurar em: Dashboard MP → Webhooks → Secret key
const mpWebhookSecret = Deno.env.get("MP_WEBHOOK_SECRET");

/**
 * Valida a assinatura HMAC-SHA256 que o Mercado Pago envia no header
 * `x-signature`. O manifest assinado segue o padrão MP:
 *   id:<data.id>;request-id:<x-request-id>;ts:<ts>;
 *
 * Ref: https://www.mercadopago.com.br/developers/pt/docs/your-integrations/notifications/webhooks
 */
async function validateSignature(req: Request, body: any): Promise<boolean> {
  if (!mpWebhookSecret) {
    // Sem secret configurado, aceita qualquer — fallback pra dev/sandbox.
    // Documentado como risco; em prod sempre definir MP_WEBHOOK_SECRET.
    return true;
  }

  const sig = req.headers.get("x-signature");
  const reqId = req.headers.get("x-request-id");
  if (!sig || !reqId) return false;

  // x-signature: "ts=1704308010,v1=<hex>"
  const parts = sig.split(",").reduce<Record<string, string>>((acc, p) => {
    const [k, v] = p.split("=");
    if (k && v) acc[k.trim()] = v.trim();
    return acc;
  }, {});
  const ts = parts["ts"];
  const v1 = parts["v1"];
  if (!ts || !v1) return false;

  const dataId = body?.data?.id;
  if (!dataId) return false;

  const manifest = `id:${dataId};request-id:${reqId};ts:${ts};`;
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(mpWebhookSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign("HMAC", key, enc.encode(manifest));
  const expected = Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  // Timing-safe compare
  if (expected.length !== v1.length) return false;
  let ok = 0;
  for (let i = 0; i < expected.length; i++) {
    ok |= expected.charCodeAt(i) ^ v1.charCodeAt(i);
  }
  return ok === 0;
}

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

    // Valida assinatura HMAC. Sem MP_WEBHOOK_SECRET configurado, passa
    // (fallback pra sandbox); em produção a secret bloqueia requests
    // forjadas.
    const valid = await validateSignature(req, body);
    if (!valid) {
      return new Response(JSON.stringify({ error: "invalid signature" }), {
        status: 401,
      });
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
