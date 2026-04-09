import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Palavras bloqueadas por categoria
const BLOCKED_POLITICAL = [
  "político", "política", "eleição", "candidato", "partido",
  "bolsonaro", "lula", "governo", "presidente", "congresso",
  "senado", "deputado", "vereador", "prefeito", "governador",
  "esquerda", "direita", "comunista", "fascista",
];

const BLOCKED_OFFENSIVE = [
  "porra", "caralho", "merda", "foda", "puta", "viado",
  "idiota", "imbecil", "retardado", "vagabunda",
];

interface ModeratePayload {
  post_id: string;
  content: string;
}

interface ModerationResult {
  flagged: boolean;
  reason: string | null;
  category: string | null;
  blocked_word: string | null;
}

function moderateContent(content: string): ModerationResult {
  const lower = content.toLowerCase();

  // Check political
  for (const word of BLOCKED_POLITICAL) {
    if (lower.includes(word)) {
      return {
        flagged: true,
        reason: "Conteúdo político detectado",
        category: "political",
        blocked_word: word,
      };
    }
  }

  // Check offensive
  for (const word of BLOCKED_OFFENSIVE) {
    if (lower.includes(word)) {
      return {
        flagged: true,
        reason: "Linguagem inadequada detectada",
        category: "offensive",
        blocked_word: word,
      };
    }
  }

  return {
    flagged: false,
    reason: null,
    category: null,
    blocked_word: null,
  };
}

Deno.serve(async (req) => {
  try {
    const payload: ModeratePayload = await req.json();
    const supabase = createClient(supabaseUrl, supabaseKey);

    const result = moderateContent(payload.content);

    if (result.flagged) {
      // Flag the post
      await supabase
        .from("community_posts")
        .update({
          is_flagged: true,
          flag_reason: result.reason,
        })
        .eq("id", payload.post_id);

      // Notify admin
      const { data: admins } = await supabase
        .from("profiles")
        .select("id")
        .eq("role", "admin");

      if (admins) {
        const notifications = admins.map((a: any) => ({
          user_id: a.id,
          title: "Post flagado",
          body: `Post flagado por: ${result.reason}. Palavra: "${result.blocked_word}"`,
          type: "moderation",
          data: { post_id: payload.post_id, category: result.category },
        }));

        await supabase.from("notifications").insert(notifications);
      }
    }

    return new Response(JSON.stringify(result));
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
    });
  }
});
