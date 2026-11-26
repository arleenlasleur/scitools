class STLaserBlast extends Effects;
var bool bAngleIndicator;
#exec mesh import mesh="scilaser" anivfile="models\scilaserblast_a.3d" datafile="models\scilaserblast_d.3d" x=0 y=0 z=0 mlod=0
#exec mesh origin mesh="scilaser" x=0 y=0 z=0
#exec mesh sequence mesh="scilaser" seq="All" startframe=0 numframes=1
#exec meshmap new meshmap="scilaser" mesh="scilaser"
#exec meshmap scale meshmap="scilaser" x=0.00157 y=0.00157 z=0.00313

function timer(){  if(vsizesq(velocity) > 0) velocity = vect(0,0,0);  }
function beginplay(){  setTimer(0.3,true);  }
singular function zonechange(zoneinfo nz){  velocity = vect(0,0,0);  }
function tick(float f){
  local byte nframe;
  if(!bAngleIndicator) return;
  nframe = (int(level.timeseconds/0.35) % 3);
  switch(nframe){
     case 0: MultiSkins[0] = texture'scipixel_g'; break;
     case 1: MultiSkins[0] = texture'scipixel_o'; break;
     case 2: MultiSkins[0] = texture'scipixel_p'; break;
  }
}

defaultproperties{
   bAngleIndicator=fasle
   Physics=PHYS_MovingBrush
   PhysRate=9999.0
   ScaleGlow=3.0
   Mesh=Mesh'scilaser'
   MultiSkins(0)=Texture'scipixel'
   DrawType=DT_Mesh
   bUnlit=True
   bNoSmooth=True
   LODBias=0.0
}
