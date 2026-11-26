class AreaReactor extends Actor;
#exec texture import file="textures\ruler\movreact.pcx" name="movreact" package="scitools" mips=1 flags=2 btc=-2

const MAX_OVERLAY_POINTS = 64; // see aerwpn for limits understanding
var() enum EOverlayKind { OK_Door, OK_Lift } OverlayKind;
var() enum ESnapStep { ST_15deg, ST_30deg, ST_45deg } SnapBy;
var() float   OverlayWidth;
var() float   OverlayHeight;
var() int     MaxPointsUsage;
var() color   PreviewColor;
var() bool    CallAutoDetect;     // unrealed actions
var() bool    CallAutoDetectNocenter; // force W/H before centering
var() bool    CallNewPoints;
var() bool    CallSnapRotation;
var() bool    CallFindMover;
var() actor     FoundMover;           // cached result for drawing link line, also manual-editable
var() bool    EdRenderAsDots;
var vector PreviewPts[MAX_OVERLAY_POINTS];   // cached static random points (runtime source)
var int    PreviewPts_n;                     // actual count
// runtime state (per-tick, non-travel)
//var bool  bOpen;
//var bool  bLocked;              // todo monitor ctl_trig bInitiallyActive or its state
//var vector LiftPos0, LiftPos1;  // KeyPos[0], KeyPos[NumKeys] 
//var vector reattach_loc;       // return to last known autoalign after mover acq

function GetOverlayCorners(out vector corners[4]){
   local vector  half_x, half_y, ax, ay, az;
   GetAxes(rotation, ax, ay, az);
   half_x = ay * OverlayWidth  * 0.5;     // along plane Y
   half_y = az * OverlayHeight * 0.5;     // along plane Z
   corners[0] = location - half_x - half_y;
   corners[1] = location + half_x - half_y;
   corners[2] = location + half_x + half_y;
   corners[3] = location - half_x + half_y;
}

function SnapRotation(){
   local int step;
   local rotator r;
   switch(SnapBy){
     case ST_15deg: step = 2730; break;
     case ST_30deg: step = 5461; break;
     case ST_45deg: step = 8192; break;
   }
   r = rotation;
   r.Yaw   = (r.Yaw   / step) * step;
   r.Pitch = (r.Pitch / step) * step;
   r.Roll  = (r.Roll  / step) * step;
   setrotation(r);
}

function Mover FindNearestMover(float radius){
   local Mover m, best;
   local float d, bd;
   bd = radius;
   foreach AllActors(class'Mover', m){
      d = vsize(m.Location - Location);
      if(d <= bd){ bd = d; best = m; }
   }
   return best;
}

function DrawEditorSelection(Canvas C){
   local vector corners[4];
   local byte i;
   local vector ax, ay, az;
   local float  len, t;

   GetAxes(rotation, ax, ay, az);
   len = 192.0;
   for(t = -len; t < len; t += 32.0) if(((t + len) / 16.0) % 2 == 0){       // rotation helpers
      c.draw3dline(previewcolor, location + ax*t + ay*1.5 + az*1.5, location + ax*(t+16) + ay*1.5 + az*1.5);
      c.draw3dline(previewcolor, location + ax*t + ay*1.5 - az*1.5, location + ax*(t+16) + ay*1.5 - az*1.5);
      c.draw3dline(previewcolor, location + ax*t - ay*1.5 + az*1.5, location + ax*(t+16) - ay*1.5 + az*1.5);
      c.draw3dline(previewcolor, location + ax*t - ay*1.5 - az*1.5, location + ax*(t+16) - ay*1.5 - az*1.5);
   }
   if(CallAutoDetect){         CallAutoDetect         = false; AutoDetect(true);  } // rebuild surface
   if(CallAutoDetectNocenter){ CallAutoDetectNocenter = false; AutoDetect(false); }
   if(CallNewPoints){          CallNewPoints          = false; PreviewPts_n = 0;  } // reroll points
   if(CallSnapRotation){       CallSnapRotation       = false; SnapRotation();    } // resnap rotation
   if(CallFindMover){          CallFindMover          = false; FoundMover = FindNearestMover(256.0); }
   GetOverlayCorners(corners);
   for(i=0; i<4; i++){
      if(!EdRenderAsDots) c.Draw3dLine(PreviewColor, corners[i], corners[(i+1)%4]);   // surface bounds
      c.Draw3dLine(PreviewColor, corners[i] - ax*16.0, corners[i] + ax*16.0);         // align helpers
   }
   if(foundmover != none){
      c.draw3dline(PreviewColor, corners[0] + vect(32,32,32), foundmover.location);
      c.draw3dline(PreviewColor, corners[0] + vect(34,34,34), foundmover.location + vect(2,2,2));
      DrawArrowHead(c, corners[0] + vect(32,32,32), foundmover.location,               48.0, 8.0, PreviewColor);
      DrawArrowHead(c, corners[0] + vect(34,34,34), foundmover.location + vect(2,2,2), 48.0, 8.0, PreviewColor);
   }

   if(EdRenderAsDots) DrawPoissonPoints(C);
    else              DrawDiagonalGrid(C);
}  

