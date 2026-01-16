class areamapscan extends weapon config(scitools);
#exec texture import file="textures\scipixel.png"    name="scipixel"    package="scitools" mips=1 flags=0 btc=-2
#exec texture import file="textures\scipixelblk.png" name="scipixelblk" package="scitools" mips=1 flags=0 btc=-2
#exec texture import file="textures\scinoblk.png"    name="scinoblk"    package="scitools" mips=1 flags=0 btc=-2
#exec texture import file="textures\sciscreenbg.png" name="sciscreenbg" package="scitools" mips=1 flags=0 btc=-2
#exec font    import file="textures\scifontbig.pcx"  name="scifontbig"  // 16x29
#exec texture import file="textures\scibearing.png"  name="scibearing"  package="scitools" mips=1 flags=2 btc=-2

var stinvfontinfo inv_finfo;         // font antimemleak spawnplug
var byte n_layerz,done_layerz;       // selected/shot to png layers
var globalconfig float vert_discretization; // AreaZ responsive map sensitivity
var globalconfig bool bClassicMode;  // place DPNs dpn_addz_classic from floor instead of narrow,
                                     // also don't mutate pathnodes already placed in level, use them as-is
var int presets_z[64];               // selectable layers z
var byte presets_nmax;               // selectable total (inclusive, lay0...lay19 = 20 layers)
var float global_offset_x,global_offset_y; // map center vs world position for texture
var float marked_offset_x,marked_offset_y; // map center vs world position for marked area
var float last_mark_timestamp;             // marked area unique label
var float scrshot_timer;             // wait after sshot to flush disk
var byte last_mark_resolution;       // marked area known worldscale
var int last_mark_texture;           // marked area known size_tex
var byte mode_player;                // 0=hide,    1=show,     2=alert,    3=pointer
var byte mode_all_layers;            // 0=current, 1=all fast, 2=all full, 3=all client-like
var byte mode_mwheel;                // 0=x,       1=y,        2=layer
var bool ena_lockz;                  // true=snap selz to playerz
var bool ena_lockoffset;             // true=snap map center to player (lock xy)
var byte mode_dpn_fall;              // 0=falling, 1=floating, 2=inheritz
var bool ena_tex_mark;               // marked area visible if true
var bool ena_2xzoom;                 // half tex resolution (digital zoom)
var bool ena_4xzoom;                 // quarter
var bool pw_sens_fire;               // true if user holds weaponfire
var float accumulated_pw_sens_fire;  // for full quality preview mode
var int mode_autospawn;              // 0=disable, 1=each 192, 2=each 128
var float autospawn_timer,autospawn_interval;
var byte mode_step,mode_texsize;     // mode number of step/texture
var int size_step,size_tex;          // value of step/texture
var byte map_resolution;
var string state_player[4];          // descriptions
var string state_mapdisplay[4];
var string new_clientmsg[2];         // notifications
var float clientmsg_timer;
var float last_tick_f,last_tick_f_upd_timer; // framerate counter related
var float wall_dist;                 // how far to place laser blast
var color  state_color[4];           // player/render mode number related
var byte shr_div_coords;             // 3=div8, 96% of foundry fits in 1024x1024; 4=div16 etc
var STLight lightbeam;               // light blast
var STLaser laserdot;                // laser blast
var bool ena_laser;
var trigger sens_trig;               // sensed trigger for controlling
var mover sens_mov;                  // sensed mover for controlling
var bool ena_prod;                   // execute prod sequence if true
var ams_shield shield;
// ============================================================================================================
// CALIBRATION DATA. Added to eliminate magicnumbers from code.
// ============================================================================================================
const user_hold_health = 200;         // user hp
const searchlight_direction = 4096;   // horz pitch to rotate
const hud_maptex_offset_x = 685;      // coords of texture top left, relative to canvas top left
const hud_maptex_offset_y = 30; 
const anti_artifacts_maxslope = 5300; // don't ignore raypoint if hitnormal pitch don't exceed this
const advance_ray_pos_full = 512;     // speed of rotator for raycast cycle, precise mode
const advance_ray_pos_std = 1024;     // normal mode
const advance_ray_pos_fast = 8192;    // economode
const timetrigger_pw_sens_fire=0.45;  // how long hold fire to preview full render mode
const max_fastscan_vsizesq = 2400000; // ignore dist>1536 pathnodes when in modes 1,3
const dpn_addz_narrow = 24;   // height of scanned wall perimeter, 50 cm
const dpn_addz_narrower = 12; // cause too many lines on laddersteps but maybe people prefer this
const dpn_addz_classic = 61;  // 130 cm, vanilla unreal pathnode placement
const player_vs_dpn_addz = 16; // 80/2 = 40; 40-24 = 16, compensate playerz
const sens_trig_radius = 384;  // how far to sense triggers
// ============================================================================================================

function string mwheel_behave_mark(byte inputval){
   if(mode_mwheel==inputval) return "+";
    else                     return " ";
}
function color mwheel_behave_color(byte inputval){
   if(mode_mwheel==inputval) return makecolor(255,255,255);
    else                     return makecolor(96 ,96 ,96 );
}

exec function init(){
   playselect();
}

exec function diag(){
   do_diag_z();
// spawn(class'pnze'); // old code
//  doing re-diag necessary, otherwise map pay attention to normal PathNode
//  locations only, not PathNodeRuntime locations as well. cause map gaps
//  in unknown to AI spots if vert mismatch
}

exec function mark(){
   marked_offset_x = global_offset_x;
   marked_offset_y = global_offset_y;
   last_mark_timestamp = level.timeseconds;
   last_mark_resolution = map_resolution;
   last_mark_texture = size_tex;
   ena_tex_mark = true;
}

