// ===========================================================================================
// AreaMapData holographic root class. Provide dotcloud data for map.
// ===========================================================================================
class AreaHoloMap extends actor;
var() vector LevelOffset;
var() string MapData[256];     // max 256 rows x 1024 char each, = 128 vect; 32768 dots total
var() int    MapData_qty;                   // do not render more, laggy
var() string ReactorData[256]; // todo mb less of these
var() int    ReactorData_qty;
// format scheme (big-endian):
//   node = (x:int16, y:int16, z:int16) -> 8 base64-chars  (same as BSP-dots    20 lines
//   edge = (A:int16, B:int16)          -> 6 base64-chars  (A,B node indices)  120 lines
var() string NodeData[20];  // len = ceil(NodesQty / Slice) <= 20
var() int    NodeData_qty;  // real existing nodes, up to 2560
var() string EdgeData[120]; // len = ceil(EdgesQty / Slice) <= 120
var() int    EdgeData_qty;  // real edges, up to 15360
// ================================ data transfer-related code, remove for mylevel variant ===
var() bool   CallCopyProc;
var() name   CopyTargName;
function draweditorselection(canvas c){
   local actor a;
   local actor CopyTarg;
   if(!CallCopyProc) return;
   CallCopyProc = false;
   if(CopyTargName=='') return;  // no targ set
   CopyTarg = none;
   foreach AllActors(class'actor', a) if(a.name==CopyTargName){ CopyTarg = a; break; }
   if(CopyTarg==none) return;    // no targ match
   CopyTarg.SetPropertyText("MapData_qty",self.GetPropertyText("MapData_qty")); // copying
   CopyTarg.SetPropertyText("ReactorData_qty",self.GetPropertyText("ReactorData_qty"));
   CopyTarg.SetPropertyText("EdgeData_qty",self.GetPropertyText("EdgeData_qty"));
   CopyTarg.SetPropertyText("NodeData_qty",self.GetPropertyText("NodeData_qty"));
   for(i=0;i<256;i++){
      CopyTarg.SetPropertyText("MapData["$i$"]",self.GetPropertyText("MapData["$i$"]")); // copying
      CopyTarg.SetPropertyText("ReactorData["$i$"]",self.GetPropertyText("ReactorData["$i$"]"));
      if(i>=120) continue; // array bounds limits, bigger to smaller
      CopyTarg.SetPropertyText("EdgeData["$i$"]",self.GetPropertyText("EdgeData["$i$"]"));
      if(i>=20) continue;
      CopyTarg.SetPropertyText("NodeData["$i$"]",self.GetPropertyText("NodeData["$i$"]"));
   }
} // ======================================================================= DTP code ends ===

function postbeginplay(){
   self.group = 'areamap';
}

defaultproperties{
   CallCopyProc=false
   bHidden=true
   bCollideWhenPlacing=false
   bStatic=true
   bNoDelete=true
   NodeData_qty=0
   EdgeData_qty=0
   bEditorSelectRender=true
   RemoteRole=ROLE_SimulatedProxy
   bAlwaysRelevant=true
}
