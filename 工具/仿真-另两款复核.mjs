// 复核 GDoodleJump（解析积分）与 GPong（纯线性 ×DT）是否帧率无关
function doodle(tickMs, sec) {
  const DT = tickMs/33, G = 0.42, JUMP = -3.9, MAXF = 8, MOVE = 11;
  let vy=0, py=40, px=50, t=0, nf=0;
  while (t < sec*1000) {
    if (t >= nf) { vy = JUMP; nf += 500; }
    py += vy*DT + 0.5*G*DT*DT;
    vy += G*DT;
    if (vy > MAXF) vy = MAXF;
    px += 1 * MOVE * DT;
    t += tickMs;
  }
  return {py:+py.toFixed(3), px:+px.toFixed(3)};
}
function pong(tickMs, sec) {
  const DT = tickMs/40, SPEED = 1.9;
  let bx=50, by=50, vx=SPEED*0.7, vy=SPEED*0.7, ay=50, t=0;
  const AI = 1.2;
  while (t < sec*1000) {
    bx += vx*DT; by += vy*DT;
    if (bx>100||bx<0) vx=-vx;
    if (by>100||by<0) vy=-vy;
    let d = by - ay; const lim = AI*DT;
    if (d>lim) d=lim; else if (d<-lim) d=-lim;
    ay = Math.max(0, Math.min(100-12, ay+d));
    t += tickMs;
  }
  return {bx:+bx.toFixed(3), by:+by.toFixed(3), ay:+ay.toFixed(3)};
}
console.log('═══ GDoodleJump（33→16ms）═══');
const d0 = doodle(33,3); console.log('  30fps:', JSON.stringify(d0));
for (const ms of [16,11,8]) {
  const r = doodle(ms,3);
  const diff = Math.max(Math.abs(r.py-d0.py), Math.abs(r.px-d0.px));
  console.log('  %4.1ffps: %s ｜ 最大差 %s %s', 1000/ms, JSON.stringify(r), diff.toFixed(3), diff<1?'✅':'⚠️');
}
console.log('═══ GPong（40→16ms）═══');
const p0 = pong(40,3); console.log('  25fps:', JSON.stringify(p0));
for (const ms of [16,11,8]) {
  const r = pong(ms,3);
  const diff = Math.max(Math.abs(r.bx-p0.bx), Math.abs(r.by-p0.by), Math.abs(r.ay-p0.ay));
  console.log('  %4.1ffps: %s ｜ 最大差 %s %s', 1000/ms, JSON.stringify(r), diff.toFixed(3), diff<1?'✅':'⚠️');
}