exec function prod(){
   local byte i;
   local string ts;
   new_clientmsg[0] = "Writing amd_????.uc data into log...";
   clientmsg_timer = 1.7;
      log(" =====================================================",'AMS');
      log(" ==  REMEMBER TO RENAME ME WHEN SAVING AS .UC FILE  ==",'AMS');
      log(" =====================================================",'AMS');
      log(" class amd_???? extends AreaMapData;",'AMS');
      log(" ",'AMS');
   for(i=0; i<=presets_nmax; i++){         // sortz counter shows last array, not qty, so 0..19 is actually 20
      ts = ""; if(i<10) ts $= "0"; ts $= string(i);
      log(" #exec texture import file=\"textures\\????\\????_"$ts$".png\" name=\"????_"$ts$"\" mips=1 flags=0 btc=-1",'AMS');
   }  log(" ",'AMS');
      log(" function postbeginplay(){",'AMS');
      log("    local playerpawn pp;",'AMS');
      log("    self.group = 'sci_areamap';",'AMS');
      log("    foreach allactors(class'playerpawn',pp) pp.consolecommand(\"sci_install_areamap\");",'AMS');
      log("    disable('tick');",'AMS');
      log(" }",'AMS');
      log(" ",'AMS');
      log(" defaultproperties{",'AMS');
      log("   SHR_factor="$shr_div_coords,'AMS');
      log("   AreaHeight="$vert_discretization,'AMS');
   for(i=0; i<=presets_nmax; i++){
      ts = ""; if(i<10) ts $= "0"; ts $= string(i);
      log("   MapTex("$i$")=texture'????_"$ts$"'",'AMS');
  }for(i=0; i<=presets_nmax; i++)
      log("   AlignX("$i$")="$int(global_offset_x),'AMS');
   for(i=0; i<=presets_nmax; i++)
      log("   AlignY("$i$")="$int(global_offset_y),'AMS');
   for(i=0; i<=presets_nmax; i++)
      log("   AlignZ("$i$")="$presets_z[i],'AMS');
      log(" }",'AMS');
      log(" ",'AMS');
   new_clientmsg[0] = "Writing cropping.bat data...";
   clientmsg_timer = 1.7;
      log(" ==================================================",'AMS');
      log(" ==  CHECK PATHS BEFORE LAUNCH. FFMPEG REQUIRED  ==",'AMS');
      log(" ==================================================",'AMS');
   for(i=0; i<=presets_nmax; i++){
      ts = ""; if(i<10) ts $= "0"; ts $= string(i);
      log(" ffmpeg -i "$ts$".png -q:v 0 -qmin 1 -vf \"crop="$size_tex$":"$size_tex$":"$
           hud_maptex_offset_x$":"$hud_maptex_offset_y$"\" crop"$ts$".png",'AMS');
   }  log(" ",'AMS');
   n_layerz = 0;
   ena_prod = true;
   scrshot_timer = 2.0;
}

function hlp(){
   local playerpawn p;
   if(owner==none) return;
   p = playerpawn(owner);
   if(p==none) return;
   p.clientmessage("This tool use PathNode and PathNodeRuntime objects as epicenters of raytracing the map. PathNodeRuntime actors");
   p.clientmessage("are also called DPN (dummy pathnode) and are runtime-spawnable. DPN serve to produce more raytracing if incomplete");
   p.clientmessage("coverage of map (most cases). There are raytracing artifacts - perpendicular lines on sloped floor surfaces. These");
   p.clientmessage("can't be evaded and must be cleaned in postprocess (.png editing) in editors like GIMP or PS.");
   p.clientmessage("General hint: place DPNs near walls at every walkable places.");
   p.clientmessage(" ");
   p.clientmessage("Commands:");
   p.clientmessage("init - reassign hotkeys when loaded .usa file. Prefer to keep your user.ini read/only.");
   p.clientmessage("diag - sort trucncated z values as map layers. 63 max. Vert resolution: 128 uu. Flags level as ready.");
   p.clientmessage("prod - start export layers of flagged level (need to run diag cmd at least once).");
   p.clientmessage("mark - set visible border around current map area (use during export to correctly cut remaining areas).");
   p.clientmessage("Mark command overwrite old region.");
   p.clientmessage("During export, areamapdata align data is logged as text. Use unreal.log contents to form the .ucc files");
   p.clientmessage("for compiling map package. Textures should be cropped, ffmpeg commands also will be included in log.");
   p.clientmessage("Uncropped screenshots will contain align data as onscreen text. Save it before crop, or keep orig files.");
   p.clientmessage(" ");
   p.clientmessage("Display modes and behavior: (switched by 1,2,8,9 keys)");
   p.clientmessage("You can switch map render mode to fast/full quality, specific layer (used at export stage), or intellifast mode");
   p.clientmessage("which is on by default (used while DPN placement as max balance-friendly). Most demanded scale is typically 1:16,");
   p.clientmessage("because map should be big enough to navigate rooms and small enough for better level coverage. One 1024 texture");
   p.clientmessage("with 1bpp color will take ~10 kb, so total level may stay around 0.4-1.2 mb. Multiple AreaMapData actors can work");
   p.clientmessage("transparently, but you will need specialized iterator to render them.");
   p.clientmessage(" ");
   p.clientmessage("Navigation behavior: (switched by 3,0,-,+ keys)");
   p.clientmessage("Control map snapping to player (horz and/or vert) and DPN spawning mode. Player snap/follow turned on by default.");
   p.clientmessage(" ");
   p.clientmessage("Mouse keys behavior:");
   p.clientmessage("LMB (fire) - always open movers");
   p.clientmessage("RMB (altfire) - always killpawns / remove closest DPN(s)");
   p.clientmessage("Wheel - control offset when snapping disabled; press to spawn. Axis select keys - 4,5,6.");
   p.clientmessage(" ");
   p.clientmessage("Export considerations:");
   p.clientmessage("It is strongly recommended to do not change default vertical resolution from 128 UU, however, this is supported");
   p.clientmessage("by AreaMapData prototype actor. I currently don't plan implementing of it's autostretch it for complex levels,");
   p.clientmessage("so you will need to do it manually, and maybe rebuild scitools package.");
   p.clientmessage("Keep an eye on movers, they must stay still while screenshots made. Keep all openable doors already-open, due to");
   p.clientmessage("solid lines on them, or it will look like noclip cheat when player crosswalk them. About AreaZ[] array contents,");
   p.clientmessage("you always can execute diag command again if you're unsure on your DPN placement. For combined faded layers (gray");
   p.clientmessage("inactive map) do merging in editors by multiply/screen blending mode. Rendering whole level is laggy and produce");
   p.clientmessage("lots of artifacts.");
}

function tick(float f){
   local vector hl,hn, x,y,z;
   local rotator r;
// local float lasermult, laserdist;
// local vector laserorigin;
   local pawn p;
   if(owner == none) return;
   p = pawn(owner);
   if(p == none) return;
   p.health = user_hold_health;                       // prevent drown death
   if(p.velocity.z <= -900) p.velocity.z = -900;      // prevent fall death
//   if(shield != none) shield.setlocation(p.location); // prevent proj damage   // removed. cause rays obstacle
// todo autokill pawns instead

   pw_sens_fire = (p.bFire!=0);
   accumulated_pw_sens_fire += f;
   if(!pw_sens_fire) accumulated_pw_sens_fire = 0;

   getaxes(p.viewrotation,x,y,z);
   if(ena_laser){
      trace(hl,hn,p.location + 1280*x,p.location,true);
      z.z = hl.z;
   /* if(rotator(hn).pitch <= anti_artifacts_maxslope) */ hl += hn*wall_dist; // 2026-01-16: offset laser off all surfs, not walls only
      hl.z = z.z;
      laserdot.setlocation(hl);
   }
   if(ena_laser) sens_mov = mover(trace(hl,hn,p.location + 10000*x,p.location,true));
    else sens_trig = FindTrigger(p.location);

/* laserorigin = p.location;
   getaxes(p.viewrotation,x,y,z);
   laserorigin += z*2;
   laserorigin += y*4;
   Trace(HitLoc,HitNor,EndTrace,laserorigin + 15000*x,True);
   hitloc -= x*7;
   laserdist = vsize(p.location - hitloc); */

   autospawn_timer -= f;
   clientmsg_timer -= f;
   scrshot_timer -= f;
   last_tick_f_upd_timer -= f;
   if(lightbeam != none && lightbeam.LightType == LT_Steady){
      r = p.viewrotation;
      lightbeam.setlocation(p.location);
      r.pitch -= searchlight_direction;
      lightbeam.setrotation(r);
   }
   if(clientmsg_timer<=0){       // info msg process
      new_clientmsg[0] = "";
      new_clientmsg[1] = "";
   }
   if(mode_autospawn!=0 && autospawn_timer<=0 && !ena_laser){   // dpn placement process
      sci_scripted_dpn_spawn(p.location);
      autospawn_timer = 0.2;
   }
   if(last_tick_f_upd_timer<=0){     // frametime monitor process
      last_tick_f_upd_timer = 1.0;
      last_tick_f = f;
   }
}

