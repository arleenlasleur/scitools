class RtNavGraph extends Object;

const CHUNK   = 16384;
const CELL    = 1200.0;
const BUCKETS = 8192;
const MAX_NODES   = 6400;
const MAX_EDGES   = 131072;
const MAX_DEGREE  = 16;
const MAX_OPT_DEGREE = 8;
const R_BRIDGE = 1200.0;
const MAX_DZ   = 384.0;

const CM_STANDARD = 0;
const CM_IGNOREZ  = 1;
const CM_SHAFT    = 2;
const CM_ANYRANGE = 3;

var array<Actor>  NodeActor_arr;  var int NodeActor_qty;
var array<vector> NodeLoc_arr;    var int NodeLoc_qty;
var array<int>    NodeMode_arr;   var int NodeMode_qty;
var array<float>  NodeParam_arr;  var int NodeParam_qty;
var array<int>    NodeDeg_arr;    var int NodeDeg_qty;
var int           Nodes_qty;

var array<RtIntChunk>   EdgeA;    var int EdgeA_qty;
var array<RtIntChunk>   EdgeB;    var int EdgeB_qty;
var array<RtFloatChunk> EdgeCost; var int EdgeCost_qty;
var int                 Edges_qty;

var array<RtIntChunk> EdgeForce; var int EdgeForce_qty;
var array<vector> ForceLocA; var int ForceLocA_qty;
var array<vector> ForceLocB; var int ForceLocB_qty;

var array<int> AdjStart; var int AdjStart_qty;
var array<int> AdjEdge;  var int AdjEdge_qty;

var array<RtBucket> NavBuckets; var int NavBuckets_qty;

var array<int>  DSU_Parent;     // main branch DSU
var int         DSU_Parent_qty;
var array<int>  DSU_Rank;
var int         DSU_Rank_qty;
var int         DSU_qty; // always same as parent
var int         DSU_Root;
var bool        DSU_Dirty;
var array<byte> DSU_EdgeMain;      // [e] = color code: 0=RED, 1=YELLOW, 2=WHITE
var int         DSU_EdgeMain_qty;
var array<int>  DSU_CompEdgeCnt;   // tmp
var int         DSU_CompEdgeCnt_qty;

var array<int> SeenStamp; var int SeenStamp_qty;
var int        CurrentStamp;

var int BuildCx, BuildCy;
var int Trace_calls_qty, Trace_hits_qty;

// ============================================================
// READ/WRITE
// ============================================================
function int   GetInt(array<RtIntChunk> C, int i)   { return C[i/CHUNK].Data[i%CHUNK]; }
function float GetFlt(array<RtFloatChunk> C, int i){ return C[i/CHUNK].Data[i%CHUNK]; }
function       SetInt(array<RtIntChunk> C, int i, int v)     { C[i/CHUNK].Data[i%CHUNK] = v; }
function       SetFlt(array<RtFloatChunk> C, int i, float v){ C[i/CHUNK].Data[i%CHUNK] = v; }
function int   GetEdgeA(int i)    { return EdgeA[i/CHUNK].Data[i%CHUNK]; }
function int   GetEdgeB(int i)    { return EdgeB[i/CHUNK].Data[i%CHUNK]; }
function float GetEdgeCost(int i){ return EdgeCost[i/CHUNK].Data[i%CHUNK]; }
function int  GetEdgeForce(int i)        { return EdgeForce[i/CHUNK].Data[i%CHUNK]; }
function      SetEdgeForce(int i, int v){ EdgeForce[i/CHUNK].Data[i%CHUNK] = v; }

function int HashCell(int cx, int cy){
   return ((cx * 73856093) ^ (cy * 19349663)) & (BUCKETS - 1);
}

function int HashXY(vector V){
   local int cx, cy;
   cx = int(V.X / CELL);
   cy = int(V.Y / CELL);
   if (V.X < 0 && V.X / CELL != cx) cx = cx - 1;
   if (V.Y < 0 && V.Y / CELL != cy) cy = cy - 1;
   return HashCell(cx, cy);
}

