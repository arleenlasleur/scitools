class RtNavBuilder extends weapon;
// todo dpn alter

var string b64_enc;   // base64 codepage for encoder

var STLaserBlast laserdot;
var mover sens_mov;                  // sensed mover for controlling
var float water_forcedodge_timer;    // fd related
var bool  wforcedodge_ready;
var int forcedodge_xdir,forcedodge_ydir;
var playerpawn p;                    // owner
var stvs topview_cam;
var bool ena_topview;
var bool ena_warpnode;
var bool ena_edgenums;
var bool ctl_topview_pitch;          // control elevation if false, pitch if true
var rotator topview_addrot;
var float topview_addz;

var bool  bMarkMode;
var int   Mark_prev;          // index in Graph/MarkGraph (common node), -1 if not init
var int   Mark_target;        // current future pathnode (aka next), -1 if not selected
var float Mark_radius;        // 1200
var int   Mark_angle;         // search target FOV
var float Mark_arriveDist;    // touch radius to perform graph write

var pathnode pnr_last;
var float next_scan;

var stinvfontinfo inv_finfo;
var HUD oldHUD;
var class<HUD> oldHUDType;

var int  LinkSrc, LinkDest;      // index in graph, -1 if not locked

var RtNavGraph Graph;
var RtNavGraph MarkGraph;
var RtNavData  DataActor;
var bool   BuildActive;      // true if writing to base graph
var int    BuildPhase;    // 0=collect, 1=edges, 2=csr, 3=done
var int    Build_i;
var int    BuildDx, BuildDy, BuildBucketIdx;  // phase 1 state
var float  BuildStartTime, BuildEndTime;    // stats
var int    BuildTicks;
var bool   bShowNav;   // render related
var string NavMsg;
var float  NavMsgTimer;
var() int  BudgetPerTick;
var int    MarkComponentsQty;

var color pc_wh,pc_gray,pc_grn,pc_red,pc_yel,pc_acy,pc_blue,pc_pink;

exec function s(){
   navbuild();
}

exec function ex(){
   navexport();
}

exec function sci_warpgrab(){
   ena_warpnode = !ena_warpnode;
}

exec function sci_edgenumbers(){
   ena_edgenums = !ena_edgenums;
}

exec function sci_spawn_pnruntime(){
   local PathNodeRuntime pn;
   local int idx;
   if(p == None)                                                             return;
   EnsureMarkGraph();
   if(MarkGraph == None){
      NavMsg = "MarkGraph not ready";                     NavMsgTimer = 2.0; return; }
   if(MarkGraph.Nodes_qty >= MarkGraph.MAX_NODES){
      NavMsg = "MarkGraph: node limit";                   NavMsgTimer = 2.0; return; }
   if(Graph.Nodes_qty == 0){
      NavMsg = "Full graph required. Call st() first.";   NavMsgTimer = 4.0; return; }
   pn = Spawn(Class'PathNodeRuntime',,, p.Location + vector(p.Rotation)*96.0); // todo adj
   if (pn == None){ NavMsg = "spawn failed";             NavMsgTimer = 2.0; return; }
   idx = MarkGraph.AddNode(pn, pn.Location, MarkGraph.CM_IGNOREZ, 2400.0);
   if (idx < 0){
      NavMsg = "MarkGraph: AddNode failed"; pn.Destroy(); NavMsgTimer = 2.0; return; }
   MarkGraph.DSU_Dirty = True;
   NavMsg = "Spawned PathNodeRuntime: idx="$idx$", MarkGraph nodes="$MarkGraph.Nodes_qty;
   NavMsgTimer = 2.0;
}

exec function sci_tog_topview(){
   if(p==none || topview_cam==none) return;
   ena_topview = !ena_topview;
   p.viewtarget = ena_topview ? topview_cam : none;
}

exec function sci_tog_topviewpitch(){
   ctl_topview_pitch = !ctl_topview_pitch;
}

exec function ctl_cam_down(){
   if(!ena_topview) goto ctl_mover_dn;
   if(ctl_topview_pitch) goto ctl_pitch_dn;
   if(topview_addz<8192) topview_addz+=40;
   return;
   ctl_pitch_dn:
   topview_addrot.pitch -= 320;
   return;
   ctl_mover_dn:
}

exec function ctl_cam_up(){
   if(!ena_topview) goto ctl_mover_up;
   if(ctl_topview_pitch) goto ctl_pitch_up;
   if(topview_addz>80) topview_addz-=40;
   return;
   ctl_pitch_up:
   topview_addrot.pitch += 320;
   return;
   ctl_mover_up:
}

exec function sci_mark_toggle(){
   bMarkMode = !bMarkMode;
   if (bMarkMode){
      if (Graph == None || Graph.Nodes_qty == 0){
         bMarkMode = False;
         NavMsg = "Full graph required. Execute navbuild() first.";
         NavMsgTimer = 4.0; return;
      }
      EnsureMarkGraph();
      Mark_prev = -1;
      Mark_target = -1;
      NavMsg = "Mark mode: WRITE";
   }else
      NavMsg = "Mark mode: UNDO, edges="$MarkGraph.Edges_qty;
   NavMsgTimer = 3.0;
}

exec function sci_mark_undo(){
   local int a, b, n;
// if (bMarkMode) return; already checked in altfire
   if (MarkGraph == None || MarkGraph.Edges_qty == 0){
      NavMsg = "Mark: nothing to undo"; NavMsgTimer = 2.0; return;
   }
   n = MarkGraph.Edges_qty - 1;
   a = MarkGraph.GetEdgeA(n);
   b = MarkGraph.GetEdgeB(n);
   if (!MarkGraph.PopLastEdge()) return;
          MarkGraph.NodeDeg_arr[a] = Max(0, MarkGraph.NodeDeg_arr[a] - 1); // new code
          MarkGraph.NodeDeg_arr[b] = Max(0, MarkGraph.NodeDeg_arr[b] - 1);
          MarkDSU_Revalidate();
          MarkComponentsQty = CountGraphComponents(False);
   Mark_prev   = a;        // focused to begin of deleted edge
   NavMsg = "Mark: edge -1 (undo), total="$MarkGraph.Edges_qty;
   NavMsgTimer = 2.0;
}

