class STLight extends Effects;

function timer(){
   local weapon w;
   if(instigator == none) return;
   w = instigator.weapon;
   if(w == none) return;
   if(!w.isa('areamapscan')){
     LightType = LT_None;
     bHidden = true;
   }
}

function beginplay(){
   setTimer(0.3,true);
}

defaultproperties{
  Physics=PHYS_MovingBrush
  PhysRate=9999.0
  DrawType=DT_None
  LightBrightness=240
  LightHue=173
  LightSaturation=230
  LightCone=180
  LightEffect=LE_None
  LightRadius=18
  LightType=LT_None
}