function trigger FindTrigger(vector search_location){
   local trigger t;
   foreach RadiusActors(class'trigger', t, sens_trig_radius){
      if(vsize(t.location-search_location) <= t.CollisionRadius) return t;
   }
   return none;
}

exec function tog_ams_light(){
   if(lightbeam == none) return;
   if(lightbeam.LightType == LT_None)
        lightbeam.LightType = LT_Steady;
   else lightbeam.LightType = LT_None;
}

function sci_scripted_dpn_spawn(vector l){
   if(FindDPN(l, autospawn_interval) != none) return;
// if(FindRPN(l, autospawn_interval) != none) return;
   dpn_spawn(false);
}

//todo: laser mesh, selectable pnz trunc, read ini, check iniread, supajump hotkey, left had hotkeys to control spawn mode
// todo: welcome dialog
// switchable classic/narrow mode

function postrender(canvas c){
   local vector x,y,z,endtrace,hl,hn;
   local string tmp_s;
   local rotator r;
   local float rotr;  // radians rotation
   local byte nmarker;
// local pathnode pn;
   local pathnoderuntime pn;
   local pathnode pns; // static
   local int hlx,hly,mkx,mky;
   local int marked_error;
   local playerpawn p;
   local int sel_z;
   local int pn_tot,pn_rad,rc_tot; // pathnode total, radius, rays cast total
   local int i,k;
   local byte nframe;
   local float pnz;
   local bool nomatch_z; // this z does not match current sel_z or lock_z
   p = playerpawn(owner);
   if(p == none || inv_finfo == none) return;
   if(ena_lockoffset){              // read it here because faster than tick()
      global_offset_x = (-1) * p.location.x;
      global_offset_y = (-1) * p.location.y;
   }
   bOwnsCrosshair=true;
   c.font = inv_finfo.GetInvFont();
   pn_tot = 0;
   foreach allactors(class'pathnode',pns) if(!pns.isa('pathnoderuntime')) pn_tot++;
//----- bg -------------------------------------------------------------------
   c.drawcolor = makecolor(25,25,55); c.setpos(0,0); c.drawtile(texture'scipixel', c.clipx, c.clipy, 0,0,4,4);
//----- tex bg ---------------------------------------------------------------
   if(size_tex<1024){
      c.setpos(hud_maptex_offset_x,hud_maptex_offset_y);
      c.drawtile(texture'scinoblk', 1024, 1024, 0,0,256,256);
      c.setpos(hud_maptex_offset_x, hud_maptex_offset_y+size_tex);
      c.drawtile(texture'scipixel', size_tex, 2, 0,0,4,4);
      c.setpos(hud_maptex_offset_x+size_tex, hud_maptex_offset_y);
      c.drawtile(texture'scipixel', 2, size_tex, 0,0,4,4);
   }
   c.setpos(hud_maptex_offset_x,hud_maptex_offset_y);
   c.drawtile(texture'scipixelblk', size_tex, size_tex, 0,0,4,4);
//----- layer raytracer ------------------------------------------------------
   sel_z = ena_lockz ? int(p.location.z - player_vs_dpn_addz) : presets_z[n_layerz]; // select scanned layer
   rc_tot = 0;
   foreach allactors(class'pathnoderuntime',pn){
      pn_tot++;
//----- layers ignorator ---------------------------------------
      pnz = pn.location.z % vert_discretization;  // eliminate z deviations to vert resolution
      pnz = pn.location.z - pnz;
      nomatch_z = (abs(sel_z - pnz) > vert_discretization);   // was 16/64 = +25% overlapping of discretized area
      if(mode_all_layers==0 && nomatch_z) continue; // we maybe still process further in fullcolor map mode
//----- dist ignorator ---------------------------------------
      x = pn.location;   // cancer code: we use x y z vars for things not meaning coords
      pnz = map_resolution * size_tex / 2;  // max map hull bounds for raytracing centers
      pnz += 540;                           // + bit more than trace length
      if(ena_2xzoom) pnz = pnz>>1;          // ignore 75% of area if 2x zooming
      if(ena_4xzoom) pnz = pnz>>1;          // ignore 93% of area if 4x zooming
      pn_rad = pnz;
      if(mode_all_layers!=0){ // always render all pathnodes in all_selected mode
         if((abs(x.x + global_offset_x) > pnz)
         || (abs(x.y + global_offset_y) > pnz)) continue;
      }  // in other modes, if PN/DPN far far outside of texture, try to eat less CPU
//--------------------------------------------------------------
      r.yaw = 0;  r.roll = 0; r.pitch = 0;
      while(r.yaw<65536){
         getaxes(r,x,y,z);
         endtrace = pn.location + 768.0*x;   // scan dist
         trace(hl,hn,endtrace,pn.location,true);
         hlx = (hl.x>>shr_div_coords);
         hly = (hl.y>>shr_div_coords);
         hlx += (size_tex>>1); hlx += (global_offset_x >> shr_div_coords);
         hly += (size_tex>>1); hly += (global_offset_y >> shr_div_coords);
         if(ena_2xzoom){
            hlx *= 2; hlx -= (size_tex>>1);
            hly *= 2; hly -= (size_tex>>1);
         }
         if(ena_4xzoom){
            hlx *= 2; hlx -= (size_tex>>1);
            hly *= 2; hly -= (size_tex>>1);
         }
         hlx += hud_maptex_offset_x;
         hly += hud_maptex_offset_y;
         c.drawcolor = makecolor(255,255,255);
         if(mode_all_layers==3 && nomatch_z){
            if       (shr_div_coords<=2) c.drawcolor = makecolor(155,203,155);
             else if (shr_div_coords==3) c.drawcolor = makecolor(112,112,160);
             else                        c.drawcolor = makecolor(80,80,128);
         }
//       if(abs(rotator(hn).pitch) <= anti_artifacts_maxslope){ // old code
         if(    rotator(hn).pitch  <= anti_artifacts_maxslope){ // allow negative slope as well
                  // todo
                  // mb allow climbabme in very close dist, for boxes on foundry [-440;-543;-1500]
            pnz = 0.25;             // cancer code but safe to use pnz here
            if(ena_2xzoom) pnz = 0.5;
            if(ena_4xzoom) pnz = 1.0;
            c.setpos(hlx,hly);  c.drawicon(texture'scipixel',pnz);
         }
         if(mode_all_layers!=0) pnz = advance_ray_pos_std;   // assign rays density, full quality for mode 0 only
          else pnz = advance_ray_pos_full;
         if(mode_all_layers==1) pnz = advance_ray_pos_fast;  // skip rays in mode 1, to 8x faster
         if(nomatch_z) pnz = advance_ray_pos_fast;           // skip mismathing by z
         if(mode_all_layers==3                               // skip in mode 3
            && vsizesq(pn.location - p.location)>max_fastscan_vsizesq) // outside max radius
                pnz = advance_ray_pos_fast;
         if(accumulated_pw_sens_fire>timetrigger_pw_sens_fire && !nomatch_z) pnz = advance_ray_pos_full; // override to full quality
         r.yaw += pnz;                                       // apply
         rc_tot ++;
      }
   }
//----- laser blast position -------------------------------------------------
   if(ena_laser){
      c.drawcolor = makecolor(112,112,160);
      hl = p.location;
      getaxes(p.viewrotation,x,y,z);
      k = int( vsize(p.location - laserdot.location) / 40);
      if(k > 256) k = 256;
      for(i=0; i<k; i++){
         hl += 40*x;
         hlx = (hl.x>>shr_div_coords);
         hly = (hl.y>>shr_div_coords);
         hlx += (size_tex>>1); hlx += (global_offset_x >> shr_div_coords);
         hly += (size_tex>>1); hly += (global_offset_y >> shr_div_coords);
         if(ena_2xzoom){
            hlx *= 2; hlx -= (size_tex>>1);
            hly *= 2; hly -= (size_tex>>1);
         }
         if(ena_4xzoom){
            hlx *= 2; hlx -= (size_tex>>1);
            hly *= 2; hly -= (size_tex>>1);
         }
         hlx+=hud_maptex_offset_x; 
         hly+=hud_maptex_offset_y;
         pnz = 0.5;
         if(ena_2xzoom) pnz = 1.0;
         c.setpos(hlx,hly); c.drawicon(texture'scipixel',pnz);
      }
   }
//----- patch bg position active, over tex -----------------------------------
  if(ena_tex_mark){
     marked_error = last_mark_texture - size_tex;
     hlx = (global_offset_x - marked_offset_x);
     hly = (global_offset_y - marked_offset_y);
     hlx = hlx >> shr_div_coords;
     hly = hly >> shr_div_coords;
     hlx += (last_mark_texture>>1);  hlx -= (marked_error>>1);
     hly += (last_mark_texture>>1);  hly -= (marked_error>>1);
     mkx = hlx - (last_mark_texture>>1);
     mky = hly - (last_mark_texture>>1);
     if(ena_2xzoom){
        mkx *= 2; mkx -= (last_mark_texture>>1);
        mky *= 2; mky -= (last_mark_texture>>1);
     }
     if(ena_4xzoom){
        mkx *= 2; mkx -= (last_mark_texture>>1);
        mky *= 2; mky -= (last_mark_texture>>1);
     }
     mkx += hud_maptex_offset_x;
     mky += hud_maptex_offset_y;
     c.drawcolor = makecolor(255,255,192);
     c.setpos(mkx+4, mky+1);      c.drawtext("Marked at " $ int(last_mark_timestamp) $ "s.");
     c.setpos(mkx+4, mky+1 +87);  c.drawtext("Cyan border MUST disappear");
     c.setpos(mkx+4, mky+1 +116); c.drawtext("on edge of adjacent area.");
     c.setpos(mkx+4, mky-61 +last_mark_texture);     c.drawtext("Scale mismatch WILL cause");
     c.setpos(mkx+4, mky-61 +last_mark_texture +29); c.drawtext("positioning error.");
     c.drawcolor = makecolor(192,255,192);
     c.setpos(mkx+4, mky+1 +29); c.drawtext("X: " $ int(marked_offset_x) $ "  Y: " $ int(marked_offset_y));
     c.setpos(mkx+4, mky+1 +58); c.drawtext("T: " $ last_mark_texture    $ "  S: " $ last_mark_resolution);
     c.drawcolor = makecolor(128,229,255);
     c.setpos(mkx, mky);                     c.drawtile(texture'scipixel', last_mark_texture, 1, 0,0,4,4); // t,l corner right
     c.setpos(mkx, mky-1+last_mark_texture); c.drawtile(texture'scipixel', last_mark_texture, 1, 0,0,4,4); // b,l corner right
     c.setpos(mkx, mky);                     c.drawtile(texture'scipixel', 1, last_mark_texture, 0,0,4,4); // t,l corner down
     c.setpos(mkx-1+last_mark_texture, mky); c.drawtile(texture'scipixel', 1, last_mark_texture, 0,0,4,4); // t,r corner down
  }
// ---- texclip bg -----------------------------------------------------------
   c.drawcolor = makecolor(25,25,55);                                       // todo mb disableable
   c.setpos(0,0);
    c.drawtile(texture'scipixel', hud_maptex_offset_x, 1080, 0,0,4,4);
   c.setpos(hud_maptex_offset_x, 0);
    c.drawtile(texture'scipixel', 1024, hud_maptex_offset_y, 0,0,4,4);
   c.setpos(hud_maptex_offset_x, 1024+hud_maptex_offset_y);
    c.drawtile(texture'scipixel', 1024, 26, 0,0,4,4);
   c.setpos(1024+hud_maptex_offset_x, 0);
    c.drawtile(texture'scipixel', 1920-1024-hud_maptex_offset_x, 1080, 0,0,4,4);
// ---- main banner text -----------------------------------------------------
   c.drawcolor = makecolor(255,255,255);
   c.setpos(10,10);  c.drawtext("CT map tool v. 0.3-2026-01-05 by Arleen");
   c.drawcolor = makecolor(128,128,128);
   c.setpos(10,39);  c.drawtext("System requirements: 1920x1080 @ 32bpp");
   c.setpos(10,68);  c.drawtext("user.ini\\hudscaler must be set to 1.0");
   c.drawcolor = makecolor(255,255,255);
   c.drawcolor=mwheel_behave_color(0); tmp_s=mwheel_behave_mark(0); c.setpos(1730,68);  c.drawtext("("$tmp_s$") x offs");
   c.drawcolor=mwheel_behave_color(1); tmp_s=mwheel_behave_mark(1); c.setpos(1730,97);  c.drawtext("("$tmp_s$") y offs");
   c.drawcolor=mwheel_behave_color(2); tmp_s=mwheel_behave_mark(2); c.setpos(1730,126); c.drawtext("("$tmp_s$") layer");
   c.drawcolor=state_color[mode_player];     c.setpos(1730,358); c.drawtext(state_player[mode_player]);
   c.drawcolor = makecolor(255,255,255);     c.setpos(1730,387); c.drawtext("X: "$int(p.location.x));
                                             c.setpos(1730,416); c.drawtext("Y: "$int(p.location.y));
                                             c.setpos(1730,445); c.drawtext("Z: "$int(p.location.z));
/*----- nav camera ------------------------*/
   getaxes(p.viewrotation,x,y,z);
   c.drawportal(10,112,665,375,p,p.location+x*2+z*(p.eyeheight-1),p.viewrotation,106,true);  // 16:9 @ 106 fov
   c.setpos(20,120); c.drawtext(new_clientmsg[0]);
   c.setpos(20,149); c.drawtext(new_clientmsg[1]);
   tmp_s = "1";
   if(ena_2xzoom) tmp_s = "2";
   if(ena_4xzoom) tmp_s = "4";
   tmp_s $= "x   ";
   tmp_s $= string(map_resolution);
   tmp_s $= "uu";
   c.setpos(20,448); c.drawtext(tmp_s);
   tmp_s = "";
   if(sens_mov != none) tmp_s = string(sens_mov.name);
   if(sens_trig != none) tmp_s = string(sens_trig.name);
   k = len(tmp_s);
   k *= 16;
   c.setpos(665-k, 120); c.drawtext(tmp_s);
//-------------------------------------------
   c.drawcolor = makecolor(128,128,128);
   c.setpos(10,505); c.drawtext("Console cmds:     ,     ,     ,");
   c.drawcolor = makecolor(255,255,255);
   c.setpos(234,505); c.drawtext("init  diag  mark  prod");
   c.drawcolor=state_color[mode_all_layers]; c.setpos(1730,561); c.drawtext(state_mapdisplay[mode_all_layers]);
   c.drawcolor = makecolor(255,255,255);
   tmp_s = ena_lockz ? "lock" : n_layerz$"/"$presets_nmax;         c.setpos(1730,590); c.drawtext("Sel: "$tmp_s);

   c.drawcolor = makecolor(255,255,255);
   c.setpos(92,590); c.drawtext("<7>");
   c.setpos(92,619); c.drawtext("<8>");
   c.setpos(92,648); c.drawtext("<9>");
   c.setpos(300,590); c.drawtext("<4>");
   c.setpos(300,619); c.drawtext("<5>");
   c.setpos(300,648); c.drawtext("<6>");
   c.setpos(300,677); c.drawtext("<\\>");
   c.setpos(444,590); c.drawtext("<1>");
   c.setpos(444,619); c.drawtext("<2>");
   c.setpos(444,648); c.drawtext("<3>");
   c.setpos(444,677); c.drawtext("<0>");

   c.setpos(92,706); c.drawtext("<Fire>");
   c.setpos(92,735); c.drawtext("<AltFire>");
   c.setpos(92,764); c.drawtext("<MWhl>");
   c.setpos(92,793); c.drawtext("<MWhl press>");

   c.setpos(444,735); c.drawtext("<F>");
   c.setpos(444,764); c.drawtext("<V>");
   c.setpos(396,793); c.drawtext("<IJKL>");

   c.setpos(92, 851); c.drawtext("<Z>");
   c.setpos(244,851); c.drawtext("<X>");
   c.setpos(396,851); c.drawtext("<Bksp>");
               
   c.drawcolor = makecolor(255,204,170);
   c.setpos(476,561); c.drawtext("Disp:");
   c.setpos(500,590); c.drawtext("player");
   c.setpos(500,619); c.drawtext("map");
   c.setpos(500,648); c.drawtext("lock L/Z");
   c.setpos(500,677); c.drawtext("lock X/Y");

   c.setpos(1730,300); c.drawtext("Player:");
   c.setpos(1730,503); c.drawtext("Process:");
   c.setpos(1730,822); c.drawtext("DPN spawn:");

   c.drawcolor = makecolor(204,255,170);
   c.setpos(332,561); c.drawtext("Mod:");
   c.setpos(356,590); c.drawtext("X");
   c.setpos(356,619); c.drawtext("Y");
   c.setpos(356,648); c.drawtext("L");
   c.setpos(1730,10); c.drawtext("Modify:");

   c.drawcolor = makecolor(170,204,255);
   c.setpos(124,561); c.drawtext("Size:");
   c.setpos(148,590); c.drawtext("step");
   c.setpos(148,619); c.drawtext("tex");
   c.setpos(148,648); c.drawtext("scale");
   c.setpos(1730,648); c.drawtext("TexData:");

   c.setpos(1730,184); c.drawtext("Step:");
   c.setpos(1730,213); c.drawtext("Tex:");
   c.setpos(1730,242); c.drawtext("Scale:");
   c.drawcolor = makecolor(255,255,255);
   c.setpos(1826,184); c.drawtext(size_step);
   c.setpos(1826,213); c.drawtext(size_tex);
   c.setpos(1842,242); c.drawtext(map_resolution);

   c.drawcolor = makecolor(221,175,233);
   c.setpos(124,677); c.drawtext("Generic:");
   c.setpos(244,706); c.drawtext("movers"); 
   c.setpos(244,735); c.drawtext("kill");
   c.setpos(292,793); c.drawtext("DPN");

   c.drawcolor = makecolor(204,255,170);
   c.setpos(244,764); c.drawtext("modify");
   c.setpos(500,793); c.drawtext("mod X/Y");

   c.drawcolor = makecolor(255,100,100);
   c.setpos(356,677); c.drawtext("mark");

   c.drawcolor = makecolor(255,204,170);
   c.setpos(476,706); c.drawtext("DPN:");
   c.setpos(500,735); c.drawtext("fall");
   c.setpos(500,764); c.drawtext("spawn");

   c.drawcolor = makecolor(255,255,155);
   c.setpos(124,822); c.drawtext("User:");
   c.setpos(148,851); c.drawtext("zoom");
   c.setpos(300,851); c.drawtext("laser");
   c.setpos(500,851); c.drawtext("light");

   c.drawcolor = makecolor(255,255,255);
   if(ena_lockoffset) c.drawcolor = makecolor(96,96,96);
   c.setpos(1730,706); c.drawtext("X: "$int(global_offset_x));
   c.setpos(1730,735); c.drawtext("Y: "$int(global_offset_y));
   c.drawcolor = makecolor(255,255,255);
   if(ena_lockz){
      c.drawcolor = makecolor(96,96,96);
      tmp_s = string(int(p.location.z));
   }else{
      tmp_s = string(presets_z[n_layerz]);
   }
   c.setpos(1730,764); c.drawtext("Z: "$tmp_s);
   
        if(mode_dpn_fall==0){ c.drawcolor = makecolor(170,204,255); tmp_s = "falling";   }   // 172,147,157
   else if(mode_dpn_fall==1){ c.drawcolor = makecolor(204,255,170); tmp_s = "floating";  }   // 213,246,255
   else if(mode_dpn_fall==2){ c.drawcolor = makecolor(255,255,155); tmp_s = "inherit z"; }   // 213,246,255
   c.setpos(1730,880); c.drawtext(tmp_s);

   if(mode_autospawn==0){
      c.drawcolor = makecolor(96,96,96);
      tmp_s = "manual";
   }else{
      if(!ena_laser) c.drawcolor = makecolor(255,255,255);
         else c.drawcolor = makecolor(255,155,155);
      tmp_s = "man+auto";
   }
   c.setpos(1730,909); c.drawtext(tmp_s);
   if(mode_autospawn>0){
      c.setpos(1730,938);
      c.drawtext("each "$int(autospawn_interval));
   }

   c.drawcolor = makecolor(255,255,155);
   c.setpos(190,909); c.drawtext("Note:");
   c.drawcolor = makecolor(255,255,255);
   if(rc_tot > 8000) c.drawcolor = makecolor(255,100,100);      // up to 5000 feels good
   if(rc_tot>11000 && ((int(level.timeseconds/0.3) % 2) == 0)) c.drawcolor = makecolor(155,255,255);
//   if(mode_all_layers==2)
   c.setpos(286,909); c.drawtext("heavy raytracing");
//   c.setpos(286,909); c.drawtext("pnr="$pn_rad$ "rc="$rc_tot);

   if((mode_all_layers!=0 || ena_lockz) && accumulated_pw_sens_fire<timetrigger_pw_sens_fire){
      nframe = (int(level.timeseconds/0.24) % 18);
      c.drawcolor = (nframe==0) ? makecolor(255,255,155) : makecolor(155,255,255);
      c.setpos(190,938); c.drawtext("Fast rmode or lockz active");
   }
   c.drawcolor = makecolor(255,255,255);
   c.setpos(190,967); c.drawtext("Aim outside mover and hold");
   c.setpos(190,996); c.drawtext("<Fire> to preview full rmode");
//   c.drawcolor = makecolor(255,255,255);
//   c.setpos(190,967); c.drawtext("Be ready to severe lagging");
//----- player displayer -------------------------------------------------------------------------------
   if(mode_player>0){
       hl = p.location;
       hlx = (hl.x>>shr_div_coords);
       hly = (hl.y>>shr_div_coords);
       hlx+=(size_tex>>1); hlx+=(global_offset_x>>shr_div_coords);
       hly+=(size_tex>>1); hly+=(global_offset_y>>shr_div_coords);
       if(ena_2xzoom){
          hlx *= 2; hlx -= (size_tex>>1);
          hly *= 2; hly -= (size_tex>>1);
       }
       if(ena_4xzoom){
          hlx *= 2; hlx -= (size_tex>>1);
          hly *= 2; hly -= (size_tex>>1);
       }
       hlx += hud_maptex_offset_x;
       hly += hud_maptex_offset_y;
       c.drawcolor = (int(level.timeseconds/1.2) % 2) == 0 ? makecolor(87,87,128) : makecolor(225,225,255);
       if(mode_player==2) c.drawcolor = makecolor(225,225,0);
       if(mode_player<3){  // mode 1, 2
          c.setpos(hlx,hly); c.drawicon(texture'scipixel',mode_player);
       }else{              // mode 3
          rotr = (p.viewrotation.yaw+16384) % 65536;  // -90 because zero yaw in unrealed is A of WASD
          if(rotr < 0) rotr += 65536;
          nmarker = byte(rotr/2730.66);
          c.setpos(hlx-8,hly-8);
          c.drawcolor = (int(level.timeseconds/0.7) % 2) == 0 ? makecolor(192,192,255) : makecolor(225,225,255);
          c.DrawTile(texture'scibearing',16,16, nmarker*16,0,16,16);
       }
   }
/*----- nav camera contd ------------------*/
   c.drawcolor = makecolor(255,255,255);
   if(pn_tot>1000)       c.drawcolor = makecolor(255,238,170);
    else if(pn_tot>2000) c.drawcolor = makecolor(255,204,170);
    else if(pn_tot>3000) c.drawcolor = makecolor(255,170,170);
    else if(pn_tot>4000) c.drawcolor = (int(level.timeseconds/0.3) % 2) == 0
                         ? makecolor(255,40,40) : makecolor(255,255,255);
   tmp_s = "";
   if(pn_tot<1000) tmp_s $= "0";
   if(pn_tot<100) tmp_s $= "0";
   if(pn_tot<10) tmp_s $= "0";
   tmp_s $= string(pn_tot);
   k = len(tmp_s);
   k *= 16;
   c.setpos(665-k, 448); c.drawtext(tmp_s);
   k += 64;
   c.drawcolor = makecolor(255,255,255);
   c.setpos(665-k, 448); c.drawtext("PN:");
   c.drawcolor = makecolor(255,255,255);
   i = int(1/last_tick_f);
   if(i > 60) i = 60;
   c.setpos(212,448); c.drawtext(i$"fps");
/*-------------------------------------------*/
   if(ena_prod && scrshot_timer <= 0.0){
      new_clientmsg[0] = "Making image "$string(n_layerz)$" of "$string(presets_nmax)$"...";
      clientmsg_timer = 1.7;
      p.consolecommand("shot");
      scrshot_timer = 2.0;
      done_layerz = n_layerz;
      if(n_layerz<presets_nmax) n_layerz++;
      if(done_layerz == n_layerz) ena_prod = false;
   }
}

