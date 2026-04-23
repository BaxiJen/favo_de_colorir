/**
 * Bridge HTML pra links do email (confirm, magic, recovery).
 *
 * Supabase só aceita URLs HTTPS como Site URL / redirect — custom scheme
 * `favo://` não funciona direto no email. Essa function devolve HTML que:
 * 1. Tenta abrir o app via `favo://auth-callback?<mesmos params>`.
 * 2. Se o scheme não estiver registrado (desktop, app não instalado),
 *    mostra fallback com links pra baixar o app.
 *
 * Deploy: `supabase functions deploy auth-bridge --no-verify-jwt`
 * Site URL: https://<project-ref>.supabase.co/functions/v1/auth-bridge
 */

const HTML = `<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>Abrindo o Favo de Colorir…</title>
<style>
  *{box-sizing:border-box}
  body{margin:0;min-height:100vh;display:grid;place-items:center;
    font-family:system-ui,-apple-system,'Segoe UI',sans-serif;
    background:
      radial-gradient(60rem 40rem at 30% 10%, #ffdcc3 0%, transparent 60%),
      radial-gradient(50rem 50rem at 85% 80%, #ffd9b5 0%, transparent 60%),
      #fff7ee;
    color:#3a1d00}
  main{max-width:28rem;padding:2.5rem;text-align:center}
  .spin{width:48px;height:48px;border:3px solid #c75b39;
    border-top-color:transparent;border-radius:50%;
    margin:0 auto 1.5rem;animation:spin .8s linear infinite}
  @keyframes spin{to{transform:rotate(360deg)}}
  h1{font-size:1.75rem;margin:0 0 .75rem;line-height:1.2}
  p{margin:0 0 .75rem;line-height:1.5;color:#5d1900}
  .fb{opacity:0;transition:opacity .35s;margin-top:2rem;
    border-top:1px solid #c75b3933;padding-top:1.5rem}
  .fb.on{opacity:1}
  .stores{display:flex;flex-wrap:wrap;gap:.75rem;justify-content:center;margin-top:1.25rem}
  .st{padding:.75rem 1.25rem;background:#3a1d00;color:#fff7ee;
    border-radius:999px;text-decoration:none;font-weight:600;font-size:.875rem}
  .st.alt{background:transparent;color:#3a1d00;border:1.5px solid #3a1d00}
  a.re{display:inline-block;margin-top:1rem;color:#c75b39;font-weight:600;font-size:.95rem}
</style>
</head>
<body>
<main>
  <div class="spin" aria-hidden="true"></div>
  <h1>Abrindo o app…</h1>
  <p>Se o Favo de Colorir estiver instalado, ele vai abrir em 1 segundo.</p>
  <div id="fb" class="fb">
    <p><strong>Não abriu?</strong></p>
    <p>Você tá no desktop ou ainda não instalou o app. Baixa pra continuar:</p>
    <div class="stores">
      <a class="st" href="#" data-todo="app-store">App Store</a>
      <a class="st alt" href="#" data-todo="google-play">Google Play</a>
    </div>
    <p><a class="re" href="javascript:location.reload()">Tentar de novo</a></p>
  </div>
</main>
<script>
  (function(){
    var q = window.location.search || '';
    var h = window.location.hash || '';
    var link = 'favo://auth-callback' + q + h;
    setTimeout(function(){ window.location.href = link; }, 300);
    setTimeout(function(){
      var el = document.getElementById('fb');
      if (el) el.classList.add('on');
    }, 2000);
  })();
</script>
</body>
</html>`;

Deno.serve(() => {
  return new Response(HTML, {
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "public, max-age=300",
    },
  });
});
