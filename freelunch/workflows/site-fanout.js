export const meta = {
  name: 'freelunch-site-fanout',
  description: 'Generic fragment fan-out: expands compact page specs into 3-fragment worker prompts',
  phases: [{ title: 'Generate' }],
}
const A = typeof args === 'string' ? JSON.parse(args) : args
const DIR = A.dir
const HEADER = `<header class="site-header"><a class="brand" href="index.html">Nubira</a><nav class="nav"> with a.nav-link to index/about/menu/contact.html (Home/About/Menu/Contact)</nav></header>`
const FOOTER = `<footer class="footer"><p>© 2026 Nubira Coffee Roasters — Brewed with patience.</p></footer>`
const RULES = `Real content, fictional specialty coffee brand "Nubira". Classes: .hero .hero-title .hero-sub .btn .section .section-title .cards .card .card-title .card-text .price .table .form .form-field .two-col. One Write call, nothing else. No verification. Return: line count only.`
const FRAG = `Do NOT open or close body/html, no doctype, no head, no header, no hero, no footer. Start directly with <section class="section"> and end with </section>.`
const prompts = []
for (const p of A.pages) {
  prompts.push({ l: `${p.f}.top`, t: `Write ONLY ${DIR}/${p.f}.top.html — TOP FRAGMENT: <!DOCTYPE html>, <html>, <head> with <meta charset>, <title>${p.title}</title>, <link rel="stylesheet" href="styles.css">, </head>, <body>, this exact header: ${HEADER}, then a hero <section class="hero"> with .hero-title/.hero-sub — ${p.hero} — closed </section>. STOP: do not close body/html, no more sections. ~30 lines. ${RULES}` })
  prompts.push({ l: `${p.f}.mid`, t: `Write ONLY ${DIR}/${p.f}.mid.html — MIDDLE FRAGMENT of a page. ${FRAG} Content: ${p.mid}. 30+ lines. ${RULES}` })
  prompts.push({ l: `${p.f}.bot`, t: `Write ONLY ${DIR}/${p.f}.bot.html — BOTTOM FRAGMENT of a page. ${FRAG} Content: ${p.bot}. 30+ lines. ${RULES}` })
}
phase('Generate')
const res = await parallel(prompts.map(pr => () => agent(pr.t, { label: pr.l, model: A.model || 'sonnet', effort: 'low' })))
return { done: res.filter(Boolean).length }
