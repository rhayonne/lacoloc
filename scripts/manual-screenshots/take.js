/**
 * Screenshots do manual Super Coloc — Flutter CanvasKit.
 *
 * Flutter CanvasKit renderiza num canvas WebGL, sem DOM para widgets.
 * - Login: Tab → email → Tab → password → Tab → botão → Enter
 * - Scroll: mouse.wheel() (window.scrollBy não funciona no CanvasKit)
 * - Cliques: coordenadas absolutas lidas dos screenshots de debug
 *
 * Uso:
 *   cd scripts/manual-screenshots
 *   npm install        (apenas na primeira vez)
 *   npm run screenshots
 */

const puppeteer = require('puppeteer');
const fs        = require('fs');
const path      = require('path');

// ─── Config ────────────────────────────────────────────────────────────────────

function loadEnv() {
  const f = path.join(__dirname, '.env.screenshots');
  if (fs.existsSync(f))
    fs.readFileSync(f, 'utf8').split('\n').forEach(l => {
      const m = l.match(/^([^#=]+)=(.*)$/);
      if (m) process.env[m[1].trim()] = m[2].trim().replace(/^['"]|['"]$/g, '');
    });
}
loadEnv();

const APP  = process.env.MANUAL_APP_URL || 'http://localhost:44785';
const USER = process.env.MANUAL_EMAIL;
const PASS = process.env.MANUAL_PASSWORD;

if (!USER || !PASS) {
  console.error('❌  MANUAL_EMAIL / MANUAL_PASSWORD não definidos em .env.screenshots');
  process.exit(1);
}

const DEST = [
  path.resolve(__dirname, '../../docs/manual/screenshots'),
  path.resolve(__dirname, '../../web/manual/screenshots'),
];
const VP = { width: 1440, height: 900 };

// Coordenadas do sidebar (medidas dos screenshots de debug, viewport 1440×900)
// Sidebar width=240px, itens espaçados ~52px a partir de y=224
const SIDEBAR = {
  vueGenerale:         { x: 120, y: 224 },
  gestionImmobiliere:  { x: 120, y: 278 },
  finances:            { x: 120, y: 330 },
  etatDesLieux:        { x: 120, y: 434 },
};

// ─── Helpers ───────────────────────────────────────────────────────────────────

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function shot(page, name) {
  const buf = await page.screenshot({ type: 'png' });
  for (const d of DEST) {
    fs.mkdirSync(d, { recursive: true });
    fs.writeFileSync(path.join(d, name), buf);
  }
  console.log(`  ✅  ${name}`);
}

async function dbg(page, tag) {
  const buf = await page.screenshot({ type: 'png' });
  fs.writeFileSync(path.join(DEST[0], `_dbg-${tag}.png`), buf);
  console.log(`  🔍  _dbg-${tag}.png`);
}

const tap   = (page, x, y, ms = 800) => page.mouse.click(x, y).then(() => sleep(ms));
const key   = (page, k, ms = 400)    => page.keyboard.press(k).then(() => sleep(ms));
const wheel = (page, dy, ms = 700)   => page.mouse.wheel({ deltaY: dy }).then(() => sleep(ms));

// Digitar num campo Flutter via injecção DOM (independente do layout de teclado).
// Flutter escuta o evento `input` no hidden input FLT-TEXT-EDITING-HOST.
async function typeInField(page, text, inputType = 'text') {
  const sel = inputType === 'password'
    ? 'flt-text-editing-host input[type="password"]'
    : 'flt-text-editing-host input:not([type="password"]), flt-text-editing-host textarea';
  await page.waitForSelector(sel, { timeout: 8000 });
  const inp = await page.$(sel);
  if (!inp) throw new Error(`Campo ${inputType} não encontrado`);

  const set = async (val) => page.evaluate((el, v) => {
    const setter = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(el), 'value').set;
    setter.call(el, v);
    el.selectionStart = v.length;
    el.selectionEnd   = v.length;
    el.dispatchEvent(new Event('input', { bubbles: true }));
  }, inp, val);

  await set('');
  await sleep(100);
  await set(text);
  await sleep(250);

  const got = await page.evaluate(el => el.value, inp);
  console.log(`    [${inputType}] ${got.length} chars — ${got.substring(0, 3)}***`);
}

// ─── Fluxo principal ───────────────────────────────────────────────────────────

(async () => {
  console.log('🚀  Iniciando Chromium…\n');
  fs.mkdirSync(DEST[0], { recursive: true });

  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
    defaultViewport: VP,
  });
  const page = await browser.newPage();
  page.setDefaultTimeout(20_000);

  try {

    // ── 1. Carregar home ───────────────────────────────────────────────────
    console.log('📋  Carregando home…');
    await page.goto(APP, { waitUntil: 'networkidle2' });
    await sleep(3000);

    // ── 2. Abrir dialog de login ───────────────────────────────────────────
    console.log('📋  Abrindo login…');
    await tap(page, 1380, 35, 2000);

    // ── 3. Preencher email ────────────────────────────────────────────────
    console.log('📋  Email…');
    await key(page, 'Tab', 800);
    await typeInField(page, USER, 'text');
    await sleep(400);

    // ── 4. Preencher senha ────────────────────────────────────────────────
    console.log('📋  Senha…');
    await key(page, 'Tab', 800);
    await typeInField(page, PASS, 'password');
    await sleep(400);

    // ── 5. Tab ao botão + Enter ───────────────────────────────────────────
    console.log('📋  Tab → Se connecter → Enter…');
    await key(page, 'Tab', 800);
    await key(page, 'Enter', 9000);
    console.log(`  ↗  URL: ${page.url()}`);
    await dbg(page, '01-after-login');

    // ── 6. Navegar para Gestion Immobilière ───────────────────────────────
    // y=278 = "Gestion Immobilière" (Vue générale está em y=224, passo de 52px)
    console.log('📋  Gestion Immobilière…');
    await tap(page, SIDEBAR.gestionImmobiliere.x, SIDEBAR.gestionImmobiliere.y, 2500);
    await dbg(page, '02-gestion-immo');

    // ── SCREENSHOT 1 : Mes Propriétés (tab por defeito) ───────────────────
    console.log('\n📸  Capturas…');
    await shot(page, 'step1-mes-proprietes.png');

    // ── 7. Abrir formulário Nouveau immeuble ──────────────────────────────
    // Botão "+ Ajouter" visível no topo-direito da lista (~1291, 136)
    console.log('📋  Abrindo formulário Nouveau immeuble…');
    await tap(page, 1291, 136, 2500);
    await dbg(page, '03-form-opened');

    // ── SCREENSHOT 2 : topo do formulário — campo Type d'immeuble ─────────
    await shot(page, 'step2-type-dropdown.png');

    // ── SCREENSHOT 4 : campo Adresse com autocomplete ─────────────────────
    // Tap directo no campo "Adresse complète" (x≈810, y≈250 lido do step2)
    console.log('📋  Campo Adresse…');
    await tap(page, 810, 250, 600);
    try {
      await typeInField(page, '12 rue des Lilas, Paris', 'text');
      await sleep(2800); // aguardar sugestões da API BAN
    } catch (_) {
      console.log('  ⚠  Campo endereço não respondeu');
    }
    await dbg(page, '04-adresse');
    await shot(page, 'step4-adresse-autocomplete.png');

    // Fechar autocomplete e voltar ao topo do form
    await key(page, 'Escape', 400);
    await page.mouse.move(810, 450);
    await page.mouse.wheel({ deltaY: -99999 });
    await sleep(800);

    // ── SCREENSHOT 6 : secção Photos des espaces communs ─────────────────
    // "Photos des espaces communs" fica a ~660px do topo do form
    await page.mouse.wheel({ deltaY: 450 });
    await sleep(700);
    await dbg(page, '05-photos-area');
    await shot(page, 'step6-photos.png');

    // ── SCREENSHOT 7 : secção Type de bail ───────────────────────────────
    await page.mouse.wheel({ deltaY: 250 });
    await sleep(700);
    await dbg(page, '06-bail-area');
    await shot(page, 'step7-bail-type.png');

    // ── SCREENSHOT 8 : secção Parties communes ───────────────────────────
    await page.mouse.wheel({ deltaY: 200 });
    await sleep(700);
    await dbg(page, '07-pieces-area');
    await shot(page, 'step8-pieces-communes.png');

    // ── SCREENSHOT 9 : clicar "Fermer" → confirma retorno à lista ─────────
    // Botão "× Fermer" no header: x≈1307, y≈34 (lido do step2)
    console.log('📋  Fermer → lista final…');
    await tap(page, 1307, 34, 2500);
    await dbg(page, '08-after-close');
    await shot(page, 'step9-confirmation.png');

    console.log('\n✅  Concluído! Screenshots em: docs/manual/screenshots/\n');

  } catch (err) {
    console.error('\n❌  Erro:', err.message);
    try { await dbg(page, 'fatal'); } catch (_) {}
    process.exit(1);
  } finally {
    await browser.close();
  }
})();