function float TraceBspOnly(vector dir, float maxdist){
   local vector start, hitloc, hitnorm;
   local actor  ha;
   start = location;
   for(;;){
      ha = Trace(hitloc, hitnorm, start + dir * maxdist, start, true);
      if(ha == none) return maxdist;
      if(ha == Level || ha.IsA('Brush') || ha.bIsMover || ha.bStatic)
         return vsize(hitloc - location);
      start = hitloc + dir * 4.0;
   }
}

function AutoDetect(bool bAfterCenter){
   local vector ax, ay, az, center;
   local float  dy_p, dy_m, dz_p, dz_m;
   GetAxes(rotation, ax, ay, az);
   dy_p = TraceBspOnly( ay, 2048.0);    // width +
   dy_m = TraceBspOnly(-ay, 2048.0);    // width -
   dz_p = TraceBspOnly( az, 2048.0);    // height +
   dz_m = TraceBspOnly(-az, 2048.0);    // height -
   if(abs(OverlayWidth  - (dy_p + dy_m)) <= 1.0 &&     // hysteresis if already centered within 1uu
      abs(OverlayHeight - (dz_p + dz_m)) <= 1.0 &&
      abs(dy_p - dy_m) <= 1.0 && abs(dz_p - dz_m) <= 1.0) return;
   center = location + ay * (dy_p - dy_m) * 0.5  + az * (dz_p - dz_m) * 0.5;
   SetLocation(center); // recenter
   if(bAfterCenter){
      dy_p = TraceBspOnly( ay, 2048.0);    // trace again for correct overlay
      dy_m = TraceBspOnly(-ay, 2048.0);
      dz_p = TraceBspOnly( az, 2048.0);
      dz_m = TraceBspOnly(-az, 2048.0);
   }
   OverlayWidth  = dy_p + dy_m;
   OverlayHeight = dz_p + dz_m;
   if(OverlayWidth  < 16.0) OverlayWidth  = 16.0;
   if(OverlayHeight < 16.0) OverlayHeight = 16.0;
   PreviewPts_n = 0;
}

function DrawPoissonPoints(Canvas C){
   local vector axis_x, axis_y, /*axis_z,*/ ax, ay, az;
   local vector candidate;
   local float  min_dist, area, target_area;
   local int    i, j, attempt, n, want;
   local bool   ok;
   local vector p0, p1, p2, p3;   // point corners
   
   GetAxes(rotation, ax, ay, az);
   axis_x = ay;   // width axis
   axis_y = az;   // height axis

   if(PreviewPts_n <= 0){            // generate only once, leave dots static after
      want = MaxPointsUsage;
      want = clamp(want, 16, MAX_OVERLAY_POINTS);
      area        = OverlayWidth * OverlayHeight; // min dist from requested density
      target_area = area / want;
      min_dist    = sqrt(target_area) * 0.7;
      n = 0;
      for(attempt=0; attempt<MAX_OVERLAY_POINTS*8 && n<want; attempt++){
         candidate = location
                   + axis_x * (FRand() * OverlayWidth  - OverlayWidth  * 0.5)
                   + axis_y * (FRand() * OverlayHeight - OverlayHeight * 0.5);
         ok = true;
         for(j=0; j<n; j++){  if(vsize(candidate - PreviewPts[j]) < min_dist){ ok = false; break; }  }
         if(ok){     PreviewPts[n] = candidate; n++;  }
      }
      PreviewPts_n = n;
   }
   for(i=0; i<PreviewPts_n; i++){
        p0 = PreviewPts[i] - axis_x - axis_y;
        p1 = PreviewPts[i] + axis_x - axis_y; C.Draw3dLine(PreviewColor, p0, p1);
        p2 = PreviewPts[i] + axis_x + axis_y; C.Draw3dLine(PreviewColor, p1, p2);
        p3 = PreviewPts[i] - axis_x + axis_y; C.Draw3dLine(PreviewColor, p2, p3);
                                              C.Draw3dLine(PreviewColor, p3, p0);
    }
}

function DrawArrowHead(canvas c, vector Start, vector End, float ArrowLength, float ArrowRadius, color LineColor){
    local vector Dir, Side1, Side2, BasePoint;
    local vector Tip[3],wdir;
    local int i;
    local float Angle;

    Dir = Normal(End - Start);
    if (VSize(End - Start) <= 1.0) return;

    wdir = (Abs(Dir.Z) < 0.99) ? vect(0, 0, 1) : vect(1, 0, 0);
    Side1 = Normal(Dir cross wdir );
    Side2 = Normal(Dir cross Side1);
    BasePoint = End - (Dir * ArrowLength);

    for (i = 0; i < 3; i++){
        Angle = i * 2.0943951; // 2 * PI / 3
        Tip[i] = BasePoint + (Side1 * Cos(Angle) + Side2 * Sin(Angle)) * ArrowRadius;
        c.Draw3DLine(LineColor, End, Tip[i]);
    }
    c.Draw3DLine(LineColor, Tip[0], Tip[1]);    // link arrowhead into pyramid
    c.Draw3DLine(LineColor, Tip[1], Tip[2]);
    c.Draw3DLine(LineColor, Tip[2], Tip[0]);
}

