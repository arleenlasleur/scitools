class pawnstatemonitor expands weapon;
var float lasttick;

function tick(float f){
  if(level.timeseconds - lasttick < 5.0) return;
  lasttick = level.timeseconds;
  ammotype.ammoamount = 10000;
}

function postrender(canvas c){
  local playerpawn p;
  p = playerpawn(owner);
  if(p == none) return;
  c.setpos(10, 10); c.drawtext("General");

  c.setpos(10, 30); c.drawtext("bBehindView:");
  c.setpos(10, 40); c.drawtext("bIsPlayer:");
  c.setpos(10, 50); c.drawtext("bJustLanded:");
  c.setpos(10, 60); c.drawtext("bUpAndOut:");
  c.setpos(10, 70); c.drawtext("bIsWalking:");
  c.setpos(10, 80); c.drawtext("bWarping:");
  c.setpos(10, 90); c.drawtext("bUpdatingDisplay:");
  c.setpos(10,100); c.drawtext("bPostRender2D:");
  c.setpos(10,110); c.drawtext("bShovePawns:");
  c.setpos(10,120); c.drawtext("bCanJump:");
  c.setpos(10,130); c.drawtext("bCanWalk:");
  c.setpos(10,140); c.drawtext("bCanSwim:");
  c.setpos(10,150); c.drawtext("bCanFly:");
  c.setpos(10,160); c.drawtext("bCanOpenDoors:");
  c.setpos(10,170); c.drawtext("bCanDoSpecial:");
  c.setpos(10,180); c.drawtext("bDrowning:");
  c.setpos(10,190); c.drawtext("bFromWall:");
  c.setpos(10,200); c.drawtext("bJumpOffPawn:");
  c.setpos(10,210); c.drawtext("bShootSpecial:");
  c.setpos(10,220); c.drawtext("bAutoActivate:");
  c.setpos(10,230); c.drawtext("bIsHuman:");
  c.setpos(10,240); c.drawtext("bIsFemale:");
  c.setpos(10,250); c.drawtext("bIsMultiSkinned:");
  c.setpos(10,260); c.drawtext("bCountJumps:");
  c.setpos(140, 30); c.drawtext(p.bBehindView);
  c.setpos(140, 40); c.drawtext(p.bIsPlayer);
  c.setpos(140, 50); c.drawtext(p.bJustLanded);
  c.setpos(140, 60); c.drawtext(p.bUpAndOut);
  c.setpos(140, 70); c.drawtext(p.bIsWalking);
  c.setpos(140, 80); c.drawtext(p.bWarping);
  c.setpos(140, 90); c.drawtext(p.bUpdatingDisplay);
  c.setpos(140,100); c.drawtext(p.bPostRender2D);
  c.setpos(140,110); c.drawtext(p.bShovePawns);
  c.setpos(140,120); c.drawtext(p.bCanJump);
  c.setpos(140,130); c.drawtext(p.bCanWalk);
  c.setpos(140,140); c.drawtext(p.bCanSwim);
  c.setpos(140,150); c.drawtext(p.bCanFly);
  c.setpos(140,160); c.drawtext(p.bCanOpenDoors);
  c.setpos(140,170); c.drawtext(p.bCanDoSpecial);
  c.setpos(140,180); c.drawtext(p.bDrowning);
  c.setpos(140,190); c.drawtext(p.bFromWall);
  c.setpos(140,200); c.drawtext(p.bJumpOffPawn);
  c.setpos(140,210); c.drawtext(p.bShootSpecial);
  c.setpos(140,220); c.drawtext(p.bAutoActivate);
  c.setpos(140,230); c.drawtext(p.bIsHuman);
  c.setpos(140,240); c.drawtext(p.bIsFemale);
  c.setpos(140,250); c.drawtext(p.bIsMultiSkinned);
  c.setpos(140,260); c.drawtext(p.bCountJumps);

  c.setpos(10,280); c.drawtext("Input");

  c.setpos(10,300); c.drawtext("bZoom:");
  c.setpos(10,310); c.drawtext("bRun:");
  c.setpos(10,320); c.drawtext("bLook:");
  c.setpos(10,330); c.drawtext("bDuck:");
  c.setpos(10,340); c.drawtext("bSnapLevel:");
  c.setpos(10,350); c.drawtext("bStrafe:");
  c.setpos(10,360); c.drawtext("bFire:");
  c.setpos(10,370); c.drawtext("bAltFire:");
  c.setpos(10,380); c.drawtext("bFreeLook:");
  c.setpos(10,390); c.drawtext("bExtra0:");
  c.setpos(10,400); c.drawtext("bExtra1:");
  c.setpos(10,410); c.drawtext("bExtra2:");
  c.setpos(10,420); c.drawtext("bExtra3:");
  c.setpos(140,300); c.drawtext(p.bZoom);
  c.setpos(140,310); c.drawtext(p.bRun);
  c.setpos(140,320); c.drawtext(p.bLook);
  c.setpos(140,330); c.drawtext(p.bDuck);
  c.setpos(140,340); c.drawtext(p.bSnapLevel);
  c.setpos(140,350); c.drawtext(p.bStrafe);
  c.setpos(140,360); c.drawtext(p.bFire);
  c.setpos(140,370); c.drawtext(p.bAltFire);
  c.setpos(140,380); c.drawtext(p.bFreeLook);
  c.setpos(140,390); c.drawtext(p.bExtra0);
  c.setpos(140,400); c.drawtext(p.bExtra1);
  c.setpos(140,410); c.drawtext(p.bExtra2);
  c.setpos(140,420); c.drawtext(p.bExtra3);

  c.setpos(10,440); c.drawtext("Player");

  c.setpos(10,460); c.drawtext("Weapon:");
  c.setpos(10,470); c.drawtext("PendingWeapon:");
  c.setpos(10,480); c.drawtext("SelectedItem:");
  c.setpos(140,460); c.drawtext(p.Weapon);
  c.setpos(140,470); c.drawtext(p.PendingWeapon);
  c.setpos(140,480); c.drawtext(p.SelectedItem);

  // ----------------------------------------------------------------------------

  c.setpos(230, 10); c.drawtext("Stats");

  c.setpos(230, 30); c.drawtext("DieCount:");
  c.setpos(230, 40); c.drawtext("ItemCount:");
  c.setpos(230, 50); c.drawtext("KillCount:");
  c.setpos(230, 60); c.drawtext("SecretCount:");
  c.setpos(230, 70); c.drawtext("Spree:");
  c.setpos(230, 80); c.drawtext("Health:");
  c.setpos(360, 30); c.drawtext(p.DieCount);
  c.setpos(360, 40); c.drawtext(p.ItemCount);
  c.setpos(360, 50); c.drawtext(p.KillCount);
  c.setpos(360, 60); c.drawtext(p.SecretCount);
  c.setpos(360, 70); c.drawtext(p.Spree);
  c.setpos(360, 80); c.drawtext(p.Health);

  c.setpos(230, 100); c.drawtext("Timers");

  c.setpos(230, 120); c.drawtext("SightCounter:");
  c.setpos(230, 130); c.drawtext("PainTime:");
  c.setpos(230, 140); c.drawtext("SpeechTime:");
  c.setpos(230, 150); c.drawtext("MoveTimer:");
  c.setpos(360, 120); c.drawtext(p.SightCounter);
  c.setpos(360, 130); c.drawtext(p.PainTime);
  c.setpos(360, 140); c.drawtext(p.SpeechTime);
  c.setpos(360, 150); c.drawtext(p.MoveTimer);

  c.setpos(230, 170); c.drawtext("Speeds");

  c.setpos(230, 190); c.drawtext("GroundSpeed:");
  c.setpos(230, 200); c.drawtext("WaterSpeed:");
  c.setpos(230, 210); c.drawtext("AirSpeed:");
  c.setpos(230, 220); c.drawtext("AccelRate:");
  c.setpos(230, 230); c.drawtext("JumpZ:");
  c.setpos(230, 240); c.drawtext("MaxStepHeight:");
  c.setpos(230, 250); c.drawtext("AirControl:");
  c.setpos(230, 260); c.drawtext("WalkingPct:");
  c.setpos(230, 270); c.drawtext("ShoveCollisionRadius:");
  c.setpos(230, 280); c.drawtext("PhysicsAnim:");
  c.setpos(400, 190); c.drawtext(p.GroundSpeed);
  c.setpos(400, 200); c.drawtext(p.WaterSpeed);
  c.setpos(400, 210); c.drawtext(p.AirSpeed);
  c.setpos(400, 220); c.drawtext(p.AccelRate);
  c.setpos(400, 230); c.drawtext(p.JumpZ);
  c.setpos(400, 240); c.drawtext(p.MaxStepHeight);
  c.setpos(400, 250); c.drawtext(p.AirControl);
  c.setpos(400, 260); c.drawtext(p.WalkingPct);
  c.setpos(400, 270); c.drawtext(p.ShoveCollisionRadius);
  c.setpos(400, 280); c.drawtext(p.PhysicsAnim);

}

