class AreaMapScan extends weapon config(scitools);

// todo hide F5 in prod mode, inaccessible prevent accidental
// todo check all keys avail vs opermode.
// todo nogui mode (disable drawportal, hotkeys and something for 1024, 1280, 1366 screens)

// todo reset nlayer after diag, 20/1 possible
// todo mark dpn-replaced level via group
// todo inspect teleporter to both stray/nonstray (in current level). highlight dest area

// todo whole !lockxy and mo_zsetmgr, allow teleporting to closest matching pn (parent of dpn) in active lastscreated layer

// no modechange zoom interventions, only third F1 reset build zoom
// where thruwall indicator for stray dpns
// red dpn inactive [ent] indocator
// original zset floorfall dist indicator on map, disableable
// mo_mark must render anyway even !enabled zset dpn
// todo relev_fast quality
// todo revert last mover action
// todo blockall blockplayer raadius editor, auto override mwheel action, acq by laser
// todo test mode for straydpn, both mark/unmark mode
// todo placeable mark to hide map lines, horz/vert/45, big DELETE, any-placeable, spawn at player nose, max priority
// after saveload, ctl_mw not working even on last active zset
//todo 4th number of nowprocessed?
// todo highlight zset layer on heightbar, as well as cyan last
// todo zsets wont raycast
// todo hide "o" in build mode
// todo bug: z align corrupted


#exec texture import file="textures\scipixel.png"     name="scipixel"     package="scitools" mips=1 flags=0 btc=-2
#exec texture import file="textures\scipixel_g.png"   name="scipixel_g"   package="scitools" mips=1 flags=0 btc=-2
#exec texture import file="textures\scipixel_o.png"   name="scipixel_o"   package="scitools" mips=1 flags=0 btc=-2
#exec texture import file="textures\scipixel_p.png"   name="scipixel_p"   package="scitools" mips=1 flags=0 btc=-2
#exec texture import file="textures\scipixelblk.png"  name="scipixelblk"  package="scitools" mips=1 flags=0 btc=-2
#exec texture import file="textures\scinoblk.png"     name="scinoblk"     package="scitools" mips=1 flags=0 btc=-2
#exec texture import file="textures\sciscreenbg.png"  name="sciscreenbg"  package="scitools" mips=1 flags=0 btc=-2
#exec font    import file="textures\scifontbig.pcx"   name="scifontbig"   // 16x29
#exec texture import file="textures\scifontmatch.png" name="scifontmatch" package="scitools" mips=1 flags=2 btc=-2
#exec texture import file="textures\scibearing.png"   name="scibearing"   package="scitools" mips=1 flags=2 btc=-2

//var pathnode debugpathnodes[12800];

var int accept_var_tmp_int;                // for setpropertytext()
var bool ena_show_name;                    // show common_texname instead of sysrq
var float when_pickup;                     // 15 sec later from pickup event
var stinvfontinfo inv_finfo;               // font antimemleak spawnplug
var HUD oldHUD;                            // used for menu-related hud setup transfer
var class<HUD> oldHUDType;
var byte n_layerz,done_layerz;             // selected/shot to png layers
var bool ena_next_dpn_zset;                // if true, next spawned DPN will act as Zset leader. if found any, diag_z only iterate them
                                // diag_z - old mode, replacing
var globalconfig float VertDiscretization; // AreaZ-in sensitivity (at scantime on AMS)
var globalconfig float LayerSensitivity;   // AreaZ-out sensitivity (at drawtime on client inv)
var globalconfig float AutofallFloordist;
var /* globalconfig */ byte SHR_Factor_prodmap; // mb make this saveable
var globalconfig bool bDisableAllBtnsNotify; // prio over 2 others
var globalconfig bool bDisableLRmouseNotify;
var globalconfig bool bEnableMmouseNotify;
var globalconfig bool bUseUntrigger; // cycle call of trigger, mover trigger()/untrigger() if true [requires TriggerControl state],
                                     //  or trigger() only if false
var globalconfig bool b_SPAWNFLOOD_WARN_AutoDPNafterSummon; // autoexec mapinit() in postbeginplay(), also hide welcome clientmsg[] info
var globalconfig bool b_MY_USERINI_IS_READONLY_AutoBindKeys; // allow "set input" code, cause overwrite of user.ini settings
var float presets_z[63];             // selectable layers z
var byte presets_nmax;               // selectable total (inclusive, lay0...lay19 = 20 layers)
var float global_offset_x,global_offset_y; // map center vs world position for texture
var float scrshot_timer;             // wait after sshot to flush disk
var string common_texname;
var byte enab_region[8];             // enabled flag, bools prohibited
var vector2d region_align[8];        // global offset copy
var float region_scale[8];           // map_resolution copy of region, used for geoscale. pxzoom is always 1x
var int region_sizetex[8];           // sizetex copy
var byte region_usefloor[63]; /*was 64 */       // num of n_layerz used in this alignz slot, any 0-63
var byte region_usedby[63];  /*was 64 */         // num of n_region preset which occupy above mem, 0..7 - region, 9 - free
var byte alignz_seek;                // mem write pointer
var byte n_region;
const MO_Scan=0; const MO_Diag=1; const MO_Mark=2; const MO_Prod=3; const MO_WantDiag=6; const MO_LifetimeCfg=4; const MO_ZSetMgr=5;
var byte mode_oper;
var enum EMWAct   { MW_modX,     MW_modY,     MW_modL,        MW_zset_zone,   MW_zset_z }            mode_mwheel;
var enum ELTCfg   { LTC_Floordist,            LTC_ZSetDiscr,  LTC_LaySens,    LTC_ProdSHR }          mode_ltcfg;
var enum ERayPrc  { RP_SelFull,  RP_AllFast,  RP_AllFullEco,  RP_ClientLike,  RP_ClientFull }        mode_rayprocess;
var enum EDPNFall { DPZ_floor,   DPZ_flying,  DPZ_user,       DPZ_laser }                            mode_dpn_fall;
var enum EConf    { MC_Reset,    MC_Doit,     MC_Yesimsure,   MC_Stopfuckingasking,   MC_Confirmed } mode_confirm;
var bool ena_debug;                  // show regions debug data
var bool ena_dpn_alice;              // rabbithole mode: show untouched dpns in red color - for level-unfamiliar users
var bool ena_lockz;                  // snap selz to playerz (vert coord lock)
var bool ena_lockxy;                 // snap map center to player (horz coords lock)
var bool ena_2xzoom;                 // half tex resolution (digital zoom)
var bool ena_4xzoom;                 // quarter
var bool pw_sens_fire;               // true if user holds weaponfire
var float accumulated_pw_sens_fire;  // for full quality preview mode
var int mode_autospawn;              // 0=disable, 1=each 192, 2=each 128
var float autospawn_timer, autospawn_interval;
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
const    SHR_Factor_default=2;
const    SHR_Factor_max=5;           // up to 7 supported
var STLight lightbeam;               // light blast
var STLaser laserdpn;                // lased DPN location
var STLaserBlast laserdot,laser_sector_sta,laser_sector_end;  // laser blast; aux start,end (for directional angle markers)
var float anywall_half_angle;        // horz rotator bounds of aux lasers to define scan sector for anywalls, in UR units
var bool ena_anywall;                // disable anti-artifacts check of RT if true, also enables two lasers above
var byte mode_laser;                 // 0=off, 1=inf, 2=finite
var trigger sens_trig;               // sensed trigger for controlling
var mover sens_mov;                  // sensed mover for controlling
var bool sens_ignore;
var bool ena_prod;                   // execute prod sequence if true
var byte order_welcome_msgs;
var float welcome_msgs_timer;
var bool ena_ams_render;             // global disable, to preview fullscr level
var int pn_tot,pn_mz, rc_tot;        // pathnode total qty, matchz qty, rays cast total
var playerpawn p;                    // owner
// ============================================================================================================
// Layer manager relateed
// ============================================================================================================
var PathNodeRuntime zset_list[63]; // leader dpn-related // todo why not 63
var byte zset_n;                 // todo rename to qty
var byte zset_kill_confirm;      // 0..3
var float zset_kill_timer;
var float zbar_rebuild_timer;
var int zbar_stray_total;
var int next_layer_id;
var int n_zset;                // selected
const pending_layer_thickness_default = 32.0;
const active_layer_release_dist = 128.0;  // outside this radius - show preview layer // todo merge these
const layer_edit_capture_dist = 128.0;  // inside radius - last ZSet DPN editable
const layer_thickness_min = 32.0;
const layer_thickness_max = 8192.0; // todo steps, switch by <S/D>
var bool bZSetEditMode; // true = control created ZSets, false = control pending layer
// ============================================================================================================
// CALIBRATION DATA. Added to eliminate magicnumbers from code.
// ============================================================================================================
const user_hold_health = 500;
const searchlight_direction = 4096;   // horz pitch to rotate
const hud_maptex_offset_x = 685;      // coords of texture top left, relative to canvas top left
const hud_maptex_offset_y = 15; 
const anti_artifacts_maxslope = 5300; // don't ignore raypoint if hitnormal pitch don't exceed this
const advance_ray_pos_full = 512;     // speed of rotator for raycast cycle, precise mode
const advance_ray_pos_std = 1024;     // normal mode
const advance_ray_pos_fast = 8192;    // economode
const advance_ray_pos_shit = 12288;   // max performance
const timetrigger_pw_sens_fire=0.45;  // how long hold fire to preview full render mode
const max_fastscan_vsizesq = 2400000; // ignore dist>1536 pathnodes when in rmodes 1,3
const dpn_addz_narrow = 24;    // height of scanned wall perimeter, 50 cm
const dpn_addz_narrower = 12;  // cause too many lines on laddersteps but maybe people prefer this
const dpn_addz_classic = 61;   // 130 cm, vanilla unreal pathnode placement
const player_vs_dpn_addz = 16; // 80/2 = 40; 40-24 = 16, compensate playerz
const sens_trig_radius = 384;  // how far to sense triggers
const max_size_tex = 1024;
const max_autofall_tracedown = 768;
const max_anywalls_tracesector = 1280;
const hardcode_scrw = 1920;
const hardcode_scrh = 1080;
const kill_dpn_radius_by_laser  = 12.0;
const kill_dpn_radius_by_player = 32.0;
const shithole = vect(32767,32767,32767); // inspired by Charlie Clouser
// ============================================================================================================
const zbar_w = 1024;               // level dpn spots indicator
const zbar_h = 18;
const zbar_y = 1051;               // ui related, todo attach to hud_maptex_offset_y
const zbar_draw_w = 192;           // histogram width (build mode)
const zbar_draw_h = 192;           // histogram height (build mode)
const zbar_marker_w = 2;           // owner marker under histogram
const zbar_marker_h = 3;
var byte  zbar_count[zbar_w];       // number of DPNs found, total
var byte  zbar_count_stray[zbar_w];
var int   zbar_used[zbar_w];       // indices of non-empty bins (compression)
var int   zbar_used_n;             // count of non-empty bins
var byte  zbar_used_max;           // max bin value (height normalization)
var float zbar_zmin, zbar_zmax;    // Z bounds for autoscale
var bool  zbar_valid;              // no_diag flag
var bool  zbar_irrelevant;         // expired flag (todo merge these two)
// === readability ============================================================================================
const pn_delayed   = true;   const maptex_x = false;
const pn_immediate = false;  const maptex_y = true;
const pn_leader    = true;
const pn_raytracer = false;
const pass_one     = false;
const pass_two     = true;
// ============================================================================================================
var color           /* UI color, set in postbeginplay() */          pc_gray_map,
   pc_blue,    pc_blue_f,    pc_orange,  pc_orange_f,  pc_brown,    pc_green_map,
   pc_bluer,   pc_bluer_f,   pc_green,   pc_green_f,   pc_brown_f,  pc_bluer_map,
   pc_yellow,  pc_yellow_f,  pc_pink,    pc_pink_f,    pc_bg,       pc_blue_map,
   pc_cyan,    pc_cyan_f,    pc_pinker,  pc_pinker_f,  pc_gray,     pc_fill_bg,
   pc_teal,    pc_teal_f,    pc_red,     pc_red_f,     pc_wh,       pc_wh_f;
enum EKeyWhere{      // UI key event for anim
   kw_f1, kw_1, kw_7, kw_u, kw_r, kw_f, kw_home,
   kw_f2, kw_2, kw_8, kw_o, kw_t, kw_v,
   kw_f7, kw_3, kw_z, kw_y, kw_h, kw_m, kw_n,
   kw_f4, kw_4, kw_x, kw_q, kw_lmb, kw_mmb, kw_rmb,
   kw_f3, kw_5, kw_b, kw_none, kw_ijkl, kw_pupd,
   kw_f8, kw_6, kw_g, kw_ent, kw_p, kw_f6};
var float      key_when;
var EKeyWhere  last_kw;
// ============================================================================================================
// UI COORDS
// ============================================================================================================
const pad_glob = 10; // <-- padding;  dimensions,       texdata             viewport
const pad_view = 12;            const fonw = 16;  const fillw = 23;  const vieww = 665;
const pad_fonh_half = 15;       const fonh = 29;  const fillh = 23;  const viewh = 375;
const fmpos_sq = 1; const fmpos_up = 18; /* once char+border*/ const fmpos_dn = 35; // twice
const x_vp = 10; // viewport x; pad_glob       here and further, x_::: - static coord
const y_vp = 78; // viewport y; (2*pad_glob)+(2*fonh)           :::_x - dynamic
const y_about = 10; const x_about = 10; // about label                 /* col text, xpos-2 */
   /* col header; y=(3*pad_glob)+(2*fonh)+viewh+pad_fonh_half */      const x_col_oper = 10;
const y_hdr_oper = 463;     const x_hdr_oper = 42;     /* xpos 2  */  const x_col_map_ctl = 250;
const y_hdr_map_ctl = 463;  const x_hdr_map_ctl = 282; /* xpos 16 */  const x_col_lvl_ctl = 458;
const y_hdr_lvl_ctl = 463;  const x_hdr_lvl_ctl = 506; /* xpos 31 */  const x_col_user = 10;
const y_hdr_user = 666;     const x_hdr_user = 58;     /* xpos 3  */  const x_col2_user = 250;
const y_hdr_region = 637;   const x_hdr_region = 490;  /* xpos 30 */  const x_col_region = 458;
const y_hdr_place = 827;    const x_hdr_place = 74;    /* xpos 4  */  const x_col_place = 10;
const y_hdr_mouse = 812;    const x_hdr_mouse = 490;   /* xpos 30 */  const x_col_mouse = 458;
const x_rcol = 1719; // right sidebar xpos 0; (3*pad_glob)+vieww+max_size_tex
const y_rcol_texdata = 10;      //=pad_glob
const y_rcol_texdata_fill = 49; //=(pad_glob*2)+(fonh)
const y_rcol_player = 308;      //=fill+(9*fillh)+(8*1)+pad_glob (+fonh)
const y_rcol_scope = 453;    /* 5 lines lower */  const y_clientmsg = 90;  //=(pad_glob*2)+(fonh*2)+pad_view
const y_rcol_align = 569;    /* 4 lines lower */  const y_statusbar = 412; //=y_vp+viewh-pad_view-fonh
const y_rcol_region = 714;   /* 4 lines lower */  const x_view_lpos = 22;  //=pad_glob+pad_view
const y_rcol_lifetime = 830; /* 5 lines lower */  const x_view_rpos = 643; //=vieww-pad_glob+pad_view
const y_rcol_noob = 1041;    //=hardcode_scrh-pad_glob-fonh
// ============================================================================================================
// USER OPERATION MODE SWITCHING
// ============================================================================================================
exec function tog_opermode(byte sw_to_oper){
   if(ena_prod) return;
//   local byte i;
// if(mode_oper == sw_to_oper) return;  // 2026-02-05: disabled, for mode reset to defaults
   ena_dpn_alice = false;
   if(ena_debug) return;  if(mode_oper==MO_WantDiag){ mode_oper=MO_Scan; return; }
     key_when = 0.3;        switch(sw_to_oper){
   case MO_Scan: last_kw=kw_f1;    n_region=9; mode_rayprocess = RP_ClientLike; mode_mwheel = MW_modL;   // new code above
     if(mode_oper==MO_Scan){          // reset zooms on second press
        ena_2xzoom=true; ena_4xzoom=false;
        SHR_Factor_scanmap=SHR_Factor_default; upd_resolution();
     }                       mode_oper=MO_Scan;                                                          break;
   case MO_Diag: last_kw=kw_f7;    mode_oper=MO_WantDiag;     n_region=9;     mode_confirm = MC_Reset;
     mode_mwheel = MW_modL;
                                                                                                         break;
   case MO_Mark: last_kw=kw_f4; if(mode_oper==MO_WantDiag) return;
     if(mode_oper==MO_Mark){
        ena_2xzoom=false; ena_4xzoom=false;
        SHR_Factor_scanmap=SHR_Factor_prodmap; upd_resolution();
     }
     mode_oper=MO_Mark; n_region=0; mode_rayprocess = RP_ClientLike; mode_mwheel = MW_modL; //was AllFast
     mode_laser=0; sanitize_laser();                                                                     break;
   case MO_Prod: last_kw=kw_f8; if(mode_oper==MO_WantDiag) return;
                     mode_oper=MO_Prod;         n_region=0;    /*  ena_2xzoom=false; ena_4xzoom=false;
     SHR_Factor_scanmap=SHR_Factor_prodmap;    upd_resolution(); */  ena_lockz=false;  ena_lockxy=false;
     mode_rayprocess = RP_SelFull;  mode_mwheel = MW_modL;         mode_laser=0;     sanitize_laser();   break;
   case MO_LifetimeCfg: last_kw=kw_f6; if(mode_oper==MO_WantDiag) return;
                          if(mode_oper!=MO_LifetimeCfg){ mode_oper=MO_LifetimeCfg; mode_ltcfg=LTC_Floordist; }
              else{          mode_oper=MO_Scan;         n_region=9;
     mode_rayprocess = RP_ClientLike; mode_mwheel = MW_modL;       }                                     break;
   case MO_ZSetMgr: /* last_kw=kw_f9; */ mode_oper=MO_ZSetMgr; mode_mwheel=MW_zset_zone;  mode_laser=0; sanitize_laser(); break; }
} 
// ============================================================================================================
// USER REGION SELECT/TOGGLE + CONFIRM MEM-DESTRUCTIVE ACTIONS
// ============================================================================================================
exec function tog_region(byte new_nregion){
   local bool bFailConf;
   if(mode_oper==MO_LifetimeCfg || ena_debug || ena_prod) return; // added ena_prod
   if(new_nregion>7) return;
   if(mode_oper==MO_WantDiag && new_nregion<=3) goto user_validation_uni;
   if(mode_oper!=MO_Mark && mode_oper!=MO_Prod) return;  // ?????? why prod?
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
      do_diag_z(false);
      tog_opermode(2);
   }
}
// ============================================================================================================
// FLOOR
// ============================================================================================================
exec function tog_layerz_assign(){
   local byte mod_pointer;
   if(ena_prod) return;
   if(mode_oper==MO_ZSetMgr){
      if(bZSetEditMode) layer_toggle_active(n_layerz);
      return;
   }
   if(mode_oper==MO_LifetimeCfg || ena_debug) return;
   if(mode_oper==MO_Prod) goto skip_by_prodmode_ent_action;
   if(presets_nmax == 0) return;   // no presets - AlignZ fill unavailable
   if(alignz_seek > 62) alignz_seek = 62;
   mod_pointer = (alignz_seek > 0) ? 1 : 0;
   if(   get_layer_z(n_layerz) == get_layer_z(region_usefloor[alignz_seek-mod_pointer])
      && n_region == region_usedby[alignz_seek-mod_pointer] && alignz_seek>0){
      region_usefloor[alignz_seek-mod_pointer] = 0;
      region_usedby[alignz_seek-mod_pointer] = 9;
      alignz_seek--;
   }else{
      region_usefloor[alignz_seek] = n_layerz;
      region_usedby[alignz_seek] = n_region;
      if(alignz_seek<62) alignz_seek++;
   }
   return;
   skip_by_prodmode_ent_action:
   prod();
}