function EnsureMarkGraph(){
   local int i, j;
   if (DataActor == None) return;   // spawn failed
   if (DataActor.MarkGraph == None){
      DataActor.MarkGraph = new(Self) Class'RtNavGraph';
      MarkGraph = DataActor.MarkGraph;
      j = (Graph != None) ? Graph.Nodes_qty : 0;
      for (i = 0; i < j; i++)
         MarkGraph.AddNode(Graph.NodeActor_arr[i], Graph.NodeLoc_arr[i],
                           Graph.NodeMode_arr[i], Graph.NodeParam_arr[i]);
      MarkGraph.DSU_Root  = -1;
      MarkGraph.DSU_Dirty = True;
      MarkGraph.DSU_EdgeMain_qty = 0;
      MarkGraph.DSU_Rebuild();
   }else
      MarkGraph = DataActor.MarkGraph;
}

exec function sci_mark_clear(){
   if (MarkGraph != None) MarkGraph.Edges_qty = 0;
   MarkDSU_Revalidate();
   Mark_prev = -1;
   Mark_target = -1;
   NavMsg = "Mark graph cleared";
   NavMsgTimer = 3.0;
}

function TickMark(float dt){
   local PathNode pn;
   local int   idx, best_j;
   local float bestD, d;
   local vector targetLoc;
   if (p == None) return;
   if (MarkGraph == None || MarkGraph.Nodes_qty == 0) return;
   // prev tracking: automatic, position-based, independent of motion
   if(MarkGraph.Edges_qty>0){               // after first edge prev MUST be a graph node
      if(Mark_prev<0 || Mark_prev>=MarkGraph.Nodes_qty){
//       Mark_prev = MarkGraph.FindNearestNode(p.Location);
         Mark_prev = MarkGraph.FindNearestGreenNode(p.Location);  
         Mark_target = -1;
      }
      // re-bind: if player left arriveDist of current prev AND strictly closer node
      // is within Mark_radius -> move prev to nearest
      if(Mark_prev>0 && VSize(p.Location -MarkGraph.NodeLoc_arr[Mark_prev]) > Mark_arriveDist){
//       idx = MarkGraph.FindNearestNode(p.Location);
         idx = MarkGraph.FindNearestGreenNode(p.Location);  
         if (idx>=0 && idx!=Mark_prev && VSize(p.Location -MarkGraph.NodeLoc_arr[idx]) < Mark_radius){
            Mark_prev = idx;
            Mark_target = -1;
         }
      }
   }else{
      if(Mark_prev < 0 || Mark_prev >= MarkGraph.Nodes_qty){     // no edges yet: soft init, radius gate kept
//       idx = MarkGraph.FindNearestNode(p.Location);
         idx = MarkGraph.FindNearestGreenNode(p.Location);  
         if (idx < 0) return;
         if (VSize(p.Location - MarkGraph.NodeLoc_arr[idx]) > Mark_radius) return;
         Mark_prev = idx;
         Mark_target = -1;
      }
   }
   
   if(laserdot != None)
        targetLoc = laserdot.Location;
   else targetLoc = p.Location + vector(p.ViewRotation) * Mark_radius;
   
   bestD = Mark_radius;
   best_j = -1;
   foreach RadiusActors(Class'PathNode', pn, Mark_radius, p.Location){
      idx = GraphFindNodeByActorMark(pn);
      if (idx < 0 || idx == Mark_prev) continue;
      if (pn.bEdShouldSnap) continue;
      d = VSize(MarkGraph.NodeLoc_arr[idx] - targetLoc);
      if (d < 0.01) continue;
      if (d < bestD){ bestD = d; best_j = idx; }
   }
   Mark_target = best_j;     // -1 if none in radius
}

function int GraphFindNodeByActorMark(Actor a){
   local int i;
   for(i=0; i<MarkGraph.Nodes_qty; i++)
      if(MarkGraph.NodeActor_arr[i] == a) return i;
   return -1;
}

function int GraphFindNodeByName(name nm){
   local int i;
   for(i=0; i<Graph.Nodes_qty; i++)
      if(Graph.NodeActor_arr[i] != None && Graph.NodeActor_arr[i].Name == nm) return i;
   return -1;
}

function int GraphFindNodeByActor(Actor a){
   local int i;
   for(i=0; i<Graph.Nodes_qty; i++)
      if(Graph.NodeActor_arr[i] == a) return i;
   return -1;
}

function int NearestNodeToPlayer(){
   local PathNode pn, best;
   local float d, bestD;
   if (p == None) return -1;
   bestD = 192.0;
   foreach RadiusActors(Class'PathNode', pn, 192, p.Location){
      d = VSize(p.Location - pn.Location);
      if (d < bestD){ bestD = d; best = pn; }
   }
   if (best == None) return -1;
   return GraphFindNodeByActor(best);
}

exec function navbuild(){
   local int i;
   Graph.Nodes_qty = 0;  // resets
   Graph.Edges_qty = 0;
   for(i=0; i<Graph.EdgeA_qty; i++) Graph.EdgeA[i].Data_qty = 0;     // reset chunk data
   for(i=0; i<Graph.EdgeB_qty; i++) Graph.EdgeB[i].Data_qty = 0;
   for(i=0; i<Graph.EdgeCost_qty; i++) Graph.EdgeCost[i].Data_qty = 0;
   for(i=0; i<Graph.EdgeForce_qty; i++) Graph.EdgeForce[i].Data_qty = 0;
   Graph.Trace_calls_qty = 0;
   Graph.Trace_hits_qty = 0;
   Graph.CurrentStamp = 0;
   Graph.DSU_Dirty = True;
   Graph.DSU_Root = -1;
   Graph.DSU_EdgeMain_qty = 0;   // todo mb MarkGraph only
   Graph.ForceLocA_qty = 0;
   Graph.ForceLocB_qty = 0;
   BuildActive = True;   // starts
   BuildPhase = 0;
   Build_i = 0;
   BuildDx = -3;      // begin new i, ensure out of -2..2 bounds
   BuildDy = 0;
   BuildBucketIdx = 0;
   BuildTicks = 0;
   BuildStartTime = Level.TimeSeconds;
   bShowNav = True;
   NavMsg = "Nav build started...";
   NavMsgTimer = 5.0;
}

function MarkDSU_Revalidate(){ // force markgraph connectivity update
   if (MarkGraph == None) return;
   MarkGraph.DSU_Dirty = True;
   MarkGraph.DSU_Rebuild();
}

