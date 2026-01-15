//====================================================================
// Unrealed ruler. Shows integer dist to a_TFS_Ruler_dest actor
// SpecifyDest - accepts Object.Name value of Dest, or auto-use any
// ScreenDir   - side where to project lcd (T, F or S)
// LSB16 LSB64 - lower sensing resolution, set above 0 to trigger
// LSB state can't be updated in Actor properties window
//====================================================================
class a_TFS_Ruler extends actor;       // Arleen Lasleur, 2024-05-26
var() color RulerScreenColor,RulerLinkColor;
var() byte ScreenDir;
var() string ScreenDirDesc;
var() bool UseAnyDest;
var() name SpecifyDest;
var() byte LSB16,LSB64_override,LSB_Reset;  // 64_override because it have priority over 16
var() float xActualDist;

#exec texture import file="textures\ruler\tfsruler16.png" name="tfsruler16" package="scitools" mips=1 flags=0 btc=-2
#exec texture import file="textures\ruler\tfsruler64.png" name="tfsruler64" package="scitools" mips=1 flags=0 btc=-2
#exec texture import file="textures\ruler\tfsrulerfree.png" name="tfsrulerfree" package="scitools" mips=1 flags=0 btc=-2

event draweditorselection(canvas c){
        local byte i;
        local vector sl,                    // screen location
                     off_r,  off_d, offn_r, // offset to right, to down, to right for next digit
                     mls, mld,              // markers
                     sonr,offdd,            // repeated calcs
                     lsb_m;                 // LSB insufficiency monitor total length
        local bool sa,sb,sc,sd,se,sf,sg;    // lcd segments
        local byte sn[5];                   // screen digits parsed byte
        local float snf,                    // screen digits raw float
                    lsb_i;                  // LSB insufficiency divide factor
        local a_TFS_Ruler_dest dest;        // end of ruler
        if(!UseAnyDest){
           if(SpecifyDest!='' && SpecifyDest!=none) dest = search_user_dest(SpecifyDest);
        }else
           dest = search_any_dest();
        if(dest != none){
           dest.LastKnownReceiver = self.name;
           mld = dest.location - vect(-128,128,128);
           c.draw3dline(RulerScreenColor, dest.location, mld);  
           c.draw3dline(RulerScreenColor, mld + vect(-16,32,32), mld);
           c.draw3dline(RulerScreenColor, mld + vect(-32,16,32), mld);
           c.draw3dline(RulerScreenColor, mld + vect(-32,32,16), mld);
           c.draw3dline(RulerLinkColor,   location, dest.location);
        }

        sl  = location + vect(16,16,16);     // screen zero point

        if((ScreenDir>0 && ScreenDir<=4)  || ScreenDir<=85){ /* offsets calculator */  // T
            off_r = vect(64,0,0);  offn_r = vect(96,0,0);  off_d = vect(0,64,0);  }
        if((ScreenDir>4 && ScreenDir<=8)  || (ScreenDir>85 && ScreenDir<=170)){        // F
            off_r = vect(64,0,0);  offn_r = vect(96,0,0);  off_d = vect(0,0,-64); }
        if((ScreenDir>8 && ScreenDir<=12) || ScreenDir>170){                           // S
            off_r = vect(0,64,0);  offn_r = vect(0,96,0);  off_d = vect(0,0,-64); }
        offdd = off_d*2;
        lsb_m =(offn_r*4)+off_r;
        c.draw3dline(RulerScreenColor, sl+offdd+off_d/4, sl+lsb_m+offdd+(off_d/4)); // underline

        if(LSB_Reset      > 0){ texture = texture'tfsrulerfree'; LSB16 = 0; LSB64_override = 0; LSB_Reset = 0; }
        if(LSB64_override > 0){ texture = texture'tfsruler64';   LSB16 = 0; }
        if(LSB16          > 0){ texture = texture'tfsruler16';   LSB64_override = 0; }

        mls = location - vect(128,128,128);
        c.draw3dline(RulerScreenColor, location, /* marker */ mls);
        c.draw3dline(RulerScreenColor, mls + vect(16,32,32), mls);
        c.draw3dline(RulerScreenColor, mls + vect(32,16,32), mls);
        c.draw3dline(RulerScreenColor, mls + vect(32,32,16), mls);

        if(dest == none) return;

        snf = vsize(mls - mld);
        xActualDist = snf;
        if(LSB16)         { lsb_i = snf%16; snf -= lsb_i; lsb_i = 16/lsb_i; }
        if(LSB64_override){ lsb_i = snf%64; snf -= lsb_i; lsb_i = 64/lsb_i; }
        if(LSB16 || LSB64_override){
            lsb_m /= lsb_i;
            c.draw3dline(RulerLinkColor, sl+offdd+off_d/4.7, sl+lsb_m+offdd+(off_d/4.7)); // LSBI meter
        }

        sn[0] = byte (snf/10000); snf -= sn[0]*10000;
        sn[1] = byte (snf/1000);  snf -= sn[1]*1000;
        sn[2] = byte (snf/100);   snf -= sn[2]*100;
        sn[3] = byte (snf/10);    snf -= sn[3]*10;
        sn[4] = byte (snf);
        
        for(i=0;i<5;i++){
            sa = true;  if(sn[i]==1 || sn[i]==4            ) sa = false; //  **a*
            sb = true;  if(sn[i]==5 || sn[i]==6            ) sb = false; // f    *
            sc = true;  if(sn[i]==2                        ) sc = false; // *    b
            sd = true;  if(sn[i]==1 || sn[i]==4 || sn[i]==7) sd = false; //  **g*
            se = false; if(sn[i]!=4 && sn[i]%2==0          ) se = true;  // e    *
            sf = true; if((sn[i]>=1 && sn[i]<=3)|| sn[i]==7) sf = false; // *    c
            sg = true;  if(sn[i]==0 || sn[i]==1 || sn[i]==7) sg = false; //  **d*
            sonr  = sl+offn_r*i;                //from     r?    d?   where    r?    d?
            if(sa) c.draw3dline(RulerScreenColor, sonr,               sonr  +off_r);       // a
            if(sb) c.draw3dline(RulerScreenColor, sonr  +off_r,       sonr  +off_r+off_d); // b
            if(sc) c.draw3dline(RulerScreenColor, sonr  +off_r+off_d, sonr  +off_r+offdd); // c
            if(sd) c.draw3dline(RulerScreenColor, sonr        +offdd, sonr  +off_r+offdd); // d
            if(se) c.draw3dline(RulerScreenColor, sonr        +off_d, sonr        +offdd); // e
            if(sf) c.draw3dline(RulerScreenColor, sonr,               sonr        +off_d); // f
            if(sg) c.draw3dline(RulerScreenColor, sonr        +off_d, sonr  +off_r+off_d); // g
        } 
}

function a_TFS_Ruler_dest search_any_dest(){
    local a_TFS_Ruler_dest atrd;
    foreach allactors(class'a_TFS_Ruler_dest',atrd) return atrd;
    return none;
}
function a_TFS_Ruler_dest search_user_dest(name targdest){
    local a_TFS_Ruler_dest atrd;
    foreach allactors(class'a_TFS_Ruler_dest',atrd) if(atrd.name==targdest) return atrd;
    return none;
}

defaultproperties{
     LSB16=1
     LSB64_override=0
     LSB_Reset=0
     bDirectional=false
     bEditorSelectRender=true
     RulerScreenColor=(R=241,G=241,B=42,A=255)
     RulerLinkColor=(R=40,G=255,B=30,A=255)
     ScreenDirDesc=4: T, 8: F, 12: S;     <<: T     86-170: F     >>: S   mousewheel/click
     ScreenDir=0
     UseAnyDest=true
     SpecifyDest=None
     Texture=texture'tfsrulerfree'
     DrawScale=0.5
}