function postbeginplay(){
   local inventory w;
   local decoration d;
   local effects e;
   local byte i;
   local pathnode pn;
   local trigger t;
   local mover m;
   foreach allactors(class'inventory',w) if(w != self) w.destroy();
   foreach allactors(class'decoration',d) d.destroy();
   foreach allactors(class'effects',e) e.destroy();
   inv_finfo = spawn(class'stinvfontinfo');
   state_player[0]="( ) hide";
   state_player[1]="(+) show";
   state_player[2]="(*) mark";
   state_player[3]="(^) dir";
   state_mapdisplay[0]="SELECTED";
   state_mapdisplay[1]="ALL FAST";
   state_mapdisplay[2]="ALL FULL";
   state_mapdisplay[3]="FAST F+C";
   clientmsg_timer = -1.0;
   new_clientmsg[0] = "";
   new_clientmsg[1] = "";
   state_color[0]=makecolor(96 ,96 ,96 );
   state_color[1]=makecolor(255,255,255);
   state_color[2]=makecolor(255,255,155);
   state_color[3]=makecolor(155,155,255);
   presets_nmax = 0;
   for(i=0;i<64;i++) presets_z[i] = 0;
   foreach allactors(class'pathnode',pn) if(!pn.isa('pathnoderuntime')) dpn_replace(pn.location);
   foreach allactors(class'trigger',t){
      t.group='';
      t.bTriggerOnceOnly = false;               // force enable
//      if(t.TriggerType == TT_PlayerProximity){   // 2026-01-16: now always execute this
         t.TriggerType = TT_ClassProximity;     // prohibit autotrigger
         t.ClassProximityType = class'ams_dummy_proxclass';
//      }
      t.RepeatTriggerTime = 0.0;                // normalize toggling stuff
      t.RetriggerDelay = 0.2;
      t.GotoState('NormalTrigger');
   }
   foreach allactors(class'mover',m){
      m.GotoState('TriggerToggle');
      m.MoverEncroachType = ME_ReturnWhenEncroach;
      m.StayOpenTime = 0.0;
   }
   lightbeam = spawn(class'STLight',,,vect(32767,32767,32767));
   laserdot = spawn(class'STLaser',,,vect(32767,32767,32767));
   shield = spawn(class'ams_shield',,,vect(32767,32767,32767));
   do_diag_z();            // initial diag pass
   mode_player = 3;        // restore to convenient defaults
   mode_all_layers = 3;
// mode_mwheel = 2; already 2
   ena_2xzoom = true;
   ena_4xzoom = false;
   shr_div_coords = 2;
   upd_resolution();
   ena_lockz = true;
   ena_lockoffset = true;
// saveconfig();
   resetconfig();
}

