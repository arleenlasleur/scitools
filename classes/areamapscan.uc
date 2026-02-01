class AreaMapScan extends weapon config(scitools);
// todo laser2 mwheel not working (wrong coords of spawn/destroy)
// todo test autospawn wont spam in water/fly
// todo make strictwall
// todo manual diag mode, <use this floor> key/cmd - almost done thru blinking dpns
// todo grayed pxzoom in mark mode, disable by keyfunc done

#exec texture import file="textures\scipixel.png"    name="scipixel"    package="scitools" mips=1 flags=0 btc=-2
#exec texture import file="textures\scipixelblk.png" name="scipixelblk" package="scitools" mips=1 flags=0 btc=-2
#exec texture import file="textures\scinoblk.png"    name="scinoblk"    package="scitools" mips=1 flags=0 btc=-2
#exec texture import file="textures\sciscreenbg.png" name="sciscreenbg" package="scitools" mips=1 flags=0 btc=-2
#exec font    import file="textures\scifontbig.pcx"  name="scifontbig"  // 16x29
#exec texture import file="textures\scibearing.png"  name="scibearing"  package="scitools" mips=1 flags=2 btc=-2

var stinvfontinfo inv_finfo;         // font antimemleak spawnplug
var HUD oldHUD;                      // used for menu-related hud setup transfer
var class<HUD> oldHUDType;
var byte n_layerz,done_layerz;       // selected/shot to png layers
var globalconfig float vert_discretization; // AreaZ responsive map sensitivity
var globalconfig float autofall_floordist;
var globalconfig bool bDisableAllBtnsNotify; // prio over 2 others
var globalconfig bool bDisableLRmouseNotify;
var globalconfig bool bEnableMmouseNotify;
var globalconfig bool bUseUntrigger;
var int presets_z[64];               // selectable layers z
var byte presets_nmax;               // selectable total (inclusive, lay0...lay19 = 20 layers)
var float global_offset_x,global_offset_y; // map center vs world position for texture
var float scrshot_timer;             // wait after sshot to flush disk
// new code ----------------
var byte enab_region[8];            // because we use 9 as noregion index;
//var byte enab_region[10];            // because we use 9 as noregion index;
                                     // here and further, enab_ = ena_byte type because bool[] prohibited
var vector2d region_align[8];
var string region_texture[8];
var float region_scale[8];   // as SHR_factor behave
var int region_sizetex[8];
var byte region_usefloor[64];        // num of n_layerz used in this alignz slot, any 0-63
var byte region_usedby[64];          // num of n_region preset which occupy above mem, 0..7 - region, 9 - free
var byte alignz_seek;                // mem write pointer
// -------------------------
var byte n_region;

var enum EOper{ MO_Scan, MO_Diag, MO_Mark, MO_Prod, MO_WantDiag, MO_LifetimeCfg} mode_oper;
var enum ELTCfg{ LTC_Floordist, LTC_ZSetDiscr, LTC_ProdSHR} mode_ltcfg;
var enum EConf{ MC_Reset, MC_Doit, MC_Yesimsure, MC_Stopfuckingasking, MC_Confirmed} mode_confirm;
var bool ena_player;
var enum ERayPrc { RP_SelFull, RP_AllFast, RP_AllFullEco, RP_ClientLike, RP_ClientFull} mode_rayprocess;
var byte mode_mwheel;                // 0=x,       1=y,        2=layer
var bool ena_lockz;                  // true=snap selz to playerz
var bool ena_lockxy;             // true=snap map center to player (lock xy)
var byte mode_dpn_fall;              // 0=falling, 1=floating, 2=inheritz
var bool ena_2xzoom;                 // half tex resolution (digital zoom)
var bool ena_4xzoom;                 // quarter
var bool pw_sens_fire;               // true if user holds weaponfire
var float accumulated_pw_sens_fire;  // for full quality preview mode
var int mode_autospawn;              // 0=disable, 1=each 192, 2=each 128
var float autospawn_timer,
          autospawn_interval;
var float water_forcedodge_timer;    // fd related
var bool  wforcedodge_ready;
var int forcedodge_xdir,forcedodge_ydir;
var float autofly_set_timer, autofly_clr_timer, autofly_abort_timer;      // af/aw related
var byte autofly_trig;
var byte mode_step,mode_texsize;     // mode number of step/texture
var int size_step,size_tex;          // value of step/texture
var byte map_resolution;
var string new_clientmsg[2];         // p.clientmessage() analog
var float clientmsg_timer;
var float last_tick_f,last_tick_f_upd_timer; // framerate counter related
var float laser_wall_dist;           // how far to place laser blast off walls, mode 1
var float laser_ray_length;          // how close to place laser blast to player, mode 2
var byte SHR_Factor_scanmap;         // 3=div8, 96% of foundry fits in 512x512; 4=div16 etc
var byte SHR_Factor_prodmap;
const    SHR_Factor_default=2;
const    SHR_Factor_max=5;           // up to 7 supported
var STLight lightbeam;               // light blast
var STLaser laserdot;                // laser blast
var byte mode_laser;                 // 0=off, 1=inf, 2=finite
var trigger sens_trig;               // sensed trigger for controlling
var mover sens_mov;                  // sensed mover for controlling
var bool sens_ignore;
var bool ena_prod;                   // execute prod sequence if true
var byte order_welcome_msgs;
var float welcome_msgs_timer;
// ============================================================================================================
// CALIBRATION DATA. Added to eliminate magicnumbers from code.
// ============================================================================================================
const user_hold_health = 500;         // user hp
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
const max_size_tex = 1024;
const hardcode_scrw = 1920;
const hardcode_scrh = 1080;
// ============================================================================================================
var color           // UI color, set in postbeginplay()
   pc_blue,    pc_blue_f,    pc_orange,  pc_orange_f,  pc_brown,
   pc_bluer,   pc_bluer_f,   pc_green,   pc_green_f,   pc_brown_f,
   pc_yellow,  pc_yellow_f,  pc_pink,    pc_pink_f,    pc_bg,    pc_fill_bg,
   pc_cyan,    pc_cyan_f,    pc_pinker,  pc_pinker_f,  pc_gray,
   pc_teal,    pc_teal_f,    pc_red,     pc_red_f,     pc_wh,    pc_wh_f;
enum EKeyWhere{      // UI key event for anim
   kw_f1, kw_1, kw_7, kw_u, kw_r, kw_f,
   kw_f2, kw_2, kw_8, kw_o, kw_t, kw_v,
   kw_f7, kw_3, kw_z, kw_y, kw_h, kw_m, kw_n,
   kw_f4, kw_4, kw_x, kw_q, kw_lmb, kw_mmb, kw_rmb,
   kw_f5, kw_5, kw_b, kw_none, kw_ijkl, kw_pupd,
   kw_f8, kw_6, kw_g, kw_ent, kw_p, kw_f6};
var float      key_when;
var EKeyWhere  last_kw;
// ============================================================================================================
const pad_glob = 10; // <-- padding;  dimensions,       texdata             viewport
const pad_view = 12;            const fonw = 16;  const fillw = 23;  const vieww = 665;
const pad_fonh_half = 15;       const fonh = 29;  const fillh = 23;  const viewh = 375;    
                                           /* coords */        
const x_vp = 10; // viewport x; pad_glob       here and further, x_::: - static coord
const y_vp = 78; // viewport y; (2*pad_glob)+(2*fonh)           :::_x - dynamic
const y_about = 10; const x_about = 10; // about label
   /* col header; y=(3*pad_glob)+(2*fonh)+viewh+pad_fonh_half */         /* col text */
const y_hdr_oper = 478;     const x_hdr_oper = 42;     /* xpos 2  */  const x_col_oper = 10; // all text xpos-2
const y_hdr_map_ctl = 478;  const x_hdr_map_ctl = 266; /* xpos 16 */  const x_col_map_ctl = 234;
const y_hdr_lvl_ctl = 478;  const x_hdr_lvl_ctl = 490; /* xpos 30 */  const x_col_lvl_ctl = 458;
const y_hdr_user = 667;     const x_hdr_user = 58;     /* xpos 3 */   const x_col_user = 10; // user=oper+5.5lines
                                                                      const x_col2_user = 266; // xpos 16
const y_hdr_region = 667;   const x_hdr_region = 490;  /* xpos 30 */  const x_col_region = 458; // 1 line higher
const y_hdr_place = 827;    const x_hdr_place = 74;    /* xpos 4 */   const x_col_place = 10;  // user+4.5 lines
const y_hdr_mouse = 827;    const x_hdr_mouse = 490;   /* xpos 30 */  const x_col_mouse = 458;
const x_rcol = 1719; // right sidebar xpos 0; (3*pad_glob)+vieww+max_size_tex
const y_rcol_texdata = 10; // =pad_glob
const y_rcol_texdata_fill = 49; // =(pad_glob*2)+(fonh)
const y_rcol_player = 308; // =fill+(9*fillh)+(8*1)+pad_glob (+fonh)
const y_rcol_scope = 453; /* 5 lines lower */           const y_clientmsg = 90; // =(pad_glob*2)+(fonh*2)+pad_view
const y_rcol_align = 569; /* 4 lines lower */           const y_statusbar = 412; // =y_vp+viewh-pad_view-fonh
const y_rcol_region = 714; /* 4 lines lower */          const x_view_lpos = 22; //=pad_glob+pad_view
const y_rcol_lifetime = 830; /* 5 lines lower */           const x_view_rpos = 643; //=vieww-pad_glob+pad_view
const y_rcol_noob = 1041; // =hardcode_scrh-pad_glob-fonh   
// ============================================================================================================
// USER OPERATION MODE SWITCHING
// ============================================================================================================
exec function tog_opermode_uni(byte sw_to_oper){
//   local byte i;
   if(mode_oper == sw_to_oper) return;
   if(mode_oper==MO_WantDiag){ mode_oper=MO_Scan; return; }
   key_when = 0.3;        switch(sw_to_oper){
   case 0: last_kw=kw_f1;    mode_oper=MO_Scan;         n_region=9;     ena_2xzoom=true;  ena_4xzoom=false;
           SHR_Factor_scanmap=SHR_Factor_default;    upd_resolution();  ena_lockz=true;   ena_lockxy=true;
           mode_rayprocess = RP_ClientLike;             ena_player=true;
         /*  for(i=0;i<8;i++) enab_region[i]=0;  */                                                           break;
   case 1: last_kw=kw_f7;    mode_oper=MO_WantDiag;     n_region=9;


                                                                                                              break;
   case 2: last_kw=kw_f4; if(mode_oper==MO_WantDiag) return;
                             mode_oper=MO_Mark;         n_region=0;      ena_2xzoom=false; ena_4xzoom=false;
           SHR_Factor_scanmap=SHR_Factor_prodmap;    upd_resolution();   ena_lockz=false;  ena_lockxy=false;
           mode_rayprocess = RP_AllFast;                ena_player=true;   mode_laser=0;                        break;
   case 3: last_kw=kw_f8; if(mode_oper==MO_WantDiag) return;
                             mode_oper=MO_Prod;         n_region=0;      ena_2xzoom=false; ena_4xzoom=false;
           SHR_Factor_scanmap=SHR_Factor_prodmap;    upd_resolution();   ena_lockz=false;  ena_lockxy=false;
           mode_rayprocess = RP_SelFull;                ena_player=false;   mode_laser=0;                        break;
   case 4: last_kw=kw_f6; if(mode_oper==MO_WantDiag) return;
                          if(mode_oper!=MO_LifetimeCfg){ mode_oper=MO_LifetimeCfg; mode_ltcfg=LTC_Floordist; }
                 else{       mode_oper=MO_Scan;         n_region=9;      ena_2xzoom=true;  ena_4xzoom=false;
           SHR_Factor_scanmap=SHR_Factor_default;    upd_resolution();   ena_lockz=true;   ena_lockxy=true;
           mode_rayprocess = RP_ClientLike;             ena_player=true;         }                              break; }
} 
// ============================================================================================================
// USER REGION SELECT/TOGGLE + CONFIRM MEM-DESTRUCTIVE ACTIONS
// ============================================================================================================
exec function tog_region_uni(byte new_nregion){
   local bool bFailConf;
   if(new_nregion>7) return;
   if(mode_oper==MO_WantDiag && new_nregion<=3) goto user_validation_uni;
   if(mode_oper!=MO_Mark && mode_oper!=MO_Prod) return;
   n_region = new_nregion;
   enab_region[n_region] = enab_region[n_region]==1 ? 0 : 1;
   return;
   user_validation_uni:
   bFailConf = false;
   switch(new_nregion+1){
      case 1: if(mode_confirm==MC_Reset)             mode_confirm=MC_Doit;              else bFailConf = true; break;
      case 2: if(mode_confirm==MC_Doit)              mode_confirm=MC_Yesimsure;         else bFailConf = true; break;
      case 3: if(mode_confirm==MC_Yesimsure)         mode_confirm=MC_Stopfuckingasking; else bFailConf = true; break;
      case 4: if(mode_confirm==MC_Stopfuckingasking) mode_confirm=MC_Confirmed;         else bFailConf = true; break;
   }
   if(bFailConf) do_fail_confirm();
   if(mode_confirm==MC_Confirmed){
      do_diag_z();
      tog_opermode_uni(2);
   }
}
// ============================================================================================================
// FLOOR
// ============================================================================================================
exec function tog_layerz_assign(){
   local byte mod_pointer;
   if(alignz_seek>0) mod_pointer=1; else mod_pointer=0;
   if( presets_z[n_layerz]==presets_z[region_usefloor[alignz_seek-mod_pointer]]
    && n_region==region_usedby[alignz_seek-mod_pointer]){
      region_usefloor[alignz_seek-mod_pointer] = 0;           // already exists, clear usagemap element
      region_usedby[alignz_seek-mod_pointer] = 9;
      if(alignz_seek>0) alignz_seek--;
   }else{
      region_usefloor[alignz_seek] = n_layerz;    // write
      region_usedby[alignz_seek] = n_region;
      if(alignz_seek<62) alignz_seek++;
   }
}
// ============================================================================================================
// USER MACROS
// ============================================================================================================
exec function init(){ playselect(); } // Used for recall hotkeys upon loadgame if read-only user.ini
exec function diag(){ do_diag_z(); }  // Invoke diag proc without confo. Destroys all AlignZ selection data.
// Old code `spawn(class'pnze');` makes rediag necessary, bc map pays attention to normal PathNode locations
// only, not PathNodeRuntime as well. This was causing map gaps in AI-unkn spots in case of vert mismatch.
exec function savecfg(){ saveconfig(); }  // scitools.ini mgmt
exec function readcfg(){ resetconfig(); }
// ============================================================================================================
// SERVICES
// ============================================================================================================
function performdodge(playerpawn p){
   local vector x,y,z;
   local rotator r;
   if(p.Physics==PHYS_Walking && (forcedodge_xdir!=0 || forcedodge_ydir!=0)){
      getaxes(p.rotation,x,y,z);
      p.velocity = (forcedodge_xdir*1.5*p.groundspeed+p.velocity dot x)*x +
                   (forcedodge_ydir*1.5*p.groundspeed+p.velocity dot y)*y;
      p.velocity.z = 160;
      p.PlayOwnedSound(p.JumpSound, SLOT_Talk, 1.0, true, 800, 1.0);
      p.SetPhysics(PHYS_Falling);
   }else if(p.Physics == PHYS_Swimming){
      if(!wforcedodge_ready) return;
      p.waterspeed = 45000;
      p.Velocity = vector(p.viewrotation) * 2000;
      r = p.viewrotation;
      r.pitch = r.pitch % 65536;
      if(r.pitch > 32768) r.pitch -= 65536;
      if(r.pitch > 3000) p.Velocity.Z = 640;
      wforcedodge_ready = false;
      water_forcedodge_timer = 0.2;
   }
}

