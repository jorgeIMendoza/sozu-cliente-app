// Cloudflare Worker — redirección a tienda según sistema operativo.
// Sirve también la landing de escritorio, así no hay que hospedar nada aparte.
//
// Worker: app-sozu-clientes · dominio: obtener-clientes-app.sozu.com
//
// Es el destino que codifica el QR del login (`assets/images/sozu-qr-web.png`) y
// el respaldo del aviso de actualización cuando `app_cliente_config` no trae URL
// de tienda (ver kAppDownloadUrl en features/app_download).
//
// Este archivo se agrega al repo porque hasta ahora el worker vivía SOLO en el
// dashboard de Cloudflare: no había copia ni historial de a dónde apuntaba el QR,
// y una edición o un borrado accidental no dejaban rastro. Su gemelo es
// `app-sozu-agentes` en el repo sozu-agente-app; misma estructura a propósito,
// para que un arreglo en uno se pueda copiar al otro sin traducir.

// ─── Cuando publiques en App Store: pon la URL real y cambia esto a true ───
const IOS_DISPONIBLE = false;
const IOS_URL = "https://apps.apple.com/mx/app/TU-APP/idXXXXXXXXX";
// ───────────────────────────────────────────────────────────────────────────

const ANDROID_URL =
  "https://play.google.com/store/apps/details?id=com.sozu.clientes_app" +
  "&referrer=utm_source%3Dqr%26utm_medium%3Dimpreso";

const ESTILOS = `
  :root { color-scheme: light dark; }
  * { box-sizing: border-box; }
  body { margin:0; min-height:100vh; display:flex; flex-direction:column;
         align-items:center; justify-content:center; gap:1rem; padding:2rem;
         font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;
         text-align:center; line-height:1.5; }
  h1 { font-size:1.4rem; margin:0; }
  p  { margin:0; opacity:.7; max-width:34ch; }
  .btn { display:block; width:100%; max-width:320px; padding:1rem 1.5rem;
         border-radius:12px; background:#111; color:#fff; text-decoration:none;
         font-weight:600; }
  .btn.off { background:transparent; color:inherit; opacity:.45;
             border:1px solid currentColor; font-weight:500; }
  .badge { font-size:.75rem; letter-spacing:.08em; text-transform:uppercase;
           opacity:.55; }
  @media (prefers-color-scheme: dark) { .btn { background:#fff; color:#111; } }
`;

const pagina = (titulo, cuerpo) => `<!DOCTYPE html>
<html lang="es"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex">
<title>${titulo}</title>
<style>${ESTILOS}</style></head>
<body>${cuerpo}</body></html>`;

const html = (contenido, titulo) =>
  new Response(pagina(titulo, contenido), {
    headers: {
      "content-type": "text/html; charset=utf-8",
      // Sin caché: el destino depende del User-Agent de cada visitante.
      "cache-control": "no-store",
    },
  });

const PAGINA_IOS = `
  <span class="badge">Próximamente</span>
  <h1>Aún no estamos en el App Store</h1>
  <p>La versión para iPhone está en camino y la publicaremos muy pronto.
     Gracias por tu paciencia.</p>
  <p style="opacity:.5;font-size:.85rem">Si tienes un dispositivo Android,
     la app ya está disponible en Google Play.</p>
`;

const PAGINA_ESCRITORIO = `
  <h1>Descarga la app de Sozu</h1>
  <p>Elige tu plataforma</p>
  <a class="btn" href="${ANDROID_URL}">Google Play (Android)</a>
  ${
    IOS_DISPONIBLE
      ? `<a class="btn" href="${IOS_URL}">App Store (iOS)</a>`
      : `<span class="btn off">App Store · Próximamente</span>`
  }
`;

export default {
  async fetch(request) {
    const ua = request.headers.get("user-agent") || "";

    // iPadOS 13+ se anuncia como Macintosh; el token "Mobile" lo delata.
    const isIOS =
      /iPhone|iPad|iPod/i.test(ua) ||
      (/Macintosh/i.test(ua) && /Mobile/i.test(ua));
    const isAndroid = /Android/i.test(ua);

    if (isAndroid) return Response.redirect(ANDROID_URL, 302);

    if (isIOS) {
      return IOS_DISPONIBLE
        ? Response.redirect(IOS_URL, 302)
        : html(PAGINA_IOS, "Próximamente en App Store · Sozu");
    }

    return html(PAGINA_ESCRITORIO, "Descarga la app de Sozu Clientes");
  },
};