function playselect(){
   local playerpawn p;
   p = playerpawn(owner);
   if(p == none) return;
   p.consolecommand("killpawns");
   p.consolecommand("killall pickup");
   p.consolecommand("killall decoration");
   p.consolecommand("killall decal");
   p.consolecommand("set input 1 tog_show_player");
   p.consolecommand("set input 2 tog_show_all_layers");
   p.consolecommand("set input 3 tog_lockz");
   p.consolecommand("set input 0 tog_lockoffset");
   p.consolecommand("set input 4 tog_mode_mwheel_x");
   p.consolecommand("set input 5 tog_mode_mwheel_y");
   p.consolecommand("set input 6 tog_mode_mwheel_l");
   p.consolecommand("set input 7 tog_mode_step");
   p.consolecommand("set input 8 tog_mode_texsize");
   p.consolecommand("set input 9 tog_shr_factor");
   p.consolecommand("set input backslash tog_mark_region");
// p.consolecommand("set input minus tog_dpn_fall");
// p.consolecommand("set input equals tog_dpn_autospawn");
   p.consolecommand("set input f tog_dpn_fall");
   p.consolecommand("set input v tog_dpn_autospawn");
   p.consolecommand("set input i do_scr_w");
   p.consolecommand("set input j do_scr_a");
   p.consolecommand("set input k do_scr_s");
   p.consolecommand("set input l do_scr_d");
   p.consolecommand("set input middlemouse sci_user_dpn_spawn");
   p.consolecommand("set input mousewheeldown sciscrolldown");
   p.consolecommand("set input mousewheelup sciscrollup");
   p.consolecommand("set input z tog_digzoom");
   p.consolecommand("set input x tog_laser");
   p.consolecommand("set input backspace tog_ams_light");
   upd_resolution(); upd_size_tex(); upd_size_step();
}