function DrawBox(Canvas C, vector l, color pc){
   c.draw3dline(pc,l+vect(-8,-8,-8),l+vect( 8,-8,-8));
   c.draw3dline(pc,l+vect( 8,-8,-8),l+vect( 8, 8,-8));
   c.draw3dline(pc,l+vect( 8, 8,-8),l+vect(-8, 8,-8));
   c.draw3dline(pc,l+vect(-8, 8,-8),l+vect(-8,-8,-8));
   c.draw3dline(pc,l+vect(-8,-8, 8),l+vect( 8,-8, 8));
   c.draw3dline(pc,l+vect( 8,-8, 8),l+vect( 8, 8, 8));
   c.draw3dline(pc,l+vect( 8, 8, 8),l+vect(-8, 8, 8));
   c.draw3dline(pc,l+vect(-8, 8, 8),l+vect(-8,-8, 8));
   c.draw3dline(pc,l+vect(-8,-8,-8),l+vect(-8,-8, 8));
   c.draw3dline(pc,l+vect( 8,-8,-8),l+vect( 8,-8, 8));
   c.draw3dline(pc,l+vect( 8, 8,-8),l+vect( 8, 8, 8));
   c.draw3dline(pc,l+vect(-8, 8,-8),l+vect(-8, 8, 8));
}

function fire(float f){   // open by mover
   if(p==none || sens_mov==none) return;
   sens_mov.trigger(p,p.instigator);
}

function altfire(float f){
   if(!bMarkMode){                                         sci_mark_undo();                     return; }
   if(MarkGraph==none || MarkGraph.Nodes_qty==0 || p==None)                                     return;
   if(Mark_prev<0 || Mark_prev>=MarkGraph.Nodes_qty){
      NavMsg = "Mark: no prev";                            NavMsgTimer = 1.5;                   return; }
   if(Mark_target<0 || Mark_target>=MarkGraph.Nodes_qty || Mark_target==Mark_prev){
      NavMsg = "Mark: no target";                          NavMsgTimer = 1.5;                   return; }
   if(MarkGraph.FindEdge(Mark_prev, Mark_target)>=0){
      NavMsg = "Mark: edge already exists";                NavMsgTimer = 1.5; Mark_target = -1; return; }
   if(MarkGraph.AppendEdge(Mark_prev, Mark_target,
        VSize(MarkGraph.NodeLoc_arr[Mark_target] - MarkGraph.NodeLoc_arr[Mark_prev])) < 0){
      NavMsg = "Mark: append failed";                      NavMsgTimer = 1.5;                   return; }
   MarkGraph.NodeDeg_arr[Mark_prev]++;
   MarkGraph.NodeDeg_arr[Mark_target]++;
   MarkDSU_Revalidate();
   MarkComponentsQty = CountGraphComponents(False);
   Mark_target = -1;
   NavMsg    = "Mark: edge +1, total="$MarkGraph.Edges_qty;
   NavMsgTimer = 1.5;
}

function NavLink_Toggle(){
   local int a, b, e, existing;
   if(LinkSrc<0 || LinkDest<0){
      NavMsg = "Nav link: pick SRC (LMB) and DEST (RMB)";  NavMsgTimer = 4.0;                   return; }
   if(LinkSrc==LinkDest){
      NavMsg = "Nav link: src == dest";                    NavMsgTimer = 3.0;                   return; }
   a = LinkSrc; b = LinkDest;
   existing = -1;  // search existing edge
   for (e = 0; e < Graph.Edges_qty; e++){
      if( (Graph.GetEdgeA(e) == a && Graph.GetEdgeB(e) == b) ||
          (Graph.GetEdgeA(e) == b && Graph.GetEdgeB(e) == a)){
         existing = e; break;
      }
   }
   if (existing>=0){                // break this edge
      Graph.SetEdgeForce(existing, 0);
      NavMsg = "Nav link: removed "$a$" <-> "$b; // still exist as EdgeA/B before rebuild - hide by EdgeOpt
   } else {
      Graph.ForceAddEdge(a, b);      // force create
      Graph.AddForceLink(a, b);      // add to table for rebuild
      NavMsg = "Nav link: forced "$a$" <-> "$b;
   }
   NavMsgTimer = 5.0;
}

function bool ValidateMarkEdge(int i, int j){  // strict checks same as TryAddEdge
   local float dz, dist;
   local vector a, b;
   local int mi, mj, k;
   local vector nrm, off;

   if(i<0 || j<0 || i>=MarkGraph.Nodes_qty || j>=MarkGraph.Nodes_qty) return False;

   a = MarkGraph.NodeLoc_arr[i];
   b = MarkGraph.NodeLoc_arr[j];
   dz = a.Z - b.Z; if (dz < 0) dz = -dz;
   if(dz > Graph.MAX_DZ) return False;

   mi = MarkGraph.NodeMode_arr[i];
   mj = MarkGraph.NodeMode_arr[j];
   dist = VSize(a - b);

   if(mi == Graph.CM_STANDARD && mj == Graph.CM_STANDARD){  // std-std edge: max 1200, 4 offset attempts
      if (dist > 1200.0) return False;
      if (FastTrace(b, a)) return True;
      nrm = Normal(b - a);
      off.X = -nrm.Y; off.Y = nrm.X; off.Z = 0.0;
      off = Normal(off);
      for (k = 1; k <= 4; k++)
         if (FastTrace(b + off*(16.0*k), a + off*(16.0*k))) return True;
      return False;
   }
      if (mi != Graph.CM_STANDARD && CheckSpecialMark(i, j)) return True;  // any-special edge: check by i mode
      if (mj != Graph.CM_STANDARD && CheckSpecialMark(j, i)) return True;  // then by j mode
      return False;
}

function bool CheckSpecialMark(int i, int j){
   local vector a, b, pa, pb;
   local float  dxy, param;
   a = MarkGraph.NodeLoc_arr[i]; b = MarkGraph.NodeLoc_arr[j];
   param = MarkGraph.NodeParam_arr[i];
   pa = a-b; pa.z = 0; dxy = VSize(pa);
   switch(MarkGraph.NodeMode_arr[i]){
      case MarkGraph.CM_IGNOREZ:
         if (dxy > param) return False;
         pa = a; pb = b; pa.Z = (a.Z+b.Z)*0.5; pb.Z = pa.Z;
         return FastTrace(pb, pa);
      case MarkGraph.CM_SHAFT:
         if (dxy > param) return False;
         pb = b; pb.X = a.X; pb.Y = a.Y;
         return FastTrace(pb, a);
      case MarkGraph.CM_ANYRANGE:
         return VSize(a - b) <= param;
   }
   return False;
}

