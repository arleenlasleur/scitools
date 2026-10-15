class PathNodeRuntime extends PathNode; // spawnable pathnode 
#exec texture import file="textures\sciYpnr.png" name="sciYpnr" package="scitools" mips=1 flags=2 btc=-2
#exec texture import file="textures\sciBpnr.png" name="sciBpnr" package="scitools" mips=1 flags=2 btc=-2
#exec texture import file="textures\sciRpnr.png" name="sciRpnr" package="scitools" mips=1 flags=2 btc=-2

// var name layer_tag; // mbshit, use Engine.Actor.tag property
var float layer_thickness; // action area, leader data or cached     // move to AnimFrame
var float layer_z; // action geometric center, leader/cached         // move to AnimRate
var int layer_id; // set occupied layer if nonzero
var bool bLayerActive; // render as pc_gray_map if false

function timer(){
   bHidden = false;
   bIsSecretGoal = false;
}
function tick(float f){
/*   local pathnoderuntime lpn;
   local bool bPreventResetKill;
   if(Texture!=texture'sciRpnr') goto skip_lasersense;
   bPreventResetKill = false;
   foreach radiusactors(class'pathnoderuntime',lpn,12.0)  // killsense radius;
        // we cant obtain it from weapon to prevent dependency
        // refer to AMS class const kill_dpn_radius_by_laser
     if(instr(caps(string(lpn.group)),"AMSLASER") != -1) bPreventResetKill = true;

   if(bPreventResetKill) goto skip_lasersense;
      Texture=default.texture;
      if(!bHiddenEd) disable('tick');
      return;
   skip_lasersense:*/
   if(!bHiddenEd) return;
   Texture = (int(level.timeseconds/0.7) % 2)==0 ? texture'sciYpnr' : texture'sciBpnr';
}
function postbeginplay(){
   disable('tick');
}

defaultproperties{
   bStatic=false        // required
   bHidden=false
   bHiddenEd=false      // used as Zset datasource flag (todo upd: now this controlling user-selected layers, not scannable layers)
   bDirectional=false   // used as anywall flag (anti-artifact behavior disabled)
   bIsSecretGoal=false  // used as delayed appear flag; handle timer in external class
   Mass=100.0           // used as anywall sector
   bIsKillGoal=false    // used as untested marker, all untouched dpns are red
// bIsItemGoal;
// bEdLocked;
// bEdShouldSnap;
// bMeshCurvy;
   VisibilityRadius=-14.0 // prevents some drawportal() misrendering shit
   layer_id=0
   layer_thickness=32.0
   layer_z=0.0
   bLayerActive=true
}