exec function tog_laser(){
   ena_laser = !ena_laser;
   if(!ena_laser){
      laserdot.setlocation(vect(32767,32767,32767));
      if(sens_mov != none) sens_mov = none; // forget mover
   }else{
      if(sens_trig != none) sens_trig = none; // forget trigger
   }
}

exec function tog_digzoom(){
   if(!ena_2xzoom){
      ena_2xzoom = true;
      ena_4xzoom = false;
   }else{
      if(!ena_4xzoom){
         ena_4xzoom = true;
      }else{
         ena_2xzoom = false;
         ena_4xzoom = false;
      }
   }
}

exec function tog_show_player(){     mode_player++;     if(mode_player>3)     mode_player=0; }     // 1
exec function tog_show_all_layers(){ mode_all_layers++; if(mode_all_layers>3) mode_all_layers=0; } // 2
exec function tog_lockoffset(){  // 0
   ena_lockoffset = !ena_lockoffset;
   if(ena_lockoffset) new_clientmsg[0] = "Map center snapped to player.";
   else new_clientmsg[0] = "Map center released.";
   clientmsg_timer = 2.0;
}
exec function tog_mark_region(){ ena_tex_mark = !ena_tex_mark; } // \
exec function tog_lockz(){ ena_lockz = !ena_lockz; } // 3
exec function tog_mode_mwheel_x(){ mode_mwheel = 0; } // 4
exec function tog_mode_mwheel_y(){ mode_mwheel = 1; } // 5
exec function tog_mode_mwheel_l(){ mode_mwheel = 2; } // 6
exec function tog_mode_step(){        // 7
   mode_step++;
   if(mode_step>2) mode_step=0;
   upd_size_step();
}
exec function tog_mode_texsize(){     // 8
   mode_texsize++;
   if(mode_texsize>2) mode_texsize=0;
   upd_size_tex();
}
exec function tog_shr_factor(){       // 9
   shr_div_coords--;
   if(shr_div_coords<1) shr_div_coords = 5;
   upd_resolution();
   upd_size_step();
}

