class PathnodeRadio extends weapon;
var int pnr_tot;
var int pnr_now;
var name pnr_last;
var float next_scan;
var byte next_rssi;

function postrender(canvas c){
   local string s,u;
   local byte i;
   local vector l;
   local pathnode pn;
   local color pc;
   c.font=c.smallfont;
   c.setpos(10,10);  c.drawtext("PathNode radio propagation assigner, v. 0.1, 2024/05/20, Arleen Lasleur.");
   c.setpos(10,20);  c.drawtext("Type pnrdump command in console to export (write to log).");
   c.setpos(10,40);  c.drawtext("Total pathnodes: "$pnr_tot);
   c.setpos(10,50);  c.drawtext("Assigned:        "$pnr_now);
   c.setpos(10,70);  c.drawtext("Fire: set        Altfire: open movers");
   s = "none";
   if(pnr_last != '') s = string(pnr_last);
   c.setpos(400,40);  c.drawtext("Now accessing: "$pnr_last);
   u = "";
   for(i=0;i<next_rssi;i++) u $= "|";
   if(next_rssi==0) u = "."; else u $= " ";
   for(i=next_rssi;i<6;i++) u $= " ";
   u = u $ "(" $ next_rssi $ ")";
   c.setpos(400,50);  c.drawtext("Next RSSI:     "$u);
   if(pnr_last == '') return;
   pn = FindPN(pnr_last);
   if(pn == none) return;
   l = pn.location;
   pc = makecolor(255,200,255);
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

function postbeginplay(){
   local pathnode p;
   foreach allactors(class'pathnode',p){
      p.bHidden=false;
      p.setCollision(true,true,false);
      pnr_tot++;
   }
}

function playselect(){
   local playerpawn p;
   p = playerpawn(owner);
   if(p == none) return;
   p.consolecommand("killpawns");
}

function tick(float f){
   local playerpawn p;
   p = playerpawn(owner);
   if(p == none) return;
   next_scan -= f;
   if(next_scan > 0) return;
   next_scan = 0.1;
   do_tick_scan_rssi(p);
}

function do_tick_scan_rssi(playerpawn p){
   local pathnode pn,pn_act;
   local float dist,dist_act;
   if(p.weapon != self) return;
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
   pnr_last = pn_act.name;
//   modem_rssi = int(right(string(pn_act.group),3));
}

exec function pnrdump(){
   local pathnoderssi pd;
   log("===============================================================",'PNR');
   foreach allactors(class'pathnoderssi',pd) log(pd.targ$": "$pd.rssi,'PNR');
   log("===============================================================",'PNR');
}

function pnr_set(byte rssi){
   local pathnode ptx;
   local pathnoderssi prx;
   ptx = FindPN(pnr_last);
   if(ptx == none) return;
   if(ptx.event == ''){
      prx = spawn(class'PathnodeRSSI',,,ptx.location);
      ptx.event = prx.name;
      prx.targ = ptx.name;
      ptx.bHidden = true;
      pnr_now++;
   }else
      prx = FindPR(ptx.event);
   if(prx == none) return;
   prx.update(rssi);
}

     function fire(float f){   pnr_set(next_rssi);          }
exec function sciscrolldown(){ if(next_rssi>0) next_rssi--; }
exec function sciscrollup(){   if(next_rssi<6) next_rssi++; }

function altfire(float f){
   local playerpawn p;
   local actor atarg;
   local vector hl, hn, x, y, z;
   local mover m;
   p = playerpawn(owner);
   if(p == none) return;
   getaxes(p.viewrotation,x,y,z);
   atarg = trace(hl,hn,p.location + 10000*x,p.location,true);
   m = mover(atarg);
   if(m==none) return;
   m.trigger(p,p.instigator);
/*    where_n=targ.keynum;
   if(where_n == call_n+2) already_here = true;
   if(call_n==10 || already_here) return;
   lock_timer = targ.MoveTime;
   targ.StayOpenTime=0;
   targ.KeyPos[1]=targ.KeyPos[targ.KeyNum];
   targ.KeyRot[1]=targ.KeyRot[targ.KeyNum];
   targ.KeyPos[0]=targ.KeyPos[call_n+2];
   targ.KeyRot[0]=targ.KeyRot[call_n+2];
   targ.PrevKeyNum=1;
   targ.gotoState('TriggerOpenTimed','Close');*/
}

function pathnode FindPN(name t){
   local pathnode pt;
   foreach radiusactors(class'pathnode',pt,128) if(pt.name == t) return pt;
   return none;
}

function pathnoderssi FindPR(name t){
   local pathnoderssi pr;
   foreach radiusactors(class'pathnoderssi',pr,128) if(pr.name == t) return pr;
   return none;
}

defaultproperties{
  PickupViewMesh=LodMesh'UnrealShare.AutoMagPickup'
  InventoryGroup=1
  PickupAmmoCount=9999
  pnr_tot=0
  pnr_now=0
  next_scan=0.0
  next_rssi=0
}