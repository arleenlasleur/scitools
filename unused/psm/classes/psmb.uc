class psmb expands weapon;
var float lasttick;
var int mycursor_x,mycursor_y;

function tick(float f){
  if(level.timeseconds - lasttick < 5.0) return;
  lasttick = level.timeseconds;
  ammotype.ammoamount = 10000;
}

function postrender(canvas c){
  local playerpawn p;
  p = playerpawn(owner);
  if(p == none) return;

  if(mycursor_x < c.clipx) mycursor_x += p.aMouseX;
  if(mycursor_y < c.clipy) mycursor_y += p.aMouseY;
  c.setpos(mycursor_x,mycursor_y); c.drawtext("o");
  
  c.setpos(10,10); c.drawtext("Input");

  c.setpos(10,30); c.drawtext("bRun:");
  c.setpos(10,40); c.drawtext("bDuck:");
  c.setpos(10,50); c.drawtext("bFire:");
  c.setpos(10,60); c.drawtext("bAltFire:");
  c.setpos(10,70); c.drawtext("bExtra0:");
  c.setpos(10,80); c.drawtext("bExtra1:");
  c.setpos(10,90); c.drawtext("bExtra2:");
  c.setpos(10,100); c.drawtext("bExtra3:");
  c.setpos(140,30); c.drawtext(p.bRun);
  c.setpos(140,40); c.drawtext(p.bDuck);
  c.setpos(140,50); c.drawtext(p.bFire);
  c.setpos(140,60); c.drawtext(p.bAltFire);
  c.setpos(140,70); c.drawtext(p.bExtra0);
  c.setpos(140,80); c.drawtext(p.bExtra1);
  c.setpos(140,90); c.drawtext(p.bExtra2);
  c.setpos(140,100); c.drawtext(p.bExtra3);

  c.setpos(10, 120); c.drawtext("Speeds");

  c.setpos(10, 140); c.drawtext("GroundSpeed:");
  c.setpos(10, 150); c.drawtext("WaterSpeed:");
  c.setpos(10, 160); c.drawtext("AirSpeed:");
  c.setpos(10, 170); c.drawtext("AccelRate:");
  c.setpos(10, 180); c.drawtext("AirControl:");
  c.setpos(140, 140); c.drawtext(p.GroundSpeed);
  c.setpos(140, 150); c.drawtext(p.WaterSpeed);
  c.setpos(140, 160); c.drawtext(p.AirSpeed);
  c.setpos(140, 170); c.drawtext(p.AccelRate);
  c.setpos(140, 180); c.drawtext(p.AirControl);

  c.setpos(10, 200); c.drawtext("View");

  c.setpos(10, 220); c.drawtext("ViewRotation:");
  c.setpos(10, 230); c.drawtext("EyeHeight:");
  c.setpos(10, 240); c.drawtext("ViewTarget:");
  c.setpos(140, 220); c.drawtext(p.ViewRotation);
  c.setpos(140, 230); c.drawtext(p.EyeHeight);
  c.setpos(140, 240); c.drawtext(p.ViewTarget);

  c.setpos(310, 10); c.drawtext("Input axis");

  c.setpos(310, 30); c.drawtext("aBaseX:");
  c.setpos(310, 40); c.drawtext("aBaseY:");
  c.setpos(310, 50); c.drawtext("aBaseZ:");
  c.setpos(310, 60); c.drawtext("aMouseX:");
  c.setpos(310, 70); c.drawtext("aMouseY:");
  c.setpos(310, 80); c.drawtext("aForward:");
  c.setpos(310, 90); c.drawtext("aTurn:");
  c.setpos(310, 100); c.drawtext("aStrafe:");
  c.setpos(310, 110); c.drawtext("aUp:");
  c.setpos(310, 120); c.drawtext("aLookUp:");
  c.setpos(310, 130); c.drawtext("aExtra4:");
  c.setpos(310, 140); c.drawtext("aExtra3:");
  c.setpos(310, 150); c.drawtext("aExtra2:");
  c.setpos(310, 160); c.drawtext("aExtra1:");
  c.setpos(310, 170); c.drawtext("aExtra0:");
  c.setpos(440, 30); c.drawtext(p.aBaseX);
  c.setpos(440, 40); c.drawtext(p.aBaseY);
  c.setpos(440, 50); c.drawtext(p.aBaseZ);
  c.setpos(440, 60); c.drawtext(p.aMouseX);
  c.setpos(440, 70); c.drawtext(p.aMouseY);
  c.setpos(440, 80); c.drawtext(p.aForward);
  c.setpos(440, 90); c.drawtext(p.aTurn);
  c.setpos(440, 100); c.drawtext(p.aStrafe);
  c.setpos(440, 110); c.drawtext(p.aUp);
  c.setpos(440, 120); c.drawtext(p.aLookUp);
  c.setpos(440, 130); c.drawtext(p.aExtra4);
  c.setpos(440, 140); c.drawtext(p.aExtra3);
  c.setpos(440, 150); c.drawtext(p.aExtra2);
  c.setpos(440, 160); c.drawtext(p.aExtra1);
  c.setpos(440, 170); c.drawtext(p.aExtra0);
}

defaultproperties{
  mycursor_x=0
  mycursor_y=0
  inventorygroup=1
  ammoname=Class'UnrealShare.ASMDAmmo'
  pickupammocount=10000
  bcanthrow=false
  pickupviewmesh=LodMesh'UnrealShare.ASMDPick'
  mesh=LodMesh'UnrealShare.ASMDPick'
}