exec function tog_dpn_fall(){     // -
   mode_dpn_fall++;
   if(mode_dpn_fall>2) mode_dpn_fall=0;
}

exec function tog_dpn_autospawn(){                            // +
   mode_autospawn++;
   if(mode_autospawn>2) mode_autospawn = 0;
   if(mode_autospawn==1) autospawn_interval = 192.0;
   if(mode_autospawn==2) autospawn_interval = 128.0;
}

function dpn_spawn(bool bSummonLike){
    local PathNodeRuntime dpn;
    local vector sp_loc;
    local vector dpn_newpos,hitnor; // trace related
    local pawn p;
    local vector x,y,z;
    local rotator r;
    if(owner==none) return;
    p = pawn(owner);
    if(p==none) return;
    r = p.viewrotation;
    sp_loc = p.location;
    if(bSummonLike){
       getaxes(r,x,y,z);
       sp_loc += 56*x;
       sp_loc.z += 15;
    }
    if(ena_laser){
       sp_loc = laserdot.location;
    }
    dpn = spawn(class'PathNodeRuntime',,,sp_loc);
    if(mode_dpn_fall==1) return;
    dpn_newpos = vect(32767,32767,32767);
    if(mode_dpn_fall==2){
       trace(dpn_newpos,hitnor,p.location+vect(0,0,-1024),p.location,true); // we need only z of this
       dpn_newpos.x = sp_loc.x;
       dpn_newpos.y = sp_loc.y;
    }else if(mode_dpn_fall==0){
       trace(dpn_newpos,hitnor,sp_loc+vect(0,0,-1024),sp_loc,true);
    }
    dpn_newpos.z += dpn_addz_narrow;
    if(dpn != none) dpn.setlocation(dpn_newpos);
}
function dpn_replace(vector l){
    local vector dpn_newpos,hitnor;
    dpn_newpos = vect(32767,32767,32767);
    trace(dpn_newpos,hitnor,l+vect(0,0,-1024),l,true);
    dpn_newpos.z += dpn_addz_narrow;
    spawn(class'PathNodeRuntime',,,dpn_newpos);
}

