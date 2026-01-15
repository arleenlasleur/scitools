class bbbm expands weapon;
var BoundingBox bbshow;
var bool bbusable;

function postrender(canvas c){
  if(!bbusable) return;
  c.setpos(10,10); c.drawtext(bbshow.Min);
  c.setpos(10,20); c.drawtext(bbshow.Max);
  c.setpos(10,30); c.drawtext(bbshow.isValid);
}

function timer(){
  local vector HitLoc, HitNor, EndTrace;
  local playerpawn p;
  local actor a;
  p = playerpawn(owner);
  if(p == none) return;
  if(p.weapon != self) return;
  EndTrace = p.location + 10000 * Vector(p.ViewRotation);
  a = Trace(HitLoc,HitNor,EndTrace,p.location,True);
  bbusable = false;
  if(a == none) return;
  bbshow = a.getBoundingBox(true);
  bbusable = true;
  setTimer(0.1,true);
}

defaultproperties{
  bbusable=false
  inventorygroup=1
  ammoname=Class'UnrealShare.ASMDAmmo'
  pickupammocount=10000
  bcanthrow=false
  pickupviewmesh=LodMesh'UnrealShare.ASMDPick'
  mesh=LodMesh'UnrealShare.ASMDPick'
}
