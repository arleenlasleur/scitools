class PathnodeRSSI extends actor;

#exec texture import file="textures\pnr_0.png" name="pnr_a" package="scitools" mips=1 flags=0 btc=-2
#exec texture import file="textures\pnr_1.png" name="pnr_b" package="scitools" mips=1 flags=0 btc=-2
#exec texture import file="textures\pnr_2.png" name="pnr_c" package="scitools" mips=1 flags=0 btc=-2
#exec texture import file="textures\pnr_3.png" name="pnr_d" package="scitools" mips=1 flags=0 btc=-2
#exec texture import file="textures\pnr_4.png" name="pnr_e" package="scitools" mips=1 flags=0 btc=-2
#exec texture import file="textures\pnr_5.png" name="pnr_f" package="scitools" mips=1 flags=0 btc=-2
#exec texture import file="textures\pnr_6.png" name="pnr_g" package="scitools" mips=1 flags=0 btc=-2

var byte rssi;
var name targ;

function update(byte new_rssi){
   rssi = new_rssi;
   switch(new_rssi){
      case 0: texture = texture'pnr_a'; break;
      case 1: texture = texture'pnr_b'; break;
      case 2: texture = texture'pnr_c'; break;
      case 3: texture = texture'pnr_d'; break;
      case 4: texture = texture'pnr_e'; break;
      case 5: texture = texture'pnr_f'; break;
      case 6: texture = texture'pnr_g'; break;
   }
}

defaultproperties{
   DrawType=DT_Sprite
   DrawScale=0.35
   rssi=0
   targ=None
   bStatic=false
}