// Z of layer by index: select from ZSet, otherwise from presets_z (fallback)
function float get_layer_z(int idx){        // todo remove presets ????? need presets
   if(zset_n>0 && idx>=0 && idx<zset_n && zset_list[idx]!=none)
      return zset_list[idx].location.z;
   if(idx>=0 && idx<presets_nmax)
      return presets_z[idx];
   return 0.0;
}

exec function tog_dpntest(){ // todo move down
   if(mode_oper==MO_Mark || mode_oper==MO_Prod){
      ena_dpn_alice = false;
      return;
   }
   key_when = 0.3; last_kw = kw_f3;
   ena_dpn_alice = !ena_dpn_alice;
}
// ============================================================================================================
// USER MACROS
// ============================================================================================================
exec function init(){ playselect(); } // Used for recall hotkeys upon loadgame if read-only user.ini
exec function diag(){ do_diag_z(false); }  // Invoke diag proc without confo. Destroys all AlignZ selection data.
// Old code `spawn(class'pnze');` makes rediag necessary, bc map pays attention to normal PathNode locations
// only, not PathNodeRuntime as well. This was causing map gaps in AI-unkn spots in case of vert mismatch.
exec function dpn(string nmode){
   local pathnoderuntime dpn;
   foreach allactors(class'pathnoderuntime',dpn){
      if(nmode=="mark")   dpn.bIsKillGoal = true;
      if(nmode=="unmark") dpn.bIsKillGoal = false;
   }
}
exec function savecfg(){ saveconfig(); }  // scitools.ini mgmt
exec function readcfg(){ resetconfig(); }
exec function killzsets(){ if(ena_prod) return; layer_remove_all(); }

