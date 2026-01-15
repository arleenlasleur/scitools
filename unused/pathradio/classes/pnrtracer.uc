class pnrtracer extends weapon;
var string pn_cur;

function postrender(canvas c){
// scan pathnodes in radius 1024
   c.font=c.smallfont;
   c.setpos(10,10);  c.drawtext("PathNode radio propagation tracer v. 0.1.0, 2024/04/03, Arleen Lasleur.");
   c.setpos(10,20);  c.drawtext("type 'pnrscan' console command to start. report is written to log, in unreal units.");
   c.setpos(10,40);  c.drawtext("Keep in mind:");
   c.setpos(10,50);  c.drawtext("1. pnrtransmitter actor removed. transmitter coords considered 0,0,32767.");
   c.setpos(10,60);  c.drawtext("   not everywhere terrain ceiling is equal, data may require scaling and adjusting.");
   c.setpos(10,70);  c.drawtext("2. make sure all necessary pathnodes exist. noob authors tend to skip these.");
   c.setpos(10,90);  c.drawtext("Processing: "$pn_cur);
}

exec function pnrscan(){
   local pathnode p;
   local playerpawn pp;
   local pnrtester pt;
   local vector pos_tx,dir_tx,pos_test,x,y,z;
   local rotator rot;
   local int j,k,score_tx;
   pp = playerpawn(owner);
   pt = spawn(class'pnrtester');
   pos_tx = vect(0,0,32767);
      log("=========================================================",'PNRP');
      foreach allactors(class'pathnode',p){
         pn_cur = string(p.name);
         dir_tx = p.location - pos_tx;
         rot = rotator(dir_tx);
         getaxes(rot,x,y,z);
         j = vsize(dir_tx) / 128.0;
         pos_test = p.location;
         score_tx = 0;
         for(k=0; k<j; k++){
            pos_test += 128.0 * x;
            pt.setlocation(pos_test);
            if(!(caps(string(pt.region.zone.name))~="LEVELINFO0")) score_tx++;
         }
         log(p.name$": "$score_tx,'PNRP');
//         pp.clientmessage("found "$p.name$" j="$j,'pickup');
      }
      log("=========================================================",'PNRP');
      pn_cur = "done";
}

defaultproperties{
  PickupViewMesh=LodMesh'UnrealShare.AutoMagPickup'
  InventoryGroup=1
  PickupAmmoCount=9999
  pn_cur="-"
}