function PathNodeRuntime FindDPN(vector search_location, float range_sensitivity){
   local PathNodeRuntime t;
   foreach RadiusActors(class'PathNodeRuntime', t, range_sensitivity) return t;
   return none;
}

function PathNode FindRPN(vector search_location, float range_sensitivity){
   local PathNode t;
   foreach RadiusActors(class'PathNode', t, range_sensitivity) return t;
   return none;
}

function do_diag_z(){
    local pathnoderuntime pn;
    local float pnz,pnz_lsb;
    local int i, j;
    local bool bDup;
    presets_nmax = 0;
    foreach AllActors(class'pathnoderuntime', pn){ // collect
       if(presets_nmax >= 64) break;
       pnz = pn.location.z; 
       pnz_lsb = pnz % vert_discretization;
       pnz -= pnz_lsb; 
       bDup = false;
       for(i=0; i<presets_nmax; i++){    // chk if exists
          if(presets_z[i] == pnz){
             bDup = true;
             break;
          }
       }
       if(!bDup){                        // add
          presets_z[presets_nmax] = pnz;
          presets_nmax++;
       }
    }
    for(i=1; i<presets_nmax; i++){       // insertion sort
       pnz = presets_z[i];               // insertable
       j = i - 1;                        // cmp from prev
       while(j>=0 && presets_z[j]>pnz){  // shr if higher
          presets_z[j+1] = presets_z[j];
          j--;
       }
       presets_z[j+1] = pnz;             // insert in pos
    }
//  for(i=0; i<presets_nmax; i++) broadcastmessage(string(presets_z[i]));  // log result
    mode_player = 0;          // reset interface to grab-ready // todo reset zooms
    mode_all_layers = 0;
    mode_mwheel = 2;
    ena_2xzoom = false;
    ena_4xzoom = false;
    shr_div_coords = 4;
    upd_resolution();
    ena_lockz = false;
    ena_lockoffset = false;
    new_clientmsg[0] = "AreaZ set diag done.";
    new_clientmsg[1] = "Ret to SEL rmode. Playerpos disabled.";
    clientmsg_timer = 4.0;
}

function upd_size_step(){ switch(mode_step){
    case 0: size_step = map_resolution*1;  break;
    case 1: size_step = map_resolution*8;  break;
    case 2: size_step = map_resolution*64; break;  }
}
function upd_size_tex(){ switch(mode_texsize){
    case 0: size_tex = 256;  break;
    case 1: size_tex = 512;  break;
    case 2: size_tex = 1024; break;   }
}
function upd_resolution(){ switch(shr_div_coords){
    case 1: map_resolution = 2; break;
    case 2: map_resolution = 4; break;
    case 3: map_resolution = 8; break;
    case 4: map_resolution = 16; break;
    case 5: map_resolution = 32; break;
    case 6: map_resolution = 64; break;
    case 7: map_resolution = 128; break; }
}

exec function sciscrolldown(){
   if(ena_laser && wall_dist<384){
      if(wall_dist<32) wall_dist += 8;
       else wall_dist += 32;
      new_clientmsg[0] = "Wall dist: "$int(wall_dist);
      clientmsg_timer = 2.0;
   }else{
      switch(mode_mwheel){
         case 0: if(!ena_lockoffset) global_offset_x -= size_step; break;
         case 1: if(!ena_lockoffset) global_offset_y -= size_step; break;
         case 2: if(n_layerz>0) n_layerz--; break;
      }
   }
}
exec function sciscrollup(){
   if(ena_laser && wall_dist>0){
      if(wall_dist>32) wall_dist -= 32;
       else wall_dist -= 8;
      new_clientmsg[0] = "Wall dist: "$int(wall_dist);
      clientmsg_timer = 2.0;
   }else{
      switch(mode_mwheel){
         case 0: if(!ena_lockoffset) global_offset_x += size_step; break;
         case 1: if(!ena_lockoffset) global_offset_y += size_step; break;
         case 2: if(n_layerz<presets_nmax) n_layerz++; break;
      }
   }
}

exec function do_scr_w(){ if(!ena_lockoffset) global_offset_y -= size_step; }
exec function do_scr_a(){ if(!ena_lockoffset) global_offset_x -= size_step; }
exec function do_scr_s(){ if(!ena_lockoffset) global_offset_y += size_step; }
exec function do_scr_d(){ if(!ena_lockoffset) global_offset_x += size_step; }

function altfire(float f){
   local vector x, y, z;
   local float rad;
   local playerpawn p;
   local pathnoderuntime pn;
   p = playerpawn(owner);
   if(p == none) return;
   p.consolecommand("killpawns");
   getaxes(p.viewrotation,x,y,z);
   if(ena_laser){
      y = laserdot.location;
      rad = 64;
   }else{
      y = p.location + 32*x;
      rad = 80;
   }
   foreach radiusactors(class'PathNodeRuntime',pn,rad,y) pn.destroy();
}

function fire(float f){
   local pawn p;
//   local actor atarg;
//   local vector hl, hn, x, y, z;
   local mover m;
   p = pawn(owner);
   if(p == none) return;
//   getaxes(p.viewrotation,x,y,z);
   if(sens_mov!=none){                     // open by mover, prio
      if(sens_mov.group=='mactive'){
         sens_mov.untrigger(p,p.instigator);
         sens_mov.group='';
      }else{
         sens_mov.trigger(p,p.instigator);
         sens_mov.group='mactive';
      }
      return;
   }
   if(sens_trig!=none){                    // open by trigger
      if(sens_trig.group=='tactive'){
         if(sens_trig.event!=none)
           foreach allactors(class'mover',m,sens_trig.event) m.untrigger(p,p.instigator);
         sens_trig.group='';
      }else{
         if(sens_trig.event!=none)
           foreach allactors(class'mover',m,sens_trig.event) m.trigger(p,p.instigator);
         sens_trig.group='tactive';
      }
   }
}

exec function sci_user_dpn_spawn(){  // middlemouse
   dpn_spawn(true);
}

defaultproperties{
  laserdot=None
  ena_laser=false
  shr_div_coords=2
  PickupViewMesh=LodMesh'UnrealShare.AutoMagPickup'
  global_offset_x=0
  global_offset_y=0
  vert_discretization=80.0
  ena_lockz=true
  ena_lockoffset=true
  mode_dpn_fall=2
  ena_tex_mark=false
  ena_2xzoom=true
  ena_4xzoom=false
  scrshot_timer=0.0
  last_mark_timestamp=0.0
  last_mark_resolution=1
  last_mark_texture=1
  mode_autospawn=0
  autospawn_interval=192.0
  wall_dist=0.0
  mode_all_layers=3
  mode_player=3
  mode_mwheel=2
  mode_step=2
  mode_texsize=2
  n_layerz=0
  done_layerz=0
  InventoryGroup=1
  PickupAmmoCount=9999
  ena_prod=false
}