defaultproperties{
  inventorygroup=1
  ammoname=Class'UnrealShare.ASMDAmmo'
  pickupammocount=10000
  bcanthrow=false
  pickupviewmesh=LodMesh'UnrealShare.ASMDPick'
  mesh=LodMesh'UnrealShare.ASMDPick'
}



/*

// lip synching stuff, idea from Deus Ex - only implemented in ALAudio.
var bool bIsSpeaking);           // are we speaking now
var bool bWasSpeaking);          // were we speaking last frame?  (should we close our mouth?)
var string lastPhoneme); // phoneme last spoken
var string nextPhoneme); // phoneme to speak next


// Navigation AI
var     Actor           MoveTarget);             // set by movement natives
var             Actor           FaceTarget);             // set by strafefacing native
var             vector          Destination);    // set by Movement natives
var             vector          Focus);                  // set by Movement natives
var             float           DesiredSpeed);
var             float           MaxDesiredSpeed);
var             vector          MovementStart);


var()   byte            Visibility);       //How visible is the pawn? 0 = invisible.
var             Texture         GroundTexture);

// Movement.
var norepnotify rotator ViewRotation);   // View rotation.
var norepnotify float EyeHeight);                // Current eye height, adjusted for bobbing and stairs.

// View
var float               OrthoZoom);       // Orthogonal/map view zoom factor.
var() float       FovAngle);       // X field of view angle in degrees, usually 90.


var(Orders) name AlarmTag); // tag of object to go to when see player
var(Orders) name SharedAlarmTag);
var     Decoration      carriedDecoration);


var() float BeaconOffset);                       // PostRender2D positioning height (CollisionHeight*BeaconOffset).
var() float MaxFrobDistance);            // Max distance frob checks are being done.
var transient Actor FrobTarget);

var PointRegion FootRegion);
var PointRegion HeadRegion);

=========================================

var const player Player;
var     globalconfig string Password;   // for restarting coop savegames

var     travel    float DodgeClickTimer;
var(Movement) globalconfig float        DodgeClickTime; // max double click interval for dodge move
var(Movement) globalconfig float Bob;
var float bobtime;

// Camera info.
var transient int ShowFlags;
var transient int RendMap;
var transient int Misc1;
var transient int Misc2;

var actor ViewTarget;
var vector FlashScale, FlashFog;
var vector CurrentFlashFog; // Used because FlashFog gets reset if under a threshold.
var HUD myHUD;
var ScoreBoard Scoring;
var class<hud> HUDType;
var class<scoreboard> ScoringType;

var float DesiredFlashScale, ConstantGlowScale, InstantFlash;
var vector DesiredFlashFog, ConstantGlowFog, InstantFog;
var float DesiredFOV;
var float DefaultFOV;

// Music info.
var music Song;
var byte  SongSection;
var byte  CdTrack;
var EMusicTransition Transition;

var float shaketimer; // player uses this for shaking view
var int shakemag;       // max magnitude in degrees of shaking
var float shakevert; // max vertical shake magnitude
var float maxshake;
var float verttimer;
var(Pawn) class<carcass> CarcassType;
var travel globalconfig float MyAutoAim;
var travel globalconfig float Handedness;
var(Sounds) sound JumpSound;

var globalconfig float MainFOV;
var float               ZoomLevel;

var class<menu> SpecialMenu;
var string DelayedCommand;
var globalconfig float  MouseSensitivity;

var globalconfig name   WeaponPriority[30]; //weapon class priorities (9 is highest)

var globalconfig int NetSpeed, LanSpeed;
var float SmoothMouseX, SmoothMouseY, KbdAccel;
var() globalconfig float MouseSmoothThreshold;

// Unreal 227 additions
var PointRegion CameraRegion; // Player camera location
var(Collision) float CrouchHeightPct;
var transient float CrouchCheckTime; // Unused, preserved for backward compatibility
var float SpecialCollisionHeight; // User-defined normal (non-reduced) CollisionHeight for this player (unused if non-positive)
var float PrePivotZModifier; // Additional Z-offset applied to ScaledDefaultPrePivot().Z when calculating normal PrePivot.Z for this player
var transient float AccumulatedHTurn, AccumulatedVTurn; // Discarded fractional parts of horizontal (Yaw) and vertical (Pitch) turns
var transient plane DistanceFogColor, // Client distance fog color.
                DistanceFogBlend;
var transient float DistanceFogDistance[2], // Client distance fog render distance.
                DistanceFogStart[2],
                DistanceFogBlendTimer[2];
var transient ZoneInfo DistanceFogOld; // Tracking camera zonechanges.
var transient float FogDensity; // Client FogDensity. For exponential fog.
var transient int FogMode; // 0 = Linear, 1 = Exponential, 2 = Exponential 2
var PortalModifier CameraModifier; // Allow modders to modify camera (overrides ZoneInfo.CameraModifier).
var PlayerInteraction LocalInteractions; // User interactions to override this player.

// Input axes.
var input float
aBaseX, aBaseY, aBaseZ,
aMouseX, aMouseY,
aForward, aTurn, aStrafe, aUp,
aLookUp, aExtra4, aExtra3, aExtra2,
aExtra1, aExtra0;

// Move Buffering.
var transient SavedMove SavedMoves;
var transient SavedMove FreeMoves;
var float CurrentTimeStamp;
var float LastUpdateTime;
var float ServerTimeStamp;
var float TimeMargin;
var float MaxTimeMargin;

// Progess Indicator.
var string ProgressMessage[5];
var color ProgressColor[5];
var float ProgressTimeOut;

// Localized strings
var localized string QuickSaveString;
var localized string NoPauseMessage;
var localized string ViewingFrom;
var localized string OwnCamera;
var localized string FailedView;
var localized string CantChangeNameMsg;

// Remote Pawn ViewTargets
var transient norepnotify rotator TargetViewRotation;
var transient norepnotify float TargetEyeHeight;
var transient norepnotify vector TargetWeaponViewOffset;

// CameraLocation
var transient const vector CalcCameraLocation;
var transient const rotator CalcCameraRotation;
var transient const Actor CalcCameraActor;

var ClientReplicationInfo ClientReplicationInfo;
var PlayerAffectorInfo FirstPlayerAffector;
var CustomPlayerStateInfo CustomPlayerStateInfo;
var RealCrouchInfo RealCrouchInfo;
var LadderTrigger ActiveLadder;
var bool bNetworkIncompability; // ClientReplicationInfo is unable to be networked to client!

// Player control flags
var bool                bAdmin;
var() globalconfig bool                 bLookUpStairs;  // look up/down stairs (player)
var() globalconfig bool         bSnapToLevel;   // Snap to level eyeheight when not mouselooking
var() globalconfig bool         bAlwaysMouseLook;
var globalconfig bool           bKeyboardLook;  // no snapping when true
var bool                bWasForward;    // used for dodge move
var bool                bWasBack;
var bool                bWasLeft;
var bool                bWasRight;
var bool                bEdgeForward;
var bool                bEdgeBack;
var bool                bEdgeLeft;
var bool                bEdgeRight;
var bool                bIsCrouching;
var     bool            bShakeDir;
var bool                bAnimTransition;
var bool                bIsTurning;
var bool                bFrozen;
var globalconfig bool   bInvertMouse;
var bool                bShowScores;
var bool                bShowMenu;
var bool                bSpecialMenu;
var bool                bWokeUp;
var bool                bPressedJump;
var bool                bUpdatePosition;
var bool                bDelayedCommand;
var bool                bRising;
var bool                bReducedVis;
var bool                bCenterView;
var() globalconfig bool bMaxMouseSmoothing;
var bool                bMouseZeroed;
var bool                bReadyToPlay;
var globalconfig bool bNoFlash;
var globalconfig bool bNoVoices;
var globalconfig bool bMessageBeep;
var bool                bZooming;
var() nowarn bool bSinglePlayer;
var bool                bJustFired;
var bool                bJustAltFired;
var bool                bIsTyping;
var bool                bFixedCamera;
var globalconfig bool bMouseSmoothing;

// 227 flags:
var globalconfig bool bNeverAutoSwitch;
var bool bIgnoreMusicChange,bIsReducedCrouch;
var bool bCanChangeBehindView;
var transient bool bConsoleCommandMessage;
var const bool bIsSpectatorClass;


*/