function int CountGraphComponents(bool use_all_nodes){  // BFS by CSR; ret -1 if empty graph, 0 if no edges
   local int i, n, e, a, b, comp, k, nb, cur, qhead;    // full 100% connected graph must render this as 1
   local array<int>  adj, start, cursor, queue;         // called after edges change
   local array<bool> seen;
   if (MarkGraph == None || MarkGraph.Nodes_qty <= 0) return -1;
   n = MarkGraph.Nodes_qty;

   start.setsize(n+1);                        // CSR start[], power -> prefix
   for (i = 0; i <= n; i++) start[i] = 0;
   for (e = 0; e < MarkGraph.Edges_qty; e++){
      a = MarkGraph.GetEdgeA(e);
      b = MarkGraph.GetEdgeB(e);
      if (a >= 0 && a < n) start[a + 1] = start[a + 1] + 1;
      if (b >= 0 && b < n) start[b + 1] = start[b + 1] + 1;
   }
   for (i = 1; i <= n; i++) start[i] = start[i] + start[i - 1];
   adj.setsize(start[n]);                     // CSR adj[] neighbors
   cursor = start;
   for (e = 0; e < MarkGraph.Edges_qty; e++){
      a = MarkGraph.GetEdgeA(e);
      b = MarkGraph.GetEdgeB(e);
      if (a >= 0 && a < n){ adj[cursor[a]] = b; cursor[a] = cursor[a] + 1; }
      if (b >= 0 && b < n){ adj[cursor[b]] = a; cursor[b] = cursor[b] + 1; }
   }
   seen.setsize(n);                           // BFS by components
   for (i = 0; i < n; i++) seen[i] = False;
   comp = 0;

   for (i = 0; i < n; i++){
      if (seen[i]) continue;
      if (!use_all_nodes && start[i + 1] == start[i]) continue;  // obey useall for isolated nodes
      comp = comp + 1;
      queue.setsize(0);
      queue.Add(i);
      seen[i] = True;
      qhead = 0;
      while (qhead < queue.size()){
         cur = queue[qhead];
         qhead = qhead + 1;
         for (k = start[cur]; k < start[cur + 1]; k++){
            nb = adj[k];
            if (!seen[nb]){
               seen[nb] = True;
               queue.Add(nb);
            }
         }
      }
   }
   return comp;
}

function do_tick_scan_rssi(float f){  // acquire pathnode by owner position
   local pathnode pn,pn_act;
   local float dist,dist_act;
   if(p == none) return;
   if(p.weapon != self) return;
   next_scan -= f;
   if(next_scan > 0) return;
   next_scan = 0.1;
   dist_act = 129.0;
   foreach radiusactors(class'pathnode',pn,128){
      dist = vsize(p.location - pn.location);
      if(dist < dist_act){
         dist_act = dist;
         pn_act = pn;
      }
   }
   if(pn_act==none && pn!=none) pn_act = pn;
   if(pn_act==none) return;
   pnr_last = pn_act;
}

exec function sci_toggle_hiddened(){
   if (p==None || pnr_last==none) return;
   pnr_last.bEdShouldSnap = !pnr_last.bEdShouldSnap;
}

simulated function Tick(float f){
   local vector hl,hn, x,y,z;
   local float lasermult, laserdist;
   local pawn pt;
   local playerpawn pp;
   local rotator r;
   if(owner == none) return;
   if(p!=none) goto skip_already_has_p;
   pp = playerpawn(owner);
   if(pp == none) return;
   p = pp;
 skip_already_has_p:
   if(topview_cam!=none){
      r = p.viewrotation;
      r.pitch = topview_addrot.pitch;
      r.roll = 0;
      topview_cam.setrotation(r);
      x = p.location;
      x.z += topview_addz;
      topview_cam.setlocation(x);
   }
   p.health = 5000;                                 // prevent drown death
   if(p.velocity.z <= -900) p.velocity.z = -900;   // prevent fall death
   water_forcedodge_timer -= f;                    // water forcedodge process
   if(water_forcedodge_timer < 0.0){
      wforcedodge_ready = true;
      p.waterspeed = 200;
   }     laserdist = 0.0;                         // safe to use this
   for(pt=level.pawnlist; pt!=none; pt=pt.nextpawn) // autokill unaggro process, for crashsite2 marines
      if(pt.enemy == p){
         pt.enemy = none;
         laserdist = 1.0;
      }
   if(laserdist>0.0) p.consolecommand("killpawns"); // exec this only one time, not for each matching pawn
   getaxes(p.viewrotation,x,y,z);
   sens_mov = mover(trace(hl,hn,p.location + 4000*x,p.location,true));
   hl -= x*2;
   if(laserdot!=none) laserdot.setlocation(hl);
   laserdist = vsize(p.location - hl);
   lasermult=fclamp(laserdist/2800,-0.3,1.3);
   lasermult+=1;
   if(laserdist>2800) lasermult+=1;
   if(laserdist>5600) lasermult+=1;
   LaserDot.drawscale=lasermult;
   do_tick_scan_rssi(f);
   if( BuildActive) BuildStep();
   if( bMarkMode)   TickMark(f);
   if(NavMsgTimer > 0.0) NavMsgTimer -= f;
}

function BuildStep(){
   BuildTicks++;
   switch(BuildPhase){
   case 0: BuildStep_Collect(); return;
   case 1: BuildStep_Edges(); return;
   }
}

function BuildStep_Collect(){    // phase 0
   local PathNode pn;
   local int   mode;
   local float param;
   foreach AllActors(Class'PathNode', pn){
      if (pn.isa('PathNodeRuntime')){
         mode  = Graph.CM_IGNOREZ;
         param = 2400.0;
      } else {
         mode  = Graph.CM_STANDARD;
         param = 1200.0;
      }
      if (Graph.AddNode(pn, pn.Location, mode, param) < 0) break;
   }

   NavMsg = "Nav: collected "$Graph.Nodes_qty$" nodes";
   NavMsgTimer = 3.0;
   log("NAV: collected "$Graph.Nodes_qty$" nodes", 'AMS');

   BuildStep_BucketInit();
   Build_i = 0;
   BuildDx = -3;
   BuildDy = 0;
   BuildBucketIdx = 0;
   BuildPhase = 1;
}

function BuildStep_BucketInit(){
   local int i;
   Graph.InitBuckets();
   for (i = 0; i < Graph.Nodes_qty; i++){
      Graph.BucketAdd(i);
      if (i < Graph.SeenStamp_qty) Graph.SeenStamp[i] = 0;
      else { Graph.SeenStamp.Add(0); Graph.SeenStamp_qty = Graph.SeenStamp_qty + 1; }
   }
   Graph.CurrentStamp = 0;
}