function InitBuckets(){
   local int i;
   local RtBucket B;
   for (i = 0; i < BUCKETS; i++){
      if (i < NavBuckets_qty){
         B = NavBuckets[i];
      } else {
         B = new(Self) Class'RtBucket';
         NavBuckets.Add(B);
         NavBuckets_qty = NavBuckets_qty + 1;
      }
      B.Items_qty = 0;
   }
}

function BucketAdd(int idx){
   local int b, cap, qty;
   b = HashXY(NodeLoc_arr[idx]);
   qty = NavBuckets[b].Items_qty;
   cap = NavBuckets[b].Items_cap;
   if (qty < cap){
      NavBuckets[b].Items[qty] = idx;
   } else {
      NavBuckets[b].Items.Add(idx);
      NavBuckets[b].Items_cap = cap + 1;
   }
   NavBuckets[b].Items_qty = qty + 1;
}

function bool MarkSeen(int idx){
   if (SeenStamp[idx] == CurrentStamp) return False;
   SeenStamp[idx] = CurrentStamp;
   return True;
}

function int AppendEdge(int a, int b, float cost){
   local int c, o, k;
   if (Edges_qty >= MAX_EDGES) return -1; // do not ret Edges_qty for error cases

   c = Edges_qty / CHUNK;
   o = Edges_qty % CHUNK;
   while (EdgeA_qty <= c){
      EdgeA.Add(new(Self) Class'RtIntChunk');
      EdgeA[EdgeA_qty].Data_qty = 0;
      EdgeA_qty++;
   }
   k = EdgeA[c].Data_qty;
   while (k <= o){ EdgeA[c].Data.Add(0); k++; }
   EdgeA[c].Data_qty = o + 1;

   while (EdgeB_qty <= c){
      EdgeB.Add(new(Self) Class'RtIntChunk');
      EdgeB[EdgeB_qty].Data_qty = 0;
      EdgeB_qty++;
   }
   k = EdgeB[c].Data_qty;
   while (k <= o){ EdgeB[c].Data.Add(0); k++; }
   EdgeB[c].Data_qty = o + 1;

   while (EdgeCost_qty <= c){
      EdgeCost.Add(new(Self) Class'RtFloatChunk');
      EdgeCost[EdgeCost_qty].Data_qty = 0;
      EdgeCost_qty++;
   }
   k = EdgeCost[c].Data_qty;
   while (k <= o){ EdgeCost[c].Data.Add(0.0); k++; }
   EdgeCost[c].Data_qty = o + 1;
   EdgeCost[c].Data[o] = cost;
   while (EdgeForce_qty <= c){
      EdgeForce.Add(new(Self) Class'RtIntChunk');
      EdgeForce[EdgeForce_qty].Data_qty = 0;
      EdgeForce_qty++;
   }
   k = EdgeForce[c].Data_qty;
   while (k <= o){ EdgeForce[c].Data.Add(0); k++; }
   EdgeForce[c].Data_qty = o + 1;
   EdgeForce[c].Data[o] = 0;

   EdgeA[c].Data[o]    = a;
   EdgeB[c].Data[o]    = b;
   Edges_qty++;
   DSU_Dirty = True;
   return Edges_qty - 1;   // last stored index
}

function bool PopLastEdge(){
   local int i, c, o, a, b;
   if (Edges_qty <= 0) return False;
   i = Edges_qty - 1;
   c = i / CHUNK;
   o = i % CHUNK;
   a = EdgeA[c].Data[o];         // before removing
   b = EdgeB[c].Data[o];
   Edges_qty = i;
   EdgeA[c].Data_qty     = o;
   EdgeB[c].Data_qty     = o;
   EdgeCost[c].Data_qty  = o;
   EdgeForce[c].Data_qty = o;
   if (a >= 0 && a < Nodes_qty && NodeDeg_arr[a] > 0) NodeDeg_arr[a]--;    // save data for next pop/append usage
   if (b >= 0 && b < Nodes_qty && NodeDeg_arr[b] > 0) NodeDeg_arr[b]--;
   DSU_Dirty = True;
   if (Edges_qty == 0){
      DSU_Root = -1;
   } else if (DSU_Root < 0 || DSU_Root >= Nodes_qty || NodeDeg_arr[DSU_Root] == 0){
      DSU_Root = GetEdgeA(0);   // re-root to first kept edge
   }
   return True;
}

