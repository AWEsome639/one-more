// 数独难度模型的对拍测试（2026-10-23，路线 B）
// 目的：证明 ArkTS 的 sudokuFeatures 与 Python 的 features() 逐项一致，
//       且前向结果一致。差一项模型就全错，而且不会报错。
import { readFileSync } from 'fs';

const W = JSON.parse(readFileSync('/Users/a0000/dev/yiju/entry/src/main/resources/rawfile/models/sudoku_diff.json','utf8'));
const cases = JSON.parse(readFileSync('/tmp/sudoku_cases.json','utf8'));

// ── 与 SudokuFeatures.ets 逐行对应的移植 ──
const N=9, ALL=0x1FF;
const PEERS=[];
for (let i=0;i<81;i++){
  const r=Math.floor(i/N), c=i%N, b=Math.floor(r/3)*3+Math.floor(c/3);
  const list=[];
  for (let j=0;j<81;j++){
    if (j===i) continue;
    const jr=Math.floor(j/N), jc=j%N, jb=Math.floor(jr/3)*3+Math.floor(jc/3);
    if (jr===r||jc===c||jb===b) list.push(j);
  }
  PEERS.push(list);
}
const popcount=x=>{let n=0,v=x;while(v!==0){v=v&(v-1);n++;}return n;};
const bitOf=v=>1<<(v-1);
function candMasks(g){
  const m=new Array(81).fill(0);
  for(let i=0;i<81;i++){
    if(g[i]!==0) continue;
    let mask=ALL;
    for(const p of PEERS[i]) if(g[p]!==0) mask&=~bitOf(g[p]);
    m[i]=mask;
  }
  return m;
}
function unitOf(i,kind){
  const r=Math.floor(i/N), c=i%N;
  if(kind===0) return r;
  if(kind===1) return c;
  return Math.floor(r/3)*3+Math.floor(c/3);
}
function unitStd(g,kind){
  const cnts=new Array(9).fill(0);
  for(let i=0;i<81;i++) if(g[i]!==0) cnts[unitOf(i,kind)]++;
  const mean=cnts.reduce((a,b)=>a+b,0)/9;
  const v=cnts.reduce((a,b)=>a+(b-mean)*(b-mean),0)/9;
  return Math.sqrt(v)/9;
}
function sudokuFeatures(g){
  let holes=0; for(let i=0;i<81;i++) if(g[i]===0) holes++;
  const masks=candMasks(g);
  const f=new Array(11).fill(0);
  f[0]=holes/81;
  f[1]=unitStd(g,0); f[2]=unitStd(g,1); f[3]=unitStd(g,2);
  let singles=0; for(let i=0;i<81;i++) if(g[i]===0&&popcount(masks[i])===1) singles++;
  f[4]=singles/81;
  let hidden=0;
  for(let kind=0;kind<3;kind++){
    for(let u=0;u<9;u++){
      const cells=[];
      for(let i=0;i<81;i++) if(g[i]===0&&unitOf(i,kind)===u) cells.push(i);
      for(let v=1;v<=9;v++){
        let spots=0; const bv=bitOf(v);
        for(const cc of cells) if((masks[cc]&bv)!==0) spots++;
        if(spots===1) hidden++;
      }
    }
  }
  f[5]=hidden/81;
  let total=0,two=0,three=0;
  for(let i=0;i<81;i++){
    if(g[i]!==0) continue;
    const n=popcount(masks[i]); total+=n;
    if(n===2) two++; else if(n===3) three++;
  }
  f[6]=holes>0?total/(holes*9):0;
  f[7]=holes>0?two/holes:0;
  f[8]=holes>0?three/holes:0;
  let dead=false;
  for(let i=0;i<81;i++) if(g[i]===0&&popcount(masks[i])===0){dead=true;break;}
  f[9]=dead?1:0;
  const numCnt=new Array(10).fill(0);
  for(let i=0;i<81;i++) if(g[i]!==0) numCnt[g[i]]++;
  const mean=numCnt.slice(1).reduce((a,b)=>a+b,0)/9;
  let var2=0; for(let v=1;v<=9;v++) var2+=(numCnt[v]-mean)*(numCnt[v]-mean);
  f[10]=Math.sqrt(var2/9)/9;
  return f;
}
function predict(x){
  const xs=x.map((v,i)=>(v-W.featureMean[i])/(W.featureStd[i]||1));
  let out=W.b2;
  for(let j=0;j<W.hidden;j++){
    let s=W.b1[j]; const row=W.W1[j];
    for(let i=0;i<W.inDim;i++) s+=row[i]*xs[i];
    if(s>0) out+=W.W2[j]*s;
  }
  return out;
}

let featMax=0, predMax=0, same=0;
for(const c of cases){
  const f=sudokuFeatures(c.grid);
  for(let i=0;i<11;i++) featMax=Math.max(featMax, Math.abs(f[i]-c.feat[i]));
  const p=predict(f);
  predMax=Math.max(predMax, Math.abs(p-c.pred));
  if(Math.abs(p-c.pred)<1e-6) same++;
}
console.log('  ══ 30 组：特征最大误差 ' + featMax.toExponential(2));
console.log('  ══ 30 组：预测最大误差 ' + predMax.toExponential(2) + ' ｜ 完全一致 ' + same + '/30');
const ok = featMax < 1e-9 && predMax < 1e-6;
console.log(ok ? '  ✅ 端口与 Python 等价，可以上线' : '  🔴 不等价，不许上线');
process.exit(ok?0:1);