function BuildStep_Edges(){                // phase 1
   local int budget, i, j, b, n, dx, dy;
   local string ts;
   budget = BudgetPerTick;
   while (budget > 0 && Build_i < Graph.Nodes_qty){
      i = Build_i;
      if (BuildDx == -3){
         Graph.CurrentStamp = Graph.CurrentStamp + 1;
         Graph.BuildCx = int(Graph.NodeLoc_arr[i].X / Graph.CELL);
         Graph.BuildCy = int(Graph.NodeLoc_arr[i].Y / Graph.CELL);
         BuildDx = -2; BuildDy = -2; BuildBucketIdx = 0;   // 5x5 bucket
      }
      dx = BuildDx; dy = BuildDy;
      b = Graph.HashCell(Graph.BuildCx + dx, Graph.BuildCy + dy);
      n = Graph.NavBuckets[b].Items_qty;
      while (budget > 0 && BuildBucketIdx < n){
         budget--;
         j = Graph.NavBuckets[b].Items[BuildBucketIdx];
         BuildBucketIdx++;
         if (j <= i) continue;
         if (!Graph.MarkSeen(j)) continue;
         TryAddEdge(i, j);
      }
      if (BuildBucketIdx >= n){
         BuildBucketIdx = 0;
         BuildDy++;
         if (BuildDy > 2){ BuildDy = -2; BuildDx++; }
         if (BuildDx > 2){
            Build_i++;
            BuildDx = -3;      // set new i
         }
      }
   }
   if (Build_i >= Graph.Nodes_qty){
      Graph.ApplyForceLinks();
      BuildActive = False;  // terminate
      BuildEndTime = Level.TimeSeconds;
      NavMsg = "Nav done: "$Graph.Nodes_qty$" nodes, "$Graph.Edges_qty$" edges, "$int(BuildEndTime-BuildStartTime)$"s";
      NavMsgTimer = 15.0;
      log("NAV BUILD: nodes="$Graph.Nodes_qty$" edges="$Graph.Edges_qty$" traces="$Graph.Trace_calls_qty$" hits="$Graph.Trace_hits_qty$" ticks="$BuildTicks$" time="$int(BuildEndTime-BuildStartTime), 'AMS');
   }
   if (Graph.Nodes_qty > 0){
      i = int(100.0 * Build_i / Graph.Nodes_qty);
      j = int(70.0  * Build_i / Graph.Nodes_qty);
      ts = "[";  for(b=0;b<j;b++)  ts $= "#";
                 for(b=j;b<70;b++) ts $= " ";  ts $= "] ";
      NavMsg = "Nav edges: "$ ts $ i $"%";
   }else
      NavMsg = "Nav edges: "$Graph.Edges_qty;
   NavMsgTimer = 2.0;
}

function bool CanConnect(int i, int j){  // link rules
   local int mi, mj;
   mi = Graph.NodeMode_arr[i];
   mj = Graph.NodeMode_arr[j];
   if (mi == Graph.CM_STANDARD && mj == Graph.CM_STANDARD)
      return CheckStandard(i, j);
   if (mi != Graph.CM_STANDARD && CheckSpecial(i, j)) return True;
   if (mj != Graph.CM_STANDARD && CheckSpecial(j, i)) return True;
   return False;
}

function bool CheckStandard(int i, int j){
   local vector a, b, nrm, off;
   local bool   free;
   local int    k;
   a = Graph.NodeLoc_arr[i];
   b = Graph.NodeLoc_arr[j];
   if (VSize(a - b) > 1200.0) return False;
   Graph.Trace_calls_qty = Graph.Trace_calls_qty + 1;
   free = FastTrace(b, a);
   if (free){ Graph.Trace_hits_qty = Graph.Trace_hits_qty + 1; return True; }
   nrm = Normal(b - a);
   off.X = -nrm.Y; off.Y = nrm.X; off.Z = 0.0;
   off = Normal(off);
   for (k = 1; k <= 4; k++){  // AER-like attempts
      Graph.Trace_calls_qty = Graph.Trace_calls_qty + 1;
      free = FastTrace(b + off * (16.0 * k), a + off * (16.0 * k));
      if (free){ Graph.Trace_hits_qty = Graph.Trace_hits_qty + 1; return True; }
   }
   return False;
}

function bool CheckSpecial(int i, int j){
   local vector a, b, pa, pb;
   local float  dxy, param;
   local bool   free;
   a     = Graph.NodeLoc_arr[i];
   b     = Graph.NodeLoc_arr[j];
   param = Graph.NodeParam_arr[i];
   pa = a-b;
   pa.z = 0;
   dxy = VSize(pa);
   switch (Graph.NodeMode_arr[i]){
      case Graph.CM_IGNOREZ:
         if (dxy > param) return False;
         pa = a; pb = b;
         pa.Z = (a.Z + b.Z) * 0.5;
         pb.Z = pa.Z;
         Graph.Trace_calls_qty = Graph.Trace_calls_qty + 1;
         free = FastTrace(pb, pa);
         if (free){ Graph.Trace_hits_qty = Graph.Trace_hits_qty + 1; return True; }
         return False;
      case Graph.CM_SHAFT:
         if (dxy > param) return False;
         pb = b; pb.X = a.X; pb.Y = a.Y;
         Graph.Trace_calls_qty = Graph.Trace_calls_qty + 1;
         free = FastTrace(pb, a);
         if (free){ Graph.Trace_hits_qty = Graph.Trace_hits_qty + 1; return True; }
         return False;
      case Graph.CM_ANYRANGE:
         return VSize(a - b) <= param;
   }
   return False;
}

function bool TryAddEdge(int i, int j){
   local float dz;
   if (Graph.Edges_qty >= Graph.MAX_EDGES) return False;
   if (Graph.NodeDeg_arr[i] >= Graph.MAX_DEGREE) return False;
   if (Graph.NodeDeg_arr[j] >= Graph.MAX_DEGREE) return False;

   dz = Graph.NodeLoc_arr[i].Z - Graph.NodeLoc_arr[j].Z;
   if (dz < 0) dz = -dz;
   if (dz > Graph.MAX_DZ) return False;
   if (!CanConnect(i, j)) return False;
   Graph.AppendEdge(i, j, VSize(Graph.NodeLoc_arr[i] - Graph.NodeLoc_arr[j]));
   Graph.NodeDeg_arr[i] = Graph.NodeDeg_arr[i] + 1;
   Graph.NodeDeg_arr[j] = Graph.NodeDeg_arr[j] + 1;
   return True;
}

