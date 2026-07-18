export const meta = {
  name: 'freelunch-code-fanout',
  description: 'Generic code fan-out: each chunk owns files, coded against a shared interface contract',
  phases: [{ title: 'Build' }],
}
const A = typeof args === 'string' ? JSON.parse(args) : args
const RULES = A.rules || 'Write ONLY your assigned files, nothing else — other workers own the rest and are running concurrently. Minimal exploration, no verification, no extra test runs. Return: file paths + line counts only.'
phase('Build')
const res = await parallel(A.chunks.map(c => () =>
  agent(
    `${c.text}\n\nSHARED CONTRACT (code against it exactly; files owned by other workers conform to it too — do NOT read or wait for them):\n${A.contract}\n\n${RULES}`,
    { label: c.label, model: A.model || 'sonnet', effort: A.effort || 'low' }
  )
))
return { done: res.filter(Boolean).length }
