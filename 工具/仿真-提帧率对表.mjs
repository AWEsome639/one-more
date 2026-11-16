// ★★★ 用仿真验证【提帧率 + 同比例缩放物理】是否等价
//   起因：模拟器里触发不了"起飞"⇒ 改从物理层验证（等价性是可算的）
//   GFlappy 的 tick() 关键行（读自源码 178-195）：
//     this.vy += GRAVITY; if (vy > MAX_FALL) vy = MAX_FALL;
//     this.py += this.vy;
//     np.x = p.x - PIPE_SPEED
const runs = [
  { name: '30fps 原版 (TICK=33, k=1)',    tick: 33, k: 1 },
  { name: '60fps 缩放版 (TICK=16, k=16/33)', tick: 16, k: 16 / 33 },
];
const G0 = 0.48, FLAP0 = -2.9, MAXF0 = 7, SPD0 = 1.5;
const GRAVITY0 = 0.48, FLAP0V = -2.9, MAXFALL0 = 7, PIPESPD0 = 1.5;

function simulate(tickMs, k, seconds, flapEveryMs) {
  const GRAVITY = GRAVITY0 * k, FLAP_V = FLAP0V * k, MAX_FALL = MAXFALL0 * k, PIPE_SPEED = PIPESPD0 * k;
  let vy = 0, py = 40, t = 0;
  let pipeX = 70;
  let nextFlap = 0;
  let flaps = 0;
  while (t < seconds * 1000) {
    // 定时扇翅膀（每 flapEveryMs 一次）
    if (t >= nextFlap) { vy = FLAP_V; nextFlap += flapEveryMs; flaps++; }
    vy += GRAVITY;
    if (vy > MAX_FALL) vy = MAX_FALL;
    py += vy;
    if (py < 0) { py = 0; if (vy < 0) vy = 0; }
    pipeX -= PIPE_SPEED;
    t += tickMs;
  }
  return { py: +py.toFixed(3), vy: +vy.toFixed(3), pipeX: +pipeX.toFixed(3), flaps, steps: Math.round(t / tickMs) };
}

console.log('═══ 同一段时间（3 秒）后的物理状态对比 ═══');
const A = simulate(33, 1, 3, 400);
const B = simulate(16, 16 / 33, 3, 400);
console.log('  30fps 原版 :', JSON.stringify(A));
console.log('  60fps 缩放 :', JSON.stringify(B));
console.log();
const d = (x, y) => Math.abs(x - y);
console.log('  鸟高度差 : %s ｜ 速度差 : %s ｜ 管道位置差 : %s',
  d(A.py, B.py).toFixed(3), d(A.vy, B.vy).toFixed(3), d(A.pipeX, B.pipeX).toFixed(3));
console.log('  扇翅膀次数: %d vs %d', A.flaps, B.flaps);
console.log('  模拟步数  : %d vs %d（★ 帧率确实翻了倍）', A.steps, B.steps);
console.log();
const ok = d(A.py, B.py) < 1.0 && d(A.pipeX, B.pipeX) < 1.0;
console.log(ok
  ? '  ✅ 结论：物理【等价】（差异 < 1 单位，属于离散化误差）⇒ 提帧率不会改手感'
  : '  ❌ 结论：物理【不等价】⇒ 提帧率会改手感，不能直接改');
