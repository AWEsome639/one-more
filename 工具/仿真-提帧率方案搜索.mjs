// 找一个【真正等价】的 60fps 缩放方案
const G0 = 0.48, FLAP0 = -2.9, MAXF0 = 7;
function sim(tickMs, kG, kF, kM, seconds, flapEveryMs) {
  const G = G0*kG, F = FLAP0*kF, M = MAXF0*kM;
  let vy = 0, py = 40, t = 0, nextFlap = 0;
  while (t < seconds*1000) {
    if (t >= nextFlap) { vy = F; nextFlap += flapEveryMs; }
    vy += G; if (vy > M) vy = M;
    py += vy;
    if (py < 0) { py = 0; if (vy < 0) vy = 0; }
    t += tickMs;
  }
  return +py.toFixed(3);
}
const REF = sim(33, 1, 1, 1, 3, 400);
console.log('═══ 基准（30fps 原版）3 秒后鸟高度 = %s ═══', REF);
console.log();
const k = 16/33;
const cands = [
  ['全部 ×k（我原来的做法）', k, k, k],
  ['重力 ×k，扇翅【不缩】', k, 1, k],
  ['重力 ×k²，扇翅 ×k', k*k, k, k*k],
  ['重力 ×k²，扇翅【不缩】', k*k, 1, k*k],
  ['重力 ×k，扇翅 ×k²', k, k*k, k],
  ['重力【不缩】，扇翅【不缩】', 1, 1, 1],
];
console.log('  方案                              3秒后高度   与基准差');
for (const [name, a, b, c] of cands) {
  const v = sim(16, a, b, c, 3, 400);
  const d = Math.abs(v - REF);
  console.log('  %-32s %8s   %8s %s', name, v, d.toFixed(2), d < 2 ? '✅ 等价' : '');
}