function bool mb_fail_confirm(){  // called from all kbd functions
   if(mode_oper!=MO_WantDiag) return false;
   do_fail_confirm();
   return true;
}
function do_fail_confirm(){
   mode_confirm = MC_Reset;         // reset confirm progress if any wrong key
   mode_oper = MO_Scan;
   new_clientmsg[0] = "AreaZ[] set diag sequence";
   new_clientmsg[1] = "has been cancelled.";
   clientmsg_timer = 2.5;
}
function upd_size_step(){  switch(mode_step){
   case 0: size_step = map_resolution*1;  break;
   case 1: size_step = map_resolution*8;  break;
   case 2: size_step = map_resolution*64; break; }
}
function upd_size_tex(){  switch(mode_texsize){
   case 0: size_tex = 256;  break;
   case 1: size_tex = 512;  break;
   case 2: size_tex = 1024; break; }
}
function upd_resolution(){  switch(SHR_Factor_scanmap){
   case 1: map_resolution = 2;   break;
   case 2: map_resolution = 4;   break;
   case 3: map_resolution = 8;   break;
   case 4: map_resolution = 16;  break;
   case 5: map_resolution = 32;  break;
   case 6: map_resolution = 64;  break;
   case 7: map_resolution = 128; break; }
}
function color color_region(byte num, bool bfade){  switch(num){
   case 0: return !bfade ? pc_blue   : pc_blue_f;   break;
   case 1: return !bfade ? pc_yellow : pc_yellow_f; break;
   case 2: return !bfade ? pc_cyan   : pc_cyan_f;   break;
   case 3: return !bfade ? pc_orange : pc_orange_f; break;
   case 4: return !bfade ? pc_green  : pc_green_f;  break;
   case 5: return !bfade ? pc_pink   : pc_pink_f;   break;
   case 6: return !bfade ? pc_red    : pc_red_f;    break;
   case 7: return !bfade ? pc_brown  : pc_brown_f;  break;
   case 9: return !bfade ? pc_brown  : pc_brown_f;  break; } return pc_gray;
}
function string now_confirmed(EConf conf_stage){  switch(conf_stage){
   case MC_Reset:             return "0"; break;
   case MC_Doit:              return "1"; break;
   case MC_Yesimsure:         return "2"; break;
   case MC_Stopfuckingasking: return "3"; break;
   case MC_Confirmed:         return "4"; break; } return "0";
}
function string now_rayprocessing(ERayPrc rp_state){  switch(rp_state){
   case RP_SelFull:    return "SEL FULL"; break;
   case RP_AllFast:    return "ALL FAST"; break;
   case RP_AllFullEco: return "ALL STD"; break;
   case RP_ClientLike: return "RELEVANT"; break;
   case RP_ClientFull: return "REL FULL"; break; } return "";
}
/*function int maptex_centering(int now_size_tex){  switch(now_size_tex){
   case 256: return 384; break;
   case 512: return 256; break;
   case 1024: return 0; break; } return 0;
}*/
function adv_welcome_msgs(){
   if(order_welcome_msgs>5){
      welcome_msgs_timer = 9999.0;
      return;
   }
   order_welcome_msgs++;
   welcome_msgs_timer = 9.0;       switch(order_welcome_msgs){
   case 1: new_clientmsg[0]="Welcome to AMS. Type mapinit in console";
           new_clientmsg[1]="to autospawn DPN in premapped spots.";    clientmsg_timer=8.7; break;
   case 2: new_clientmsg[0]="This operation will create extra actors";
           new_clientmsg[1]="and intended to protect vs overspawn;";   clientmsg_timer=8.7; break;
   case 3: new_clientmsg[0]="it can't be placed into postbeginplay()";
           new_clientmsg[1]="because AMS weapon may be spawned again"; clientmsg_timer=8.7; break;
   case 4: new_clientmsg[0]="accidentally by user. Existing DPNs are";
           new_clientmsg[1]="never autoremoved to keep map data.";     clientmsg_timer=8.7; break;
   case 5: new_clientmsg[0]="Ready.";
           new_clientmsg[1]="";    clientmsg_timer=2.0; break;  }
}

// ============================================================================================================

exec function sci_forcedodge(){
   local playerpawn p;   // required
   p = playerpawn(owner);
   if(p == none) return;
   forcedodge_xdir = 0; forcedodge_ydir = 0;
   if(p.bwasforward) forcedodge_xdir = 1;
   if(p.bwasback)    forcedodge_xdir = -1;
   if(p.bwasleft)    forcedodge_ydir = 1;
   if(p.bwasright)   forcedodge_ydir = -1;
   if(forcedodge_xdir == 0 && forcedodge_ydir == 0) return;
   performdodge(p);
}

