class STLaser extends PathNodeRuntime;
//  #exec mesh import mesh="dpn_angle" anivfile="Models\dpn_angle_a.3d" datafile="Models\dpn_angle_d.3d" x=0 y=0 z=0 mlod=0
//  #exec mesh origin mesh="dpn_angle" x=0 y=0 z=0
//  #exec mesh sequence mesh="dpn_angle" seq=All startframe=0 numframes=1
//  #exec meshmap new meshmap="dpn_angle" mesh="dpn_angle"
//  #exec meshmap scale meshmap="dpn_angle" x=0.23460 y=0.23460 z=0.46921

defaultproperties{
   ScaleGlow=3.0
   DrawType=DT_Sprite
// DrawType=DT_Mesh
   DrawScale=0.3
// DrawScale=1.0
   bUnlit=True
   bNoSmooth=True
   LODBias=0.0

//     Mesh=Mesh'dpn_angle'             // meshlaser related
//     bCollideWhenPlacing=false
//     bCollideActors=false
//     bCollideWorld=false
//     bBlockActors=false
//     bBlockPlayers=false
//  //  CollisionRadius=240.00000
//  //  CollisionRadius=0.50000
//  //  CollisionHeight=0.50000
//     MultiSkins(0)=Texture'scinoblk'
}