function DrawDiagonalGrid(Canvas C){
   local vector axis_x, axis_y, axis_z;
   local vector p1, p2;
   local float  u0, u1, v0, v1;
   local float  s0, s1, step, s;
   local float  t_min, t_max;
   local float  ua, va, ub, vb;
   GetAxes(rotation, axis_x, axis_y, axis_z);
   axis_x = axis_y;   // width axis
   axis_y = axis_z;   // height axis
   axis_z = vect(0,0,0);
   u0 = -OverlayWidth  * 0.5;  u1 = OverlayWidth  * 0.5;
   v0 = -OverlayHeight * 0.5;  v1 = OverlayHeight * 0.5;
   step = 16.0;
   s0 = u0 + v0;          // ---- family 1: +45 degrees, line u + v = s, direction (+1,-1) ----
   s1 = u1 + v1;
   for(s=s0; s<=s1; s+=step){
      // point on line: u=u0 -> v=s-u0
      if(!ClipLineRect2D(u0, s - u0, 1.0, -1.0, u0, u1, v0, v1, t_min, t_max)) continue;
      ua = u0 + t_min*1.0;  va = (s - u0) + t_min*(-1.0);
      ub = u0 + t_max*1.0;  vb = (s - u0) + t_max*(-1.0);
      p1 = location + axis_x * ua + axis_y * va;
      p2 = location + axis_x * ub + axis_y * vb;
      C.Draw3dLine(PreviewColor, p1, p2);
   }
   s0 = u0 - v1;         // ---- family 2: -45 degrees, line u - v = s, direction (+1,+1) ----
   s1 = u1 - v0;
   for(s=s0; s<=s1; s+=step){
      // point on line: u=u0 -> v=u0-s
      if(!ClipLineRect2D(u0, u0 - s, 1.0, 1.0, u0, u1, v0, v1, t_min, t_max)) continue;
      ua = u0 + t_min*1.0;  va = (u0 - s) + t_min*1.0;
      ub = u0 + t_max*1.0;  vb = (u0 - s) + t_max*1.0;
      p1 = location + axis_x * ua + axis_y * va;
      p2 = location + axis_x * ub + axis_y * vb;
      C.Draw3dLine(PreviewColor, p1, p2);
   }
}

// ============================================================
// Clip infinite 2D line (u,v) = P0 + t*D to rectangle [u0..u1]x[v0..v1].
// Returns false if no intersection. Outputs t_min and t_max.
// ============================================================
function bool ClipLineRect2D(float p0u, float p0v, float du, float dv,
                             float u0, float u1, float v0, float v1,
                             out float t_min, out float t_max){
   local float t1, t2, tmp;
   t_min = -1000000.0;
   t_max =  1000000.0;
   if(du == 0.0){                                   // u axis slab
      if(p0u < u0 || p0u > u1) return false;
   }else{
      t1 = (u0 - p0u) / du;
      t2 = (u1 - p0u) / du;
      if(t1 > t2){ tmp = t1; t1 = t2; t2 = tmp; }
      if(t1 > t_min) t_min = t1;
      if(t2 < t_max) t_max = t2;
   }
   if(dv == 0.0){                                     // v axis slab
      if(p0v < v0 || p0v > v1) return false;
   }else{
      t1 = (v0 - p0v) / dv;
      t2 = (v1 - p0v) / dv;
      if(t1 > t2){ tmp = t1; t1 = t2; t2 = tmp; }
      if(t1 > t_min) t_min = t1;
      if(t2 < t_max) t_max = t2;
   }
   if(t_min > t_max) return false;
   return true;
}

defaultproperties{
  SnapBy=ST_15deg
  OverlayKind=OK_Door
  OverlayWidth=128.0
  OverlayHeight=128.0
  FoundMover=None
  MaxPointsUsage=64
  PreviewColor=(R=200,G=255,B=200,A=0)
  bHidden=True
  bCollideActors=False
  bBlockActors=False
  bBlockPlayers=False
  bCollideWhenPlacing=true
  CollisionHeight=32.0
  CollisionRadius=32.0
  EdRenderAsDots=false
  CallNewPoints=false
  CallAutoDetect=false
  CallAutoDetectNocenter=false
  CallSnapRotation=false
  CallFindMover=false
  bEditorSelectRender=true
  Texture=texture'scitools.movreact'
}