exec function mark_current_region(){
   if(mb_fail_confirm()) return;
   if(mode_oper!=MO_Mark) return;
   key_when = 0.3; last_kw = kw_m;
   if(n_region>7) return;  // prohibit access outside of array
   enab_region[n_region] = 1;
   region_align[n_region].x = global_offset_x;
   region_align[n_region].y = global_offset_y;
   region_scale[n_region] = map_resolution; //SHR_Factor_prodmap;   // behave as SHR_factor
   region_sizetex[n_region] = size_tex;
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
      log("   SHR_factor="$SHR_Factor_prodmap,'AMS');
      log("   FloorHeight="$vert_discretization,'AMS');
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

exec function q(){
   local playerpawn p;
   if(owner==none) return;
   p = playerpawn(owner);
   if(p==none) return;
   p.clientmessage("Welcome to AMS - semiautomatic areamap production tool.");
   p.clientmessage(" ");
   p.clientmessage("AMS use PathNode runtime-placeable equivalent as epicenters of raytracing");
   p.clientmessage(" to construct hull/walls and solid collision. Due to collision reactivity with");
   p.clientmessage(" bCollideActors, most puckups and deco are auto-removed. You can clean excessive");
   p.clientmessage(" scan obstacles in PNG editor.");
   p.clientmessage("Your task is to spawn PathNodeRuntime, or dummy pathnodes, DPN, on level -");
   p.clientmessage(" lots enough to do effective walls scan, though less enough to don't cause");
   p.clientmessage(" FPS freeze. Always remember, Unreal Virtual Machine works in single-thread");
   p.clientmessage(" manner on single core of CPU. Because of this, even if you have very powerful");
   p.clientmessage(" processor such as latest Ryzens, excessive raycasting will eat framerate.");
   p.clientmessage("In build, or DPN placement mode, many measures were taken to minimize load.");
   p.clientmessage(" Laggy performance while max quality mode won't be long; after export is");
   p.clientmessage(" done, AMS will return to build mode.");
   p.clientmessage("This version almost got rid of scanning artifacts, but this may lead to some");
   p.clientmessage(" objects inconsistency. This behavior fixed by special mode of scanning actors");
   p.clientmessage(" when placing these, called strict walls/directional anywalls. Even hill/slope");
   p.clientmessage(" will count as \"wall\", so directional DPNs must have correct scan angle and");
   p.clientmessage(" rotation to minimize artifacts.");
   p.clientmessage(" ");
   p.clientmessage("Navigation:");
   p.clientmessage("W/A/S/D, Spc, C - regular move.");
   p.clientmessage("Alt - single-key dodge. Used in pair with dodge direction keys (move keys).");
   p.clientmessage(" If player stand still, does nothing. Diagonal directions are auto-detected.");
   p.clientmessage(" In water, just increase speed shortly. Acts as some kind of flying replacement.");
   p.clientmessage(" Repeat C three times - request autofly mode. Repeat time window is 0.4/0.4 sec.");
   p.clientmessage(" Acts same as \"fly\" console command. If user flying no higher than 56uu from");
   p.clientmessage(" floor surface, autowalk will be triggered. Autofly step resets in 1.2 sec.");
   p.clientmessage("P - disable water flag of current zone. This action can't be undone.");
   p.clientmessage(" Use \"editactor class=zoneinfo\" console command to revert the effect.");
   p.clientmessage(" Pain flag is always auto-disabled in all zones. Player is set to amphibious.");
   p.clientmessage(" ");
   p.clientmessage("Zooms, steps/scale related:");
   p.clientmessage("Z, X - digital and spatial zoom. Digital zoom enlarge map pixels, can be set to");
   p.clientmessage(" 1x, 2x, 4x. Spatial zoom controls SHR_Factor, or actual vectors division.");
   p.clientmessage(" More divided coords means less level area, i. e. more zoom. Can be set to");
   p.clientmessage(" these factors: 1px = 32uu, 16uu, 8uu, 4uu, 2uu. Both types of zoom cause less");
   p.clientmessage(" CPU load due to less processing.");
   p.clientmessage("B - control step size of map offset, when horizontal lock (aka lock XY)");
   p.clientmessage(" disabled. Spoken terms are described further.");
   p.clientmessage("G - control the size of map black texture, aka region size. Both controls");
   p.clientmessage(" are working in zoom manner (key toggle 3 values).");
   p.clientmessage(" ");
   p.clientmessage("Lock/offset:");
   p.clientmessage(" ");
   p.clientmessage("U - LockZ aka lock layer - snap map vertically, or inherit AreaZ from PlayerZ.");
   p.clientmessage(" Good for realtime scan result preview.");
   p.clientmessage("O - LockXY - snap center of map to center of player X;Y coords in level. Making");
   p.clientmessage(" search of player marker less necessary.");
   p.clientmessage("R - toggle axis which will be altered by mouse wheel, with selected step size.");
   p.clientmessage("I/J/K/L - horizontal offset, acts same as mouse wheel in X, Y mode.");
   p.clientmessage("PgUp/PgDn - vertical offset, same as wheel in Z mode. Controls AreaZ presets,");
   p.clientmessage(" which can be obtained by diag mode.");
   p.clientmessage(" ");
   p.clientmessage("User/misc features:");
   p.clientmessage("T - toggle mover ignore. Useful for eliminating horizontal lifts as obstacle.");
   p.clientmessage("Y - searchlight. Useful in very dark places of level.");
   p.clientmessage("Q - toggle laser mode; off, infinite minus some distance from walls, or finite");
   p.clientmessage(" with max length from player. Infinite laser is colliding, finite laser is always");
   p.clientmessage(" ghostmode. Useful for DPN placement in player-unreachable spots. Any mode");
   p.clientmessage(" of laser switch coords monitor to show laser instead of player. Used to create");
   p.clientmessage(" map reactors (interactive regions of player interest such as open/closed doors,");
   p.clientmessage(" fences, inactive/active lifts etc). Laser show nowspawning DPN render result");
   p.clientmessage(" as pink color walls of map.");
   p.clientmessage("F5 - player marker (off, small blinking, big yellow dot or directional arrow).");
   p.clientmessage(" ");
   p.clientmessage("DPN (dummy pathnode) placement:");
   p.clientmessage("F - let them sit in spawned area (flying), autofall on floor (with floordist)");
   p.clientmessage(" or copy height of player (inherit z)");
   p.clientmessage("V - autospawn them");
   p.clientmessage("H - toggle directional mode with setting of horizontal scan angle. These DPNs");
   p.clientmessage(" produce rendering artifacts if pointed to incorrect places such as walkable");
   p.clientmessage(" hills, floors, slopes, climbable rocks. Regular DPNs protecting from artifacts");
   p.clientmessage(" by checking wall vertical angle, but won't recognize some unwalkable obstacles");
   p.clientmessage(" and show these as empty space.");
   p.clientmessage("Mid mouse/wheel press - spawn DPN in manual mode. Always available.");
   p.clientmessage("Right mouse - kill all pawns in level and remove DPNs in area. Spawn/remove");
   p.clientmessage(" does respecting laser, which is useful for increased precision DPNs placement.");
   p.clientmessage(" ");
   p.clientmessage("Left mouse:");
   p.clientmessage("-> When laser is off, open by trigger. All triggers are active, triggerable,");
   p.clientmessage(" norepeatable. If movers tagged to trigger, these will be started (executes");
   p.clientmessage(" mover.trigger() or mover.untrigger() on them). Untrigger() call is disabled");
   p.clientmessage(" by default; this behavior controlled by bUseUntrigger variable in scitools.ini");
   p.clientmessage("-> When laser is on, open by mover.");
   p.clientmessage("-> Always, when held for more than 0.6 sec,");
   p.clientmessage(" enable better quality of map scan for quick preview.");
   p.clientmessage(" ");
   p.clientmessage("Operation mode:");
   p.clientmessage("F1 - build bode. Used for DPN placement and convenient navigation by map.");
   p.clientmessage(" Sets these display behavior defaults:");
   p.clientmessage(" -> 2x digital zoom    -> 4uu spatial zoom");
   p.clientmessage(" -> lockZ, lockXY enabled     -> player marker set to directional");
   p.clientmessage("F4 - region markup mode. Used for final align assign layers to certain regions.");
   p.clientmessage(" Sets these defaults:");
   p.clientmessage(" -> 1x digital zoom    -> 16uu spatial zoom");
   p.clientmessage(" -> max quality     -> both lockZ and lockXY disable    -> player hidden");
   p.clientmessage("F7 - region reconstruct mode, aka AreaZ diagnostics. Performs these actions:");
   p.clientmessage(" -> all DPNs in level will be collected, and their Z roughed");
   p.clientmessage("  according to Z discretization (explained further).");
   p.clientmessage(" -> remove non-unique and sorted;");
   p.clientmessage("  if set exceed 63 elements of array, more will be ignored");
   p.clientmessage(" Diag mode may make already used region info irrelevant, so use it before");
   p.clientmessage(" markup, or with caution. Protected by four keys confirmation");
   p.clientmessage(" (press 1, 2, 3, 4 sequence) to prevent invoking this accidentally.");
   p.clientmessage("F8 - production mode. Auto scroll all regions and their layers, screenshoting");
   p.clientmessage(" the result, writes .uc package template and .bat script template to unreal.log;");
   p.clientmessage(" use text editor to correct these files to your needs.");
   p.clientmessage(" You can obtain list of screenshots sorted by creation time with command:");
   p.clientmessage(" X:\\\%unreal%\\system\\screenshots> dir /od /tc /b /a-d > file.bat");
   p.clientmessage(" ");
   p.clientmessage("Config variables (scitools.ini):");
   p.clientmessage("vert_discretization - AreaZ sensitivity, the height of zone where actual map");
   p.clientmessage(" layer shows certain texture");
   p.clientmessage("vert_floordist - height of most DPNs relative to floor;");
   p.clientmessage(" classic unreal dist is 61uu, narrow floor - 24, narrower - 12");
   p.clientmessage(" narrower may cause some artifacts and excessive lines on stairsteps due to");
   p.clientmessage(" their typical 16uu height.");
   p.clientmessage("bDisableAllBtnsNotify - do not rogerblink pressed key name in the interface");
   p.clientmessage("bDisableLRmouseNotify - do not blink for left/right mouse buttons, even if");
   p.clientmessage(" other keys still enabled");
   p.clientmessage("bEnableMmouseNotify - blink for mid mouse button as well");
   p.clientmessage(" ");
   p.clientmessage("Regions and prepare to prod:");
   p.clientmessage("1-8, incl numpad keys - select/toggle region.");
   p.clientmessage("M - mark region.");
   p.clientmessage(" Map align on X;Y axis, texture size, spatial zoom will be overwritten.");
   p.clientmessage("Enter - fill current layer number (aka diag result Z from set) to current");
   p.clientmessage(" region. Keep X;Y offset unchanged for correct map working in this area.");
   p.clientmessage(" Already existing Z in current region, if matched, will be removed");
   p.clientmessage(" if Enter pressed twice; this is how region layer toggle working.");
   p.clientmessage(" For region occupy navigation, no additional keys implemented, due to lots");
   p.clientmessage(" of keys used already.");
   p.clientmessage(" ");
   p.clientmessage("Render:");
   p.clientmessage("F2 - toggle render mode");
   p.clientmessage("Leftmouse hold - preview full quality in player area or layer matching by Z.");
   p.clientmessage(" ");
   p.clientmessage("Tips on how to define regions:");
   p.clientmessage("-> use ALL FAST render mode to preview/positioning overall level");
   p.clientmessage("-> keep regions edges with zero distance; adjacent region border may disappear");
   p.clientmessage(" just right 1px far, but not more (2px gap will result in 1px seam on map)");
   p.clientmessage("-> always use same spatial zoom;");
   p.clientmessage(" inconsistent scale of coords WILL cause align error");
   p.clientmessage("-> regions may overlap, but of course this produce some excessive drawcalls");
   p.clientmessage(" ");
   p.clientmessage("Prod mode requirements:");
   p.clientmessage("-> at least one Z preset in TexData[] array");
   p.clientmessage(" (press Enter at least once, in at least one region).");
   p.clientmessage(" ");
   p.clientmessage("Viewport statusbar:");
   p.clientmessage("First number - digital zoom");
   p.clientmessage("Second, before slash - map spatial zoom, after - prod texture spatial zoom");
   p.clientmessage(" (aka prod SHR_Factor of .uc template)");
   p.clientmessage("Third number - framerate counter");
   p.clientmessage("Fourth number - total DPNs in mathing by Z layer / total DPNs in level");
   p.clientmessage(" ");
   p.clientmessage("Console commands:");
   p.clientmessage("init - execute playselect() again, restores all binds;");
   p.clientmessage(" useful if user.ini is read-only");
   p.clientmessage("diag - same as switching to diag mode, do Z set diagnostics+store+sort;");
   p.clientmessage(" may corrupt region/texdata.");
   p.clientmessage("savecfg - store current globalconfig variables to scitools.ini");
   p.clientmessage("readcfg - read them from scitools.ini");
   p.clientmessage(" ");
   p.clientmessage("Greetz: Omega, Fumbles McStupid, Aspide, Krull0r, Metallicafan212, Sly.,");
   p.clientmessage(" >K*S*A<Hybz, (T:S:B)IceLizard, Xaleros, AlCapowned, apjcts and rest of");
   p.clientmessage(" OldUnreal/UnrealSP people and others who I forgot to mention. I wrote");
   p.clientmessage(" lots of advanced code past time and it wouldn't be possible without help");
   p.clientmessage(" of others.");
   p.clientmessage(" ");
   p.clientmessage("After all data prepared, AMS works unattended, just enable prod mode and");
   p.clientmessage(" wait for all screenshots will be taken. Then you can cut them, edit if");
   p.clientmessage(" you want in any graphics software, then prepare your package files and");
   p.clientmessage(" use UCC to compile. For cutting screenshoted maps (from fullscreen FHD to");
   p.clientmessage(" square map region), FFMPEG is required.");
   p.clientmessage(" It can be installed from https://www.gyan.dev/ffmpeg/builds/");

   return;
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
   local playerpawn p;
   if(owner == none) return;
   p = playerpawn(owner);
   if(p == none) return;
   p.health = user_hold_health;                    // prevent drown death
   if(p.velocity.z <= -900) p.velocity.z = -900;   // prevent fall death

   if(bDisableAllBtnsNotify) key_when = 0.5;       // keyboard process
      else key_when -= f;
   if(key_when<0 && last_kw!=kw_none) last_kw = kw_none;

   water_forcedodge_timer -= f;               // water forcedodge process
   if(water_forcedodge_timer < 0.0){
      wforcedodge_ready = true;
      p.waterspeed = 200;
   }

// todo autokill pawns instead of shield

   pw_sens_fire = (p.bFire!=0);             // preview full rmode process
   accumulated_pw_sens_fire += f;
   if(!pw_sens_fire) accumulated_pw_sens_fire = 0;

   getaxes(p.viewrotation,x,y,z);
   if(mode_laser != 0){
      sens_mov = mover(trace(hl,hn,p.location + 4000*x,p.location,true));
      sens_ignore = sens_mov.group == 'sciignore';
      sens_trig = none;
      if(mode_laser == 1){
         z.z = hl.z;
      /* if(rotator(hn).pitch <= anti_artifacts_maxslope) */ hl += hn*laser_wall_dist; // 2026-01-16: offset laser off all surfs, not walls only
         hl.z = z.z;
      }else if(mode_laser == 2){
         hl = p.location;
         hl += vector(p.viewrotation)*laser_ray_length;
      }
      laserdot.setlocation(hl); // todo overwrite falling z coord altering into hl.z
   }else{
      sens_trig = FindTrigger(p.location);
      sens_mov = none;
   }

/* laserorigin = p.location;
   getaxes(p.viewrotation,x,y,z);
   laserorigin += z*2;
   laserorigin += y*4;
   Trace(HitLoc,HitNor,EndTrace,laserorigin + 15000*x,True);
   hitloc -= x*7;
   laserdist = vsize(p.location - hitloc); */

   autofly_set_timer -= f;
   autofly_clr_timer -= f;
   autofly_abort_timer -= f;
   autospawn_timer -= f;
   clientmsg_timer -= f;
   scrshot_timer -= f;
   last_tick_f_upd_timer -= f;
   welcome_msgs_timer -= f;

   if(lightbeam != none && lightbeam.LightType == LT_Steady){
      r = p.viewrotation;
      lightbeam.setlocation(p.location);
      r.pitch -= searchlight_direction;
      lightbeam.setrotation(r);
   }

   if(welcome_msgs_timer<=0) adv_welcome_msgs();   // initial msgs process

   if(clientmsg_timer<=0){       // info msg process
      new_clientmsg[0] = "";
      new_clientmsg[1] = "";
   }
   if(mode_autospawn!=0 && autospawn_timer<=0 && mode_laser==0){   // dpn placement process
      if(p.physics == PHYS_Walking) sci_scripted_dpn_spawn(p.location);
      autospawn_timer = 0.2;
   }
   if(last_tick_f_upd_timer<=0){     // frametime monitor process
      last_tick_f_upd_timer = 1.0;
      last_tick_f = f;
   }

   if(autofly_set_timer<0 && p.bIsCrouching){
      autofly_trig++;
      new_clientmsg[0] = "Autofly: "$autofly_trig$"/3";
      new_clientmsg[1] = "Repeat crouch to trigger.";
      clientmsg_timer = 1.2;
      autofly_set_timer = 0.4;
      autofly_abort_timer = 1.2;
      if(p.physics==PHYS_Walking && autofly_trig >= 3){
         new_clientmsg[0] = "Autofly invoked.";
         new_clientmsg[1] = "Takeoff within 4 sec.";
         clientmsg_timer = 2.5;
         autofly_abort_timer = 4.0;
         autofly_trig = 1;
         p.consolecommand("fly");
      }
      if(!p.bIsCrouching) autofly_clr_timer = 0.8;
   }
   if(p.physics==PHYS_Walking && autofly_clr_timer<0){
      if(p.bIsCrouching) autofly_trig = 0;
      autofly_clr_timer = 0.4;
   }
   if(autofly_abort_timer<0 && autofly_trig>0){
      if(p.physics==PHYS_None){
         getaxes(p.rotation,x,y,z);
         trace(hl,hn,p.location - 4000*z,p.location,true);
         if(vsize(hl-p.location)<=56){
            new_clientmsg[0] = "Autowalk invoked.";
            clientmsg_timer = 2.5;
            autofly_trig = 0;
            autofly_set_timer = 4.0;
            p.consolecommand("walk");
         }
      }else autofly_trig = 0;
   }
}

function trigger FindTrigger(vector search_location){
   local trigger t;
   foreach RadiusActors(class'trigger', t, sens_trig_radius){
      if(vsize(t.location-search_location) <= t.CollisionRadius) return t;
   }
   return none;
}

exec function tog_light(){
   if(mb_fail_confirm()) return;
   key_when = 0.3; last_kw = kw_y;
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

// todo: laser mesh, selectable pnz trunc
// todo: welcome dialog

function int draw_key_help(canvas c, color dc, string hk, string desc, int from_x, int from_y){
   local int desc_x,lx,ly;
   desc_x = (len(hk)+1)*fonw; // offset 1 xpos to descr
   lx = from_x; ly = from_y;
   c.drawcolor = pc_wh_f;
   c.setpos(lx,ly);  c.drawtext(hk);
   if(hk!="") lx += desc_x;   // do not apply offset if empty hotkey
   c.drawcolor = dc;
   c.setpos(lx,ly);  c.drawtext(desc);
   return ly+fonh;            // move 1 ypos down
}

function int draw_key_action(canvas c, color dc, ekeywhere evs, string hk, string desc, int from_x, int from_y){
   local int desc_x,lx,ly;
   desc_x = (len(hk)+1)*fonw; // offset 1 xpos to descr
   lx = from_x; ly = from_y;
   if(last_kw==evs && last_kw!=kw_none){
      if(key_when >= 0.40){ c.drawcolor = pc_wh;   goto dka_pc_ready; } // reserved for disable blinking
      if(key_when >= 0.25){ c.drawcolor = pc_cyan; goto dka_pc_ready; } // blinking, frame 1
      if(key_when >= 0.15){ c.drawcolor = pc_red;  goto dka_pc_ready; } // frame 2
      if(key_when >= 0.05)  c.drawcolor = pc_cyan;                      // frame 3
      dka_pc_ready:
   }else{
      c.drawcolor = pc_wh;                                  // dim white keybar shithacks:
      if( evs==kw_t && sens_mov==none)                             c.drawcolor = pc_gray; // no mover to ignore
      if( evs==kw_ijkl && ena_lockxy && mode_oper!=MO_LifetimeCfg) c.drawcolor = pc_gray; // no ijkl, snapped to player
      if((evs==kw_m || evs==kw_ent)  && mode_oper!=MO_Mark)        c.drawcolor = pc_gray; // not in markup mode for mark/assign
      if( evs==kw_p && dc!=pc_orange)                              c.drawcolor = pc_gray; // zone is not water
   }
   c.setpos(lx,ly);  c.drawtext(hk);
   if(desc=="") return ly;    // abort if empty
   if(hk!="") lx += desc_x;   // do not apply offset if empty hotkey
   c.drawcolor = dc;
   c.setpos(lx,ly);  c.drawtext(desc);
   return ly+fonh;            // move 1 ypos down
}

function draw_lifetime_sel(canvas c, ELTCfg now_ltc, int xpos, int ypos){
   if(mode_oper!=MO_LifetimeCfg) return;
   if(mode_ltcfg!=now_ltc) return;
   c.setpos(xpos-112, ypos);
   c.drawcolor=pc_wh; c.drawtext("---->");
}

function postrender(canvas c){
   local int upx,upy; // ui pos x,y
   local color pc_tmp;  // tmp presetcolor
   local vector vect_tmp;
   local bool bool_tmp;
   local float resolution_error;
   local int region_area;
   // new vars ends
   local actor rtarg;
   local vector x,y,z,endtrace,hl,hn;
   local string str_tmp;
   local rotator r;
   local float rotr;  // radians rotation
   local byte nmarker;
// local pathnode pn;
   local pathnoderuntime pn;
//   local pathnode pns; // static
   local int hlx,hly,mkx,mky;
   local int marked_error;
   local playerpawn p;
   local int sel_z;
   local int pn_tot,pn_mz, /*pn_rad,*/ rc_tot; // pathnode total qty, matchz qty, radius, rays cast total
   local int i,j,k;
   local byte nframe;
   local float pnz;
   local bool nomatch_z; // this z does not match current sel_z or lock_z
   p = playerpawn(owner);
   if(p==none || inv_finfo==none || lightbeam==none || laserdot==none) return;
   if(ena_lockxy){              // read it here because faster than tick()
      global_offset_x = (-1) * p.location.x;
      global_offset_y = (-1) * p.location.y;
   }
   bOwnsCrosshair=true;
   c.font = inv_finfo.GetInvFont();
   pn_tot = 0;
   // overall bg ----------------------------------------------------------------------
   c.drawcolor = pc_bg;
   c.setpos(0,0); c.drawtile(texture'scipixel', c.clipx, c.clipy, 0,0,4,4);
   // size_tex area -------------------------------------------------------------------
   c.drawcolor = pc_bg;
   if(size_tex<max_size_tex){
      c.setpos(hud_maptex_offset_x,hud_maptex_offset_y);
      c.drawtile(texture'scinoblk', max_size_tex, max_size_tex, 0,0,256,256);
      c.setpos(hud_maptex_offset_x, hud_maptex_offset_y+size_tex);
      c.drawtile(texture'scipixel', size_tex+3, 3, 0,0,4,4);
      c.setpos(hud_maptex_offset_x+size_tex, hud_maptex_offset_y);
      c.drawtile(texture'scipixel', 3, size_tex, 0,0,4,4);
   }
   c.setpos(hud_maptex_offset_x+region_area,hud_maptex_offset_y+region_area);
   c.drawtile(texture'scipixelblk', size_tex, size_tex, 0,0,4,4);
//----- layer raytracer ------------------------------------------------------
   sel_z = ena_lockz ? int(p.location.z - player_vs_dpn_addz) : presets_z[n_layerz]; // select scanned layer
   rc_tot = 0;
   pn_mz = 0;
   foreach allactors(class'pathnoderuntime',pn){
      pn_tot++;
//----- layers ignorator ---------------------------------------
      pnz = pn.location.z % vert_discretization;  // eliminate z deviations to vert resolution
      pnz = pn.location.z - pnz;
      nomatch_z = (abs(sel_z - pnz) > vert_discretization);   // was 16/64 = +25% overlapping of discretized area
      // todo why this behave other than diagz layers? respect vert_discr
      // todo rename it to floorheight
      // TODO: MANUAL Zset write mode, red/cyan apples, some sort of "use this floor".
      // TODO write doku how to define them, incl write bottom/ceil Z to paper and calc middleval, mb adjust floorheight
      // ?????????? per-layer floorheight (imo shit)
      if(mode_rayprocess==RP_SelFull && nomatch_z) continue; // we maybe still process further in fullcolor map mode
      if(!nomatch_z) pn_mz++;
//----- dist ignorator ---------------------------------------
      x = pn.location;   // cancer code: we use x y z vars for things not meaning coords
      pnz = map_resolution * size_tex / 2;  // max map hull bounds for raytracing centers
      pnz += 540;                           // + bit more than trace length
      if(ena_2xzoom) pnz = pnz>>1;          // ignore 75% of area if 2x zooming
      if(ena_4xzoom) pnz = pnz>>1;          // ignore 93% of area if 4x zooming
     // pn_rad = pnz; // ???????? no idea for what it, mb remove ???????
      if(mode_rayprocess!=RP_SelFull){ // always render all pathnodes in all_selected mode
         if((abs(x.x + global_offset_x) > pnz)
         || (abs(x.y + global_offset_y) > pnz)) continue;
      }  // in other modes, if PN/DPN far far outside of texture, try to eat less CPU
//--------------------------------------------------------------
      r.yaw = 0;  r.roll = 0; r.pitch = 0;
      while(r.yaw<65536){
         getaxes(r,x,y,z);
         endtrace = pn.location + 768.0*x;   // scan dist
         rtarg = trace(hl,hn,endtrace,pn.location,true);
         hlx = (hl.x>>SHR_Factor_scanmap);
         hly = (hl.y>>SHR_Factor_scanmap);
         hlx += (size_tex>>1); hlx += (global_offset_x >> SHR_Factor_scanmap);
         hly += (size_tex>>1); hly += (global_offset_y >> SHR_Factor_scanmap);
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
         // -----------------------------------------
         if( hlx<hud_maptex_offset_x          || hly<hud_maptex_offset_y          ||
             hlx>hud_maptex_offset_x+size_tex || hly>hud_maptex_offset_y+size_tex  )
             goto skip_by_drawmap_outtexbounds;
         // -----------------------------------------
         c.drawcolor = pc_wh;
         if(mode_rayprocess==RP_ClientLike && nomatch_z){
            if       (SHR_Factor_scanmap<=2) c.drawcolor = makecolor(155,203,155);  // todo change to presets
             else if (SHR_Factor_scanmap==3) c.drawcolor = makecolor(112,112,160);
             else                        c.drawcolor = makecolor(80,80,128);
         }
         if(pn==laserdot) c.drawcolor = pc_pinker;
//       if(abs(rotator(hn).pitch) <= anti_artifacts_maxslope){ // old code // todo strictwalls here
         if(    rotator(hn).pitch  <= anti_artifacts_maxslope){ // allow negative slope as well
                  // todo
                  // mb allow climbable in very close dist, for boxes on foundry [-440;-543;-1500]
            pnz = 0.25;             // cancer code but safe to use pnz here
            if(ena_2xzoom) pnz = 0.5;
            if(ena_4xzoom) pnz = 1.0;
            if(rtarg.group!='sciignore'){
               c.setpos(hlx,hly);  c.drawicon(texture'scipixel',pnz);
            }
         }
         skip_by_drawmap_outtexbounds:
         if(mode_rayprocess!=RP_SelFull) pnz = advance_ray_pos_std;   // assign rays density, full quality for mode 0 only
          else pnz = advance_ray_pos_full;
         if(mode_rayprocess==RP_AllFast) pnz = advance_ray_pos_fast;  // skip rays in mode 1, to 8x faster
         if(nomatch_z) pnz = advance_ray_pos_fast;           // skip mismathing by z
         if(mode_rayprocess==RP_ClientLike                               // skip in mode 3
            && vsizesq(pn.location - p.location)>max_fastscan_vsizesq) // outside max radius
                pnz = advance_ray_pos_fast;
         if(accumulated_pw_sens_fire>timetrigger_pw_sens_fire && !nomatch_z) pnz = advance_ray_pos_full; // override to full quality
         r.yaw += pnz;                                       // apply
         rc_tot ++;
      }
   }
//----- laser blast position -------------------------------------------------
   if(mode_laser != 0){
      c.drawcolor = makecolor(112,112,160);
      hl = p.location;
      getaxes(p.viewrotation,x,y,z);
      k = int( vsize(p.location - laserdot.location) / 40);
      if(k > 256) k = 256;
      for(i=0; i<k; i++){
         hl += 40*x;
         hlx = (hl.x>>SHR_Factor_scanmap);
         hly = (hl.y>>SHR_Factor_scanmap);
         hlx += (size_tex>>1); hlx += (global_offset_x >> SHR_Factor_scanmap);
         hly += (size_tex>>1); hly += (global_offset_y >> SHR_Factor_scanmap);
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
         // -----------------------------------------
         if( hlx<hud_maptex_offset_x          || hly<hud_maptex_offset_y          ||
             hlx>hud_maptex_offset_x+size_tex || hly>hud_maptex_offset_y+size_tex  )
             break; // goto skip_by_drawlaser_outtexbounds;
         pnz = 0.5;
         if(ena_2xzoom) pnz = 1.0;
         c.setpos(hlx,hly); c.drawicon(texture'scipixel',pnz);
      }
   }
//----- region borders, above main texture, under menu text ------------------
   if(mode_oper!=MO_Mark) goto skip_by_drawregion_nomarkup;
   for(i=0;i<8;i++){
      if(enab_region[i]==0) continue;
      marked_error = region_sizetex[i] - size_tex;
      resolution_error = map_resolution / region_scale[i];
      region_area = int(region_sizetex[i] / resolution_error);
      hlx = (global_offset_x - region_align[i].x);
      hly = (global_offset_y - region_align[i].y);
      hlx = hlx >> SHR_Factor_scanmap; // todo if(shr_div_coords!=region_shr) warn_shr;
      hly = hly >> SHR_Factor_scanmap;
      hlx += (region_sizetex[i]>>1);  hlx -= (marked_error>>1);
      hly += (region_sizetex[i]>>1);  hly -= (marked_error>>1);
      mkx = hlx - ((region_sizetex[i]>>1)/resolution_error);
      mky = hly - ((region_sizetex[i]>>1)/resolution_error);
      mkx += hud_maptex_offset_x;
      mky += hud_maptex_offset_y;
      c.drawcolor = color_region(i,false);
      c.setpos(mkx, mky);               c.drawtile(texture'scipixel', region_area, 1, 0,0,4,4); // t,l corner right
      c.setpos(mkx, mky-1+region_area); c.drawtile(texture'scipixel', region_area, 1, 0,0,4,4); // b,l corner right
      c.setpos(mkx, mky);               c.drawtile(texture'scipixel', 1, region_area, 0,0,4,4); // t,l corner down
      c.setpos(mkx-1+region_area, mky); c.drawtile(texture'scipixel', 1, region_area, 0,0,4,4); // t,r corner down
   }
   skip_by_drawregion_nomarkup:
// ---- texclip bg -----------------------------------------------------------
   c.drawcolor = pc_bg;  // if disable this, region borders may go outside main texture
   c.setpos(0,0);
    c.drawtile(texture'scipixel', hud_maptex_offset_x, hardcode_scrh, 0,0,4,4);
   c.setpos(hud_maptex_offset_x, 0);
    c.drawtile(texture'scipixel', max_size_tex, hud_maptex_offset_y, 0,0,4,4);
   c.setpos(hud_maptex_offset_x, max_size_tex+hud_maptex_offset_y);
    c.drawtile(texture'scipixel', max_size_tex, 26, 0,0,4,4);  // 26 = tex_size end until screen end     // ???????
   c.setpos(max_size_tex+hud_maptex_offset_x, 0);
    c.drawtile(texture'scipixel', hardcode_scrw-max_size_tex-hud_maptex_offset_x, hardcode_scrh, 0,0,4,4);
// ---- level nav camera -----------------------------------------------------
   c.drawcolor = pc_wh;
   getaxes(p.viewrotation,x,y,z);                 // 16:9 @ 106 fov
   c.drawportal(pad_glob, (pad_glob*2)+(fonh*2), vieww, viewh, p,p.location+x*2+z*(p.eyeheight-1),p.viewrotation,106,true);
   c.setpos(x_view_lpos,y_clientmsg);      c.drawtext(new_clientmsg[0]);
   c.setpos(x_view_lpos,y_clientmsg+fonh); c.drawtext(new_clientmsg[1]);
   str_tmp = "1";
   if(ena_2xzoom) str_tmp = "2";
   if(ena_4xzoom) str_tmp = "4";
   str_tmp $= "x   ";
   str_tmp $= string(map_resolution);
   str_tmp $= "/";
   str_tmp $= string(int(2**SHR_Factor_prodmap));
   str_tmp $= "uu";
   c.setpos(x_view_lpos,y_statusbar); c.drawtext(str_tmp);
   str_tmp = "";
   if(sens_mov != none) str_tmp = string(sens_mov.name);
   if(sens_trig != none) str_tmp = string(sens_trig.name);
   k = len(str_tmp) -1;  // do -1 to length because we positioning from rightmost pixel of font
   k *= fonw;
   c.setpos(x_view_rpos-k, y_clientmsg); c.drawtext(str_tmp);
   if(sens_ignore){
      c.setpos(x_view_rpos-(6*fonw), y_clientmsg+fonh); c.drawtext("Ignored");
   }
// ---- banner ---------------------------------------------------------------
   c.drawcolor = pc_wh;
   c.setpos(x_about,y_about);      c.drawtext("CT AMS v 0.4 / Leena Klammer / 2026-01-24");
   c.drawcolor = pc_gray;
   c.setpos(x_about,y_about+fonh); c.drawtext("System requirements: 1920x1080@32");
// ---- hotkeys, labels, modes -----------------------------------------------
   upx = x_hdr_oper; upy = y_hdr_oper;
   c.drawcolor = pc_green;
   str_tmp = mode_oper==MO_LifetimeCfg ? " global behavior setup" : "";
   c.setpos(upx,upy); c.drawtext("Opermode:"$str_tmp);
     upx = x_col_oper; upy += (pad_fonh_half+fonh);
   pc_tmp = mode_oper==MO_Scan ? pc_green : pc_green_f;
   upy = draw_key_action(c, pc_tmp, kw_f1, "<F1>", "build",  upx, upy);
   pc_tmp = mode_oper==MO_Diag ? pc_blue : pc_blue_f;
   if(mode_oper==4)
     pc_tmp = (int(level.timeseconds/0.5) % 2)==0 ? pc_blue : pc_cyan;   // blink nowentering mode
   upy = draw_key_action(c, pc_tmp,  kw_f7, "<F7>", "diag",   upx, upy);
   pc_tmp = mode_oper==MO_Mark ? pc_green : pc_green_f;
   upy = draw_key_action(c, pc_tmp, kw_f4, "<F4>", "markup", upx, upy);
   pc_tmp = mode_oper==MO_Prod ? pc_green : pc_green_f;
   upy = draw_key_action(c, pc_tmp, kw_f8, "<F8>", "prod",   upx, upy);
   // -------------------
   if(mode_oper==MO_LifetimeCfg) goto skip_by_drawkeys_lifetimecfg;
   upx = x_hdr_map_ctl; upy = y_hdr_map_ctl;
   c.drawcolor = pc_blue;
   c.setpos(upx,upy); c.drawtext("Map ctl:");
     upx = x_col_map_ctl; upy += (pad_fonh_half+fonh);
   upy = draw_key_action(c, pc_blue, kw_z, "<Z>", "pxzoom",  upx, upy);
   upy = draw_key_action(c, pc_blue, kw_x, "<X>", "uuzoom", upx, upy);
   upy = draw_key_action(c, pc_blue, kw_b, "<B>", "step",   upx, upy);
   upy = draw_key_action(c, pc_blue, kw_g, "<G>", "texture",upx, upy); upx -= (fonw*2);
   pc_tmp = mode_oper==MO_Mark ? pc_blue : pc_blue_f;
   upy = draw_key_action(c, pc_tmp, kw_ent, "<Ent>", "assign L",upx, upy);
   // -------------------
   upx = x_hdr_lvl_ctl; upy = y_hdr_lvl_ctl;
   c.drawcolor = pc_orange;
   c.setpos(upx,upy); c.drawtext("Level ctl:");
     upx = x_col_lvl_ctl; upy += (pad_fonh_half+fonh);
   pc_tmp = ena_player ? pc_orange : pc_orange_f;
   upy = draw_key_action(c, pc_tmp, kw_f5, "<F5>", "player",  upx, upy);
   upy = draw_key_action(c, pc_orange, kw_f2, "<F2>", "rmode",   upx, upy);
   if(mode_mwheel==0) str_tmp = "X";
   if(mode_mwheel==1) str_tmp = "Y";
   if(mode_mwheel==2) str_tmp = "L";
   upy = draw_key_action(c, pc_orange, kw_r,  "<R>",  "mwheel: "$str_tmp, upx, upy);
   upy = draw_key_action(c, pc_orange, kw_pupd, "<PuPd>",  "sel L", upx, upy);
   // -------------------
   upx = x_hdr_user; upy = y_hdr_user;
   c.drawcolor = pc_yellow;
   c.setpos(upx,upy); c.drawtext("User:");
     upx = x_col_user; upy += (pad_fonh_half+fonh);
   pc_tmp = ena_lockz ? pc_yellow : pc_yellow_f;
   upy = draw_key_action(c, pc_tmp,    kw_u,    "<U>",    "lock Z/L",  upx, upy);
   pc_tmp = ena_lockxy ? pc_yellow : pc_yellow_f;
   upy = draw_key_action(c, pc_tmp, kw_o,    "<O>",    "lock XY", upx, upy);
   pc_tmp = !ena_lockxy ? pc_yellow : pc_yellow_f;
   upy = draw_key_action(c, pc_tmp, kw_ijkl, "<IJKL>", "offset",  upx, upy);
     upx = x_col2_user; upy = y_hdr_user+pad_fonh_half;
   pc_tmp = sens_ignore ? pc_yellow : pc_yellow_f;
   upy = draw_key_action(c, pc_tmp, kw_t,    "<T>", "ignore", upx, upy);
   pc_tmp = lightbeam.LightType!=LT_None ? pc_yellow : pc_yellow_f;
   upy = draw_key_action(c, pc_tmp, kw_y,    "<Y>", "light",  upx, upy);
   str_tmp = "laser"; pc_tmp = pc_yellow;
   if(mode_laser==1)  str_tmp $= ": infinite -"$int(laser_wall_dist);
   if(mode_laser==2)  str_tmp $= ": finite +"$int(laser_ray_length);
   if(mode_laser==0){ str_tmp $= " off"; pc_tmp = pc_yellow_f; }
   upy = draw_key_action(c, pc_tmp, kw_q,  "<Q>", str_tmp,  upx, upy);
   pc_tmp = mode_oper!=MO_Mark ? pc_green_f : pc_green;
   upy = draw_key_action(c, pc_tmp, kw_m,  "<M>", "mark reg",  upx, upy);
   pc_tmp = mode_oper==MO_Scan ? pc_brown : pc_brown_f;
         draw_key_action(c, pc_tmp, kw_n,  "<N>", "Zset DPN",  upx, upy);
   upx = x_hdr_region;
   pc_tmp = pc_orange;                                      // shithack: adjust pc_tmp to trigger pc_wh replacement
   if(region.zone!=none){ if(!region.zone.bwaterzone) pc_tmp = pc_orange_f; }  // and dont access zone handle again
   upy = draw_key_action(c, pc_tmp, kw_p, "<P>", "!water",  upx, upy);
   // -------------------
   upx = x_hdr_region; upy = y_hdr_region;
   c.drawcolor = pc_green;
   bool_tmp = (mode_oper!=MO_Mark && mode_oper!=MO_Prod);
   if(bool_tmp) c.drawcolor = pc_yellow_f;
   c.setpos(upx,upy); c.drawtext("Region+1:");
   if(bool_tmp) goto skip_noregion_num;
   upx = x_col_region;
   upy += pad_fonh_half+fonh;
   k = n_region+1;
   if(n_region>=0 && n_region<=7){
      c.drawcolor = pc_green;
      c.setpos(upx+(k*fonw),upy); c.drawtext("< >");
   }
   for(i=0;i<8;i++){
      c.drawcolor = color_region(i,true);
      if(n_region==i){ 
        c.drawcolor = color_region(n_region,false);
         if(enab_region[n_region]==0) c.drawcolor = pc_gray;
      }
      j = i>n_region ? 2 : 0;
      k = i<n_region ? 2 : 0;
      upx += fonw; c.setpos(upx+(1*fonw)+(j*fonw)-(k*fonw),upy); c.drawtext(i+1);
   }
   goto done_region_num;
   skip_noregion_num:
   upx = x_col_region;
   upy += pad_fonh_half+fonh;
   c.drawcolor = pc_yellow_f;
   c.setpos(upx+(5*fonw),upy); c.drawtext("n/a");
   done_region_num:
   // -------------------
   upx = x_hdr_place; upy = y_hdr_place;
   c.drawcolor = pc_brown;
   c.setpos(upx,upy); c.drawtext("Placement: ");
     upx = x_col_place; upy += pad_fonh_half+fonh;
   if(mode_dpn_fall==0){ pc_tmp = pc_brown;  str_tmp = "floordist"; }
   if(mode_dpn_fall==1){ pc_tmp = pc_green;  str_tmp = "floating";  }
   if(mode_dpn_fall==2){ pc_tmp = pc_yellow; str_tmp = "inherit z"; }
   c.setpos(upx+(14*fonw),upy);
   c.drawcolor = pc_tmp; c.drawtext(str_tmp);
   upy = draw_key_action(c, pc_brown, kw_f, "<F>", "autofall:", upx, upy);
   pc_tmp = mode_autospawn!=0 ? pc_brown : pc_brown_f;
   str_tmp = " off";
   if(mode_autospawn==1) str_tmp = ": each 192";
   if(mode_autospawn==2) str_tmp = ": each 128";
   upy = draw_key_action(c, pc_tmp,   kw_v, "<V>", "autospawn"$str_tmp, upx, upy);
// todo pc_tmp = ena_strict_walls ? pc_brown : pc_wh;
   upy = draw_key_action(c, pc_brown, kw_h, "<H>", "strict walls",    upx, upy);
   // -------------------
   upx = x_hdr_mouse; upy = y_hdr_mouse;
   c.drawcolor = pc_pink;
   c.setpos(upx,upy); c.drawtext("Mouse:");
     upx = x_col_mouse; upy += pad_fonh_half+fonh;
   upy = draw_key_action(c, pc_pink, !bDisableLRmouseNotify ? kw_lmb : kw_none, "<LB>", "open",  upx, upy);
   upy = draw_key_action(c, pc_pink,  bEnableMmouseNotify   ? kw_mmb : kw_none, "<MW>", "spawn", upx, upy);
   upy = draw_key_action(c, pc_pink, !bDisableLRmouseNotify ? kw_rmb : kw_none, "<RB>", "kill",  upx, upy);
// ---- warnings -------------------------------------------------------------
   upx = x_about; upy +=  pad_fonh_half;
   if(mode_oper==MO_WantDiag){  // requested to enter diag mode
      pc_tmp = pc_red;
      if((int(level.timeseconds/0.5) % 2) == 0) pc_tmp = pc_cyan;
      upy = draw_key_action(c, pc_tmp,  kw_none, "Attention:", "this operation can't be undone.", upx, upy);
      upy += pad_glob;
      upy = draw_key_action(c, pc_wh, kw_none, "", "Confirm "$now_confirmed(mode_confirm)$"/4 you want to overwrite Z-set.", upx, upy);
      upy = draw_key_action(c, pc_wh_f, kw_none, "", "Press 1,2,3,4 keys or F1/F7 to cancel.", upx, upy);
      goto skip_by_validation;
   }
   if((mode_rayprocess!=RP_SelFull || ena_lockz) && accumulated_pw_sens_fire<timetrigger_pw_sens_fire){
      nframe = (int(level.timeseconds/0.24) % 18);
      pc_tmp = (nframe==0) ? pc_yellow : pc_cyan;
      upy = draw_key_action(c, pc_tmp,  kw_none, "", "Fast rmode or lockz active. ",  upx, upy);
      if(rc_tot > 8000){
         c.drawcolor = pc_red;
         c.setpos(upx+(29*fonw), upy-fonh);
         c.drawtext("Heavy RT.");
      }
      upy += pad_glob;
      upy = draw_key_action(c, pc_wh_f, kw_none, "", "Aim outside mover and hold <Fire> to",  upx, upy);
      upy = draw_key_action(c, pc_wh_f, kw_none, "", "preview in full render mode.",  upx, upy);
   }else{
      pc_tmp = pc_wh;
      str_tmp = "";
      if(rc_tot < 4000){ pc_tmp = pc_wh_f; str_tmp = " possible";}     // up to 5000 feels good
      if(rc_tot > 8000) pc_tmp = pc_red;
      if(rc_tot>11000 && ((int(level.timeseconds/0.3) % 2) == 0)) pc_tmp = pc_cyan;
      upy = draw_key_action(c, pc_tmp,  kw_none, "Note:", "heavy raytracing"$str_tmp$".", upx, upy);
      upy += pad_glob;
      upy = draw_key_action(c, pc_wh_f, kw_none, "", "Be ready to severe lagging.", upx, upy);
   }
   skip_by_drawkeys_lifetimecfg:
   if(mode_oper==MO_LifetimeCfg){
      upx = x_col_map_ctl; upy = y_hdr_oper+pad_fonh_half+fonh;
      c.drawcolor = pc_wh;
      c.setpos(upx,upy); c.drawtext("<- press these keys or F6"); upy += fonh;
      c.setpos(upx,upy); c.drawtext("   to leave this mode."); upy += fonh;
      upy = draw_key_action(c, pc_green, kw_ijkl, "<IK>", "select var",  upx, upy);
      upy = draw_key_action(c, pc_green, kw_ijkl, "<JL>", "change",  upx, upy);
      
      upx = x_col_oper; upy = y_hdr_region;
      c.drawcolor = pc_orange; c.setpos(upx,upy); c.drawtext("FloorDist:");
      upx = x_col_oper + (11*fonw);
      c.drawcolor = pc_wh; c.setpos(upx,upy); c.drawtext("autofall control. Presets:");
      upx = x_col_oper; upy += fonh; c.setpos(upx,upy); c.drawtext("61: classic unreal, best for 256 rooms");
      upx = x_col_oper; upy += fonh; c.setpos(upx,upy); c.drawtext("24: narrow, for 128 rooms");
      upx = x_col_oper; upy += fonh; c.setpos(upx,upy); c.drawtext("12: narrower, catches 16uu steps");
      upx = x_col_oper; upy += (fonh*2);
      c.drawcolor = pc_red; c.setpos(upx,upy); c.drawtext("Z-set discretization:");
      upx = x_col_oper + (22*fonw);
      c.drawcolor = pc_wh; c.setpos(upx,upy); c.drawtext("how thick each map");
      upx = x_col_oper; upy += fonh; c.setpos(upx,upy); c.drawtext("layer is. Controls vertical sensitivity.");
      upx = x_col_oper; upy += (fonh*2);
      c.drawcolor = pc_green; c.setpos(upx,upy); c.drawtext("Prod SHR:");
      upx = x_col_oper + (10*fonw);
      c.drawcolor = pc_wh; c.setpos(upx,upy); c.drawtext("uniform spatial resolution for");
      upx = x_col_oper; upy += fonh; c.setpos(upx,upy); c.drawtext("map. If you stick to 227j and limited by");
      upx = x_col_oper; upy += fonh; c.setpos(upx,upy); c.drawtext("256px textures, 16uu/1px may be best.");
   }
   skip_by_validation:
// ---- right sidebar --------------------------------------------------------
   upx = x_rcol; upy = y_rcol_texdata;
   pc_tmp = mode_oper==MO_Mark ? pc_wh : pc_gray;
   upy = draw_key_action(c, pc_tmp, kw_none, "", "AlignZ fill", upx, upy);
   // -------------------
   upx = x_rcol; upy = y_rcol_texdata_fill;
   // fill monitor code here
   c.drawcolor = pc_fill_bg;
   for(k=0;k<8;k++){
      for(i=0;i<8;i++){
         j = (k*8)+i;
         if(j==63) continue;
         c.setpos(upx,upy);
         c.drawtile(texture'scipixel',  fillw, fillh, 0,0,4,4);
         upx += (fillw+1);
      }
         upy += (fillh+1); upx = x_rcol;
   }
   upx = x_rcol; upy = y_rcol_texdata_fill;
   for(k=0;k<8;k++){
      for(i=0;i<8;i++){
         j = (k*8)+i;
         if(j==63) continue;
         bool_tmp = false;
         c.drawcolor = color_region(region_usedby[j],false);
         if(region_usedby[j]!=9) bool_tmp = true;
         if(bool_tmp){
            c.setpos(upx+3,upy-2);
            c.style = erenderstyle.sty_masked;
            c.drawtext("*");
         }
         upx += (fillw+1);
      }
         upy += (fillh+1); upx = x_rcol;
   }
   // -------------------
   upx = x_rcol; upy = y_rcol_player-58;
         draw_key_action(c, pc_tmp, kw_none, "", "Set:    @", upx, upy);
   str_tmp = "";
   if(n_layerz<10) str_tmp $= " ";
    str_tmp $= string(n_layerz);
   pc_tmp = mode_oper==MO_Mark ? pc_teal : pc_teal_f;
   if(pc_tmp==pc_teal) pc_tmp = !ena_lockz ? pc_teal : pc_green;
         draw_key_action(c, pc_tmp, kw_none, "", str_tmp, upx+(5*fonw), upy);
   str_tmp = "X";
   if(n_region>=0 && n_region<=7) str_tmp = string(n_region+1);
   pc_tmp = color_region(n_region,mode_oper!=MO_Mark);
   upy = draw_key_action(c, pc_tmp, kw_none, "", str_tmp, upx+(10*fonw), upy);
   // -------------------
   upx = x_rcol; upy = y_rcol_player;
   str_tmp = "   Player";
   if(mode_laser != 0) str_tmp = "   Laser";
   upy = draw_key_action(c, pc_orange, kw_none, "", str_tmp, upx, upy);
   vect_tmp = mode_laser==0 ? p.location : laserdot.location;
   upy = draw_key_action(c, pc_wh, kw_none, "", "X: "$int(vect_tmp.x), upx, upy);
   upy = draw_key_action(c, pc_wh, kw_none, "", "Y: "$int(vect_tmp.y), upx, upy);
   upy = draw_key_action(c, pc_wh, kw_none, "", "Z: "$int(vect_tmp.z), upx, upy);
   // -------------------
   upx = x_rcol; upy = y_rcol_scope;
   upy = draw_key_action(c, pc_yellow, kw_none, "", "  Process", upx, upy);
   str_tmp = now_rayprocessing(mode_rayprocess);
   if(accumulated_pw_sens_fire > timetrigger_pw_sens_fire) str_tmp = now_rayprocessing(RP_ClientFull);
   upy = draw_key_action(c, pc_wh, kw_none, "", str_tmp, upx, upy);
   str_tmp = ena_lockz ? "lock" : n_layerz$"/"$presets_nmax;
   pc_tmp = ena_lockz ? pc_green : pc_teal; // was :pc_blue
   upy = draw_key_action(c, pc_tmp, kw_none, "Sel:", str_tmp, upx, upy);
   // -------------------
   upx = x_rcol; upy = y_rcol_align;
   upy = draw_key_action(c, pc_blue, kw_none, "", "   Align", upx, upy);
   if(mode_mwheel==0){ pc_tmp = !ena_lockxy ? pc_green : pc_green_f; }else{ pc_tmp = !ena_lockxy ? pc_wh: pc_wh_f; }
   upy = draw_key_action(c, pc_tmp, kw_none, "", "X: "$int(global_offset_x), upx, upy);
   if(mode_mwheel==1){ pc_tmp = !ena_lockxy ? pc_green : pc_green_f; }else{ pc_tmp = !ena_lockxy ? pc_wh: pc_wh_f; }
   upy = draw_key_action(c, pc_tmp, kw_none, "", "Y: "$int(global_offset_y), upx, upy);
   str_tmp = ena_lockz ? string(int(p.location.z)) : string(presets_z[n_layerz]);
   if(mode_mwheel==2){ pc_tmp = !ena_lockxy ? pc_green : pc_green_f; }else{ pc_tmp = !ena_lockxy ? pc_wh: pc_wh_f; }
   upy = draw_key_action(c, pc_tmp, kw_none, "", "Z: "$str_tmp, upx, upy);
   // -------------------
   upx = x_rcol; upy = y_rcol_region;
   upy = draw_key_action(c, pc_pink, kw_none, "", "   Region", upx, upy);
   upy = draw_key_action(c, pc_wh,   kw_none, "", "S: "$size_step, upx, upy);
   upy = draw_key_action(c, pc_wh,   kw_none, "", "T: "$size_tex, upx, upy);
   // -------------------
   upx = x_rcol; upy = y_rcol_lifetime;
   nframe = (int(level.timeseconds/2.5) % 2);
   pc_tmp = (nframe==0) ? pc_blue : pc_yellow;
   if(mode_oper!=MO_LifetimeCfg) pc_tmp = pc_brown;
   upy = draw_key_action(c, pc_tmp, kw_none, "", "Map lifetime", upx, upy);
   upy = draw_key_action(c, pc_tmp, kw_none, "", "  behavior", upx, upy);
   pc_tmp = mode_oper==MO_LifetimeCfg ? pc_orange : pc_gray;     draw_lifetime_sel(c,LTC_Floordist,upx,upy);
   upy = draw_key_action(c, pc_tmp, kw_none, "", "FlrDist: "$int(autofall_floordist), upx, upy);
   pc_tmp = mode_oper==MO_LifetimeCfg ? pc_red    : pc_gray;     draw_lifetime_sel(c,LTC_ZSetDiscr,upx,upy);
   upy = draw_key_action(c, pc_tmp, kw_none, "", "ZDiscr: "$int(vert_discretization), upx, upy);
   pc_tmp = mode_oper==MO_LifetimeCfg ? pc_green  : pc_gray;     draw_lifetime_sel(c,LTC_ProdSHR,upx,upy);
   upy = draw_key_action(c, pc_tmp, kw_none, "", "PrSHR: "$int(2**SHR_Factor_prodmap), upx, upy);
   upy = draw_key_action(c, pc_brown, kw_f6, "<F6>", mode_oper==MO_LifetimeCfg ? "done" : "edit", upx, upy);
   // -------------------
   upx = x_rcol; upy = y_rcol_noob;
   upy = draw_key_action(c, pc_green, kw_none, "Noob? cmd", ">q", upx, upy); // right sidebar ends
//----- player displayer -----------------------------------------------------
   if(ena_player){
       hl = p.location;
       hlx = (hl.x>>SHR_Factor_scanmap);
       hly = (hl.y>>SHR_Factor_scanmap);
       hlx+=(size_tex>>1); hlx+=(global_offset_x>>SHR_Factor_scanmap);
       hly+=(size_tex>>1); hly+=(global_offset_y>>SHR_Factor_scanmap);
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
//       c.drawcolor = (int(level.timeseconds/1.2) % 2) == 0 ? makecolor(87,87,128) : makecolor(225,225,255);
//       if(mode_player==2) c.drawcolor = makecolor(225,225,0);
//       if(mode_player<3){  // mode 1, 2
//          c.setpos(hlx,hly); c.drawicon(texture'scipixel',mode_player);
//       }else{              // mode 3
          rotr = (p.viewrotation.yaw+16384) % 65536;  // -90 because zero yaw in unrealed is A of WASD
          if(rotr < 0) rotr += 65536;
          nmarker = byte(rotr/2730.66);
          c.setpos(hlx-8,hly-8);
          c.drawcolor = (int(level.timeseconds/0.7) % 2) == 0 ? makecolor(192,192,255) : makecolor(225,225,255);
          c.DrawTile(texture'scibearing',16,16, nmarker*16,0,16,16);
//       }
   }
// ---- nav camera counters --------------------------------------------------
   c.drawcolor = pc_wh;
   i = int(1/last_tick_f);
   if(i > 60) i = 60;
   c.setpos(x_view_lpos+(15*fonw),y_statusbar); c.drawtext(i$"fps ");
   str_tmp = "";
   str_tmp $= string(pn_mz);
   str_tmp $= "/";
   str_tmp $= string(pn_tot);
   k = len(str_tmp) -1;
   k *= fonw;
   c.setpos(x_view_rpos-k, y_statusbar); c.drawtext(str_tmp);
// ---- prod mode autoexec ---------------------------------------------------
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
// ==================================================================================================

exec function mapinit(){
   local pathnode pn;
   foreach allactors(class'pathnode',pn) if(!pn.isa('pathnoderuntime')) dpn_replace(pn.location);
   do_diag_z();            // initial diag pass
   tog_opermode_uni(0);
}

function postbeginplay(){
   local info ifo;
   local inventory w;
   local decoration d;
   local effects e;
   local byte i;
   local trigger t;
   local mover m;
   inv_finfo = spawn(class'stinvfontinfo');
// saveconfig();
   resetconfig();
   pc_blue   = makecolor(175,175,255);   pc_blue_f   = makecolor(75 ,76 ,121);
   pc_bluer  = makecolor(148,148,255);   pc_bluer_f  = makecolor(66 ,67 ,121);
   pc_yellow = makecolor(255,255,170);   pc_yellow_f = makecolor(102,103,92 );
   pc_cyan   = makecolor(128,229,255);   pc_cyan_f   = makecolor(59 ,94 ,121);
   pc_teal   = makecolor(108,173,184);   pc_teal_f   = makecolor(52 ,75 ,97 );
   pc_orange = makecolor(255,204,170);   pc_orange_f = makecolor(102,86 ,92 );
   pc_green  = makecolor(204,255,170);   pc_green_f  = makecolor(85 ,103,92 );
   pc_pink   = makecolor(238,170,255);   pc_pink_f   = makecolor(96 ,74 ,121);
   pc_pinker = makecolor(204,128,255);   pc_pinker_f = makecolor(85 ,60 ,121);
   pc_red    = makecolor(255,128,128);   pc_red_f    = makecolor(102,60 ,78 );
   pc_brown  = makecolor(198,156,156);   pc_brown_f  = makecolor(83 ,70 ,88 );
   pc_bg     = makecolor(24 ,25 ,53);    pc_fill_bg  = makecolor(38 ,39 ,70 );
   pc_gray   = makecolor(128,128,128);
   pc_wh     = makecolor(255,255,255);   pc_wh_f     = makecolor(161,161,173);
   foreach allactors(class'info',ifo){
      if(!ifo.isa('ONPLevelInfo')) ifo.SetPropertyText("MaxHealth","500");
      if(ifo.isa('ZoneInfo')) zoneinfo(ifo).bPainZone = false;
   }
   foreach allactors(class'inventory',w) if(w != self) w.destroy();
   foreach allactors(class'decoration',d) d.destroy();
   foreach allactors(class'effects',e) e.destroy();
   clientmsg_timer = -1.0;
   new_clientmsg[0] = "";
   new_clientmsg[1] = "";
   presets_nmax = 0;
   for(i=0;i<64;i++){
      presets_z[i] = 0;
      region_usefloor[i] = 0;
      region_usedby[i] = 9;
   }
   foreach allactors(class'trigger',t){
      t.group='';
      t.bTriggerOnceOnly = false;               // force enable
         t.TriggerType = TT_ClassProximity;     // prohibit autotrigger
         t.ClassProximityType = class'scihud';
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
//   mode_oper = MO_Scan;
   new_clientmsg[0] = "";
   new_clientmsg[1] = "";
   clientmsg_timer = 0.0;
   tog_opermode_uni(0);    // goto build mode
   adv_welcome_msgs();
/*
   mode_player = 3;        
   mode_rayprocess = RP_ClientLike;
// mode_mwheel = 2; already 2
   ena_2xzoom = true;
   ena_4xzoom = false;
   SHR_Factor_scanmap = 2;
   upd_resolution();
   ena_lockz = true;
   ena_lockxy = true; */
}

function playselect(){
   local playerpawn p;
   p = playerpawn(owner);
   if(p == none) return;
   oldHUD = p.myHUD;
   oldHUDType = p.HUDType;
   p.HUDType = Class'scihud';
   p.myHUD = Spawn(Class'scihud',p,,vect(32767,32767,32767));
   p.myHUD.MainMenu = oldHUD.MainMenu;
   p.myHUD.MainMenuType = oldHUD.MainMenuType;
   p.consolecommand("killpawns");
   p.consolecommand("killall pickup");
   p.consolecommand("killall decoration");
   p.consolecommand("killall decal");
   p.consolecommand("amphibious");
   p.consolecommand("set input alt sci_forcedodge");       // level setup ends
   p.consolecommand("set input f1 tog_opermode_uni 0");
   p.consolecommand("set input f7 tog_opermode_uni 1");
   p.consolecommand("set input f4 tog_opermode_uni 2");
   p.consolecommand("set input f8 tog_opermode_uni 3");     // opermode ends
   p.consolecommand("set input z tog_digzoom");
   p.consolecommand("set input x tog_shr_factor");
   p.consolecommand("set input b tog_mode_step");
   p.consolecommand("set input g tog_mode_texsize");
   p.consolecommand("set input enter tog_layerz_assign");  // mapctl ends
   p.consolecommand("set input f5 tog_show_player");
   p.consolecommand("set input f2 tog_show_all_layers");
   p.consolecommand("set input r tog_mode_mwheel");
   p.consolecommand("set input pageup inc_nlayer");
   p.consolecommand("set input pagedown dec_nlayer");
// --------- regions ---------------------------------------------------
   p.consolecommand("set input 1 tog_region_uni 0"); p.consolecommand("set input numpad1 tog_region_uni 0");  // was tog_region_1
   p.consolecommand("set input 2 tog_region_uni 1"); p.consolecommand("set input numpad2 tog_region_uni 1");  // was tog_region_2
   p.consolecommand("set input 3 tog_region_uni 2"); p.consolecommand("set input numpad3 tog_region_uni 2");  // was tog_region_3
   p.consolecommand("set input 4 tog_region_uni 3"); p.consolecommand("set input numpad4 tog_region_uni 3");  // was tog_region_4
   p.consolecommand("set input 5 tog_region_uni 4"); p.consolecommand("set input numpad5 tog_region_uni 4");  // was tog_region_5
   p.consolecommand("set input 6 tog_region_uni 5"); p.consolecommand("set input numpad6 tog_region_uni 5");  // was tog_region_6
   p.consolecommand("set input 7 tog_region_uni 6"); p.consolecommand("set input numpad7 tog_region_uni 6");  // was tog_region_7
   p.consolecommand("set input 8 tog_region_uni 7"); p.consolecommand("set input numpad8 tog_region_uni 7");  // was tog_region_8
// --------- group 2 ---------------------------------------------------
   p.consolecommand("set input u tog_lockz");
   p.consolecommand("set input o tog_lockxy");
   p.consolecommand("set input i do_scr_w");
   p.consolecommand("set input j do_scr_a");
   p.consolecommand("set input k do_scr_s");
   p.consolecommand("set input l do_scr_d");         // user col1 ends
   p.consolecommand("set input t tog_ignore");
   p.consolecommand("set input y tog_light");
   p.consolecommand("set input q tog_laser");
   p.consolecommand("set input m mark_current_region");
// --------- group 3 ---------------------------------------------------
   p.consolecommand("set input f tog_dpn_fall");
   p.consolecommand("set input v tog_dpn_autospawn");
// p.consolecommand("set input h tog_strictwalls");     // placement ends
   p.consolecommand("set input middlemouse sci_user_dpn_spawn");
   p.consolecommand("set input mousewheeldown ctl_mw_less");
   p.consolecommand("set input mousewheelup ctl_mw_more");  
   p.consolecommand("set input p shdn_waterable");
   p.consolecommand("set input f6 tog_opermode_uni 4");
   upd_resolution(); upd_size_tex(); upd_size_step();
}

exec function tog_laser(){
   if(mb_fail_confirm()) return;
   key_when = 0.3; last_kw = kw_q;
   sens_ignore = false;
   mode_laser++;
   if(mode_laser>2) mode_laser = 0;
   if(mode_laser==0){
      laserdot.setlocation(vect(32767,32767,32767));
      sens_mov = none;  // forget mover
      return;
   }
   if(mode_laser==1){                     // ??????
      sens_trig = none; // forget trigger
      return;
   }
   if(mode_laser==2){
      sens_trig = none; // forget trigger
   }
}

exec function tog_ignore(){
   if(mb_fail_confirm()) return;
   if(sens_mov == none) return;
   key_when = 0.3; last_kw = kw_t;
   if(sens_mov.group=='sciignore'){
      sens_mov.group='';
   }else{
      sens_mov.group='sciignore';
   }
}

exec function tog_digzoom(){
   if(mb_fail_confirm()) return;
   if(mode_oper==MO_Mark) return;
   key_when = 0.3; last_kw = kw_z;
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

exec function shdn_waterable(){
   local zoneinfo z;
   z = region.zone;
   if(z == none) return;
   if(!z.bWaterzone) return;
   z.bWaterzone = false;
   new_clientmsg[0] = string(z.name)$" bWaterZone";
   new_clientmsg[1] = "is now false.";
   clientmsg_timer = 2.0;
}

exec function tog_show_player(){
   if(mb_fail_confirm()) return;
   key_when = 0.3; last_kw = kw_f5;
   ena_player = !ena_player;
//   mode_player++;
//   if(mode_player > 3) mode_player = 0;
}

exec function tog_show_all_layers(){
   if(mb_fail_confirm()) return;
   key_when = 0.3; last_kw = kw_f2;     switch(mode_rayprocess){
   case RP_SelFull:    mode_rayprocess = RP_AllFast;    break;
   case RP_AllFast:    mode_rayprocess = RP_AllFullEco; break;
   case RP_AllFullEco: mode_rayprocess = RP_ClientLike; break;
   case RP_ClientLike: mode_rayprocess = RP_SelFull;    break; }
}

exec function tog_lockxy(){
   if(mb_fail_confirm()) return;
   key_when = 0.3; last_kw = kw_o;
   ena_lockxy = !ena_lockxy;
   if(ena_lockxy) new_clientmsg[0] = "Map center snapped to player.";
   else new_clientmsg[0] = "Map center released.";
   clientmsg_timer = 2.0;
}

exec function tog_lockz(){
   if(mb_fail_confirm()) return;
   key_when = 0.3; last_kw = kw_u;
   ena_lockz = !ena_lockz;
}
exec function tog_mode_mwheel(){
   if(mb_fail_confirm()) return;
   key_when = 0.3; last_kw = kw_r;
   mode_mwheel++;
   if(mode_mwheel > 2) mode_mwheel = 0;
}
exec function tog_mode_step(){
   if(mb_fail_confirm()) return;
   key_when = 0.3; last_kw = kw_b;
   mode_step++;
   if(mode_step>2) mode_step=0;
   upd_size_step();
}
exec function tog_mode_texsize(){
   if(mb_fail_confirm()) return;
   key_when = 0.3; last_kw = kw_g;
   mode_texsize++;
   if(mode_texsize>2) mode_texsize=0;
   upd_size_tex();
}
exec function tog_shr_factor(){
   if(mb_fail_confirm()) return;
   key_when = 0.3; last_kw = kw_x;
   SHR_Factor_scanmap--;
   if(SHR_Factor_scanmap<1) SHR_Factor_scanmap = SHR_Factor_max;
   upd_resolution();
   upd_size_step();
}

exec function tog_dpn_fall(){
   if(mb_fail_confirm()) return;
   key_when = 0.3; last_kw = kw_f;
   mode_dpn_fall++;
   if(mode_dpn_fall>2) mode_dpn_fall=0;
}

exec function tog_dpn_autospawn(){
   if(mb_fail_confirm()) return;
   key_when = 0.3; last_kw = kw_v; // todo add 96, maybe 256
   mode_autospawn++;
   if(mode_autospawn>2) mode_autospawn = 0;
   if(mode_autospawn==1) autospawn_interval = 192.0;
   if(mode_autospawn==2) autospawn_interval = 128.0;
}

function dpn_spawn(bool bSummonLike){ // todo track laser state
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
    if(mode_laser == 1){
       sp_loc = laserdot.location;
    }
    dpn = spawn(class'PathNodeRuntime',,,sp_loc);
    if(mode_dpn_fall==1) return;
    dpn_newpos = vect(32767,32767,32767);
    if(mode_dpn_fall==2){
//     trace(dpn_newpos,hitnor,p.location+vect(0,0,-1024),p.location,true); // we need only z of this
       dpn_newpos.x = sp_loc.x;
       dpn_newpos.y = sp_loc.y;
       dpn_newpos.z = p.location.z; //2026-01-19: just use playerz instead of trace
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
   bDup = false;
   if(laserdot==none) bDup = true; // cancer code but safe to use bdup. returnless protection against iterating laser
   presets_nmax = 0;
   foreach AllActors(class'pathnoderuntime', pn){ // collect
      if(bdup) goto skip_diagz_nolaser;
      if(pn==laserdot) continue;
      skip_diagz_nolaser:   // evaded "accessed none" error. no need to bdup=false, it will be done anyway later
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
// for(i=0; i<presets_nmax; i++) broadcastmessage(string(presets_z[i]));  // log result

/*   mode_player = 0;          // reset interface to grab-ready // todo reset zooms
   mode_rayprocess = RP_SelFull;
   mode_mwheel = 2;
   mode_laser = 0;
   ena_2xzoom = false;
   ena_4xzoom = false;
   SHR_Factor_scanmap = 4;
   upd_resolution();
   ena_lockz = false;
   ena_lockxy = false;
   mode_oper = MO_Mark; */
   new_clientmsg[0] = "AreaZ set diag probe done, return to";
   new_clientmsg[1] = "mark mode. Prod defaults applied.";
   clientmsg_timer = 4.0;
   tog_opermode_uni(2);
}

exec function ctl_mw_less(){
   if(mode_laser==1 && laser_wall_dist<384){
      if(laser_wall_dist<32) laser_wall_dist += 8;
       else laser_wall_dist += 32;
   }else if(mode_laser==2){
      if(laser_ray_length>64) laser_ray_length -= 32;
       else laser_ray_length = 64;
   }else{ if(mode_laser!=0) return;             switch(mode_mwheel){
      case 0: if(!ena_lockxy) global_offset_x -= size_step; break;
      case 1: if(!ena_lockxy) global_offset_y -= size_step; break;
      case 2: if(n_layerz>0) n_layerz--;                    break; }
   }
}
exec function ctl_mw_more(){
   if(mode_laser==1 && laser_wall_dist>0){
      if(laser_wall_dist>32) laser_wall_dist -= 32;
       else laser_wall_dist -= 8;
   }else if(mode_laser==2){
      if(laser_ray_length<768) laser_ray_length += 32;
       else laser_ray_length = 768;
   }else{ if(mode_laser!=0) return;             switch(mode_mwheel){
      case 0: if(!ena_lockxy) global_offset_x += size_step; break;
      case 1: if(!ena_lockxy) global_offset_y += size_step; break;
      case 2: if(n_layerz<presets_nmax) n_layerz++;         break; }
   }
}

exec function inc_nlayer(){
   if(n_layerz>=presets_nmax) return;
   key_when = 0.3; last_kw = kw_pupd;
   n_layerz++;
}
exec function dec_nlayer(){
   if(n_layerz<=0) return;
   key_when = 0.3; last_kw = kw_pupd;
   n_layerz--;
}

exec function do_scr_w(){ if(do_scr_common(0)) return; global_offset_y -= size_step; }
exec function do_scr_a(){ if(do_scr_common(1)) return; global_offset_x -= size_step; }
exec function do_scr_s(){ if(do_scr_common(2)) return; global_offset_y += size_step; }
exec function do_scr_d(){ if(do_scr_common(3)) return; global_offset_x += size_step; }
function bool do_scr_common(byte ijkl_key){ // used in MO_LifetimeCfg mode only
   if(mode_oper==MO_LifetimeCfg) goto skip_to_lifetimecfg_controls;
   if(mb_fail_confirm()) return ena_lockxy;
   if(ena_lockxy) return true;
   key_when = 0.3; last_kw = kw_ijkl; return false;
   skip_to_lifetimecfg_controls: switch(ijkl_key){
      case 0: switch(mode_ltcfg){  // up key, inc mode
         case LTC_ZSetDiscr: mode_ltcfg=LTC_Floordist; break;
         case LTC_ProdSHR:   mode_ltcfg=LTC_ZSetDiscr; break; }
      break;
      case 2: switch(mode_ltcfg){  // dn key, dec mode
         case LTC_Floordist: mode_ltcfg=LTC_ZSetDiscr; break;
         case LTC_ZSetDiscr: mode_ltcfg=LTC_ProdSHR;   break; }
      break;
   } switch(mode_ltcfg){           // alter keys, exec anyway                 
    case LTC_Floordist:
       if(ijkl_key==3){ if(autofall_floordist<24) autofall_floordist=24; // inc
                   else if(autofall_floordist<61) autofall_floordist=61; }
       if(ijkl_key==1){ if(autofall_floordist>24) autofall_floordist=24; // dec
                   else if(autofall_floordist>12) autofall_floordist=12; }                          break;
    case LTC_ZSetDiscr:
       if(ijkl_key==3){ vert_discretization+=16; if(vert_discretization>256) vert_discretization=256; }
       if(ijkl_key==1){ vert_discretization-=16; if(vert_discretization<80)  vert_discretization=80;  }  break;
    case LTC_ProdSHR:  
       if(ijkl_key==3){ SHR_Factor_prodmap++; if(SHR_Factor_prodmap>SHR_Factor_max) SHR_Factor_prodmap=SHR_Factor_max; }
       if(ijkl_key==1){ SHR_Factor_prodmap--; if(SHR_Factor_prodmap<1) SHR_Factor_prodmap=1; }           break;
   }
   return true;
 }

function altfire(float f){
   local vector x, y, z;
   local float rad;
   local playerpawn p;
   local pathnoderuntime pn;
   p = playerpawn(owner);
   if(p == none) return;
   if(laserdot == none) return;
   key_when = 0.3; last_kw = kw_rmb;
   p.consolecommand("killpawns");
   getaxes(p.viewrotation,x,y,z);
   if(mode_laser == 1){
      y = laserdot.location;
      rad = 64;
   }else if(mode_laser == 0){
      y = p.location + 32*x;
      rad = 80;
   }
   foreach radiusactors(class'PathNodeRuntime',pn,rad,y) if(pn!=laserdot) pn.destroy();
}

function fire(float f){
   local pawn p;
   local mover m;
   p = pawn(owner);
   if(p == none) return;
   key_when = 0.3; last_kw = kw_lmb;
   if(sens_mov!=none){                     // open by mover
      if(!bUseUntrigger) goto skip_fire_nountrigger_mov;
      if(sens_mov.group=='mactive'){
         sens_mov.untrigger(p,p.instigator);
         sens_mov.group='';
      }else{
         sens_mov.trigger(p,p.instigator);
         sens_mov.group='mactive';
      }
      return;
      skip_fire_nountrigger_mov:
         sens_mov.trigger(p,p.instigator);
      return;
   }
   if(sens_trig!=none){                    // open by trigger
      if(!bUseUntrigger) goto skip_fire_nountrigger_trig;
      if(sens_trig.group=='tactive'){
         if(sens_trig.event!=none)
           foreach allactors(class'mover',m,sens_trig.event) m.untrigger(p,p.instigator);
         sens_trig.group='';
      }else{
         if(sens_trig.event!=none)
           foreach allactors(class'mover',m,sens_trig.event) m.trigger(p,p.instigator);
         sens_trig.group='tactive';
      }
      skip_fire_nountrigger_trig:
         if(sens_trig.event!=none)
           foreach allactors(class'mover',m,sens_trig.event) m.trigger(p,p.instigator);
      return;
   }
}

exec function sci_user_dpn_spawn(){  // middlemouse
   dpn_spawn(true);
}

defaultproperties{
  laserdot=None
  mode_laser=0
  SHR_Factor_scanmap=SHR_Factor_default
  SHR_Factor_prodmap=4
  PickupViewMesh=LodMesh'UnrealShare.AutoMagPickup'
  global_offset_x=0
  global_offset_y=0
  vert_discretization=128.0
  autofall_floordist=61.0
  bDisableAllBtnsNotify=false
  bDisableLRmouseNotify=false
  bEnableMmouseNotify=false
  bUseUntrigger=false
  ena_lockz=true
  ena_lockxy=true
  mode_dpn_fall=2
  ena_2xzoom=true
  ena_4xzoom=false
  scrshot_timer=0.0
  n_region=9
  mode_autospawn=0
  autospawn_interval=192.0
  laser_wall_dist=0.0
  laser_ray_length=64.0
  mode_rayprocess=RP_ClientLike
  mode_oper=MO_Scan
  mode_confirm=MC_Reset
  ena_player=false
  mode_mwheel=2
  mode_step=2
  mode_texsize=2
  n_layerz=0
  done_layerz=0
  water_forcedodge_timer=0.0
  wforcedodge_ready=false
  InventoryGroup=1
  PickupAmmoCount=9999
  ena_prod=false
  PickupMessage=AreaMap CT scan tool. Enter Q in console for more info. Enter MAPINIT in console to autospawn DPN in premapped spots.
  alignz_seek=0
  region_align(0)=(X=275.0,Y=0.0)
  region_align(1)=(X=-275.0,Y=0.0)
  region_align(2)=(X=0.0,Y=275.0)
  region_align(3)=(X=275.0,Y=275.0)
  region_align(4)=(X=-275.0,Y=275.0)
  region_align(5)=(X=0.0,Y=-275.0)
  region_align(6)=(X=275.0,Y=-275.0)
  region_align(7)=(X=-275.0,Y=-275.0)
  enab_region(0)=0
  enab_region(1)=0
  enab_region(2)=0
  enab_region(3)=0
  enab_region(4)=0
  enab_region(5)=0
  enab_region(6)=0
  enab_region(7)=0
//  enab_region(8)=0
//  enab_region(9)=0
  region_scale(0)=16.0;
  region_scale(1)=16.0;
  region_scale(2)=16.0;
  region_scale(3)=16.0;
  region_scale(4)=16.0;
  region_scale(5)=16.0;
  region_scale(6)=16.0;
  region_scale(7)=16.0;
  region_sizetex(0)=128;
  region_sizetex(1)=128;
  region_sizetex(2)=128;
  region_sizetex(3)=128;
  region_sizetex(4)=128;
  region_sizetex(5)=128;
  region_sizetex(6)=128;
  region_sizetex(7)=128;
  order_welcome_msgs=0
}

/*
function vector NewScreenToWorld(vector ScreenLoc, float ScreenWidth, float ScreenHeight, float FOV, vector CamLoc, rotator CamRot){
    local float  ScreenWidthHalf, ScreenHeightHalf;
    local float  tanFOV, Scale;
    local vector tmpWorldLoc, vLook, WorldLoc;
    local vector axesX, axesY, axesZ;

    ScreenWidthHalf    = ScreenWidth  / 2;
    ScreenHeightHalf= ScreenHeight / 2;

    tanFOV = tan(FOV * Pi / 360.0);
    Scale = tanFOV / ScreenWidthHalf;

    tmpWorldLoc.Y = (ScreenLoc.X - ScreenWidthHalf)  * Scale;
    tmpWorldLoc.Z = (ScreenHeightHalf - ScreenLoc.Y) * Scale;
    tmpWorldLoc.X = 1;

    GetAxes(CamRot, axesX, axesY, axesZ);
    vLook = tmpWorldLoc.X * axesX + tmpWorldLoc.Y * axesY + tmpWorldLoc.Z * axesZ;
    vLook = normal(vLook);

    WorldLoc = CamLoc + vLook / Scale;

    return WorldLoc;
}

function vector NewWorldToScreen(vector WorldLoc, float ScreenWidth, float ScreenHeight, float FOV, vector CamLoc, rotator CamRot){
    local float  ScreenWidthHalf, ScreenHeightHalf;
    local float  tanFOV, Scale, a, b, c;
    local vector tmpWorldLoc, vLook, ScreenLoc;
    local vector axesX, axesY, axesZ;

    ScreenWidthHalf    = ScreenWidth  / 2;
    ScreenHeightHalf= ScreenHeight / 2;

    tanFOV = tan(FOV * Pi / 360.0);
    Scale = tanFOV / ScreenWidthHalf;

    GetAxes(CamRot, axesX, axesY, axesZ);

    vLook = WorldLoc - CamLoc;

    a = (vLook dot axesX) * Scale;
    b = vLook dot axesY;
    c = vLook dot axesZ;

    ScreenLoc.X = ScreenWidthHalf  + b / a;
    ScreenLoc.Y = ScreenHeightHalf - c / a;
    ScreenLoc.Z = 1;

    return ScreenLoc;
}
*/