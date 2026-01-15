class a_TFS_Ruler_dest extends actor;
var color atrd_mc;
var name LastKnownReceiver;
#exec texture import file="textures\ruler\tfsrulertip.png" name="tfsrulertip" package="scitools" mips=1 flags=2 btc=-2

event draweditorselection(canvas c){
    local a_TFS_Ruler FoundReceiver;
    local vector mld;
    if(LastKnownReceiver!=none && LastKnownReceiver!='')
        FoundReceiver = search_ruler(LastKnownReceiver);
    if(FoundReceiver!=none){
        FoundReceiver.draweditorselection(c);
        return;
    }
    mld = location - vect(-128,128,128);
    c.draw3dline(atrd_mc, location, mld);  
    c.draw3dline(atrd_mc, mld + vect(-16,32,32), mld);
    c.draw3dline(atrd_mc, mld + vect(-32,16,32), mld);
    c.draw3dline(atrd_mc, mld + vect(-32,32,16), mld);
}
function a_TFS_Ruler search_ruler(name targ){
    local a_TFS_Ruler atrr;
    foreach allactors(class'a_TFS_Ruler',atrr) if(atrr.name==targ) return atrr;
    return none;
}

defaultproperties{
    atrd_mc=(R=241,G=241,B=42,A=255)
    bDirectional=false
    bEditorSelectRender=true
    LastKnownReceiver=None
    Texture=texture'tfsrulertip'
    DrawScale=0.5
}
