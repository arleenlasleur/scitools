class AreaReactorExport extends Actor;

function MakeLine(AreaReactor r, int reactor_n){
   local string ok_str, out_str;
   ok_str = r.OverlayKind==OK_Lift ? "1" : "0"; // aka bIsLift
   out_str = "ReactorData(" $ reactor_n $ ")=" $ mid(string(r.FoundMover),8) $ ";" $ ok_str $ ";"
            $ int(r.Location.X) $ ";" $ int(r.Location.Y) $ ";" $ int(r.Location.Z) $ ";"
            $ r.Rotation.Yaw $ ";" $ r.Rotation.Pitch $ ";" $ r.Rotation.Roll $ ";"
            $ int(r.OverlayWidth) $ ";" $ int(r.OverlayHeight) $ ";" $ r.MaxPointsUsage;
   log(out_str, 'AR_ent');
}

event DrawEditorSelection(Canvas C){
   local AreaReactor r;
   local int i;
   i=0;
   foreach AllActors(class'AreaReactor', r){
      if(r.FoundMover==none) continue;
      MakeLine(r,i);
      i++;
   }
   log("ReactorData_qty=" $ i, 'AR_ent');
   destroy();
}

defaultproperties{
   bHidden=True
   bCollideActors=False
   bBlockActors=False
   bBlockPlayers=False
   bEditorSelectRender=True
}
