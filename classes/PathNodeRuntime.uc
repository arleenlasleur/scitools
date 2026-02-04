class PathNodeRuntime extends PathNode; // spawnable pathnode 
var float anywall_full_angle;
#exec texture import file="textures\sciYpnr.png"   name="sciYpnr"   package="scitools" mips=1 flags=2 btc=-2
#exec texture import file="textures\sciBpnr.png"   name="sciBpnr"   package="scitools" mips=1 flags=2 btc=-2

function tick(float f){
   if(!bHiddenEd) return;
   Texture = (int(level.timeseconds/0.7) % 2)==0
     ? texture'sciYpnr'
     : texture'sciBpnr';
}

function timer(){
   bHidden = false;
}

function postbeginplay(){
   disable('tick');
   if(bIsSecretGoal){          // used for timed unhide (to prevent annoying dpns blinking when autospawn)
      setTimer(0.7,false);
      bIsSecretGoal = false;
   }
}

defaultproperties{
   bStatic=false            // required for spawn()
   bHidden=false            // required for user visual control
   bHiddenEd=false          // used as Z-set array datasource (alternative of diag_z)
   bDirectional=false       // anti-artifact behavior disabled
   bIsSecretGoal=false      // more safe to use vars
   anywall_full_angle=4096.0
// bIsKillGoal;
// bIsItemGoal;
// bEdLocked;
// bEdShouldSnap;
// bMeshCurvy;
// group=                   // angle width for anywall usage:
//  content: name( "a" $ string(scan_angle) )
//  where var float scan_angle; is yaw rotation of raycast area, centered by rotation.yaw
//  truncate content by float(int(float_angle)) or do minus (scan_angle % 1.000) to this var
//  content string may be 16 chars max, incl first "a" letter; which is required
   VisibilityRadius=-14.0   // prevents some drawportal() misrendering shit
// CollisionHeight=32
// CollisionRadius=16
}