function PostRender(Canvas C){
   local int i, e, j;
   local color pc;
   local pathnode pn;
   local vector l;
   local string s;
   if(p == none) return;
   if(inv_finfo==none) return;
   c.font = inv_finfo.GetInvFont();
   if (NavMsgTimer > 0.0){
      c.setpos(10, c.clipy -39);
      c.drawtext(navmsg);
   }
   c.drawcolor = pc_grn;
      c.setpos(4, 4);      c.drawtext("Mouse");
      c.setpos(660, 4);    c.drawtext("Alt/+WASD");
      c.setpos(1176, 4);   c.drawtext("Ctrl/G");
      c.setpos(1604, 4);   c.drawtext("Shft");
      c.setpos(4, 33);     c.drawtext("B");
      c.setpos(660, 33);   c.drawtext("N");
   
   c.drawcolor = pc_wh;
   s = bMarkMode ? "add path" : "delete last";
      c.setpos(84, 4);    c.drawtext(": open mover/add node/"$s);
   s = ctl_topview_pitch ? "z [ptch]" : "[z] ptch";
      c.setpos(804, 4);    c.drawtext(": edge mode/fastjump");
      c.setpos(1272, 4);   c.drawtext(": topcam: " $s);
      c.setpos(1668, 4);   c.drawtext(": ignore");
   if(!ena_warpnode){
      s =                                       "normal";
   }else{
      s = (int(level.timeseconds/0.2) % 2)==0 ? "warpzone" : "        ";
   }  c.setpos(20, 33);    c.drawtext(": node grab: "$s$ " (src: "$Mark_prev$ " dst: "$Mark_target$")");
      c.setpos(676, 33);   c.drawtext(": edge numbers");

   c.drawcolor = pc_acy;
      c.setpos(1450, 989);  c.drawtext("N: " $MarkGraph.Nodes_qty$ "/" $MarkGraph.MAX_NODES);
   c.drawcolor = pc_wh;
      c.setpos(1450, 1018); c.drawtext("E: " $MarkGraph.Edges_qty$ "/16384");
   if (MarkComponentsQty==1)    s = "(ok)";
   else{
      s = (int(level.timeseconds/0.3) % 2)==0 ? "(broken)" : " ";
      if (MarkComponentsQty<=0) s = "(empty)";
   }  c.setpos(1450, 1047); c.drawtext("C: "$s);
      c.setpos(1450+256, 989);  c.drawtext(Graph.Nodes_qty$ "/" $Graph.MAX_NODES);
      c.setpos(1450+256, 1018); c.drawtext(Graph.Edges_qty$ "/" $Graph.MAX_EDGES);
      c.setpos(1450+256, 1047); c.drawtext(MarkComponentsQty);

   if (!bShowNav || Graph==none || Graph.Nodes_qty<=0) goto skip_no_nav_data;
      for (i = 0; i < Graph.Edges_qty; i++){             // full: under feet
         e = Graph.GetEdgeA(i); j = Graph.GetEdgeB(i);
         c.Draw3DLine(pc_blue, Graph.NodeLoc_arr[e] -vect(0,0,46), Graph.NodeLoc_arr[j] - vect(0,0,46));
      }
   if (MarkGraph != None && MarkGraph.Edges_qty > 0){    // marked
      if (MarkGraph.DSU_Dirty) MarkDSU_Revalidate();      // grant before render fallback
      for (i = 0; i < MarkGraph.Edges_qty; i++){
         e = MarkGraph.GetEdgeA(i); j = MarkGraph.GetEdgeB(i);
         switch (MarkGraph.DSU_EdgeMain[i]){
            case 2:  pc = pc_wh;  break;  // WHITE  = root comp (edges[0])
            case 1:  pc = pc_yel; break;  // YELLOW = cluster (>=2 edges)
            default: pc = pc_red; break;  // RED    = stray (1 edge)
         }
         c.Draw3DLine(pc, MarkGraph.NodeLoc_arr[e], MarkGraph.NodeLoc_arr[j]);
         c.Draw3DLine(pc, MarkGraph.NodeLoc_arr[j] +vect(0,0,-3), MarkGraph.NodeLoc_arr[j] +vect(0,0,+2)); // node marker
      }
   }
   if (MarkGraph != None && bMarkMode && Mark_prev >= 0 && Mark_prev < MarkGraph.Nodes_qty &&     // future edge preview
       Mark_target >= 0 && Mark_target < MarkGraph.Nodes_qty){
      c.Draw3DLine(pc_pink, MarkGraph.NodeLoc_arr[Mark_prev] -vect(0,0,1), MarkGraph.NodeLoc_arr[Mark_target] -vect(0,0,1));
      c.Draw3DLine(pc_pink, MarkGraph.NodeLoc_arr[Mark_target],            MarkGraph.NodeLoc_arr[Mark_target] -vect(0,0,48));
      c.Draw3DLine(pc_pink, MarkGraph.NodeLoc_arr[Mark_prev],              MarkGraph.NodeLoc_arr[Mark_prev]   -vect(0,0,48));
      c.Draw3DLine(pc_pink, MarkGraph.NodeLoc_arr[Mark_prev] -vect(1,1,0), MarkGraph.NodeLoc_arr[Mark_prev]   -vect(1,1,48));
   }
  skip_no_nav_data:
   foreach RadiusActors( class'pathnode', pn, 2048.0){
      if(pn==pnr_last) DrawBox(c, pn.location, pc_wh);
      i = bool(pathnoderuntime(pn)) ? 1 : 0;
      l = pn.location - vect(0,0,46);
      if(pn.bEdShouldSnap)
           pc = pc_red;  // disabled
      else pc = pc_grn;  // enabled
      c.Draw3DLine(pc, l+vect(-5,+5,0), l+vect(+5,+5,0));
      c.Draw3DLine(pc, l+vect(-5,-5,0), l+vect(+5,-5,0));
      c.Draw3DLine(pc, l+vect(-5,-5,0), l+vect(-5,+5,0));
      c.Draw3DLine(pc, l+vect(+5,-5,0), l+vect(+5,+5,0));
      c.Draw3DLine(pc, l+vect(-5,-5,0), l+vect(+5,+5,0));
      c.Draw3DLine(pc, l+vect(-5,+5,0), l+vect(+5,-5,0));
      if(!ena_edgenums) continue;
      if(i!=1) DrawSegmentDisplay(c, pn.location +vect(12,0,2), Graph.FindNearestNode(pn.location), pc_wh);
      else     DrawSegmentDisplay(c, pn.location +vect(12,0,2), MarkGraph.FindNearestNode(pn.location), pc_acy);
   }
}

