class STVS expands Info;

var playerpawn oInst;

function view_cam(){
   if (oInst.ViewTarget == Self) return;
   oInst.ViewTarget = Self;
}

function view_own(){
   if (oInst.ViewTarget != Self){
      oInst = None;
      return;
   }
      oInst.ViewTarget = None;
}

defaultproperties{
   oInst=none
}