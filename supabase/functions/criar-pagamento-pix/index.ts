import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const mpAccessToken = Deno.env.get("MP_ACCESS_TOKEN"); // sandbox ou prod

/**
 * Cria cobrança Pix no Mercado Pago e devolve QR code + copia-e-cola
 * + payment_id pra tela mostrar.
 *
 * Sem MP_ACCESS_TOKEN configurada, retorna 503 pra aluna cair no fluxo
 * "enviar comprovante" (já existente).
 *
 * Payload: { cobranca_id: string }
 */
interface Payload {
  cobranca_id: string;
}

Deno.serve(async (req) => {
  try {
    if (!mpAccessToken) {
      return new Response(
        JSON.stringify({
          error: "Integração Pix não configurada",
          hint: "Defina MP_ACCESS_TOKEN nas secrets da edge function",
        }),
        { status: 503 },
      );
    }

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

    const payload: Payload = await req.json();

    const { data: bill, error: billErr } = await supabase
      .from("cobrancas")
      .select("*, profiles:student_id(full_name, email)")
      .eq("id", payload.cobranca_id)
      .single();

    if (billErr || !bill) {
      return new Response(JSON.stringify({ error: "Cobrança não encontrada" }), {
        status: 404,
      });
    }

    // Aluna só paga cobrança própria
    if (bill.student_id !== caller.data.user.id) {
      return new Response(JSON.stringify({ error: "Cobrança não é sua" }), {
        status: 403,
      });
    }

    const profile = bill.profiles as any;

    // Chama Mercado Pago (API Pix)
    const idempotencyKey = `favo-${bill.id}-${Date.now()}`;
    const mpResp = await fetch("https://api.mercadopago.com/v1/payments", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${mpAccessToken}`,
        "Content-Type": "application/json",
        "X-Idempotency-Key": idempotencyKey,
      },
      body: JSON.stringify({
        transaction_amount: bill.total_amount,
        description: `Favo de Colorir — ${bill.month_year}`,
        payment_method_id: "pix",
        payer: {
          email: profile?.email ?? caller.data.user.email,
          first_name: (profile?.full_name ?? "").split(" ")[0] ?? "Aluno",
        },
        external_reference: bill.id,
      }),
    });

    const mp = await mpResp.json();

    if (!mpResp.ok) {
      return new Response(
        JSON.stringify({ error: "Mercado Pago falhou", detail: mp }),
        { status: 502 },
      );
    }

    const qrBase64 = mp.point_of_interaction?.transaction_data?.qr_code_base64;
    const qrCode = mp.point_of_interaction?.transaction_data?.qr_code;
    const paymentId = mp.id?.toString();

    await supabase.from("cobrancas").update({
      status: "notified", // aguardando pagamento
      payment_method: "pix",
      payment_reference: paymentId,
    }).eq("id", bill.id);

    return new Response(
      JSON.stringify({
        payment_id: paymentId,
        qr_code_base64: qrBase64,
        qr_code: qrCode,
        amount: bill.total_amount,
        expires_in: 30 * 60, // 30 min é o default MP
      }),
    );
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
    });
  }
});
