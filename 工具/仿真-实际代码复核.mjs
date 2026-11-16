// ★ 复核【实际写进 GFlappy.ets 的代码】是否帧率无关
//   代码（tick 内）：
//     py += vy*DT + 0.5*GRAVITY*DT*DT
//     vy += GRAVITY*DT
//     if (vy > MAX_FALL) vy = MAX_FALL
//     if (py < 0) { py = 0; if (vy < 0) vy = 0 }
//     pipe.x -= PIPE_SPEED*DT
//     wingPhase += (fast?0.34:0.06)*DT
//   flap: vy = FLAP_V（★ 冲量，不缩）
const GRAVITY = 0.48, FLAP_V = -2.9, MAX_FALL = 7, PIPE_SPEED = 1.5;
function sim(tickMs, seconds, flapEveryMs) {
  const DT = tickMs / 33;
  let vy = 0, py = 40, pipeX = 70, wing = 0, t = 0, nextFlap = 0;
  while (t < seconds * 1000) {
    if (t >= nextFlap) { vy = FLAP_V; nextFlap += flapEveryMs; }
    py += vy * DT + 0.5 * GRAVITY * DT * DT;
    vy += GRAVITY * DT;
    if (vy > MAX_FALL) vy = MAX_FALL;
    if (py < 0) { py = 0; if (vy < 0) vy = 0; }
    pipeX -= PIPE_SPEED * DT;
    wing += 0.06 * DT;
    t += tickMs;
  }
  return { py:+py.toFixed(3), vy:+vy.toFixed(3), pipeX:+pipeX.toFixed(3), wing:+wing.toFixed(3), fps:+(1000/tickMs).toFixed(1) };
}
console.log('═══ 实际代码（解析积分 + DT）在不同帧率下的 3 秒后状态 ═══');
const ref = sim(33, 3, 400);
console.log('  基准 30fps:', JSON.stringify(ref));
let worst=0;
for (const ms of [16, 11, 8]) {
  const r = sim(ms, 3, 400);
  const d = Math.max(Math.abs(r.py-ref.py), Math.abs(r.pipeX-ref.pipeX), Math.abs(r.wing-ref.wing)*5);
  worst = Math.max(worst, d);
  console.log('  %4.1ffps  :', JSON.stringify(r), '｜ 最大差', d.toFixed(3));
}
console.log();
console.log(worst < 1.0
  ? '  ✅✅ 帧率无关（最大差 ' + worst.toFixed(3) + '）⇒ TICK_MS=16（60fps）可以上，手感不变'
  : '  ⚠️ 仍有残差 ' + worst.toFixed(3));