function DrawSegmentDisplay(canvas c, vector location, float value, color pc){
    local int i;
    local vector off_r, off_d, offn_r, offdd, sonr;
    local byte sn[5];
    local float snf;
    local bool sa, sb, sc, sd, se, sf, sg;

    off_r  = vect(4, 0, 0);    // horz segment length
    off_d  = vect(0,  0, -4);  // vert
    offn_r = vect(6, 0, 0);   // char tracking

    offdd  = off_d * 2;
    snf = FClamp(value, 0, 99999);                     // parse input
    sn[0] = byte(snf / 10000); snf -= sn[0] * 10000;
    sn[1] = byte(snf / 1000);  snf -= sn[1] * 1000;
    sn[2] = byte(snf / 100);   snf -= sn[2] * 100;
    sn[3] = byte(snf / 10);    snf -= sn[3] * 10;
    sn[4] = byte(snf);
    for (i = 0; i < 5; i++){            // segment truthtable
        sa = true;  if (sn[i] == 1 || sn[i] == 4)                   sa = false; //  **a*
        sb = true;  if (sn[i] == 5 || sn[i] == 6)                   sb = false; // f    *
        sc = true;  if (sn[i] == 2)                                 sc = false; // *    b
        sd = true;  if (sn[i] == 1 || sn[i] == 4 || sn[i] == 7)     sd = false; //  **g*
        se = false; if (sn[i] != 4 && sn[i] % 2 == 0)               se = true;  // e    *
        sf = true;  if ((sn[i] >= 1 && sn[i] <= 3) || sn[i] == 7)   sf = false; // *    c
        sg = true;  if (sn[i] == 0 || sn[i] == 1 || sn[i] == 7)     sg = false; //  **d*
        sonr = location + offn_r * i;   // top left of current digit
        if (sa) c.draw3dline(pc, sonr,                 sonr + off_r);           // a
        if (sb) c.draw3dline(pc, sonr + off_r,         sonr + off_r + off_d);   // b
        if (sc) c.draw3dline(pc, sonr + off_r + off_d, sonr + off_r + offdd);   // c
        if (sd) c.draw3dline(pc, sonr + offdd,         sonr + off_r + offdd);   // d
        if (se) c.draw3dline(pc, sonr + off_d,         sonr + offdd);           // e
        if (sf) c.draw3dline(pc, sonr,                 sonr + off_d);           // f
        if (sg) c.draw3dline(pc, sonr + off_d,         sonr + off_r + off_d);   // g
    }
}

function postbeginplay(){
   local stinvfontinfo sf;
   local STLaserBlast ld;
   local STVS tc;
   local RtNavData d;
   local pathnode pn;
   local mover m;
   b64_enc = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+;";
   foreach allactors(class'pathnode',pn){ pn.bHidden = false; pn.drawscale /= 2; }
   foreach AllActors(class'stinvfontinfo', sf){ inv_finfo   = sf; break; }
    if(inv_finfo==none)    inv_finfo   = spawn(class'stinvfontinfo');
   foreach AllActors(class'STLaserBlast',  ld){ laserdot    = ld; break; }
    if(laserdot==none)     laserdot    = spawn(class'STLaserBlast',,,vect(32767,32767,32767));
   foreach AllActors(class'STVS',          tc){ topview_cam = tc; break; }
    if(topview_cam ==none) topview_cam = spawn(class'STVS',,,        vect(32767,32767,32767));
   foreach AllActors(class'RtNavData',      d){ DataActor   = d;  break; }
    if (DataActor == None) DataActor   = spawn(class'RtNavData',,,   vect(32767,32767,32767));
   if (DataActor.Graph == None) DataActor.Graph = new(Self) Class'RtNavGraph';
   Graph = DataActor.Graph;
   foreach allactors(class'mover',m){
      m.GotoState('TriggerToggle');
      m.MoverEncroachType = ME_ReturnWhenEncroach;
      m.StayOpenTime = 0.0;
      if(m.MoveTime>0.0) m.MoveTime = 1.0;
   }
}

function playselect(){
   local playerpawn pp;
   pp = playerpawn(owner);
   if(pp == none) return;
   oldHUD = pp.myHUD;
   oldHUDType = pp.HUDType;
   pp.HUDType = Class'STHUD';
   pp.myHUD = Spawn(Class'STHUD',pp,,shithole);
   pp.myHUD.MainMenu = oldHUD.MainMenu;
   pp.myHUD.MainMenuType = oldHUD.MainMenuType;
   pp.consolecommand("killpawns");
   pp.consolecommand("set input alt sci_forcedodge");
   pp.consolecommand("set input ctrl sci_tog_topview");
   pp.consolecommand("set input shift sci_toggle_hiddened");
   pp.consolecommand("set input g sci_tog_topviewpitch");
   pp.consolecommand("set input b sci_warpgrab");
   pp.consolecommand("set input n sci_edgenumbers");
   pp.consolecommand("set input mousewheeldown ctl_cam_down");
   pp.consolecommand("set input mousewheelup ctl_cam_up");
   pp.consolecommand("set input middlemouse sci_spawn_pnruntime");
   pc_wh   = makecolor(255,255,255);
   pc_gray = makecolor(120,120,120);
   pc_grn  = makecolor(80,180,80);
   pc_red  = makecolor(255,80,80);
   pc_yel  = makecolor(255,200,0);
   pc_acy  = makecolor(255,255,40);
   pc_blue = makecolor(0,0,85);
   pc_pink = makecolor(255,120,255);
}

function bool NodeHasEdge(int a, int b){
   local int e;
   for (e = 0; e < Graph.Edges_qty; e++){
      if ((Graph.GetEdgeA(e) == a && Graph.GetEdgeB(e) == b) ||
          (Graph.GetEdgeA(e) == b && Graph.GetEdgeB(e) == a)) return True;
   }
   return False;
}