function int FindEdge(int a, int b){
   local int e;
   for (e = Edges_qty - 1; e >= 0; e--){   // read from end
      if ((GetEdgeA(e) == a && GetEdgeB(e) == b) ||
          (GetEdgeA(e) == b && GetEdgeB(e) == a)) return e;
   }
   return -1;
}

function DSU_Init(){ // main-component DSU (path compression + union by rank)
   local int i;
   // grow to Nodes_qty, then overwrite in [0, Nodes_qty]
   while (DSU_Parent_qty < Nodes_qty){ DSU_Parent.Add(0);  DSU_Parent_qty = DSU_Parent_qty + 1; }
   while (DSU_Rank_qty < Nodes_qty){   DSU_Rank.Add(0);    DSU_Rank_qty = DSU_Rank_qty + 1; }
   for (i = 0; i < Nodes_qty; i++){
      DSU_Parent[i] = i;
      DSU_Rank[i]   = 0;
   }
   DSU_qty = Nodes_qty;
}

function int DSU_Find(int x){
   local int r, p;
   if (x < 0 || x >= DSU_qty) return -1;
   r = x;
   while (DSU_Parent[r] != r) r = DSU_Parent[r];
   while (DSU_Parent[x] != r){
      p = DSU_Parent[x];
      DSU_Parent[x] = r;
      x = p;
   }
   return r;
}

function DSU_Union(int a, int b){
   local int ra, rb;
   ra = DSU_Find(a);
   rb = DSU_Find(b);
   if (ra < 0 || rb < 0 || ra == rb) return;
   if (DSU_Rank[ra] < DSU_Rank[rb]){ DSU_Parent[ra] = rb; }
   else if (DSU_Rank[ra] > DSU_Rank[rb]){ DSU_Parent[rb] = ra; }
   else { DSU_Parent[rb] = ra; DSU_Rank[ra] = DSU_Rank[ra] + 1; }
}

function DSU_Rebuild(){
//   local int e,    a, b,    rr, inMain, code;
   local int e, i, a,    r, rr,        code;
   DSU_Init();
   for (e = 0; e < Edges_qty; e++) DSU_Union(GetEdgeA(e), GetEdgeB(e));
   if (DSU_Root < 0 && Edges_qty > 0) DSU_Root = GetEdgeA(0);   // root = edges[0].a
   while (DSU_CompEdgeCnt_qty < DSU_qty){         // edge count per component (indexed by DSU root)
      DSU_CompEdgeCnt.Add(0);
      DSU_CompEdgeCnt_qty = DSU_CompEdgeCnt_qty + 1;
   }
   for (i = 0; i < DSU_qty; i++) DSU_CompEdgeCnt[i] = 0;
   for (e = 0; e < Edges_qty; e++){
      r = DSU_Find(GetEdgeA(e));
      if (r >= 0) DSU_CompEdgeCnt[r] = DSU_CompEdgeCnt[r] + 1;
   }
   rr = -1;
   if (DSU_Root >= 0 && DSU_Root < DSU_qty) rr = DSU_Find(DSU_Root);
   for (e = 0; e < Edges_qty; e++){       // per-edge color
      a = GetEdgeA(e);
      r = (a >= 0) ? DSU_Find(a) : -1;
      if      (r >= 0 && r == rr)                 code = 2;   // WHITE (root comp)
      else if (r >= 0 && DSU_CompEdgeCnt[r] >= 2) code = 1;   // YELLOW (cluster)
      else                                        code = 0;   // RED (stray)
      if (e < DSU_EdgeMain_qty) DSU_EdgeMain[e] = code;
      else { DSU_EdgeMain.Add(code); DSU_EdgeMain_qty = DSU_EdgeMain_qty + 1; }
   }
   if (DSU_EdgeMain_qty > Edges_qty) DSU_EdgeMain_qty = Edges_qty; // cut logical length if reduced edges
   DSU_Dirty = False;
}

