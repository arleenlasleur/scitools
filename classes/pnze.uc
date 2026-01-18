class pnze extends actor; // debug export z of dpn

function postbeginplay(){
  local pathnoderuntime pn;
  local float pnz,pnz_lsb;
  local playerpawn pp;
  foreach allactors(class'pathnoderuntime',pn){
     pnz = pn.location.z; 
     pnz_lsb = pnz % 16;
     pnz -= pnz_lsb; 
     log(pnz,'PNZE');
  }
  foreach allactors(class'playerpawn',pp) pp.consolecommand("exit");
  destroy();
}

defaultproperties{
  bstasis=false
  bstatic=false
}