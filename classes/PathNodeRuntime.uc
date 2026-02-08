class PathNodeRuntime extends PathNode; // spawnable pathnode 
//var float anywall_full_angle;
#exec texture import file="textures\sciYpnr.png"   name="sciYpnr"   package="scitools" mips=1 flags=2 btc=-2
#exec texture import file="textures\sciBpnr.png"   name="sciBpnr"   package="scitools" mips=1 flags=2 btc=-2

function timer(){
   bHidden = false;
   bIsSecretGoal = false;
}

function tick(float f){
   if(!bHiddenEd) return;
   Texture = (int(level.timeseconds/0.7) % 2)==0 ? texture'sciYpnr' : texture'sciBpnr';
}

function postbeginplay(){
   disable('tick');
}

defaultproperties{
   bStatic=false
   bHidden=false
   bHiddenEd=false      // used as Zset flag
   bDirectional=false   // used as anywall flag
   bIsSecretGoal=false  // used as delayed appear flag
   Mass=100.0           // used as anywall sector
//   anywall_full_angle=4096.0
// bIsKillGoal;
// bIsItemGoal;
// bEdLocked;
// bEdShouldSnap;
// bMeshCurvy;
   VisibilityRadius=-14.0
}

/*
   bStatic: required for spawn()
   bHidden:          required for user visual control
   bHiddenEd:        used as Z-set array datasource (alternative of diag_z)
   bDirectional:     anti-artifact behavior disabled
   bIsSecretGoal:    timed bhidden reset scheduled, handle timer in external class
   Mass:             sector width in UR/100
   VisibilityRadius: prevents some drawportal() misrendering shit
*/