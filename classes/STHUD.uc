class STHUD extends HUD nousercreate;

simulated function PlayReceivedMessage(string S, string PName, ZoneInfo PZone);

simulated function PreRender(canvas c){
  local playerpawn p;
  p = playerpawn(owner);
  if(p == none) return;
  if(p.weapon != none) p.weapon.prerender(c);
}

simulated function PostRender(canvas c){
  local playerpawn p;
  p = playerpawn(owner);
  if(p == none) return;
  c.reset();
  c.bNoSmooth = false;
  c.SetDrawColorRGB(255,255,255);
  if(p.weapon!=none && (Level.LevelAction==LEVACT_None)) p.weapon.postrender(c);
}

defaultproperties{
  HudMode=0
  HudScaler=1.0
}