exec function ams(string name_var, string content_var){ if(ena_prod) return; switch(name_var){
   case "fd":
      setPropertyText("accept_var_tmp_int",content_var);
      if(accept_var_tmp_int>0) AutofallFloordist = accept_var_tmp_int; break;
   case "zd":
      setPropertyText("accept_var_tmp_int",content_var);
      if(accept_var_tmp_int<40) break;
      if(accept_var_tmp_int>384) accept_var_tmp_int = 384;
      VertDiscretization = accept_var_tmp_int;                         break;
   case "ls":
      setPropertyText("accept_var_tmp_int",content_var);
      if(accept_var_tmp_int<40) break;
      if(accept_var_tmp_int>384) accept_var_tmp_int = 160;
      LayerSensitivity = accept_var_tmp_int;                           break;
   case "shr":
      setPropertyText("accept_var_tmp_int",content_var);
      if(accept_var_tmp_int<=0) break;
      if(accept_var_tmp_int>7) accept_var_tmp_int = 7; 
      SHR_Factor_prodmap = accept_var_tmp_int;                         break;
   case "name":
      setPropertyText("common_texname",content_var);                   break;  }
}
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
/*   n_region=9; mode_rayprocess = RP_ClientLike;
   ena_2xzoom=true; ena_4xzoom=false;
   ena_lockz=true;  ena_lockxy=true;
   SHR_Factor_scanmap=SHR_Factor_default; upd_resolution(); */
   new_clientmsg[0] = "AreaZ[] set diag sequence";
   new_clientmsg[1] = "has been cancelled.";
   clientmsg_timer = 2.5;
}
function int maptex_coord(float wx,bool axis_y){  // texture coords incl. hud delta
   local int mx;
   local int apply_offset;
   mx = (int(wx) >> SHR_Factor_scanmap);
   apply_offset = axis_y ? (int(global_offset_y)) : (int(global_offset_x));
   mx += (size_tex>>1); mx += (apply_offset >> SHR_Factor_scanmap);
   if(ena_2xzoom){ mx *= 2; mx -= (size_tex>>1); }
   if(ena_4xzoom){ mx *= 2; mx -= (size_tex>>1); }
   mx += (axis_y ? hud_maptex_offset_y : hud_maptex_offset_x);
   return mx;
}
function int world_to_map_x(float wx){ return maptex_coord(wx,maptex_x) + hud_maptex_offset_x; }
function int world_to_map_y(float wy){ return maptex_coord(wy,maptex_y) + hud_maptex_offset_y; }
function bool map_tex_out_of_bounds(int hlx, int hly){
   return ( hlx<hud_maptex_offset_x || hly<hud_maptex_offset_y ||
      hlx>hud_maptex_offset_x+size_tex || hly>hud_maptex_offset_y+size_tex );
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
   case 7: return !bfade ? pc_brown  : pc_brown_f;  break; } return pc_gray;
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
function int maptex_centering(int now_size_tex){
   if(mode_oper==MO_Prod) return 0; // disable offset in prod mode, for correct ffmpeging the result
   switch(now_size_tex){
   case 256: return 384; break;
   case 512: return 256; break;
   case 1024: return 0; break; } return 0;
}
function adv_welcome_msgs(){
   if(order_welcome_msgs>5){ // set above than this number in postbeginplay() to suppress
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
           new_clientmsg[1]="";    clientmsg_timer=4.0; break;  }
}
// ============================================================================================================
exec function sci_forcedodge(){
   if(p == none) return;
   if(ena_prod) return;
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
   if(mode_oper==MO_LifetimeCfg || ena_debug) return;
   if(mode_oper!=MO_Mark) return;    // ena_prod already grants it, no need to check
   key_when = 0.3; last_kw = kw_m;
   if(n_region>7) return;  // prohibit access outside of array
   enab_region[n_region] = 1;
   region_align[n_region].x = global_offset_x;
   region_align[n_region].y = global_offset_y;
   region_scale[n_region] = map_resolution; //SHR_Factor_prodmap;   // behave as SHR_factor
   region_sizetex[n_region] = size_tex;
}
exec function prod(){
   local byte i,i_max;
//              k;     // global texture counter
   local string tmp_s,tmp_ss;
   local bool reg_unused;
   if(mode_oper==MO_LifetimeCfg || ena_debug) return;

   if(p!=none && p.player!=none && p.player.console!=none){ // if console nandle nonempty
      if(p.player.console.isinstate('typing') || p.player.console.isinstate('Open')){
         p.player.console.gotostate('');        // force close console
         p.player.console.bnodrawworld = false;
      }
   }

   reg_unused = alignz_seek==0;
//   k = 0;
      log(" ====================================",'AMS');
      log(" ==  EXEC THIS IN SCREENSHOTS DIR  ==",'AMS');
      log(" ====================================",'AMS');
      log(" dir /od /tc /b /a-d > amsr_"$common_texname$".bat",'AMS');
      log(" ",'AMS');
   new_clientmsg[0] = "Writing amd_"$common_texname$".uc data into log...";
   clientmsg_timer = 1.7;
      log(" =====================================================",'AMS');
      log(" ==  REMEMBER TO RENAME ME WHEN SAVING AS .UC FILE  ==",'AMS');
      log(" =====================================================",'AMS');
      log(" class amd_"$common_texname$" extends AreaMapData;",'AMS');
      log(" ",'AMS');
   i=0;
   i_max = !reg_unused ? alignz_seek : presets_nmax;
   for(i=0; i<=i_max; i++){                   // sortz counter shows last array, not qty, so 0..19 is actually 20
      if(!reg_unused && region_usedby[i]==9) continue;
      tmp_s = ""; if(i<10) tmp_s $= "0"; tmp_s $= string(i);
      log(" #exec texture import file=\"textures\\"$common_texname$"\\amd_"$common_texname$"_"
         $tmp_s$".png\" name=\"amd_"$common_texname$"_"$tmp_s$"\" mips=1 flags=0 btc=-1",'AMS');
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
      log("   FloorHeight="$LayerSensitivity,'AMS');
   for(i=0; i<=i_max; i++){
      if(!reg_unused && region_usedby[i]==9) continue;
      tmp_s = ""; if(i<10) tmp_s $= "0"; tmp_s $= string(i);
      log("   MapTex("$i$")=texture'amd_"$common_texname$"_"$tmp_s$"'",'AMS');
  }for(i=0; i<=i_max; i++){
      if(!reg_unused && region_usedby[i]==9) continue;
      tmp_ss = !reg_unused ? string(int(region_align[region_usedby[i]].x)) : string(int(global_offset_x));
      log("   AlignX("$i$")="$ tmp_ss, 'AMS');
  }for(i=0; i<=i_max; i++){
      if(!reg_unused && region_usedby[i]==9) continue;
      tmp_ss = !reg_unused ? string(int(region_align[region_usedby[i]].y)) : string(int(global_offset_y));
      log("   AlignY("$i$")="$ tmp_ss, 'AMS');
  }for(i=0; i<=i_max; i++){
      if(!reg_unused && region_usedby[i]==9) continue;
      // tmp_ss = !reg_unused ? string(int(presets_z[region_usefloor[i]])) : string(int(presets_z[i])); // old code
      tmp_ss = !reg_unused ? string(int(get_layer_z(region_usefloor[i]))) : string(int(get_layer_z(i)));
      log("   AlignZ("$i$")="$ tmp_ss,'AMS');
  }   log(" }",'AMS');
      log(" ",'AMS');
   new_clientmsg[0] = "Writing cropping.bat data...";
   clientmsg_timer = 1.7;
      log(" ==================================================",'AMS');
      log(" ==  CHECK PATHS BEFORE LAUNCH. FFMPEG REQUIRED  ==",'AMS');
      log(" ==================================================",'AMS');
   for(i=0; i<=i_max; i++){
      if(!reg_unused && region_usedby[i]==9) continue;
      tmp_s = ""; if(i<10) tmp_s $= "0"; tmp_s $= string(i);
      tmp_ss = !reg_unused ? string(region_sizetex[region_usedby[i]]) : string(size_tex);
      log(" ffmpeg -i "$tmp_s$".png -q:v 0 -qmin 1 -vf \"crop="$tmp_ss$":"$tmp_ss$":"$
           hud_maptex_offset_x$":"$hud_maptex_offset_y$"\" amd_"$common_texname$"_"$tmp_s$".png",'AMS');
   }  log(" ",'AMS');
   n_layerz = 0;
   ena_prod = true;
   done_layerz = 0;
   scrshot_timer = 2.0;
}

exec function q(){
   local int iv;
   local string c_cmd,c_ucon,c_link,c_var,c_key,c_str;
   if(owner==none) return;
   iv = int(Level.EngineVersion);
   c_cmd  = "";
   c_ucon = "";
   c_link = "";
   c_var  = "";
   c_str  = "";
   if(iv>=227){
      c_cmd  = chr(27) $ chr(190) $ chr(190) $ chr(240);
      c_ucon = chr(27) $ chr(120) $ chr(255) $ chr(120);
      c_link = chr(27) $ chr(80)  $ chr(80)  $ chr(255);
      c_var  = chr(27) $ chr(240) $ chr(190) $ chr(240);
      c_key  = chr(27) $ chr(255) $ chr(255) $ chr(60);
      c_str  = chr(27) $ chr(255) $ chr(255) $ chr(255);
   }
   p.clientmessage("Welcome to AMS - semiautomatic areamap production tool.");
   p.clientmessage(" ");
   p.clientmessage("              Getting started");
   p.clientmessage(" ");
   p.clientmessage("By default AMS do not bind its keys to user console, because users complained. Simultaneous assign of both user keys and AMS keys is useless, some of them MUST be removed to make things working properly. For example, AMS uses <T> key which is assigned to teamspeak. Follow these instructions to override:");
   p.clientmessage(" ");
   p.clientmessage("1. Save AMS config to write scitools.ini if it doesn't exist, then terminate:");
   p.clientmessage(c_ucon$"   savecfg");
   p.clientmessage(c_ucon$"   exit");
   p.clientmessage("2. Edit config:");
   p.clientmessage(c_cmd$"   notepad scitools.ini");
   p.clientmessage("3. Change autobind variable this way:");
   p.clientmessage(c_var$"   b_MY_USERINI_IS_READONLY_AutoBindKeys=True");
   p.clientmessage("4. Save file, close it and relaunch unreal. You need R/O attribute set on user.ini file, or use another copy of it. To specify separate user.ini, use command: "$c_cmd$"unreal %1 userini=user_ams.ini "$c_str$" where %1 is name of .unr file.");
   p.clientmessage(" ");
   p.clientmessage("AMS use PathNode runtime-placeable equivalent as epicenters of raytracing to construct hull/walls and solid collision. Due to collision reactivity with bCollideActors, most puckups and deco are auto-removed. You can clean excessive scan obstacles in PNG editor like GIMP, PS or mspaint. AMS also supports raytracing from bStatic normal PathNodes, but this feature is transitional. I will debug it further.");
   p.clientmessage("Your task is to spawn PathNodeRuntime, or dummy pathnodes, DPN, on level - lots enough to do effective walls scan, though less enough to don't cause FPS freeze. Always remember, Unreal Virtual Machine works in single-thread manner on single core of CPU. Because of this, even if you have very powerful processor such as latest Ryzens, excessive raycasting will eat framerate. In build, or DPN placement mode, many measures were taken to minimize load. Laggy performance while max quality mode won't be long; after export is done, AMS will return to build mode.");
   p.clientmessage(" ");
   p.clientmessage("General hint: place DPNs near walls at every walkable places.");
   p.clientmessage(" ");
   p.clientmessage("This version almost got rid of scanning artifacts, but this may lead to some objects inconsistency. This behavior fixed by special mode of scanning actors when placing these, called strict walls/directional anywalls. Even hill/slope will count as \"wall\", so directional DPNs must have correct scan sector and rotation to minimize artifacts.");
   p.clientmessage(" ");
   p.clientmessage("              Navigation:");
   p.clientmessage(c_key$"W/A/S/D, Spc, C"$c_str$" - regular move.");
   p.clientmessage(c_key$"Alt"$c_str$" - single-key dodge. Used in pair with dodge direction keys (move keys).");
   p.clientmessage(" If player stand still, does nothing. Diagonal directions are auto-detected. In water, just increase speed shortly. You may train some bunnyhopping timing with it.");
   p.clientmessage("Repeat "$c_key$"C"$c_str$" three times - request autofly mode. Repeat time window is 0.4/0.4 sec.");
   p.clientmessage(" Acts same as \"fly\" console command, but without raising user's hand from mouse. If flying no higher than 56uu from floor surface, autowalk will be triggered. Autofly step resets in 1.2 sec.");
   p.clientmessage(c_key$"P"$c_str$" - disable water flag of current zone. This action can't be undone. Use "$c_ucon$"editactor class=zoneinfo"$c_str$" console command to revert the effect. Pain flag is always auto-disabled in all zones. Player is set to amphibious.");
   p.clientmessage(" ");
   p.clientmessage("              Zooms, steps/scale related:");
   p.clientmessage(c_key$"Z, X"$c_str$" - digital and spatial zoom. Digital zoom enlarge map pixels, can be set to 1x, 2x, 4x. Spatial zoom controls SHR_Factor, or actual vectors division.");
   p.clientmessage(" More divided coords means less level area, i. e. more zoom. Can be set to these factors: 1px = 32uu, 16uu, 8uu, 4uu, 2uu. Both types of zoom cause less CPU load due to less processing.");
   p.clientmessage(c_key$"B"$c_str$" - control step size of map offset, when horizontal lock (aka lock XY) disabled. Spoken terms are described further.");
   p.clientmessage(c_key$"G"$c_str$" - control the size of map black texture, aka region size. Both controls are working in zoom manner (key toggle 3 values).");
   p.clientmessage(" ");
   p.clientmessage("              Lock/offset:");
   p.clientmessage(c_key$"U"$c_str$" - LockZ aka lock layer - snap map vertically, or inherit AreaZ from PlayerZ. Good for realtime scan result preview.");
   p.clientmessage(c_key$"O"$c_str$" - LockXY - snap center of map to center of player X;Y coords in level. Making search of player marker less necessary.");
   p.clientmessage(c_key$"R"$c_str$" - toggle axis which will be altered by mouse wheel, with selected step size.");
   p.clientmessage(c_key$"I/J/K/L"$c_str$" - horizontal offset, acts same as mouse wheel in X, Y mode.");
   p.clientmessage(c_key$"PgUp/PgDn"$c_str$" - vertical offset, same as wheel in Z mode. Controls AreaZ presets, which can be obtained by diag mode.");
   p.clientmessage(" ");
   p.clientmessage("              User/misc features:");
   p.clientmessage(c_key$"T"$c_str$" - toggle mover ignore. Useful for eliminating horizontal lifts as obstacle.");
   p.clientmessage(c_key$"Y"$c_str$" - searchlight. Useful in very dark places of level.");
   p.clientmessage(c_key$"Q"$c_str$" - toggle laser mode; off, infinite minus some distance from walls, or finite with max length from player.");
   p.clientmessage(" Infinite laser is colliding, finite laser is always ghostmode. Useful for DPN placement in player-unreachable spots. Any mode of laser switch coords monitor to show laser instead of player. Used to create map reactors (interactive regions of player interest such as open/closed doors, fences, inactive/active lifts etc). Laser show nowspawning DPN render result as pink color walls of map.");
   p.clientmessage(c_cmd$"(no key)"$c_str$" - player marker, automatic (forced off in prod mode, on in other modes).");
   p.clientmessage(" ");
   p.clientmessage("              DPN placement:");
   p.clientmessage(c_key$"F"$c_str$" - let them sit in spawned area (flying), autofall on floor (with floordist) or copy height of player/laser (inherit z)");
   p.clientmessage(c_key$"V"$c_str$" - autospawn them");
   p.clientmessage(c_key$"H"$c_str$" - toggle directional mode with setting of horizontal scan angle.");
   p.clientmessage(" These DPNs produce rendering artifacts if pointed to incorrect places such as walkable hills, floors, slopes, climbable rocks. Regular DPNs protecting from artifacts by checking wall vertical angle, but won't recognize some unwalkable obstacles and show these as empty space.");
   p.clientmessage(c_key$"Mid mouse/wheel press"$c_str$" - spawn DPN in manual mode. Always available.");
   p.clientmessage(c_key$"Right mouse"$c_str$" - kill all pawns in level and remove DPNs in area. Spawn/remove does respect laser, which is useful for increased precision DPNs placement.");
   p.clientmessage(" ");
   p.clientmessage("Left mouse:");
   p.clientmessage(c_ucon$"->"$c_str$" When laser is off, open by trigger. All triggers are active, triggerable, norepeatable.");
   p.clientmessage(" If movers tagged to trigger, these will be started (executes mover.trigger() or mover.untrigger() on them). Untrigger() call is disabled by default; this behavior controlled by bUseUntrigger variable in scitools.ini");
   p.clientmessage(c_ucon$"->"$c_str$" When laser is on, open by mover.");
   p.clientmessage(c_ucon$"->"$c_str$" Always, when held for more than 0.6 sec, enable better quality of map scan for quick preview.");
   p.clientmessage(" ");
   p.clientmessage("              Operation mode:");
   p.clientmessage(c_key$"F1"$c_str$" - build bode. Used for DPN placement and convenient navigation by map.");
   p.clientmessage(" Sets these display behavior defaults:");
   p.clientmessage(c_ucon$" ->"$c_str$" 2x digital zoom    "$c_ucon$"->"$c_str$" 4uu spatial zoom    "$c_ucon$"->"$c_str$" lockZ, lockXY enabled");
   p.clientmessage(c_key$"F4"$c_str$" - region markup mode. Used for final align assign layers to certain regions.");
   p.clientmessage(" Sets these defaults:");
   p.clientmessage(c_ucon$" ->"$c_str$" 1x digital zoom    "$c_ucon$"->"$c_str$" 16uu spatial zoom    "$c_ucon$"->"$c_str$" coords lock disabled    "$c_ucon$"->"$c_str$" max quality");
   p.clientmessage(c_key$"F7"$c_str$" - region reconstruct mode, aka AreaZ diagnostics. Performs these actions:");
   p.clientmessage(" - all DPNs in level will be collected, and their Z roughed according to Z discretization (explained further);");
   p.clientmessage(" - remove non-unique and sorted;");
   p.clientmessage(" - if set exceed 63 elements of array, more will be ignored.");
   p.clientmessage(" Diag mode may make already used region info irrelevant, so use it "$c_var$"before"$c_str$" markup, or "$c_var$"with caution"$c_str$". Protected by four keys confirmation (press 1, 2, 3, 4 sequence) to prevent invoking this accidentally.");
   p.clientmessage(c_key$"F8"$c_str$" - production mode. Auto scroll all regions and their layers, screenshoting the result, writes .uc package template and .bat script template to unreal.log; use text editor to correct these files to your needs.");
   p.clientmessage(" You can obtain list of screenshots sorted by creation time with command:");
   p.clientmessage(c_cmd$" %unrealdir%\\system\\screenshots> dir /od /tc /b /a-d > file.bat");
   p.clientmessage(c_key$"Enter"$c_str$" (in prod mode) - begin export process. After done, AMS will return to build mode.");
   p.clientmessage(" ");
   p.clientmessage("              Config variables (scitools.ini):");
   p.clientmessage(c_var$"VertDiscretization"$c_str$" aka IN AreaZ sensitivity - height of zone counted as corresponding map layer. Less layers means less textures and thus smaller file. Optimal: 128.");
   p.clientmessage(c_var$"LayerSensitivity"$c_str$" aka OUT AreaZ sensitivity - height of zone where actual map layer shows certain texture. More layers means more z-responsive map. Optimal: 64.");
   p.clientmessage(c_var$"AutofallFloordist"$c_str$" - height of most DPNs relative to floor;");
   p.clientmessage(" classic unreal dist is 61uu, narrow floor - 24, narrower - 12");
   p.clientmessage(" narrower may cause some artifacts and excessive lines on stairsteps due to their typical 16uu height.");
   p.clientmessage(c_var$"bDisableAllBtnsNotify"$c_str$" - do not rogerblink pressed key name in the interface.");
   p.clientmessage(c_var$"bDisableLRmouseNotify"$c_str$" - do not blink for left/right mouse buttons, even if other keys still enabled.");
   p.clientmessage(c_var$"bEnableMmouseNotify"$c_str$" - blink for mid mouse button as well.");
   p.clientmessage(c_var$"bUseUntrigger"$c_str$" - cycle between executing trigger()/untrigger() on activatables or trigger() only.");
   p.clientmessage(c_var$"b_SPAWNFLOOD_WARN_AutoDPNafterSummon"$c_str$" - autoexec mapinit command upon summon. Cause overspawn of DPNs if tool summoned twice/more.");
   p.clientmessage(c_var$"b_MY_USERINI_IS_READONLY_AutoBindKeys"$c_str$" - enable keymapping. Cause user settings overwriting (always). Make copy of file before use.");
   p.clientmessage(" ");
   p.clientmessage("              Regions and prepare to prod:");
   p.clientmessage(c_key$"1-8"$c_str$", incl numpad keys - select/toggle region.");
   p.clientmessage(c_key$"M"$c_str$" - mark region. Map align on X;Y axis, texture size, spatial zoom of region will be overwritten.");
   p.clientmessage(c_key$"Enter"$c_str$" (in markup mode) - fill current layer number (aka diag result Z from set) to current region. Keep X;Y offset unchanged for correct map working in this area. Already existing Z in current region, if matched, will be removed if "$c_key$"Enter"$c_str$" pressed twice; this is how region layer toggle working. For region occupy navigation, no additional keys implemented yet (maybe later).");
   p.clientmessage(" ");
   p.clientmessage("              Render:");
   p.clientmessage(c_key$"F2"$c_str$" - toggle render mode");
   p.clientmessage(c_key$"F10"$c_str$" - toggle pause mode (disable all processing + hide gui)");
   p.clientmessage(c_key$"Leftmouse hold"$c_str$" - preview full quality in player area or layer matching by Z.");
   p.clientmessage("You can switch map render mode to fast/full quality, specific layer (used at export stage), or intellifast mode which is on by default (used while DPN placement as max balance-friendly). Most demanded scale is typically 1:16, because map should be big enough to navigate rooms and small enough for better level coverage. One 1024 texture with 1bpp color will take ~10 kb, so total level may stay around 0.4-1.2 mb. Multiple AreaMapData actors can work transparently, but you will need specialized iterator to render them.");
   p.clientmessage(" ");
   p.clientmessage("              Tips on how to define regions:");
   p.clientmessage("* use ALL FAST render mode to preview/positioning overall level");
   p.clientmessage("* keep regions edges with zero distance; adjacent region border may disappear just right 1px far, but not more (2px gap will result in 1px seam on map)");
   p.clientmessage("* always use same spatial zoom; inconsistent scale of coords "$c_var$"WILL"$c_str$" cause align error");
   p.clientmessage("* regions may overlap, but of course this produce some excessive drawcalls");
   p.clientmessage(" ");
   p.clientmessage("              Prod mode operation:");
   p.clientmessage("- If at least one Z preset set in TexData[] array, export will follow this array directions. You can refill it later and do one more export, if 63 map segments are insufficient for your level (your client inventory should support AreaMapData actors linkage).");
   p.clientmessage("- If array is empty, exports all Z layers discovered by "$c_ucon$"diag"$c_str$" command.");
   p.clientmessage(" ");
   p.clientmessage("              Z-diagnostics operation:");
   p.clientmessage("If any ZSet DPNs exist, only them will be iterated as heights source. To return auto mode, use "$c_ucon$"killzsets"$c_str$" command to remove them.");
   p.clientmessage(" ");
   p.clientmessage("              Viewport statusbar:");
   p.clientmessage("First number - digital zoom");
   p.clientmessage("Second, before slash - map spatial zoom, after - prod texture spatial zoom (aka prod SHR_Factor of .uc template)");
   p.clientmessage("Third number - framerate counter");
   p.clientmessage("Fourth number - total DPNs in layer, mathing by Z coord / total DPNs in level");
   p.clientmessage(" ");
   p.clientmessage("              Console commands:");
   p.clientmessage(c_ucon$"init"$c_str$" - execute playselect() again, restores all keybindings after loadgame; useful if user.ini does not contain binds.");
   p.clientmessage(c_ucon$"diag"$c_str$" - same as switching to diag mode, do Z set diagnostics+store+sort; may corrupt region/texdata.");
   p.clientmessage(c_ucon$"mapinit"$c_str$" - use level pathnodes to place DPN over them, working as initial build of zero-progress map; this command autoexec diag command.");
   p.clientmessage(c_ucon$"killzsets"$c_str$" - remove all ZSet (blue-yellow blinking) DPNs");
   p.clientmessage(c_ucon$"savecfg"$c_str$" - store current globalconfig variables to scitools.ini");
   p.clientmessage(c_ucon$"readcfg"$c_str$" - read them from scitools.ini");
   p.clientmessage(c_ucon$"ams_pause"$c_str$" - pause all raytracing and disable GUI, used for screenshoting places");
   p.clientmessage(c_ucon$"ams "$c_str$"<cfgvar> - configure certain var, alias of "$c_ucon$"set"$c_str$" console command; cfg vars are:");
   p.clientmessage("fd - "$c_var$"AutofallFloordist");
   p.clientmessage("zd - "$c_var$"VertDiscretization");
   p.clientmessage("ls - "$c_var$"LayerSensitivity");
   p.clientmessage("shr - "$c_var$"SHR_Factor_prodmap");
   p.clientmessage("name - "$c_var$"common_texname"$c_str$" (it isn't "$c_cmd$"globalconfig"$c_str$", used for configuring export textures name template)");
   p.clientmessage("Example: "$c_ucon$"ams shr 4"$c_str$" - set "$c_var$"SHR_Factor_prodmap"$c_str$" to 16.");
   p.clientmessage(" ");
   p.clientmessage("After all data prepared, AMS works unattended, just enable prod mode and wait for all screenshots will be taken. Then you can cut them, edit if you want in any graphics software, then prepare your package files and use UCC to compile. For cutting screenshoted maps (from fullscreen FHD to square map region), FFMPEG is required. It can be installed from https://www.gyan.dev/ffmpeg/builds/");
   p.clientmessage(" ");
   p.clientmessage("              Working process");
   p.clientmessage(" ");
   p.clientmessage("1. Use build mode to place DPN in appropriate places.");
   p.clientmessage("If you want define Z layers manually, spawn ZSet DPNs. These must stay on every walkable height, aka floors of level.");
   p.clientmessage("2. Switch to diag mode and approve it. This action is already performed during map init, but another analysis may be necessary (typically if DPNs spawned on never-used by bStatic PNs heights).");
   p.clientmessage("3. Switch to markup mode to define regions. You can use less than 8 regions. You can leave some of them activated (they never shows in prod mode).");
   p.clientmessage("4. Assign AlignZ fill array if you plan to use region(s). Otherwise, simply adjust X;Y ofset to fit level in texture.");
   p.clientmessage("   AlignZ fill data can be altered at any time, but only stack-editable. This means you need pop last value if you want push in current place another value. Next to LAR indicator you can see white backspace marker if current area match array data. If it shows up or down icon, current selected layer must be adjusted. If it shows square cursor, next "$c_key$"Enter"$c_str$" press will pop value, acting as backspace. This indicator grayed upon region mismatch.");
   p.clientmessage("5. Switch to prod mode and press Enter to start.");
   p.clientmessage("At any stage of production, savegame may be used to keep setings/work.");
   p.clientmessage("7. Close unreal and open "$c_cmd$"unreal.log");
   p.clientmessage("8. Search lines starting with \"ams:\" inside it. First occurence is actual file.uc contents for AreaMapData child actor. Second occurence is command(s) for FFMPEG to crop screenshots into textures, which will be used by this class. You need to move first into "$c_cmd$"your_map_package\\classes"$c_str$" folder and cropped textures into "$c_cmd$"your_map_package\\textures"$c_str$" folder");
   p.clientmessage("9. Enter (new) "$c_var$"EditPackages="$c_str$" line fou your map package in "$c_cmd$"unreal.ini");
   p.clientmessage("10. Make sure your_map_package.u file doesn't exist and start "$c_cmd$"ucc make"$c_str$" to build it.");
   p.clientmessage(" ");
   p.clientmessage("              Export considerations");
   p.clientmessage(" ");
   p.clientmessage("It is strongly recommended to do not change default vertical resolution from 128 UU, however, this is supported by AreaMapData prototype actor. I currently don't plan implementing of autostretching it for complex levels, so you will need to do it manually, and maybe rebuild scitools package. Further, maybe FFT for ZSet recognition will be added.");
   p.clientmessage("Keep an eye on movers, they ideally must stay still while screenshots made. Keep all openable doors already-open, due to solid lines on them, or it will look like noclip cheat when player crosswalk them.");
   p.clientmessage(" ");
   p.clientmessage("              Greetz:");
   p.clientmessage(" Omega, MetallicaFan212, Fumbles McStupid, all people who helped me and who I forgot to mention.");
   p.clientmessage(" ");
}
// ==================================================================================================================
function tick(float f){
   local vector hl,hn, x,y,z, spawn_where;
   local rotator r;
   local float lasermult, laserdist;
   local playerpawn pp;
   local pathnoderuntime dpn;
   local pawn pt;
   if(owner == none) return;
   if(pp!=none) goto skip_already_has_p;
   pp = playerpawn(owner);
   if(pp == none) return;
   p = pp;
 skip_already_has_p:
   p.health = user_hold_health;                    // prevent drown death
   if(p.velocity.z <= -900) p.velocity.z = -900;   // prevent fall death
   if(!ena_show_name) when_pickup = level.timeseconds; // name/sysrq select process
   if(bDisableAllBtnsNotify) key_when = 0.5;       // keyboard process
      else key_when -= f;
   if(key_when<0 && last_kw!=kw_none) last_kw = kw_none;
   water_forcedodge_timer -= f;                    // water forcedodge process
   if(water_forcedodge_timer < 0.0){
      wforcedodge_ready = true;
      p.waterspeed = 200;
   }     laserdist = 0.0;                         // safe to use this
   for(pt=level.pawnlist; pt!=none; pt=pt.nextpawn) // autokill unaggro process, for crashsite2 marines
      if(pt.enemy == p){
         pt.enemy = none;
         laserdist = 1.0;
      }
   if(laserdist>0.0) p.consolecommand("killpawns"); // exec this only one time, not for each matching pawn
   pw_sens_fire = (p.bFire!=0);                     // preview full rmode process
   accumulated_pw_sens_fire += f;
   if(!pw_sens_fire) accumulated_pw_sens_fire = 0;
   getaxes(p.viewrotation,x,y,z);
   spawn_where = p.location + 56*x;  // exec anyway, summonlike pos if laser off
   z.z = p.location.z; // store laser_z from user_z for case when laser off, to prevent usage of undefined
   if(mode_laser!=0){
      sens_mov = mover(trace(hl,hn,p.location + 4000*x,p.location,true));
      hl -= x*2;
      if(laserdot!=none) laserdot.setlocation(hl);
      laserdist = vsize(p.location - hl);
      lasermult=fclamp(laserdist/2800,-0.3,1.3);
      lasermult+=1;
      if(laserdist>2800) lasermult+=1;
      if(laserdist>5600) lasermult+=1;
      LaserDot.drawscale=lasermult;
      sens_ignore = sens_mov.group == 'sciignore';
      sens_trig = none;
      if(mode_laser == 1){
         z.z = hl.z;      // save laserblast pos z
         hl += hn*laser_wall_dist; // offset laser
      }
      if(mode_laser == 2){
         hl = p.location;
         hl += vector(p.viewrotation)*laser_ray_length;
      }
      spawn_where = hl;              // some laser trace done, laser-dictated pos
   }else{
      sens_trig = FindTrigger(p.location);
      sens_mov = none;
   }
   y = spawn_where;               // cancer code, but we don't use y later, so safe to do it
   y.z -= max_autofall_tracedown;
   trace(hl, hn, y, spawn_where, true); // trace to floor from pos got above
   if(mode_dpn_fall!=DPZ_flying) spawn_where    = hl;  // use floortraced pos if non-floating mode
   if(mode_dpn_fall==DPZ_floor)  spawn_where.z += AutofallFloordist; // falling mode, RAISE laser pos from floor
   // mode_dpn_fall==DPZ_flying, do nothing                          //  bc we traced DOWN to floor
   if(mode_dpn_fall==DPZ_user)   spawn_where.z  = p.location.z;      // inherit user z
   if(mode_dpn_fall==DPZ_laser)  spawn_where.z  = z.z;               // inherit laserblast z
// ----------------------
   if(laserdpn!=none){
      laserdpn.setlocation(spawn_where);
      foreach radiusactors(class'pathnoderuntime',dpn,kill_dpn_radius_by_player*16,p.location){ // todo ?
         if(dpn==laserdpn) continue;
         if(dpn.bIsKillGoal){
            dpn.bIsKillGoal = false;
         }
      }
      laserdpn.bHidden = (mode_laser==0) || (mode_oper==MO_ZSetMgr);
      laserdpn.bDirectional = ena_anywall;
      r = p.viewrotation;
      r.yaw -= 1536;         // compensate discrete playermarker frame  // ??? still working like shit on low sector vals
      laserdpn.setrotation(r);
      laserdpn.mass = anywall_half_angle*2;
   }
   if(ena_anywall){
      r = p.viewrotation;    // safe to use r
      r.yaw -= anywall_half_angle;
      getaxes(r,x,y,z);
      trace(hl,hn,p.location + max_anywalls_tracesector*x,p.location,true);
      if(laser_sector_sta!=none) laser_sector_sta.setlocation(hl-x*8);
      r.yaw += anywall_half_angle*2;
      getaxes(r,x,y,z);
      trace(hl,hn,p.location + max_anywalls_tracesector*x,p.location,true);
      if(laser_sector_end!=none) laser_sector_end.setlocation(hl-x*8);
   }
   autofly_set_timer -= f;
   autofly_clr_timer -= f;
   autofly_abort_timer -= f;
   autospawn_timer -= f;
   clientmsg_timer -= f;
   scrshot_timer -= f;
   last_tick_f_upd_timer -= f;
   welcome_msgs_timer -= f;
   zbar_rebuild_timer -= f;
   zset_kill_timer -= f;
   if(zset_kill_timer <= 0.0){
      zset_kill_timer = 0.0;
      zset_kill_confirm = 0;
   }
   if(lightbeam != none && lightbeam.LightType == LT_Steady){
      r = p.viewrotation;
      lightbeam.setlocation(p.location);
      r.pitch -= searchlight_direction;
      lightbeam.setrotation(r);
   }
   if(welcome_msgs_timer<=0) adv_welcome_msgs();   // initial msgs process
   if(clientmsg_timer<=0){                         // info msg process
      new_clientmsg[0] = "";
      new_clientmsg[1] = "";
   }
   if(mode_autospawn!=0 && autospawn_timer<=0 && mode_laser==0 && !ena_anywall){   // dpn placement process
      if(p.physics==PHYS_Walking && laserdpn!=none && zset_n == 0 /*todo zset change cond*/) sci_scripted_dpn_spawn(laserdpn.location);
      autospawn_timer = 0.2;
   }
   if(last_tick_f_upd_timer<=0){                   // frametime monitor process
      last_tick_f_upd_timer = 1.0;
      last_tick_f = f;
   }
   if(autofly_set_timer<0 && p.bIsCrouching){      // autofly/walk mgmt process
      autofly_trig++;
      new_clientmsg[0] = "Autofly: "$autofly_trig$"/3";
      new_clientmsg[1] = "Repeat crouch to trigger.";
      clientmsg_timer = 1.2;
      autofly_set_timer = 0.8;
      autofly_abort_timer = 1.2;
      if(p.physics==PHYS_Walking && autofly_trig >= 3){
         new_clientmsg[0] = "Autofly invoked.";
         new_clientmsg[1] = "Takeoff within 4 sec.";
         clientmsg_timer = 2.5;
         autofly_abort_timer = 4.0;
         autofly_trig = 1;
         p.consolecommand("fly");
      }
      if(!p.bIsCrouching) autofly_clr_timer = 1.6;
   }
   if(p.physics==PHYS_Walking && autofly_clr_timer<0){
      if(p.bIsCrouching) autofly_trig = 0;
      autofly_clr_timer = 0.8;
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
   if(zbar_rebuild_timer <= 0){
      zbar_rebuild_timer = 0.2;
      if(zbar_irrelevant) build_zbar();
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
   if(mode_oper==MO_LifetimeCfg || ena_debug || ena_prod) return;
   key_when = 0.3; last_kw = kw_y;
   if(lightbeam == none) return;
   if(lightbeam.LightType == LT_None)
        lightbeam.LightType = LT_Steady;
   else lightbeam.LightType = LT_None;
}

function sci_scripted_dpn_spawn(vector l){ if(FindDPN(l, autospawn_interval)==none) dpn_spawn(pn_delayed, pn_raytracer); }

function int draw_key_action(canvas c, color dc, ekeywhere evs, string hk, string desc, int from_x, int from_y){
   local int desc_x,lx,ly;
      local bool bGrayTrig;
   desc_x = (len(hk)+1)*fonw; // offset 1 xpos to descr
   lx = from_x; ly = from_y;
   if(last_kw==evs && last_kw!=kw_none){
      if(key_when >= 0.40){ c.drawcolor = pc_wh;   goto dka_pc_ready; } // reserved for disable blinking
      if(key_when >= 0.25){ c.drawcolor = pc_cyan; goto dka_pc_ready; } // blinking, frame 1
      if(key_when >= 0.15){ c.drawcolor = pc_red;  goto dka_pc_ready; } // frame 2
      if(key_when >= 0.05)  c.drawcolor = pc_cyan;                      // frame 3
      dka_pc_ready:
   }else{
      bGrayTrig = false;       // sucks that no |= operator there
      c.drawcolor = pc_wh;     // dim white keybar shithacks, mb replace with ena_key func bool param
      bGrayTrig = bGrayTrig || ( evs==kw_n                                   && (mode_oper!=MO_Scan && mode_oper!=MO_Mark));
      bGrayTrig = bGrayTrig || ( evs==kw_t    && sens_mov==none);
      bGrayTrig = bGrayTrig || ( evs==kw_ijkl && ena_lockxy                  &&  mode_oper!=MO_LifetimeCfg);
      bGrayTrig = bGrayTrig || ( evs==kw_r    && ena_lockxy);
      bGrayTrig = bGrayTrig || ((evs==kw_m    || evs==kw_ent)                &&  mode_oper!=MO_Mark);
      bGrayTrig = bGrayTrig || ( evs==kw_p    && dc!=pc_orange); // !water
      bGrayTrig = bGrayTrig || ( evs==kw_z                                   && (mode_oper==MO_Mark || mode_oper==MO_Prod));
      bGrayTrig = bGrayTrig || ((evs==kw_lmb  || evs==kw_mmb || evs==kw_rmb) &&  mode_oper==MO_Prod);
      bGrayTrig = bGrayTrig && !(evs==kw_ent                                 &&  mode_oper==MO_Prod); // some override
      if(bGrayTrig) c.drawcolor = pc_gray;
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

function draw_map_line(canvas c, vector a, vector b){
   local int x0,y0,x1,y1,dx,dy,sx,sy,err,e2;
   local int steps, max_steps;
   local float pnz;
   x0 = maptex_coord(a.x,maptex_x); y0 = maptex_coord(a.y,maptex_y);
   x1 = maptex_coord(b.x,maptex_x); y1 = maptex_coord(b.y,maptex_y);
   dx = abs(x1-x0); dy = -abs(y1-y0);
   sx = x0<x1 ? 1 : -1;
   sy = y0<y1 ? 1 : -1;
   err = dx+dy;
   pnz = 0.5;
   if(ena_2xzoom) pnz = 1.0;
   max_steps = max(abs(x1-x0), abs(y1-y0)) + 2;
   steps = 0;
   while(true){
      c.setpos(x0,y0);
      c.drawicon(texture'scipixel', pnz);
      if(x0==x1 && y0==y1) break;
      steps++;
      if(steps > max_steps) break;   // prevent infinite loop
      e2 = 2*err;
      if(e2 >= dy){ err += dy; x0 += sx; }
      if(e2 <= dx){ err += dx; y0 += sy; }
   }
}

function draw_debug_data(canvas c){
   local byte i,j,k,l;
   local bool tmp_b;
   local string tmp_s;
      c.drawcolor = pc_wh;
      c.setpos(pad_glob,pad_glob);
      c.drawtext("Region to AlignZ links (same as fill indicator):          Region state / horz align (X; Y), grayed are off:");
      c.setpos(pad_glob+(58*fonw),pad_glob+(2*fonh)); c.drawtext("X:");
      c.setpos(pad_glob+(58*fonw),pad_glob+(3*fonh)); c.drawtext("Y:");
      c.setpos(pad_glob+(58*fonw),pad_glob+(4*fonh)); c.drawtext("S:");
      c.setpos(pad_glob+(58*fonw),pad_glob+(5*fonh)); c.drawtext("T:");
   for(i=0;i<8;i++){
      c.drawcolor = color_region(i, enab_region[i]!=1);
      tmp_s = string(int(region_align[i].x)); l = len(tmp_s);
      c.setpos(pad_glob+((61+((i+1)*7))*fonw)-((l+1)*fonw),pad_glob+((2+0)*fonh));
      c.drawtext(tmp_s); //  int(region_align[i].x) $"; "$ int(region_align[i].y)
      tmp_s = string(int(region_align[i].y)); l = len(tmp_s);
      c.setpos(pad_glob+((61+((i+1)*7))*fonw)-((l+1)*fonw),pad_glob+(3*fonh));
      c.drawtext(tmp_s);
      tmp_s = string(int(region_scale[i])); l = len(tmp_s);
      c.setpos(pad_glob+((61+((i+1)*7))*fonw)-((l+1)*fonw),pad_glob+(4*fonh));
      c.drawtext(tmp_s);
      tmp_s = string(region_sizetex[i]); l = len(tmp_s);
      c.setpos(pad_glob+((61+((i+1)*7))*fonw)-((l+1)*fonw),pad_glob+(5*fonh));
      c.drawtext(tmp_s);
      for(j=0;j<8;j++){
         k = (i*8)+j;
         if(k>62) continue; // break
         tmp_b = region_usedby[k]==9;
     //  tmp_s = !tmp_b ? string(int(presets_z[region_usefloor[k]])) : "."; // old code
         tmp_s = !tmp_b ? string(int(get_layer_z(region_usefloor[k]))) : ".";
         l = len(tmp_s);
         c.drawcolor = color_region(region_usedby[k], tmp_b);
         c.setpos(pad_glob+((i+1)*fonw*7)-((l+1)*fonw),pad_glob+((j+2)*fonh));
         c.drawtext(tmp_s);
      }
   }
}

function draw_zbar_histogram(canvas c){
   local int zx, zy, k, j, lo, hi, sum, x0, x1, w, h;
   local int zcol;
   local float pnz;
   if(p==none) return;
   zx = x_rcol;
   zy = y_rcol_texdata_fill;
   c.drawcolor = pc_fill_bg; // ------------------------------- background
   c.setpos(zx, zy);
   c.drawtile(texture'scipixel', zbar_draw_w, zbar_draw_h, 0,0,4,4);
   if(!zbar_valid || zbar_used_n<=0 || zbar_used_max==0) return;
   pnz = get_sel_z(p);
   // absolute bin of current layer
   zcol = 0;
   if(zbar_zmax > zbar_zmin)
      zcol = int((pnz - zbar_zmin) * (zbar_w-1) / (zbar_zmax - zbar_zmin));
   if(zcol < 0) zcol = 0;
   if(zcol >= zbar_w) zcol = zbar_w-1;
   if(zbar_used_n <= zbar_draw_w){  // -------- stretch mode: column borders, solid graph
      for(k=0; k<zbar_used_n; k++){
         x0 = zx + (k     * zbar_draw_w / zbar_used_n);
         x1 = zx + ((k+1) * zbar_draw_w / zbar_used_n);
         w  = x1 - x0;
         if(w < 1) w = 1;
         h = zbar_draw_h * zbar_count[zbar_used[k]] / zbar_used_max;
         if(h < 1) h = 1;
         if(h > zbar_draw_h) h = zbar_draw_h;
         // unsure code
//       if(abs(float(zbar_used[k] - zcol)) <= LayerSensitivity) c.drawcolor = pc_red; // todo affect laysens by preset thick
////     else if(zbar_count[zbar_used[k]] > zbar_count_stray[zbar_used[k]]) c.drawcolor = pc_gray;  // nonstray-доминанта
//       else c.drawcolor = pc_wh;
         if     (zbar_count[zbar_used[k]] > zbar_count_stray[zbar_used[k]]) c.drawcolor = pc_gray;
         else if(abs(float(zbar_used[k] - zcol)) <= LayerSensitivity) c.drawcolor = pc_red;
         else c.drawcolor = pc_wh;

         c.setpos(x0, zy+zbar_draw_h-h);
         c.drawtile(texture'scipixel', w, h, 0,0,4,4);
      }
   }else{ // -------------------------------------- aggregation mode: 192 buckets
      for(k=0; k<zbar_draw_w; k++){
         lo = k * zbar_used_n / zbar_draw_w;
         hi = (k+1) * zbar_used_n / zbar_draw_w;
         if(hi <= lo) continue;
         sum = 0;
         for(j=lo; j<hi; j++) sum += zbar_count[zbar_used[j]];
         h = zbar_draw_h * sum / (zbar_used_max * (hi-lo));
         if(h < 1) h = 1;
         if(h > zbar_draw_h) h = zbar_draw_h;
         // color: bucket contains near-player bin
         if(zcol >= zbar_used[lo] && zcol <= zbar_used[hi-1]) c.drawcolor = pc_red;
         else c.drawcolor = pc_wh;
         c.setpos(zx+k, zy+zbar_draw_h-h);
         c.drawtile(texture'scipixel', 1, h, 0,0,4,4);
      }
   }
}

function draw_zset_table(canvas c){
   local int i, y,xp,yp; //  first, last,
   local pathnoderuntime leader;
   local color pc_tmp;
   local string str_tmp;
   if(p==none) return;
   y = y_hdr_oper-5;
   for(i=1;i<4;i++){
      c.setpos((i*12*fonw)+1,y); //+pad_glob?
      c.drawtile(texture'scipixelblk', 1, 21*fonh, 0,0,4,4);
   }
   if(zset_n == 0) return;
   pc_tmp = (n_layerz == zset_n-1) ? pc_green_f : pc_red_f;
   for(i=0; i<zset_n; i++){  // todo test all 63
      leader = zset_list[i];
      if(leader==none) continue;
      str_tmp = leader.bLayerActive ? ":" : ".";
      if(i==zset_n-1){
         c.drawcolor = (mode_mwheel!=MW_zset_zone) ? pc_tmp : pc_fill_bg;
         xp = pad_glob+((i/21)*12*fonw);
         yp = (y_hdr_oper-5)+(i%21)*fonh;
         c.setpos(xp, yp);
         c.drawtile(texture'scipixel', 6*fonw, fonh, 0,0,4,4);
         c.drawcolor = (mode_mwheel==MW_zset_zone) ? pc_tmp : pc_fill_bg;
         xp+=(7*fonw);
         c.setpos(xp, yp);
         c.drawtile(texture'scipixel', 4*fonw, fonh, 0,0,4,4);
      }
      c.drawcolor = bZSetEditMode ? pc_wh : pc_wh_f;
      xp = pad_glob+((i/21)*12*fonw);
      c.setpos(xp, (y_hdr_oper-5)+(i%21)*fonh);
      c.drawtext(int(leader.location.z));
      c.setpos(xp+(6*fonw), (y_hdr_oper-5)+(i%21)*fonh);
      c.drawtext(str_tmp$int(leader.layer_thickness));
   }
   for(i=0; i<zset_n; i++){
      if(i==n_layerz && bZSetEditMode){
         c.drawcolor = pc_wh;
         xp = pad_glob+((i/21)*12*fonw);
         yp = (y_hdr_oper-5)+(i%21)*fonh;
         c.setpos(xp, yp);
         c.drawtile(texture'scipixel', 11*fonw, 1, 0,0,4,4);
         yp += fonh;
         c.setpos(xp, yp);
         c.drawtile(texture'scipixel', 11*fonw, 1, 0,0,4,4);
      }
   }
}

function postrender(canvas c){
   local int upx,upy; // ui pos x,y
   local color pc_tmp;  // tmp presetcolor
   local vector vect_tmp;
   local bool bool_tmp;
   local float resolution_error;
   local int region_area;
// local actor rtarg;
   local vector x,y,z,hl ;
   local string str_tmp;
   local float rotr;  // radians rotation
   local byte nmarker;
   local pathnoderuntime leader, cursor_leader; // todo move this outside
   local int hlx,hly,mkx,mky;
   local int marked_error;
   local int i,j,k; //,e;
   local byte nframe;
   local float pnz;
   local int zx, zy, zcol, z_lo, z_hi, col_lo, col_hi; // zbar-related
   if(p==none) return;
   if(!ena_ams_render) return;
   if(inv_finfo==none || lightbeam==none || laserdpn==none || laserdot==none) return;
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
   if(!ena_debug) goto skip_debug;
   draw_debug_data(c);
   return;
 skip_debug:
   // region offset intercept, must be done BEFORE map RT process ---------------------
   bool_tmp = alignz_seek>0;
   if(ena_prod){
      n_layerz = bool_tmp ? region_usefloor[done_layerz] : done_layerz;
      if(!bool_tmp) goto skip_region_offset_unused;
      global_offset_x =   region_align[region_usedby[done_layerz]].x;
      global_offset_y =   region_align[region_usedby[done_layerz]].y;
      map_resolution  =   region_scale[region_usedby[done_layerz]];
      size_tex        = region_sizetex[region_usedby[done_layerz]];
      skip_region_offset_unused:
   }
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
   rc_tot = 0;
   pn_mz = 0;
   process_map(pass_one, c, p);
   process_map(pass_two, c, p);
//----- laser blast position -------------------------------------------------
   if(mode_laser != 0 && !ena_prod){
      // ------------------------------------------------
      c.drawcolor = pc_bluer_map;
      hl = p.location;
      getaxes(p.viewrotation,x,y,z);
      k = int( vsize(p.location - laserdpn.location) / 40);
      if(k > 256) k = 256;
      for(i=0; i<k; i++){
         hl += 40*x;
         hlx = maptex_coord(hl.x,maptex_x);
         hly = maptex_coord(hl.y,maptex_y);
         if(map_tex_out_of_bounds(hlx,hly)) break;
         pnz = 0.5;
         if(ena_2xzoom) pnz = 1.0;
         c.setpos(hlx,hly); c.drawicon(texture'scipixel',pnz);
      }
      // ------------------------------------------------
      c.drawcolor = pc_yellow;
      hl = laserdot.location;
         hlx = maptex_coord(hl.x,maptex_x);
         hly = maptex_coord(hl.y,maptex_y);
         pnz = 1.0;
//       if(ena_2xzoom) pnz = 1.0;
         c.setpos(hlx,hly);
         if(!map_tex_out_of_bounds(hlx,hly)) c.drawicon(texture'scipixel',pnz);
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
      hlx = hlx >> SHR_Factor_scanmap;
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
// goto skip_maintex_border_clip; // uncomment this to allow region borders go outside main texture
   c.drawcolor = pc_bg;
   c.setpos(0,0);
    c.drawtile(texture'scipixel', hud_maptex_offset_x, hardcode_scrh, 0,0,4,4);
   c.setpos(hud_maptex_offset_x, 0);
    c.drawtile(texture'scipixel', max_size_tex, hud_maptex_offset_y, 0,0,4,4);
   c.setpos(hud_maptex_offset_x, max_size_tex+hud_maptex_offset_y);
    c.drawtile(texture'scipixel', max_size_tex, hardcode_scrh-hud_maptex_offset_y-max_size_tex, 0,0,4,4);
   c.setpos(max_size_tex+hud_maptex_offset_x, 0);
    c.drawtile(texture'scipixel', hardcode_scrw-max_size_tex-hud_maptex_offset_x, hardcode_scrh, 0,0,4,4);
 skip_maintex_border_clip:
   // zbar indicator ------------------------------------------------------------------
   zx = hud_maptex_offset_x;
   zy = zbar_y;
   c.drawcolor = pc_fill_bg;
   c.setpos(zx, zy);
   c.drawtile(texture'scipixel', zbar_w, zbar_h, 0,0,4,4);
   // ------------------------------------------------- zset leader acq zone
   leader = none;
   if(mode_oper==MO_ZSetMgr && zset_n>0 && zset_list[zset_n-1]!=none && zbar_zmax>zbar_zmin){
      leader = zset_list[zset_n-1];
      z_lo = leader.location.z - leader.layer_thickness/2;
      z_hi = leader.location.z + leader.layer_thickness/2;
      col_lo = int((z_lo - zbar_zmin) * (zbar_w-1) / (zbar_zmax - zbar_zmin));
      col_hi = int((z_hi - zbar_zmin) * (zbar_w-1) / (zbar_zmax - zbar_zmin));
      if(col_lo < 0) col_lo = 0;
      if(col_hi >= zbar_w) col_hi = zbar_w-1;
      if(col_hi >= col_lo){
         c.drawcolor = pc_teal_f;
         c.setpos(zx+col_lo, zy);
         c.drawtile(texture'scipixel', col_hi-col_lo+1, zbar_h, 0,0,4,4);
      }
   }
   // ------------------------------------------------- heights strips
   if(zbar_valid){             // p!=none already
      c.drawcolor = pc_yellow; // was zbar_irrelevant?pc_bluer_f:pc_yellow; annoyed blinking
      i = 0;
      while(i < zbar_w){
         if(zbar_count_stray[i]==0){ i++; continue; }
         zcol = i;
         while(i < zbar_w && zbar_count_stray[i]!=0) i++;
         c.setpos(zx+zcol, zy);
         c.drawtile(texture'scipixel', i-zcol, zbar_h, 0,0,4,4);
      }
   }
   if(zbar_zmax > zbar_zmin){
      pnz = p.location.z;
      zcol = int((pnz - zbar_zmin) * (zbar_w-1) / (zbar_zmax - zbar_zmin));
      if(zcol < 0) zcol = 0;
      if(zcol >= zbar_w) zcol = zbar_w-1;
      c.drawcolor = pc_red;
      c.setpos(zx+zcol-1, zy);
      c.drawtile(texture'scipixel', 3, zbar_h, 0,0,4,4);
   }
   if(leader!=none){
      pnz = leader.location.z;
      zcol = int((pnz - zbar_zmin) * (zbar_w-1) / (zbar_zmax - zbar_zmin));
      if(zcol < 0) zcol = 0;
      if(zcol >= zbar_w) zcol = zbar_w-1;
      c.drawcolor = (int(level.timeseconds/0.5) % 2)==0 ? pc_green: pc_cyan;
      c.setpos(zx+zcol-1, zy);
      c.drawtile(texture'scipixel', 2, zbar_h, 0,0,4,4);
   }
// ---- level nav camera -----------------------------------------------------
   c.drawcolor = pc_wh;
   getaxes(p.viewrotation,x,y,z);                                                               // 16:9 @ 106 fov
   c.drawportal(pad_glob, (pad_glob*2)+(fonh*2), vieww, viewh, p,p.location+x*2+z*(p.eyeheight-1),p.viewrotation,106.0,true);
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
   bool_tmp = (level.timeseconds-when_pickup)>15.0;
   c.drawcolor = pc_wh;
   str_tmp = bool_tmp ? "<F10> - pause" : "2026-10-12";
   if(mode_oper==MO_ZSetMgr && bool_tmp) str_tmp = "<F1> - build";
   c.setpos(x_about,y_about); c.drawtext("CT AMS 0.5 / Arleen / "$str_tmp);
   c.drawcolor = pc_gray;
   str_tmp = bool_tmp ? left(common_texname,33) : "System requirements: 1920x1080@32";
   c.setpos(x_about,y_about+fonh); c.drawtext(str_tmp);
// ---- hotkeys, labels, modes -----------------------------------------------
   if(mode_oper==MO_ZSetMgr) goto skip_by_zsetmgr_hidebasic;
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
   pc_tmp = ena_dpn_alice ? pc_cyan : pc_green_f;
   upy = draw_key_action(c, pc_tmp, kw_f3, "<F3>", "test",   upx, upy);
// upy = draw_key_action(c, pc_red_f, kw_none, "<F10>", "pause", upx, upy);
 skip_by_zsetmgr_hidebasic:
   // -------------------
   if(mode_oper==MO_LifetimeCfg) goto skip_by_drawkeys_lifetimecfg;
   if(mode_oper!=MO_ZSetMgr){
      upx = x_hdr_map_ctl; upy = y_hdr_map_ctl;
   }else{
      upx = x_col_place; upy = y_hdr_place;   // move legend, todo remove or change
   }

   if(mode_oper==MO_ZSetMgr) goto skip_by_zsetmgr_hidemorebasic;

   c.drawcolor = pc_blue;
   c.setpos(upx,upy); c.drawtext("Map ctl:");
   if(mode_oper!=MO_ZSetMgr)
      upx = x_col_map_ctl;
    else upx = x_col_place;
      upy += (pad_fonh_half+fonh);
   pc_tmp = (mode_oper!=MO_Mark && mode_oper!=MO_Prod) ? pc_blue : pc_blue_f;
   upy = draw_key_action(c, pc_tmp,  kw_z, "<Z>", "pxzoom",  upx, upy);
   upy = draw_key_action(c, pc_blue, kw_x, "<X>", "uuzoom", upx, upy);
   upy = draw_key_action(c, pc_blue, kw_b, "<B>", "step",   upx, upy);
   upy = draw_key_action(c, pc_blue, kw_g, "<G>", "texture",upx, upy); upx -= (fonw*2);
   if(mode_oper!=MO_ZSetMgr){
                              str_tmp = "assign L"; pc_tmp = pc_blue_f;
      if(mode_oper==MO_Mark){  pc_tmp = pc_blue;   }
      if(mode_oper==MO_Prod){ str_tmp = "*EXPORT*"; pc_tmp = (int(level.timeseconds/0.5) % 2)==0 ? pc_green : pc_teal; }
      upy = draw_key_action(c, pc_tmp, kw_ent, "<Ent>", str_tmp, upx, upy);
   }
 skip_by_zsetmgr_hidemorebasic:
   // -------------------
   if(mode_oper==MO_ZSetMgr) goto skip_by_zsetmgr_hidecommon;
   upx = x_hdr_lvl_ctl; upy = y_hdr_lvl_ctl;
   c.drawcolor = pc_orange;
   c.setpos(upx,upy); c.drawtext("Common:");
     upx = x_col_lvl_ctl; upy += (pad_fonh_half+fonh);
   upy = draw_key_action(c, pc_gray, kw_none, "<F5>", "debug",  upx, upy);  // ???????
   upy = draw_key_action(c, pc_orange, kw_f2, "<F2>", "rmode",   upx, upy);
   if(!ena_anywall){
      if(mode_mwheel==MW_modX) str_tmp = "X";
      if(mode_mwheel==MW_modY) str_tmp = "Y";
      if(mode_mwheel==MW_modL) str_tmp = "L";
      upy = draw_key_action(c, pc_orange, kw_r, "<R>",  "mwheel: "$str_tmp, upx, upy);
   }else{
      upy = draw_key_action(c, pc_cyan, kw_r, "",  "mwheel: AWS", upx, upy);
   }
   upy = draw_key_action(c, pc_orange, kw_pupd, "<PuPd>",  "sel L", upx, upy);
 skip_by_zsetmgr_hidecommon:
   // -------------------
   if(mode_oper==MO_ZSetMgr) goto skip_by_zsetmgr_hideevenmorebasic;
   upx = x_hdr_user; upy = y_hdr_user;
   c.drawcolor = pc_yellow;
   c.setpos(upx,upy); c.drawtext("User:");
     upx = x_col_user; upy += (pad_fonh_half+fonh);
   pc_tmp = ena_lockz ? pc_yellow : pc_yellow_f;
   upy = draw_key_action(c, pc_tmp, kw_u,    "<U>",    "lock Z/L",  upx, upy);
   pc_tmp = ena_lockxy ? pc_yellow : pc_yellow_f;
   upy = draw_key_action(c, pc_tmp, kw_o,    "<O>",    "lock XY", upx, upy);
   pc_tmp = !ena_lockxy ? pc_yellow : pc_yellow_f;
   upy = draw_key_action(c, pc_tmp, kw_ijkl, "<IJKL>", "offset",  upx, upy);
   if(mode_oper!=MO_ZSetMgr){
      if(ena_anywall)
            upy = draw_key_action(c, pc_cyan,   kw_h, "", "Sector: "$int(anywall_half_angle), upx, upy);
      else upy = draw_key_action(c, pc_cyan_f, kw_h, "", "Sector: n/a", upx, upy);
   }
 skip_by_zsetmgr_hideevenmorebasic:
   // -------------------
   if(mode_oper==MO_ZSetMgr) goto skip_by_zsetmgr_hidemisc;
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
   if(mode_oper==MO_Scan || mode_oper==MO_Mark){
         pc_tmp = pc_brown;
         if(ena_next_dpn_zset) pc_tmp = (int(level.timeseconds/0.4) % 2)==0 ? pc_brown : pc_wh;
   }else pc_tmp = pc_brown_f;
         draw_key_action(c, pc_tmp, kw_n,  "<N>", "Zset DPN",  upx, upy);
   upx = x_hdr_region;
   pc_tmp = pc_orange;                                      // shithack: adjust pc_tmp to trigger pc_wh replacement
   if(region.zone!=none){ if(!region.zone.bwaterzone) pc_tmp = pc_orange_f; }  // and dont access zone handle again
         draw_key_action(c, pc_tmp, kw_p, "<P>", "!water",  upx, upy-fonh);
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
      upx += fonw;
         c.setpos(upx+(1*fonw)+(j*fonw)-(k*fonw),upy); c.drawtext(i+1);
      if(region_scale[i]!=2**SHR_Factor_prodmap){
         c.drawcolor = (int(level.timeseconds/0.5) % 2)==0 ? pc_wh : pc_red;  // region resolution mismatch warn
         c.setpos(upx+(1*fonw)+(j*fonw)-(k*fonw),upy-fonh); c.drawtext(".");
      }
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
     upx = x_col_place; upy += fonh;
   if(mode_dpn_fall==DPZ_floor){  pc_tmp = pc_brown;  str_tmp = "floordist"; }
   if(mode_dpn_fall==DPZ_flying){ pc_tmp = pc_green;  str_tmp = "floating";  }
   if(mode_dpn_fall==DPZ_user){   pc_tmp = pc_yellow; str_tmp = "inherit user z"; }
   if(mode_dpn_fall==DPZ_laser){  pc_tmp = pc_yellow; str_tmp = "inherit laser z"; }
   c.setpos(upx+(10*fonw),upy);
   c.drawcolor = pc_tmp; c.drawtext(str_tmp);
   upy = draw_key_action(c, pc_brown, kw_f, "<F>", "fall:", upx, upy);
   pc_tmp = mode_autospawn!=0 ? pc_brown : pc_brown_f;
                                         str_tmp = " off";
   if(mode_autospawn==1)                 str_tmp = ": each 192";
   if(mode_autospawn==2)                 str_tmp = ": each 128";
   if(mode_autospawn!=0 && ena_anywall){ str_tmp = " suspended"; pc_tmp = pc_wh; }
   upy = draw_key_action(c, pc_tmp, kw_v, "<V>", "autospawn"$str_tmp, upx, upy);
   pc_tmp = ena_anywall ? pc_pink : pc_brown;
   str_tmp = ena_anywall ? "directional anywalls" : "strict walls";
   upy = draw_key_action(c, pc_tmp, kw_h, "<H>", str_tmp, upx, upy);
   // -------------------
   upx = x_hdr_mouse; upy = y_hdr_mouse;
   c.drawcolor = mode_oper!=MO_Prod ? pc_pink : pc_pink_f;
   c.setpos(upx,upy); c.drawtext("Mouse:");
     upx = x_col_mouse; upy += pad_fonh_half+fonh;
   pc_tmp = mode_oper!=MO_Prod ? pc_pink : pc_pink_f;
   upy = draw_key_action(c, pc_tmp, !bDisableLRmouseNotify ? kw_lmb : kw_none, "<LB>", "open/fqr",  upx, upy);
   upy = draw_key_action(c, pc_tmp,  bEnableMmouseNotify   ? kw_mmb : kw_none, "<MW>", "spawn", upx, upy);
   upy = draw_key_action(c, pc_tmp, !bDisableLRmouseNotify ? kw_rmb : kw_none, "<RB>", "kill/spd",  upx, upy);
// ---- warnings -------------------------------------------------------------
   upx = x_about; upy += fonh;
   if(mode_oper==MO_WantDiag){  // requested to enter diag mode
      pc_tmp = pc_red;
      if((int(level.timeseconds/0.5) % 2) == 0) pc_tmp = pc_cyan;
      upy = draw_key_action(c, pc_tmp,  kw_none, "Attention:", "this operation can't be undone.", upx, upy);
      upy += pad_glob;
      upy = draw_key_action(c, pc_wh, kw_none, "", "Confirm "$now_confirmed(mode_confirm)$"/4 you want to overwrite Z-set.", upx, upy);
      upy = draw_key_action(c, pc_wh_f, kw_none, "", "Press 1,2,3,4 keys or F1/F7 to cancel.", upx, upy);
      goto skip_by_validation;
   }
   bool_tmp = false;
   for(i=0;i<8;i++) bool_tmp = bool_tmp || (region_scale[i]!=2**SHR_Factor_prodmap);
   if(bool_tmp){
      nframe = (int(level.timeseconds/0.24) % 18);
      pc_tmp = (nframe==0) ? pc_yellow : pc_red;
      upy = draw_key_action(c, pc_tmp,  kw_none, "", "Region(s) scale violate lifetime cfg.",  upx, upy);
      upy += pad_glob;
      upy = draw_key_action(c, pc_wh_f, kw_none, "", "Keep same uuzoom as PrSHR in all regions,",  upx, upy);
      upy = draw_key_action(c, pc_wh_f, kw_none, "", "otherwise positioning error WILL ocurr.",  upx, upy);
      goto skip_by_drawkeys_region_misscale;
   }
   if((mode_rayprocess!=RP_SelFull || ena_lockz) && accumulated_pw_sens_fire<timetrigger_pw_sens_fire){ // todo allow RT warn in MO_LayMrg
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
 skip_by_zsetmgr_hidemisc:
   if(mode_oper==MO_ZSetMgr){
      draw_zset_table(c);
      goto skip_by_validation; // skip LO_Lifetime text
   }
 skip_by_drawkeys_lifetimecfg:
   if(mode_oper==MO_LifetimeCfg){
      upx = x_col_map_ctl; upy = y_hdr_oper+pad_fonh_half+fonh;
      c.drawcolor = pc_wh;
      c.setpos(upx,upy); c.drawtext("<- press these keys or F6"); upy += fonh;
      c.setpos(upx,upy); c.drawtext("   to leave this mode."); upy += fonh;
      upy = draw_key_action(c, pc_green, kw_ijkl, "<IK>", "select var",  upx, upy);
      upy = draw_key_action(c, pc_green, kw_ijkl, "<JL>", "change",  upx, upy);
      upx = x_col_oper; upy = y_hdr_region+fonh+pad_fonh_half;
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
 skip_by_drawkeys_region_misscale:
// ---- right sidebar --------------------------------------------------------
   // --- fill monitor ----------------
   upx = x_rcol; upy = y_rcol_texdata;
   if(mode_oper==MO_Scan || mode_oper==MO_ZSetMgr){
      pc_tmp = pc_wh;
      upy = draw_key_action(c, pc_tmp, kw_none, "", "DPN density", upx, upy);
      draw_zbar_histogram(c);
   }else{
      pc_tmp = mode_oper==MO_Mark ? pc_wh : pc_gray;
      upy = draw_key_action(c, pc_tmp, kw_none, "", "AlignZ fill", upx, upy);
      upx = x_rcol; upy = y_rcol_texdata_fill;
      for(k=0;k<8;k++){
         for(i=0;i<8;i++){
            j = (k*8)+i;
            if(j==63) continue;
            c.setpos(upx,upy);
            c.drawcolor = (ena_prod && alignz_seek>0 && done_layerz==j) ? pc_gray : pc_fill_bg;
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
      c.style = erenderstyle.sty_normal;
   }
   // -------------------
   upx = x_rcol; upy = y_rcol_player-58;
         draw_key_action(c, pc_tmp, kw_none, "", "Set:", upx, upy);
         draw_key_action(c, pc_tmp, kw_none, "", "@", upx+(7*fonw)+8, upy);
   str_tmp = "";
   if(n_layerz<10) str_tmp $= " ";
    str_tmp $= string(n_layerz);
   pc_tmp = mode_oper==MO_Mark ? pc_teal : pc_teal_f;
   if(pc_tmp==pc_teal) pc_tmp = !ena_lockz ? pc_teal : pc_green;
         draw_key_action(c, pc_tmp, kw_none, "", str_tmp, upx+(5*fonw), upy);
   str_tmp = "X";
   if(n_region>=0 && n_region<=7) str_tmp = string(n_region+1);
   pc_tmp = color_region(n_region,mode_oper!=MO_Mark);
         draw_key_action(c, pc_tmp, kw_none, "", str_tmp, upx+(9*fonw), upy);

   if(!ena_lockz){     // alignz_fill bksp indicator - need go up/dn or now matching
      pc_tmp = pc_wh;
      nframe = n_region;
      if(nframe>7) nframe=0;
      k = alignz_seek;
      if(alignz_seek > 0) k -= 1;
      if(region_usedby[k] != n_region) pc_tmp = pc_bluer_f;
      c.Style = ERenderStyle.STY_Masked;
      c.setpos(upx+(fonw*10)+2,upy-3);
      c.drawcolor = pc_tmp;
      if(region_usefloor[k] <  n_layerz){ c.drawtile(texture'scifontmatch',fonw,fonh,fmpos_dn,1,fonw,fonh); goto done_alignz_bksp; }
      if(region_usefloor[k] == n_layerz){ c.drawtile(texture'scifontmatch',fonw,fonh,fmpos_sq,1,fonw,fonh); goto done_alignz_bksp; }
      if(region_usefloor[k] >  n_layerz){ c.drawtile(texture'scifontmatch',fonw,fonh,fmpos_up,1,fonw,fonh); goto done_alignz_bksp; }
      done_alignz_bksp:
      c.drawcolor = pc_wh;
      c.Style = ERenderStyle.STY_Normal;
   }
   // -------------------
   upx = x_rcol; upy = y_rcol_player-15;
   str_tmp = "   Player";
   if(mode_laser != 0) str_tmp = "   Laser";
   upy = draw_key_action(c, pc_orange, kw_none, "", str_tmp, upx, upy);
   vect_tmp = mode_laser==0 ? p.location : laserdot.location;
   upy = draw_key_action(c, pc_wh, kw_none, "", "X: "$int(vect_tmp.x), upx, upy);
   upy = draw_key_action(c, pc_wh, kw_none, "", "Y: "$int(vect_tmp.y), upx, upy);
   upy = draw_key_action(c, pc_wh, kw_none, "", "Z: "$int(vect_tmp.z), upx, upy);
   // -------------------
   upx = x_rcol; upy = y_rcol_scope-29;
   upy = draw_key_action(c, pc_yellow, kw_none, "", "  Process", upx, upy);
   str_tmp = now_rayprocessing(mode_rayprocess);
   if(accumulated_pw_sens_fire > timetrigger_pw_sens_fire) str_tmp = now_rayprocessing(RP_ClientFull);
   upy = draw_key_action(c, pc_wh, kw_none, "", str_tmp, upx, upy);
   str_tmp = ena_lockz ? "lock" : n_layerz$"/"$presets_nmax;
   pc_tmp = ena_lockz ? pc_green : pc_teal;
         draw_key_action(c, pc_tmp, kw_none, "L:", str_tmp, upx, upy);
   // -------------------
   upx = x_rcol; upy = y_rcol_align-15-29;
   upy = draw_key_action(c, pc_blue, kw_none, "", "   Align", upx, upy);
   if(mode_mwheel==MW_modX){ pc_tmp = !ena_lockxy ? pc_green : pc_green_f; }else{ pc_tmp = !ena_lockxy ? pc_wh: pc_wh_f; }
   upy = draw_key_action(c, pc_tmp, kw_none, "", "X: "$int(global_offset_x), upx, upy);
   if(mode_mwheel==MW_modY){ pc_tmp = !ena_lockxy ? pc_green : pc_green_f; }else{ pc_tmp = !ena_lockxy ? pc_wh: pc_wh_f; }
   upy = draw_key_action(c, pc_tmp, kw_none, "", "Y: "$int(global_offset_y), upx, upy);
   str_tmp = ena_lockz ? string(int(p.location.z)) : string(int(presets_z[n_layerz]));
   if(mode_mwheel==MW_modL){ pc_tmp = !ena_lockxy ? pc_green : pc_green_f; }else{ pc_tmp = !ena_lockxy ? pc_wh: pc_wh_f; }
   upy = draw_key_action(c, pc_tmp, kw_none, "", "Z: "$str_tmp, upx, upy);
   // -------------------
   upx = x_rcol; upy = y_rcol_region-29-29;
   nframe = n_region;
   if(nframe>7) nframe=0;
   upy = draw_key_action(c, pc_teal, kw_none, "", "  LAR ("$nframe+1$")", upx, upy);
   upy = draw_key_action(c, pc_pink, kw_none, "X:", string(int(region_align[nframe].x)), upx, upy);
   upy = draw_key_action(c, pc_pink, kw_none, "Y:", string(int(region_align[nframe].y)), upx, upy);
   upy = draw_key_action(c, pc_blue, kw_none, "S:", string(size_step), upx, upy);
   upy = draw_key_action(c, pc_blue, kw_none, "T:", string(size_tex), upx, upy);
   // -------------------
   upx = x_rcol; upy = y_rcol_lifetime;
   nframe = (int(level.timeseconds/2.5) % 2);
   pc_tmp = (nframe==0) ? pc_blue : pc_yellow;
   if(mode_oper!=MO_LifetimeCfg) pc_tmp = pc_brown;
   upy = draw_key_action(c, pc_tmp, kw_none, "", "Map lft bhvr", upx, upy);
   pc_tmp = mode_oper==MO_LifetimeCfg ? pc_orange : pc_gray;     draw_lifetime_sel(c,LTC_Floordist,upx,upy);
   upy = draw_key_action(c, pc_tmp, kw_none, "", "FlrDist: "$int(AutofallFloordist), upx, upy);
   pc_tmp = mode_oper==MO_LifetimeCfg ? pc_red    : pc_gray;     draw_lifetime_sel(c,LTC_ZSetDiscr,upx,upy);
   upy = draw_key_action(c, pc_tmp, kw_none, "", "ZDiscr: "$int(VertDiscretization), upx, upy);
   pc_tmp = mode_oper==MO_LifetimeCfg ? pc_pink   : pc_gray;     draw_lifetime_sel(c,LTC_LaySens,upx,upy);
   upy = draw_key_action(c, pc_tmp, kw_none, "", "LaySens: "$int(LayerSensitivity), upx, upy);
   pc_tmp = mode_oper==MO_LifetimeCfg ? pc_green  : pc_gray;     draw_lifetime_sel(c,LTC_ProdSHR,upx,upy);
   upy = draw_key_action(c, pc_tmp, kw_none, "", "PrSHR: "$int(2**SHR_Factor_prodmap), upx, upy);
   upy = draw_key_action(c, pc_brown, kw_f6, "<F6>", mode_oper==MO_LifetimeCfg ? "done" : "edit", upx, upy);
   // -------------------
   upx = x_rcol; upy = y_rcol_noob;
   upy = draw_key_action(c, pc_green, kw_none, "Noob? cmd", ">q", upx, upy); // right sidebar ends
//----- zset markers ---------------------------------------------------------
   if(mode_oper!=MO_Prod){
      if(mode_oper==MO_ZSetMgr)
         cursor_leader = find_leader_under_cursor();
      else
         cursor_leader = none;
      for(i=0; i<zset_n; i++){
         leader = zset_list[i];
         if(leader==none) continue;
         hl = leader.location;
         hlx = maptex_coord(hl.x,maptex_x);
         hly = maptex_coord(hl.y,maptex_y);
         if(map_tex_out_of_bounds(hlx,hly)) continue;
         if(leader == cursor_leader){
            if(i == zset_n-1) c.drawcolor = pc_red;                                         // deletable
            else    c.drawcolor = (int(level.timeseconds/0.4) % 2)==0 ? pc_red : pc_yellow; // undeletable
         }else    { c.drawcolor = (i == zset_n-1) ? pc_green : pc_wh; }                     // generic
         if(i == n_layerz){ c.setpos(hlx - (3*fonw)/2, hly - fonh/2); c.drawtext("[o]"); }  // selected
          else            { c.setpos(hlx - fonw/2, hly - fonh/2);     c.drawtext( "o" ); }
      }      
   }
//----- route displayer ------------------------------------------------------
// if(nav_path_n > 1){
//    c.drawcolor = pc_green;
//    for(i=0; i<nav_path_n-1; i++)
//       draw_map_line(c, nav_path[i].location, nav_path[i+1].location);
// }
//----- player displayer -----------------------------------------------------
   if(mode_oper!=MO_Prod){
       hl = p.location;
      hlx = maptex_coord(hl.x,maptex_x);
      hly = maptex_coord(hl.y,maptex_y);
      rotr = (p.viewrotation.yaw+16384) % 65536;  // -90 because zero yaw in unrealed is A of WASD
      if(rotr < 0) rotr += 65536;
      nmarker = byte(rotr/2730.66);
      c.setpos(hlx-8,hly-8);
      c.drawcolor = (int(level.timeseconds/0.7) % 2) == 0 ? pc_blue : pc_wh;
      c.DrawTile(texture'scibearing',16,16, nmarker*16,0,16,16);
   }
// ---- nav camera counters --------------------------------------------------
   c.drawcolor = pc_wh;
   i = int(1/last_tick_f);
   if(i > 60) i = 60;
   c.setpos(x_view_lpos+(15*fonw),y_statusbar); c.drawtext(i$"fps ");
   str_tmp = "";
   str_tmp $= string(pn_mz);
   str_tmp $= "/";
   if(mode_oper==MO_ZSetMgr)
      str_tmp $= string(zbar_stray_total)$"/";
   str_tmp $= string(pn_tot);
   k = len(str_tmp) -1;
   k *= fonw;
   c.setpos(x_view_rpos-k, y_statusbar); c.drawtext(str_tmp);
// ---- autofly timer monitor update -----------------------------------------
   if(autofly_abort_timer>0 && p.physics==PHYS_Walking){
      str_tmp = "";
      i=int(autofly_set_timer*10);
      for(k=0;k<i;k++) str_tmp $= "x";
      new_clientmsg[0] = "Autofly: "$autofly_trig$"/3   "$str_tmp$"     oooo";
   }
// ---- prod mode autoexec ---------------------------------------------------
   if(!ena_prod || scrshot_timer > 0.0) return;
   new_clientmsg[0] = "Making image "$string(done_layerz+1)$" of "$string(alignz_seek>0 ? alignz_seek : presets_nmax)$"...";
   clientmsg_timer = 1.7;
   // initial entrypoint prepared done_layerz=0 for us
   p.consolecommand("shot");
   scrshot_timer = 2.0;
   done_layerz++;
   bool_tmp = true;
   if(alignz_seek>0){
      if(region_usedby[done_layerz]==9) bool_tmp = false;
   }else{
      // if(done_layerz>presets_nmax) bool_tmp = false; // old code
      if(done_layerz >= (zset_n>0 ? zset_n : presets_nmax)) bool_tmp = false;
   }
   if(!bool_tmp){
      ena_prod = false; tog_opermode(0);
      new_clientmsg[0] = "Map export done.";
      clientmsg_timer = 8.0;
      mode_texsize = 2;                // restore settings
      upd_resolution(); upd_size_tex(); upd_size_step();
   }
}
// ==================================================================================================
function process_map(bool second_pass, canvas c, playerpawn p){
   local int sel_z;
   local int band_z;            // virtual pending band center = player Z compensated (mode-independent)
   local bool bool_tmp;
   local bool bInVirtualBand;   // stray dpn within +/-16uu pending/owner
   local actor rtarg;
   local vector x,y,z,endtrace,hl,hn;
   local rotator r;
   local pathnoderuntime dpn;
   local int hlx,hly;
   local float pnz;
   local bool nomatch_z;  // this z does not match current sel_z or lock_z
   local float yaw_until; // end of sector
   local float z_tol;           // z tolerance while acquire layer
   local bool bNoZSet;          // no ZSet DPNs while in markup/prod/zsetmgr mode
   local bool bZSetMode;        // markup/prod/zsetmgr
 // ---- mode and z tolerance ???? what mode ---------------------------------
   bZSetMode = (mode_oper==MO_Mark || mode_oper==MO_Prod || mode_oper==MO_ZSetMgr); // ??? what is semantic of bZSetMode?
   bNoZSet = false;
   if(mode_oper==MO_Scan){
      z_tol = LayerSensitivity;
   }else if(bZSetMode){
      if(zset_n>0 && n_layerz>=0 && n_layerz<zset_n && zset_list[n_layerz]!=none){
         z_tol = zset_list[n_layerz].layer_thickness / 2;
      }else{
         bNoZSet = true;
         z_tol = 0.0;
      }
   }else{
      z_tol = LayerSensitivity;
   }

   sel_z = get_sel_z(p);
   band_z = int(p.location.z - player_vs_dpn_addz);   // ADD: band center follows owner, not selected layer   
   
   foreach allactors(class'pathnoderuntime',dpn){
      if(!second_pass) pn_tot++;
      if(mode_oper==MO_ZSetMgr && dpn==laserdpn) continue;  // hide laser rays in zsetmgr
//----- layers ignorator ---------------------------------------
      bInVirtualBand = false;
      if(dpn.layer_id == 0){            // nonstray never enters band
         if(mode_oper==MO_ZSetMgr || (mode_oper==MO_Mark && !bZSetEditMode))
            bInVirtualBand = (abs(band_z - int(dpn.location.z)) <= pending_layer_thickness_default/2);
      }
      if(bNoZSet){     // no zsets - special rules

         if(mode_oper==MO_Mark){  // latest code
            if(!second_pass) continue;
            if(bZSetEditMode) nomatch_z = false;        // edit: all white
            else              nomatch_z = !bInVirtualBand;   // band=cyan, outside=alert
         }         
      }else{
         // ---- std Z selection ----------------------------------------------
         pnz = dpn.location.z;   // no truncating
         nomatch_z = (abs(sel_z - pnz) > z_tol);
         // DPN of other layer - apply nomatch, will render in pass1, pc_blue_map
         if(bZSetMode && dpn.layer_id != 0 && dpn.layer_id != zset_list[n_layerz].layer_id)
            nomatch_z = true;         
      }
      // ----- virtual pending band (stray only) -----
      bool_tmp = (dpn==laserdpn) || dpn.bDirectional;          // always render
      if(!bool_tmp){
         if(!second_pass && !nomatch_z) continue;            // ignore matchz on pass1
         if(second_pass && nomatch_z) continue;              // ignore nomatch on pass2
         if(mode_rayprocess==RP_SelFull && nomatch_z) continue; // we maybe still process further in fullcolor map mode
      }else{
         if(!second_pass) continue;                             // ignore any of them in pass1
      }
      if(!nomatch_z) pn_mz++;
//----- dist ignorator ---------------------------------------
      x = dpn.location;   // cancer code: we use x y z vars for things not meaning coords
      pnz = map_resolution * size_tex / 2;  // max map hull bounds for raytracing centers
      pnz += 540;                           // + bit more than trace length
      if(ena_2xzoom) pnz = pnz>>1;          // ignore 75% of area if 2x zooming
      if(ena_4xzoom) pnz = pnz>>1;          // ignore 93% of area if 4x zooming
      if(mode_rayprocess!=RP_SelFull){ // always render all pathnodes in all_selected mode
         if((abs(x.x + global_offset_x) > pnz)
         || (abs(x.y + global_offset_y) > pnz)) continue;
      }  // in other modes, if PN/DPN far far outside of texture, try to eat less CPU
//--------------------------------------------------------------
      r.yaw = 0;  r.roll = 0; r.pitch = 0; yaw_until = 65536.0;
      if(dpn.bDirectional){
         r.yaw = dpn.rotation.yaw - dpn.mass/2;
         yaw_until = dpn.rotation.yaw + dpn.mass;
      }
      while(r.yaw<yaw_until){
         getaxes(r,x,y,z);
         endtrace = dpn.location + 768.0*x;   // scan dist
         rtarg = trace(hl,hn,endtrace,dpn.location,true);
         hlx = maptex_coord(hl.x,maptex_x);
         hly = maptex_coord(hl.y,maptex_y);
         if(map_tex_out_of_bounds(hlx,hly)) goto skip_by_drawmap_outtexbounds;
         // -----------------------------------------
         c.drawcolor = pc_wh;
         // 1. real (nonstray) layers - top priority
         if(bZSetMode && dpn.layer_id!=0 && !dpn.bLayerActive
            && mode_oper!=MO_Prod && mode_oper!=MO_Mark){
            c.drawcolor = pc_gray_map;                  // disabled real layer
         }else{
            // 3. alert colors for stray nomatch
            if(nomatch_z && (mode_rayprocess==RP_ClientLike || mode_oper==MO_Scan)){
               if       (SHR_Factor_scanmap<=2) c.drawcolor = pc_green_map;
                else if (SHR_Factor_scanmap==3) c.drawcolor = pc_bluer_map;
                else                            c.drawcolor = pc_blue_map;
            }
            // 2. cyan LAST - overrides alert, stray only, not real layers
            if(bInVirtualBand) c.drawcolor = pc_cyan;
         }
         if(dpn.bIsKillGoal && ena_dpn_alice){
            c.drawcolor = pc_red;
            if(nomatch_z) c.drawcolor = pc_red_f;
         }
         bool_tmp = false;
         if(dpn.bDirectional) bool_tmp = true; // always render, no matter of hitloc.pitch
         if(dpn==laserdpn) c.drawcolor = pc_pinker; // nowspawning dpn scan result, pink
         if(bool_tmp || rotator(hn).pitch  <= anti_artifacts_maxslope){ // do strict walls if bool_tmp is false
            pnz = 0.25;               // safe to use pnz here
            if(ena_2xzoom) pnz = 0.5;
            if(ena_4xzoom) pnz = 1.0;
            if(rtarg.group!='sciignore'){ // all ready to put pixel
               if(mode_oper==MO_LifetimeCfg){            // dim all map if in lifetime cfg mode
                  c.drawcolor.r = c.drawcolor.r>>2;
                  c.drawcolor.g = c.drawcolor.g>>2;
                  c.drawcolor.b = c.drawcolor.b>>2;
               }
               if(dpn==laserdpn && (mode_oper==MO_Mark || mode_oper==MO_Prod)) goto skip_by_drawmap_prod;
               c.setpos(hlx,hly);  c.drawicon(texture'scipixel',pnz);
             skip_by_drawmap_prod:
            }
         }
       skip_by_drawmap_outtexbounds:
         if(mode_rayprocess!=RP_SelFull) pnz = advance_ray_pos_std;   // assign rays density, full quality for mode 0 only
          else pnz = advance_ray_pos_full;
         if(mode_rayprocess==RP_AllFast) pnz = advance_ray_pos_fast;  // skip rays in mode 1, to 8x faster
         if(nomatch_z) pnz = advance_ray_pos_fast;                    // skip mismathing by z
         if(mode_rayprocess==RP_ClientLike                            // skip in mode 3
            && vsizesq(dpn.location - p.location)>max_fastscan_vsizesq) // outside max radius
                pnz = advance_ray_pos_fast;
         if(dpn==laserdpn) pnz = advance_ray_pos_std;    // cancel skips for laser
         if(accumulated_pw_sens_fire>timetrigger_pw_sens_fire && !nomatch_z) pnz = advance_ray_pos_full; // override to full quality
         if(mode_oper==MO_LifetimeCfg || !second_pass) pnz = advance_ray_pos_shit;
         r.yaw += pnz;  // apply
         rc_tot ++;     // rays counter
      }
   }
}

function int get_sel_z(playerpawn p){
   if(mode_oper==MO_Scan)    // build: acq by owner
      return int(p.location.z - player_vs_dpn_addz);
   // markup/prod/zsetmgr: acq by ZSets
   if(mode_oper==MO_Mark || mode_oper==MO_Prod || mode_oper==MO_ZSetMgr){
      if(zset_n>0 && n_layerz>=0 && n_layerz<zset_n && zset_list[n_layerz]!=none)
         return int(zset_list[n_layerz].location.z);
      return int(p.location.z - player_vs_dpn_addz);   // fallback (handled in process_map)
   }
   // other/unknown mode - old code
   return ena_lockz ? int(p.location.z - player_vs_dpn_addz) : int(presets_z[n_layerz]);
}

// ==================================================================================================
exec function mapinit(){
   local pathnode pn;
   if(mode_oper==MO_prod) return;
   if(order_welcome_msgs<4) order_welcome_msgs = 4;
   foreach allactors(class'pathnode',pn) if(!pn.isa('pathnoderuntime')) dpn_replace(pn.location);
   do_diag_z(true);            // initial diag pass
   tog_opermode(0);
}
function postbeginplay(){
// local string KeyName, Alias;
   local info ifo;
   local inventory w;
   local decoration d;
   local effects e;
   local int i;
   local trigger t;
   local teleporter tp;
   local mover m;
   inv_finfo        = spawn(class'stinvfontinfo');
   lightbeam        = spawn(class'STLight'     ,,,shithole);
   laserdpn         = spawn(class'STLaser'     ,,,shithole);
   laserdot         = spawn(class'STLaserBlast',,,shithole);
   laser_sector_sta = spawn(class'STLaserBlast',,,shithole);
   laser_sector_end = spawn(class'STLaserBlast',,,shithole);
   if(laser_sector_sta!=none) laser_sector_sta.bAngleIndicator = true;
   if(laser_sector_end!=none) laser_sector_end.bAngleIndicator = true;
   if(laserdpn        !=none) laserdpn.group = 'AMSLASER';
   // ==============
//       keyname = getplayerowner().consolecommand("keyname "$i);
//       alias = getplayerowner().consolecommand("keybinding "$keyname);
   // ==============
   foreach allactors(class'info',ifo){
      if(!ifo.isa('ONPLevelInfo')) ifo.SetPropertyText("MaxHealth","500");
      if(ifo.isa('ZoneInfo')) zoneinfo(ifo).bPainZone = false;
   }
   foreach allactors(class'teleporter',tp){
      tp.setCollisionSize(48.0,128.0);
      tp.bHidden=false;
   }
   foreach allactors(class'trigger',t){
      t.group='';
      t.bTriggerOnceOnly = false;               // force enable
         t.TriggerType = TT_ClassProximity;     // prohibit autotrigger
         t.ClassProximityType = class'STHUD';
      t.RepeatTriggerTime = 0.0;                // normalize toggling stuff
      t.RetriggerDelay = 0.2;
      t.GotoState('NormalTrigger');
   }
   foreach allactors(class'mover',m){
      m.GotoState('TriggerToggle');
      m.MoverEncroachType = ME_ReturnWhenEncroach;
      m.StayOpenTime = 0.0;
   }
   pc_blue   = makecolor(175,175,255);   pc_blue_f   = makecolor(75 ,76 ,121);   pc_blue_map  = makecolor(80, 80, 128);
   pc_bluer  = makecolor(148,148,255);   pc_bluer_f  = makecolor(66 ,67 ,121);   pc_bluer_map = makecolor(112,112,160);
   pc_yellow = makecolor(255,255,170);   pc_yellow_f = makecolor(102,103,92 );   pc_green_map = makecolor(155,203,155);
   pc_cyan   = makecolor(128,229,255);   pc_cyan_f   = makecolor(59 ,94 ,121);   pc_gray_map  = makecolor(32, 32, 32 );
   pc_teal   = makecolor(108,173,184);   pc_teal_f   = makecolor(52 ,75 ,97 );
   pc_orange = makecolor(255,204,170);   pc_orange_f = makecolor(102,86 ,92 ); 
   pc_green  = makecolor(204,255,170);   pc_green_f  = makecolor(85 ,103,92 );
   pc_pink   = makecolor(238,170,255);   pc_pink_f   = makecolor(96 ,74 ,121);
   pc_pinker = makecolor(204,128,255);   pc_pinker_f = makecolor(85 ,60 ,121);
   pc_red    = makecolor(255,128,128);   pc_red_f    = makecolor(102,60 ,78 );
   pc_brown  = makecolor(198,156,156);   pc_brown_f  = makecolor(83 ,70 ,88 );
   pc_bg     = makecolor(24 ,25 ,53 );   pc_fill_bg  = makecolor(38 ,39 ,70 );
   pc_wh     = makecolor(255,255,255);   pc_wh_f     = makecolor(161,161,173);   pc_gray      = makecolor(128,128,128);
   common_texname=GetURLMap();
   clientmsg_timer = -1.0;
   new_clientmsg[0] = "";
   new_clientmsg[1] = "";
   presets_nmax = 0;
   for(i=0;i<64;i++){
      presets_z[i] = 0.0;
      region_usefloor[i] = 0;
      region_usedby[i] = 9;
   }
   for(i=0;i<zbar_w;i++) zbar_count[i]=0;
   tog_opermode(0);    // goto build mode
   resetconfig();
   if(b_SPAWNFLOOD_WARN_AutoDPNafterSummon){
      order_welcome_msgs = 4;
      PickupMessage = "AreaMap CT scan tool. Enter Q in console for more info.";
      mapinit();
   }
   foreach allactors(class'inventory',w) if(w != self) w.destroy();
   foreach allactors(class'decoration',d) d.destroy();
   foreach allactors(class'effects',e){
      if(e==laserdot)         continue;
      if(e==laser_sector_sta) continue;
      if(e==laser_sector_end) continue;
      if(e==lightbeam)        continue;
      e.destroy();
   }
}

function playselect(){
   local playerpawn pp;
   pp = playerpawn(owner);
   if(pp == none) return;
   oldHUD = pp.myHUD;
   oldHUDType = pp.HUDType;
   pp.HUDType = Class'STHUD';
   pp.myHUD = Spawn(Class'STHUD',pp,,shithole);
   pp.myHUD.MainMenu = oldHUD.MainMenu;
   pp.myHUD.MainMenuType = oldHUD.MainMenuType;
   ena_show_name = true;
   when_pickup = level.timeseconds;
   pp.consolecommand("killpawns");
   pp.consolecommand("killall pickup");
   pp.consolecommand("killall decoration");
   pp.consolecommand("killall decal");
   pp.consolecommand("amphibious");
   if(!b_MY_USERINI_IS_READONLY_AutoBindKeys) goto skip_by_playselect_nobinds;
   pp.consolecommand("set input alt sci_forcedodge");       // level setup ends
   pp.consolecommand("set input f1 tog_opermode 0");
   pp.consolecommand("set input f7 tog_opermode 1");
   pp.consolecommand("set input f4 tog_opermode 2");
   pp.consolecommand("set input f8 tog_opermode 3");
   
   pp.consolecommand("set input e tog_opermode 5"); // debug
// pp.consolecommand("set input e sci_nav_to_dpn"); // debug
   pp.consolecommand("set input home tog_zset_editmode");
   
   pp.consolecommand("set input f3 tog_dpntest");
   pp.consolecommand("set input f10 ams_pause");            // opermode ends
   pp.consolecommand("set input z tog_digzoom");
   pp.consolecommand("set input x tog_shr_factor");
   pp.consolecommand("set input b tog_mode_step");
   pp.consolecommand("set input g tog_mode_texsize");
   pp.consolecommand("set input enter tog_layerz_assign");  // mapctl ends
   pp.consolecommand("set input f5 tog_show_debug");
   pp.consolecommand("set input f2 tog_show_all_layers");
   pp.consolecommand("set input r tog_mode_mwheel");
   pp.consolecommand("set input pageup dec_nlayer");
   pp.consolecommand("set input pagedown inc_nlayer");
// ---------- regions ---------------------------------------------------
   pp.consolecommand("set input 1 tog_region 0"); pp.consolecommand("set input numpad1 tog_region 0");
   pp.consolecommand("set input 2 tog_region 1"); pp.consolecommand("set input numpad2 tog_region 1");
   pp.consolecommand("set input 3 tog_region 2"); pp.consolecommand("set input numpad3 tog_region 2");
   pp.consolecommand("set input 4 tog_region 3"); pp.consolecommand("set input numpad4 tog_region 3");
   pp.consolecommand("set input 5 tog_region 4"); pp.consolecommand("set input numpad5 tog_region 4");
   pp.consolecommand("set input 6 tog_region 5"); pp.consolecommand("set input numpad6 tog_region 5");
   pp.consolecommand("set input 7 tog_region 6"); pp.consolecommand("set input numpad7 tog_region 6");
   pp.consolecommand("set input 8 tog_region 7"); pp.consolecommand("set input numpad8 tog_region 7");
// --------- group 2 ---------------------------------------------------
   pp.consolecommand("set input u tog_lockz");
   pp.consolecommand("set input o tog_lockxy");
   pp.consolecommand("set input i do_scr_w");
   pp.consolecommand("set input j do_scr_a");
   pp.consolecommand("set input k do_scr_s");
   pp.consolecommand("set input l do_scr_d");         // user col1 ends
   pp.consolecommand("set input t tog_ignore");
   pp.consolecommand("set input y tog_light");
   pp.consolecommand("set input q tog_laser");
   pp.consolecommand("set input m mark_current_region");
   pp.consolecommand("set input n new_layerz_manual");
// --------- group 3 ---------------------------------------------------
   pp.consolecommand("set input f tog_dpn_fall");
   pp.consolecommand("set input v tog_dpn_autospawn");
   pp.consolecommand("set input h tog_strictwalls");     // placement ends
   pp.consolecommand("set input middlemouse sci_user_dpn_spawn");
   pp.consolecommand("set input mousewheeldown ctl_mw_less");
   pp.consolecommand("set input mousewheelup ctl_mw_more");  
   pp.consolecommand("set input p shdn_waterable");
   pp.consolecommand("set input f6 tog_opermode 4");
   skip_by_playselect_nobinds:
   upd_resolution(); upd_size_tex(); upd_size_step();
}

exec function tog_laser(){
   if(mb_fail_confirm()) return;
   if(mode_oper==MO_LifetimeCfg || ena_debug || ena_prod) return;
   key_when = 0.3; last_kw = kw_q;
   sens_ignore = false;
   mode_laser++;
   if(mode_laser>2) mode_laser = 0;
   sanitize_laser();
}
function sanitize_laser(){
   if(mode_laser==0){
      if(laserdpn!=none) laserdpn.setlocation(shithole);
      if(laserdot!=none) laserdot.setlocation(shithole);
      if(laser_sector_sta!=none) laser_sector_sta.setlocation(shithole);
      if(laser_sector_end!=none) laser_sector_end.setlocation(shithole);
      sens_mov = none;  // forget mover
   }else
      sens_trig = none; // forget trigger
}

exec function tog_ignore(){
   if(mb_fail_confirm()) return;
   if(mode_oper==MO_LifetimeCfg || mode_oper==MO_prod || ena_debug) return;
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
   if(mode_oper==MO_LifetimeCfg || mode_oper==MO_prod || ena_debug) return;
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
   if(mode_oper==MO_LifetimeCfg || mode_oper==MO_prod || ena_debug) return;
   z = region.zone;
   if(z == none) return;
   if(!z.bWaterzone) return;
   z.bWaterzone = false;
   new_clientmsg[0] = string(z.name)$" bWaterZone";
   new_clientmsg[1] = "is now false.";
   clientmsg_timer = 2.0;
}

exec function tog_show_debug(){
   if(mb_fail_confirm()) return;
   if(mode_oper==MO_LifetimeCfg || mode_oper==MO_prod) return;
   ena_debug = !ena_debug;
}

exec function ams_pause(){
   if(ena_prod) return;
   ena_ams_render = !ena_ams_render;
}


exec function tog_show_all_layers(){
   if(mb_fail_confirm()) return;
   if(mode_oper==MO_LifetimeCfg || mode_oper==MO_prod || ena_debug) return;
   key_when = 0.3; last_kw = kw_f2;
   if(mode_oper==MO_Mark){                       // markup: SelFull <-> Relevant only
      if(mode_rayprocess==RP_SelFull) mode_rayprocess = RP_ClientLike;
      else                            mode_rayprocess = RP_SelFull;
      return;
   }
   switch(mode_rayprocess){
   case RP_SelFull:    mode_rayprocess = RP_AllFast;    break;
   case RP_AllFast:    mode_rayprocess = RP_AllFullEco; break;
   case RP_AllFullEco: mode_rayprocess = RP_ClientLike; break;
   case RP_ClientLike: mode_rayprocess = RP_SelFull;    break; }
}

exec function tog_lockxy(){
   if(mb_fail_confirm()) return;
   if(mode_oper==MO_LifetimeCfg || ena_prod || ena_debug) return;
   key_when = 0.3; last_kw = kw_o;
   ena_lockxy = !ena_lockxy;
   if(ena_lockxy) new_clientmsg[0] = "Map center snapped to player.";
   else new_clientmsg[0] = "Map center released.";
   clientmsg_timer = 2.0;
}

exec function tog_lockz(){
   if(mb_fail_confirm()) return;
   if(mode_oper==MO_LifetimeCfg || ena_prod || ena_debug) return;
   key_when = 0.3; last_kw = kw_u;
   ena_lockz = !ena_lockz;
}

exec function tog_mode_mwheel(){
   if(mode_oper==MO_LifetimeCfg || ena_prod || ena_debug || ena_anywall) return;
   key_when = 0.3; last_kw = kw_r;
   if(mode_oper==MO_ZSetMgr){
      switch(mode_mwheel){
         case MW_zset_zone: mode_mwheel = MW_zset_z;    break;
         case MW_zset_z:    mode_mwheel = MW_zset_zone; break;
         default:           mode_mwheel = MW_zset_zone; break;
      }
      return;
   }
   if(mb_fail_confirm()) return;
   // todo check mode availty vs opermode/anywall
   if(ena_lockxy) return;                       // LockXY - R ignored
   switch(mode_mwheel){
      case MW_modX: mode_mwheel = MW_modY; break;
//    case MW_modY: mode_mwheel = MW_modX; break;  // new code after this line
//    default:      mode_mwheel = MW_modX; break;   // if MW_modL then goto modX - BUG: breaks existing behavior
      case MW_modY: mode_mwheel = MW_modL; break;
      case MW_modL: mode_mwheel = MW_modX; break;
   }
}

exec function tog_strictwalls(){
   if(mode_oper==MO_LifetimeCfg || mode_oper==MO_prod || ena_debug) return;
   key_when = 0.3; last_kw = kw_h;
   ena_anywall = !ena_anywall;
   if(ena_anywall) return;
   if(laser_sector_sta!=none) laser_sector_sta.setlocation(shithole);
   if(laser_sector_end!=none) laser_sector_end.setlocation(shithole);
}

exec function tog_mode_step(){
   if(mb_fail_confirm()) return;
   if(mode_oper==MO_LifetimeCfg || ena_prod || ena_debug) return;
   key_when = 0.3; last_kw = kw_b;
   mode_step++;
   if(mode_step>2) mode_step=0;
   upd_size_step();
}
exec function tog_mode_texsize(){
   if(mb_fail_confirm()) return;
   if(mode_oper==MO_LifetimeCfg || ena_prod || ena_debug) return;
   key_when = 0.3; last_kw = kw_g;
   mode_texsize++;
   if(mode_texsize>2) mode_texsize=0;
   upd_size_tex();
}
exec function tog_shr_factor(){
   if(mb_fail_confirm()) return;
   if(mode_oper==MO_LifetimeCfg || ena_prod || ena_debug) return;
   key_when = 0.3; last_kw = kw_x;
   SHR_Factor_scanmap--;
   if(SHR_Factor_scanmap<1) SHR_Factor_scanmap = SHR_Factor_max;
   upd_resolution();
   upd_size_step();
}

exec function tog_dpn_fall(){
   if(mb_fail_confirm()) return;
   if(mode_oper==MO_LifetimeCfg || mode_oper==MO_prod || ena_debug) return;
   key_when = 0.3; last_kw = kw_f;
   switch(mode_dpn_fall){
      case DPZ_floor:  mode_dpn_fall = DPZ_flying; break;
      case DPZ_flying: mode_dpn_fall = DPZ_user;   break;
      case DPZ_user:   mode_dpn_fall = DPZ_laser;  break;
      case DPZ_laser:  mode_dpn_fall = DPZ_floor;  break;
   }
}

exec function tog_dpn_autospawn(){
   if(mb_fail_confirm()) return;
   if(mode_oper==MO_LifetimeCfg || mode_oper==MO_prod || ena_debug) return;
   key_when = 0.3; last_kw = kw_v;
   mode_autospawn++;
   if(mode_autospawn>2) mode_autospawn = 0;
   if(mode_autospawn==1) autospawn_interval = 192.0;
   if(mode_autospawn==2) autospawn_interval = 128.0;
}

exec function tog_zset_editmode(){  // ???????????
   if(mode_oper!=MO_ZSetMgr) return; // cover ena_prod as well
   key_when = 0.3; last_kw = kw_home;
   bZSetEditMode = !bZSetEditMode;
}

function PathNodeRuntime dpn_spawn(bool delayed_show, bool bAsLeader){
   local PathNodeRuntime dpn;
   if(laserdpn==none) return none;
   dpn = spawn(class'PathNodeRuntime',,,laserdpn.location,laserdpn.rotation);
   if(dpn==none) return none;
   zbar_rebuild_timer = 0.2;
   zbar_irrelevant = true; // new: set this always
   dpn.bDirectional = laserdpn.bDirectional;
   dpn.mass = laserdpn.mass;
   if(bAsLeader){
      dpn.bHiddenEd = true;
      dpn.enable('tick');
      dpn.layer_thickness = pending_layer_thickness_default;
      layer_add(dpn);
      return dpn;
   }
   if(!delayed_show) return dpn;
   dpn.bHidden = true;
   dpn.bIsSecretGoal = true;
   dpn.setTimer(0.7,false);
   return dpn;
}

function dpn_replace(vector l){
   local vector dpn_newpos,hitnor;
   dpn_newpos = shithole;
   trace(dpn_newpos,hitnor,l+vect(0,0,-1024),l,true);
   dpn_newpos.z += AutofallFloordist;
   spawn(class'PathNodeRuntime',,,dpn_newpos);
   zbar_rebuild_timer = 0.2;
   zbar_irrelevant = true;
}

function PathNodeRuntime FindDPN(vector search_location, float range_sensitivity){
   local PathNodeRuntime t;
   if(laserdpn==none) return none; // potential spawnspam here but we protect tick() before call this
   foreach RadiusActors(class'PathNodeRuntime', t, range_sensitivity) if(t!=laserdpn) return t;
   return none;
}

/*function do_diag_z(bool bScriptedCall){
   local pathnoderuntime pn;
   local float pnz,pnz_lsb;
   local int i, j;
   local bool bDup;
   local bool bManualZSet;

   build_zbar();  //debug
   return;

   for(i=0;i<64;i++){
      presets_z[i] = 0.0;
      region_usefloor[i] = 0;
      region_usedby[i] = 9;
   }
   alignz_seek = 0;
   bManualZSet = false;
   foreach AllActors(class'pathnoderuntime', pn) if(pn.bHiddenEd) bManualZSet = true;
   bDup = false;
   if(laserdpn==none) bDup = true; // cancer code but safe to use bDup. returnless protection against iterating laser
   presets_nmax = 0;
   foreach AllActors(class'pathnoderuntime', pn){ // collect
      if(bManualZSet && !pn.bHiddenEd) continue;  // user-defined ZSet mode enabled, skip all DPNs except ZSets
      if(bdup) goto skip_diagz_nolaser;
      if(pn==laserdpn) continue;
      skip_diagz_nolaser:   // evaded "accessed none" error
      if(presets_nmax >= 64) break;
      pnz = pn.location.z; 
      pnz_lsb = pnz % VertDiscretization;
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
   for(i=presets_nmax;i<64;i++) presets_z[i] = 0.0;
   build_zbar();
// for(i=0; i<presets_nmax; i++) broadcastmessage(string(presets_z[i]));  // log result
   if(!bScriptedCall){
      new_clientmsg[0] = "Zset diag probe done,";
      new_clientmsg[1] = "return to mark mode.";
      clientmsg_timer = 4.0;
   }
   n_layerz = 0;
   tog_opermode(2);
}*/

function do_diag_z(bool bScriptedCall){
   local pathnoderuntime pn;
   local float pnz;
   local int i, j;

   // reset presets and AlignZ fill
   for(i=0;i<64;i++){
      region_usefloor[i] = 0;
      region_usedby[i] = 9;
   }
   for(i=0;i<63;i++) presets_z[i] = 0.0;
   alignz_seek = 0;
   presets_nmax = 0;

   // collect Z from ZSet leaders only
   foreach AllActors(class'pathnoderuntime', pn){
      if(!pn.bHiddenEd) continue;   // leaders only
      if(pn==laserdpn) continue;
      if(presets_nmax >= 63) break;
      presets_z[presets_nmax] = pn.location.z;
      presets_nmax++;
   }

   // insertion sort
   for(i=1; i<presets_nmax; i++){
      pnz = presets_z[i];
      j = i - 1;
      while(j>=0 && presets_z[j]>pnz){
         presets_z[j+1] = presets_z[j];
         j--;
      }
      presets_z[j+1] = pnz;
   }
   for(i=presets_nmax;i<63;i++) presets_z[i] = 0.0;

   build_zbar();

   if(!bScriptedCall){
      new_clientmsg[0] = "Zset diag probe done,";
      new_clientmsg[1] = "return to mark mode.";
      clientmsg_timer = 4.0;
   }
   n_layerz = 0;
}

function layer_capture_stray(pathnoderuntime leader){
   local pathnoderuntime pn;
   if(leader.layer_thickness <= 0) return;
   foreach AllActors(class'pathnoderuntime', pn){
      if(pn.bHiddenEd) continue;
      if(pn==laserdpn) continue;
      if(pn.layer_id != 0) continue;   // stray only
      if(abs(pn.location.z - leader.location.z) <= leader.layer_thickness/2){
         pn.layer_id        = leader.layer_id;
         pn.layer_z         = leader.location.z;
         pn.layer_thickness = leader.layer_thickness;
         pn.bLayerActive    = leader.bLayerActive;
         pn.texture = leader.bLayerActive ? texture'sciRpnr' : texture'sciBpnr'; // todo black
      }
   }
   zbar_rebuild_timer = 0.2;
   zbar_irrelevant = true;
}

function layer_release(pathnoderuntime leader){
   local pathnoderuntime pn;
   foreach AllActors(class'pathnoderuntime', pn){
      if(pn.bHiddenEd) continue;
      if(pn==laserdpn) continue;
      if(pn.layer_id != leader.layer_id) continue;   // DPN of this layer only
      pn.layer_id        = 0;
      pn.layer_z         = 0;
      pn.layer_thickness = 0;
      pn.bLayerActive    = true;
      pn.texture = pn.default.texture;
   }
   zbar_rebuild_timer = 0.2;
   zbar_irrelevant = true;
}

function layer_add(pathnoderuntime leader){
   if(zset_n >= 63) return;
   next_layer_id++;
   leader.layer_id = next_layer_id;
   leader.layer_z = leader.location.z;
   if(leader.layer_thickness <= 0)
      leader.layer_thickness = pending_layer_thickness_default;
   zset_list[zset_n] = leader;
   zset_n++;
   n_zset = zset_n - 1;
   if(mode_oper==MO_ZSetMgr) n_layerz = zset_n - 1;       // auto-select newly created layer
   layer_capture_stray(leader);
}

function layer_change_thickness(float delta_thickness){
   local pathnoderuntime leader;
   local float new_thickness;
   if(zset_n == 0) return;
   leader = zset_list[zset_n-1];  // affect last created only
   if(leader == none) return;
   if(!leader.bLayerActive) return;
   new_thickness = leader.layer_thickness + delta_thickness;
   if(new_thickness < layer_thickness_min) new_thickness = layer_thickness_min;
   if(new_thickness > layer_thickness_max) new_thickness = layer_thickness_max;
   layer_release(leader);
   leader.layer_thickness = new_thickness;
   layer_capture_stray(leader);
}

function layer_change_z(float delta_z){
   local pathnoderuntime leader;
   local vector new_loc;
   local float new_z;
   if(p==none) return;
   if(zset_n == 0) return;
   leader = zset_list[zset_n-1];   // affect last created only
   if(leader == none) return;
   if(!leader.bLayerActive) return;
   new_z = leader.location.z + delta_z; // new code
   if(zbar_valid){
      if(new_z < zbar_zmin) new_z = zbar_zmin;       // limit by level z
      if(new_z > zbar_zmax) new_z = zbar_zmax;
   }else{
      // todo use default
   }
   layer_release(leader);
   new_loc = leader.location;
   new_loc.z = new_z;
   leader.setlocation(new_loc);
   leader.layer_z = leader.location.z;
   layer_capture_stray(leader);
}

exec function layer_remove_last(){
   local pathnoderuntime leader;
   local int i,max_id;
   if(zset_n == 0) return;
   if(mode_oper==MO_Prod) return;
   leader = zset_list[zset_n-1];
   if(leader != none){
      layer_release(leader);
      leader.destroy();
   }
   zset_n--;                   // todo test this, id corrupt possible
   next_layer_id = zset_n;
   max_id = 0;
   for(i=0; i<zset_n; i++){
      if(zset_list[i]!=none && zset_list[i].layer_id > max_id)
         max_id = zset_list[i].layer_id;
   }
   next_layer_id = max_id;
   n_zset = zset_n > 0 ? zset_n - 1 : 0;
   if(n_layerz >= zset_n) n_layerz = zset_n > 0 ? zset_n - 1 : 0;
}

exec function layer_remove_all(){
   local pathnoderuntime pn;
   local byte i;
   if(ena_prod) return;
   foreach AllActors(class'pathnoderuntime', pn){     // release all DPNs to stray
      if(pn.bHiddenEd) continue;
      if(pn==laserdpn) continue;
      pn.layer_id        = 0;
      pn.texture=pn.default.texture;
      pn.layer_z         = 0;
      pn.layer_thickness = 0;
      pn.bLayerActive    = true;
   }
   foreach AllActors(class'pathnoderuntime', pn){      // remove all leaders
      if(!pn.bHiddenEd) continue;
      pn.destroy();
   }
   for(i=0; i<63; i++) zset_list[i] = none;
   zset_n = 0;
   next_layer_id = 0;
   n_zset = 0;
   // ---- reset layer/preset/region counters ----
   n_layerz = 0;
   presets_nmax = 0;
   for(i=0; i<63; i++){
      presets_z[i] = 0.0;
      region_usefloor[i] = 0;
      region_usedby[i] = 9;
   }
   alignz_seek = 0;
   // ---- rebuild histogram ----
   zbar_rebuild_timer = 0.2;
   zbar_irrelevant = true;
}

function build_zbar(){
   local pathnoderuntime pn;
   local float pnz, span;
   local int col, i;
   for(i=0; i<zbar_w; i++){ zbar_count[i]=0; zbar_count_stray[i]=0; }    // reset
   zbar_valid = false;
   zbar_zmin = 0; zbar_zmax = 0;
   // pass 1: min/max incl. leaders
   foreach AllActors(class'pathnoderuntime', pn){
      if(pn==laserdpn) continue;
      pnz = pn.location.z;
      if(!zbar_valid){ zbar_zmin = pnz; zbar_zmax = pnz; zbar_valid = true; }
      else{
         if(pnz < zbar_zmin) zbar_zmin = pnz;
         if(pnz > zbar_zmax) zbar_zmax = pnz;
      }
   }
   if(!zbar_valid) return;
   span = zbar_zmax - zbar_zmin;
   if(span < 1.0) span = 1.0;   // prevent infinity
   // pass 2: bins
   zbar_stray_total = 0;
   foreach AllActors(class'pathnoderuntime', pn){
      if(pn==laserdpn) continue;
      pnz = pn.location.z;
      col = int((pnz - zbar_zmin) * (zbar_w-1) / span);
            if(col < 0) col = 0;
      if(col >= zbar_w) col = zbar_w-1;
      if(zbar_count[col] < 255) zbar_count[col]++;     // histogram: all DPN
      if(!pn.bHiddenEd && pn.layer_id == 0){   // bottom indicator:  stray only
         if(zbar_count_stray[col] < 255) zbar_count_stray[col]++;
         zbar_stray_total++;
      }
   }
   // pass 3: compress dynrange by used bins list
   zbar_used_n = 0;
   zbar_used_max = 0;
   for(i=0; i<zbar_w; i++){
      if(zbar_count[i]==0) continue;
      zbar_used[zbar_used_n] = i;
      zbar_used_n++;
      if(zbar_count[i] > zbar_used_max) zbar_used_max = zbar_count[i];
   }
   zbar_irrelevant = false;
}

exec function ctl_mw_less(){ ctl_mw(false); }
exec function ctl_mw_more(){ ctl_mw(true); }
function ctl_mw(bool dir_more){
   local int dir;     // +1 = more, -1 = less
   local float laser_delta;
   if(mode_oper==MO_LifetimeCfg || ena_prod || ena_debug) return;
   if(p==none) return;
   dir = dir_more ? 1 : -1;
   if(mode_oper==MO_ZSetMgr){
      if(!bZSetEditMode) return;  // pending mode: wheel does nothing
      if(zset_n<=0 || zset_list[zset_n-1]==none) return;
      if(n_layerz != zset_n-1) return;              // readonly if not last one
      if(!zset_list[n_layerz].bLayerActive) return; // readonly if inactive
      if(mode_mwheel == MW_zset_zone) layer_change_thickness(8.0*dir);
      else                            layer_change_z(8.0*dir);
      return;
   }
   if(ena_anywall){
      anywall_half_angle += 256.0*dir;
      if(anywall_half_angle<1024.0) anywall_half_angle = 1024.0;
      if(anywall_half_angle>6144.0) anywall_half_angle = 6144.0;
      return;
   }
   if(mode_laser == 1){      // less: dist<384 -> +8/+32 ; more: dist>0 -> -32/-8
           if( dir_more && laser_wall_dist > 0){   laser_delta = (laser_wall_dist > 32) ? 32 : 8;  laser_wall_dist -= laser_delta; }
      else if(!dir_more && laser_wall_dist < 384){ laser_delta = (laser_wall_dist < 32) ? 8  : 32; laser_wall_dist += laser_delta; }
      return;
   }
   if(mode_laser == 2){
      if (dir_more) laser_ray_length = min(laser_ray_length + 32, 768);
      else          laser_ray_length = max(laser_ray_length - 32, 64);
      return;
   }
   if(mode_laser!=0) return;
   switch(mode_mwheel){
      case MW_modX: if(!ena_lockxy) global_offset_x += size_step*dir; break;
      case MW_modY: if(!ena_lockxy) global_offset_y += size_step*dir; break;
      case MW_modL: if(dir_more){ if(n_layerz<presets_nmax) n_layerz++; }
                    else     { if(n_layerz>0)            n_layerz--; } break;
   }
}

exec function inc_nlayer(){
   if(mode_oper==MO_LifetimeCfg || ena_prod || ena_debug) return;
   if(mode_oper==MO_Scan) return; // new code
   if(mode_oper==MO_Mark || mode_oper==MO_Prod || mode_oper==MO_ZSetMgr){
      if(n_layerz >= zset_n-1) return;
   }else{
      if(n_layerz >= presets_nmax) return;  //??????
   }
   key_when = 0.3; last_kw = kw_pupd;
   n_layerz++;
}
exec function dec_nlayer(){
   if(mode_oper==MO_LifetimeCfg || ena_prod || ena_debug) return;
   if(mode_oper==MO_Scan) return; // new code
   if(n_layerz<=0) return;
   key_when = 0.3; last_kw = kw_pupd;
   n_layerz--;
}

function layer_toggle_active(int idx){
   local pathnoderuntime leader, pn;
   if(idx<0 || idx>=zset_n) return;
   leader = zset_list[idx];
   if(leader == none) return;
   leader.bLayerActive = !leader.bLayerActive;
   foreach AllActors(class'pathnoderuntime', pn){
      if(pn.bHiddenEd) continue;
      if(pn==laserdpn) continue;
      if(pn.layer_id != leader.layer_id) continue;
      pn.bLayerActive = leader.bLayerActive;
      pn.texture = leader.bLayerActive ? texture'sciRpnr' : texture'sciBpnr'; // todo black
   }
   zbar_rebuild_timer = 0.2;
   zbar_irrelevant = true;
}

exec function do_scr_w(){ if(do_scr_common(0)) return; global_offset_y -= size_step; }
exec function do_scr_a(){ if(do_scr_common(1)) return; global_offset_x -= size_step; }
exec function do_scr_s(){ if(do_scr_common(2)) return; global_offset_y += size_step; }
exec function do_scr_d(){ if(do_scr_common(3)) return; global_offset_x += size_step; }
function bool do_scr_common(byte ijkl_key){ // used in MO_LifetimeCfg mode only
   if(ena_debug || ena_prod) return true;
   if(mode_oper==MO_LifetimeCfg) goto skip_to_lifetimecfg_controls;
   if(mb_fail_confirm()) return ena_lockxy;
   if(ena_lockxy) return true;
   key_when = 0.3; last_kw = kw_ijkl; return false;
   skip_to_lifetimecfg_controls: switch(ijkl_key){
      case 0: switch(mode_ltcfg){  // up key, inc mode
         case LTC_ZSetDiscr: mode_ltcfg=LTC_Floordist; break;
         case LTC_LaySens:   mode_ltcfg=LTC_ZSetDiscr; break;
         case LTC_ProdSHR:   mode_ltcfg=LTC_LaySens; break; }
      break;
      case 2: switch(mode_ltcfg){  // dn key, dec mode
         case LTC_Floordist: mode_ltcfg=LTC_ZSetDiscr; break;
         case LTC_ZSetDiscr: mode_ltcfg=LTC_LaySens;   break;
         case LTC_LaySens:   mode_ltcfg=LTC_ProdSHR;   break; }
      break;
   } switch(mode_ltcfg){           // alter keys, exec anyway                 
    case LTC_Floordist:
       if(ijkl_key==3){ if(AutofallFloordist<dpn_addz_narrow)   AutofallFloordist=dpn_addz_narrow; // inc
                   else if(AutofallFloordist<dpn_addz_classic)  AutofallFloordist=dpn_addz_classic;  }
       if(ijkl_key==1){ if(AutofallFloordist>dpn_addz_narrow)   AutofallFloordist=dpn_addz_narrow; // dec
                   else if(AutofallFloordist>dpn_addz_narrower) AutofallFloordist=dpn_addz_narrower; } break;
    case LTC_ZSetDiscr:
       if(ijkl_key==3){ VertDiscretization+=16; if(VertDiscretization>256) VertDiscretization=256; }
       if(ijkl_key==1){ VertDiscretization-=16; if(VertDiscretization<80)  VertDiscretization=80;  }   break;
    case LTC_LaySens:
       if(ijkl_key==3){ LayerSensitivity+=8;    if(LayerSensitivity>160)   LayerSensitivity=160; }
       if(ijkl_key==1){ LayerSensitivity-=8;    if(LayerSensitivity<40)    LayerSensitivity=40;  }     break;
    case LTC_ProdSHR:  
       if(ijkl_key==3){ SHR_Factor_prodmap++; if(SHR_Factor_prodmap>SHR_Factor_max) SHR_Factor_prodmap=SHR_Factor_max; }
       if(ijkl_key==1){ SHR_Factor_prodmap--; if(SHR_Factor_prodmap<1) SHR_Factor_prodmap=1; }         break;
   }
   return true; // prevent execution of global_offset_* changes
 }

function altfire(float f){
   local vector x, y, z;
   local float rad;
   local pathnoderuntime pn;
   if(p == none) return;
   if(mode_oper==MO_ZSetMgr){ tog_mode_mwheel(); return; }
   if(mode_oper==MO_LifetimeCfg || mode_oper==MO_Prod || ena_debug) return;
   key_when = 0.3; last_kw = kw_rmb;
   p.consolecommand("killpawns");
   getaxes(p.viewrotation,x,y,z);
   y = p.location + 56*x;
   rad = kill_dpn_radius_by_player;
   if(mode_laser==1 || mode_laser==2){
      if(laserdpn!=none) y = laserdpn.location;
      rad = kill_dpn_radius_by_laser;
   }
   foreach radiusactors(class'PathNodeRuntime',pn,rad,y) if(pn!=laserdpn){
      if(pn.bHiddenEd) continue;
      pn.destroy();
      zbar_rebuild_timer = 0.2;
      zbar_irrelevant = true;
   }
}

function fire(float f){
   local pawn p;
   local mover m;
   p = pawn(owner);
   if(p == none) return;
   if(mode_oper==MO_LifetimeCfg || mode_oper==MO_Prod || ena_debug) return;
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

function pathnoderuntime find_leader_under_cursor(){
   local pathnoderuntime leader;
   local vector x, y, z, search_pos;
   local float dx, dy, dist_sq, rad_sq;
   local int i;
   if(p==none) return none;
   getaxes(p.viewrotation, x, y, z);
   search_pos = p.location + 56*x;
   rad_sq = 32.0 * 32.0;
   for(i=0; i<zset_n; i++){
      leader = zset_list[i];
      if(leader==none) continue;
      dx = leader.location.x - search_pos.x;
      dy = leader.location.y - search_pos.y;
      dist_sq = dx*dx + dy*dy;
      if(dist_sq <= rad_sq) return leader;
   }
   return none;
}
exec function sci_user_dpn_spawn(){  // middlemouse
   local pathnoderuntime found_leader;
   local vector x, y, z, search_pos;
   if(mode_oper==MO_LifetimeCfg || mode_oper==MO_Prod || ena_debug) return;
   key_when = 0.3; last_kw = kw_mmb;
   if(mode_oper==MO_ZSetMgr){
      if(p==none) return;
      found_leader = find_leader_under_cursor();
      if(found_leader != none){
         if(zset_n > 0 && found_leader == zset_list[zset_n-1]){
            if(zset_kill_timer > 0.0 && zset_kill_confirm > 0)
               zset_kill_confirm++;
            else
               zset_kill_confirm = 1;
            zset_kill_timer = 0.4;
            if(zset_kill_confirm >= 3){
               layer_remove_last();
               zset_kill_confirm = 0;
               zset_kill_timer = 0.0;
            }else{
               new_clientmsg[0] = "Confirm: "$string(zset_kill_confirm)$"/3";
               clientmsg_timer = 0.5;
            }
         }else{
            new_clientmsg[0] = "Orphaned nonstray DPNs possible:";
            new_clientmsg[1] = "only last ZSet is deletable.";
            clientmsg_timer = 2.0;
         }
         return;
      }
      getaxes(p.viewrotation, x, y, z);
      search_pos = p.location + 56*x;
      if(laserdpn!=none) laserdpn.setlocation(search_pos);
      dpn_spawn(pn_immediate, pn_leader);
      return;
   }
   dpn_spawn(pn_immediate, ena_next_dpn_zset); // todo can I replace ena_next_dpn_zset -> pn_raytracer ?
   ena_next_dpn_zset = false;
}

exec function new_layerz_manual(){    // todo delete this func
   if(ena_prod) return;
   key_when = 0.3; last_kw = kw_n;
   ena_next_dpn_zset = !ena_next_dpn_zset;
}


defaultproperties{
  laserdpn=None
  laserdot=None
  laser_sector_sta=None
  laser_sector_end=None
  mode_laser=0
  SHR_Factor_scanmap=SHR_Factor_default
  SHR_Factor_prodmap=4
  PickupViewMesh=LodMesh'UnrealShare.AutoMagPickup'
  bCanThrow=false
  when_pickup=999.0
  ena_show_name=false
  global_offset_x=0
  global_offset_y=0
  VertDiscretization=128.0
  LayerSensitivity=64.0
  AutofallFloordist=24.0
  bDisableAllBtnsNotify=true
  bDisableLRmouseNotify=false
  bEnableMmouseNotify=false
  bUseUntrigger=false
  b_SPAWNFLOOD_WARN_AutoDPNafterSummon=false
  b_MY_USERINI_IS_READONLY_AutoBindKeys=false
  ena_lockz=true
  ena_lockxy=true
  mode_dpn_fall=DPZ_floor
  ena_2xzoom=true
  ena_4xzoom=false
  scrshot_timer=0.0
  n_region=9
  mode_autospawn=0
  autospawn_interval=192.0
  laser_wall_dist=0.0
  laser_ray_length=64.0
  ena_anywall=false
  anywall_half_angle=4096.0
  mode_rayprocess=RP_ClientLike
  mode_oper=0
  mode_confirm=MC_Reset
  ena_debug=false
  ena_dpn_alice=false
  mode_mwheel=MW_modL
  mode_step=2
  mode_texsize=2
  n_layerz=0
  done_layerz=0
  ena_next_dpn_zset=false
  bZSetEditMode=false
  water_forcedodge_timer=0.0
  wforcedodge_ready=false
  InventoryGroup=1
  PickupAmmoCount=9999
  ena_prod=false
  zbar_zmin=-32766.0
  zbar_zmax=32766.0
  zbar_valid=false
  zbar_irrelevant=true
  zbar_rebuild_timer=0.0
  zbar_stray_total=0
  zset_kill_confirm=0
  zset_kill_timer=0.0
  PickupMessage=AreaMap CT scan tool. Enter Q in console for more info. Enter MAPINIT in console to autospawn DPN in premapped spots.
  common_texname=
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
  ena_ams_render=true
  next_layer_id=0
}

// // ================================================================
// // Area map. Texture/align supplier for client renderers.
// // Set group='activate' to allow client weapons to acquire map.
// // Used for collectible intel, with DataStart above 0 to prevent
// // overwriting of client's existing data.
// // LIMITATIONS: 1. SHR_factor is uniform for all textures
// //              2. 63 textures max, 1024x1024 max
// // AUTOEXEC: redefine postbeginplay() to invoke provide_data()
// // Data acquisition performed on clients thru GetPropertyText()
// // ================================================================
// class AreaMapData extends Info abstract;
// #exec texture import file="textures\icon_areamap.bmp" name="icon_areamap" package="linescomm" mips=1 flags=0 btc=-2
// var() byte DataStart;      // from where to copy data, used for discoverable multiple maps
// var() texture MapTex[63];  // payload
// var() int AlignX[63],AlignY[63],AlignZ[63]; // align
// var() byte SHR_factor;     // bitshift factor (pixel to uu scale)
// var() float FloorHeight;   // AreaZ height if other than 128
// var() string NextAMDActor; // further linkage (use group, not name)
// var float dataprovider_timer;
// 
// function tick(float f){
//    dataprovider_timer -= f;
//    if(dataprovider_timer <= 0){
//       if(instr(caps(string(self.group)),"ACTIVATE") != -1) provide_data();
//       dataprovider_timer = 10.0;
//    }
// }
// 
// function provide_data(){
//    local playerpawn pp;
//    self.group = 'sci_areamap';
//    foreach allactors(class'playerpawn',pp) pp.consolecommand("sci_install_areamap");
//    disable('tick');
// }
// 
// function postbeginplay(){
//    dataprovider_timer = 10.0;
//    enable('tick');
// }
// 
// defaultproperties{
//   Texture=texture'icon_areamap'
//   SHR_factor=4
//   DataStart=0
//   FloorHeight=128.0
//   bHidden=true
//   bHiddenEd=false
// }
// 
// 
// // ================================================================
// // Interactive region reactor
// // Usage: execute RenderTexture() on your client.
// // 128 regions max. Spawn more if neccessary.
// // ================================================================
// class AreaReactorData extends Info abstract;
// var() string NextARDActor; // linkage
// 
// function RenderTexture(scriptedtexture tex){
// }