function performdodge(playerpawn p){
   local vector x,y,z;
   local rotator r;
   if(p.Physics==PHYS_Walking && (forcedodge_xdir!=0 || forcedodge_ydir!=0)){
      getaxes(p.rotation,x,y,z);
      p.velocity =  (forcedodge_xdir*1.5*p.groundspeed+p.velocity dot x)*x
                   +(forcedodge_ydir*1.5*p.groundspeed+p.velocity dot y)*y;
      p.velocity.z = 160;
      p.PlayOwnedSound(p.JumpSound, SLOT_Talk, 1.0, true, 800, 1.0);
      p.SetPhysics(PHYS_Falling);
   }else if(p.Physics == PHYS_Swimming){
      if(!wforcedodge_ready) return;
      p.waterspeed = 45000;
      p.Velocity = vector(p.viewrotation) * 2000;
      r = p.viewrotation;
      r.pitch = r.pitch % 65536;
      if(r.pitch > 32768) r.pitch -= 65536;
      if(r.pitch > 3000) p.Velocity.Z = 640;
      wforcedodge_ready = false;
      water_forcedodge_timer = 0.2;
   }
}
exec function sci_forcedodge(){
   if(p == none) return;
   forcedodge_xdir = 0; forcedodge_ydir = 0;
   if(p.bwasforward) forcedodge_xdir = 1;
   if(p.bwasback)    forcedodge_xdir = -1;
   if(p.bwasleft)    forcedodge_ydir = 1;
   if(p.bwasright)   forcedodge_ydir = -1;
   if(forcedodge_xdir == 0 && forcedodge_ydir == 0){
      sci_mark_toggle();
      return;
   }
   performdodge(p);
}

exec function navexport(){  // export MarkGraph into unreal.log for dataprovider actors
   local int i, e, cnt, linecnt;
   local string line;
   if (MarkGraph == None){ log("Navnet export failed: MarkGraph is None"); return; }
//   log("RtNavBlobBegin");
//   log("NavVersion=1");
//   log("Slice=128");
   log("NodeData_qty="$MarkGraph.Nodes_qty);     // nodes; 8x b64 x,y,z int16-BE
   line = ""; cnt = 0; linecnt = 0;
   for(i = 0; i < MarkGraph.Nodes_qty; i++){
      line = line $ EncodeVec3(MarkGraph.NodeLoc_arr[i]);
      cnt = cnt + 1;
      if(cnt>=128){
         log("NodeData("$linecnt$")="$line);
         line = ""; cnt = 0; linecnt = linecnt + 1;
      }
   }
   if(cnt>0)
         log("NodeData("$linecnt$")="$line);

   log("EdgeData_qty="$MarkGraph.Edges_qty);     // edges; 6x b64 A,B int16-BE
   line = ""; cnt = 0; linecnt = 0;
   for(e = 0; e < MarkGraph.Edges_qty; e++){
      line = line $ EncodePair(MarkGraph.GetEdgeA(e), MarkGraph.GetEdgeB(e));
      cnt = cnt + 1;
      if(cnt>=128){
         log("EdgeData("$linecnt$")="$line);
         line = ""; cnt = 0; linecnt = linecnt + 1;
      }
   }
   if(cnt>0)
         log("EdgeData("$linecnt$")="$line);

//   log("RtNavBlobEnd");
}

function string EncodeVec3(vector loc){
   local int xu, yu, zu;
   local int b0,b1,b2,b3,b4,b5;        // data bytes
   local int c0,c1,c2,c3,c4,c5,c6,c7;  // carrier bytes
   local string s;

   xu = int(loc.X) & 0xFFFF;
   yu = int(loc.Y) & 0xFFFF;
   zu = int(loc.Z) & 0xFFFF;

   b0 = (xu >> 8) & 0xFF;   b1 = xu & 0xFF;
   b2 = (yu >> 8) & 0xFF;   b3 = yu & 0xFF;
   b4 = (zu >> 8) & 0xFF;   b5 = zu & 0xFF;

   c0 =  (b0 >> 2) & 0x3F;
   c1 = ((b0 & 0x03) << 4) | ((b1 >> 4) & 0x0F);
   c2 = ((b1 & 0x0F) << 2) | ((b2 >> 6) & 0x03);
   c3 =   b2 & 0x3F;
   c4 =  (b3 >> 2) & 0x3F;
   c5 = ((b3 & 0x03) << 4) | ((b4 >> 4) & 0x0F);
   c6 = ((b4 & 0x0F) << 2) | ((b5 >> 6) & 0x03);
   c7 =  b5  & 0x3F;

   s = Mid(b64_enc, c0, 1) $ Mid(b64_enc, c1, 1) $ Mid(b64_enc, c2, 1) $ Mid(b64_enc, c3, 1) $
       Mid(b64_enc, c4, 1) $ Mid(b64_enc, c5, 1) $ Mid(b64_enc, c6, 1) $ Mid(b64_enc, c7, 1);
   return s;
}

function string EncodePair(int a, int b){
   local int au, bu, w;
   local int c0,c1,c2,c3,c4,c5;
   local string s;
   au = a & 0xFFFF;
   bu = b & 0xFFFF;
   w  = (au << 16) | bu;   // 32-bit word
   c0 = (w >> 26) & 0x3F;
   c1 = (w >> 20) & 0x3F;
   c2 = (w >> 14) & 0x3F;
   c3 = (w >>  8) & 0x3F;
   c4 = (w >>  2) & 0x3F;
   c5 = (w & 0x03) << 4;   // low 2 bits -> high 2 bitsà of C5, other zeroed
   s = Mid(b64_enc, c0, 1) $ Mid(b64_enc, c1, 1) $ Mid(b64_enc, c2, 1) $
       Mid(b64_enc, c3, 1) $ Mid(b64_enc, c4, 1) $ Mid(b64_enc, c5, 1);
   return s;
}

defaultproperties{
  PickupViewMesh=LodMesh'UnrealShare.AutoMagPickup'
  InventoryGroup=1
  PickupAmmoCount=9999
// BudgetPerTick=2500
  BudgetPerTick=250
  water_forcedodge_timer=0.0
  wforcedodge_ready=false
  LinkSrc=-1
  LinkDest=-1
  next_scan=0.0
  laserdot=None
  bMarkMode=false
  Mark_prev=-1
  Mark_target=-1
  Mark_radius=1200.0
  Mark_angle=20
  Mark_arriveDist=64.0
  topview_cam=none
  ena_topview=false
  ena_warpnode=false
  ena_edgenums=true
  ctl_topview_pitch=false
  topview_addrot=(pitch=-12400,yaw=0,roll=0)
  topview_addz=80.0
  MarkComponentsQty=-1
}