function bool EdgeInMainComp(int e){
   if (DSU_Dirty) DSU_Rebuild();
   if (e < 0 || e >= DSU_EdgeMain_qty) return False;
   return DSU_EdgeMain[e] == 2;   // 2 = WHITE = main component
}

function int AddNode(Actor NodeActor, vector Loc, int Mode, float Param){
   local int idx;
   if (Nodes_qty >= MAX_NODES) return -1;
   idx = Nodes_qty;
   // rewrite elements if exist
   if (idx < NodeActor_qty) NodeActor_arr[idx] = NodeActor; else { NodeActor_arr.Add(NodeActor); NodeActor_qty++; }
   if (idx < NodeLoc_qty)   NodeLoc_arr[idx]   = Loc;       else { NodeLoc_arr.Add(Loc);         NodeLoc_qty++;   }
   if (idx < NodeMode_qty)  NodeMode_arr[idx]  = Mode;      else { NodeMode_arr.Add(Mode);       NodeMode_qty++;  }
   if (idx < NodeParam_qty) NodeParam_arr[idx] = Param;     else { NodeParam_arr.Add(Param);     NodeParam_qty++; }
   if (idx < NodeDeg_qty)   NodeDeg_arr[idx]   = 0;         else { NodeDeg_arr.Add(0);           NodeDeg_qty++;   }
   Nodes_qty++;
   DSU_dirty = true;
   return idx;
}

function AddForceLink(int a, int b){
   ForceLocA.Add(NodeLoc_arr[a]); ForceLocA_qty = ForceLocA_qty + 1;
   ForceLocB.Add(NodeLoc_arr[b]); ForceLocB_qty = ForceLocB_qty + 1;
}

function int ForceAddEdge(int a, int b){
   local int e;
   if (Edges_qty >= MAX_EDGES) return -1;
   if (a < 0 || b < 0 || a >= Nodes_qty || b >= Nodes_qty) return -1;
   e = AppendEdge(a, b, VSize(NodeLoc_arr[a] - NodeLoc_arr[b]));
   if (e < 0) return -1;
   SetEdgeForce(e, 1);
   NodeDeg_arr[a] = NodeDeg_arr[a] + 1;
   NodeDeg_arr[b] = NodeDeg_arr[b] + 1;
   return e;
}

function int FindNearestNode(vector loc){
   local int i, best;
   local float bestD, d;
   best = -1; bestD = 100000000.0;
   for (i = 0; i < Nodes_qty; i++){
      d = VSize(NodeLoc_arr[i] - loc);
      if (d < bestD){ bestD = d; best = i; }
   }
   return best;
}

function int FindNearestGreenNode(vector loc){
   local int i, best;
   local float bestD, d;
   local PathNode pn;
   best = -1;
   bestD = 100000000.0;
   for (i = 0; i < Nodes_qty; i++){
      pn = PathNode(NodeActor_arr[i]);
      if (pn != None && pn.bHiddenEd) continue;      // skip disabled nodes
      d = VSize(NodeLoc_arr[i] - loc);
      if (d < bestD){ bestD = d; best = i; }
   }
   return best;
}

function ApplyForceLinks(){
   local int k, a, b;
   for (k = 0; k < ForceLocA_qty; k++){
      a = FindNearestNode(ForceLocA[k]);
      b = FindNearestNode(ForceLocB[k]);
      if (a >= 0 && b >= 0 && a != b) ForceAddEdge(a, b);
   }
}
