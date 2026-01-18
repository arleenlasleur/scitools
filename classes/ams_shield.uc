class ams_shield extends FearSpot;

function beginplay(){
        local pawn p;
        foreach touchingactors(class'pawn', p) touch(p);
}
function touch(actor other){
        local pawn p;
        local projectile pj;
        if(!other.bispawn) goto skip_nopawn;
        p = pawn(other);
        if(p==none) goto skip_nopawn;
        p.fearthisspot(self);
        skip_nopawn:
        pj = projectile(other);
        if(pj == none) return;
        if(bool(fragment(pj))) return;
        pj.explode(other.location,normal(other.location));
}

defaultproperties{
        LifeSpan=0.0
        CollisionRadius=192
        CollisionHeight=192
        bBlockActors=true
        bProjTarget=true
}
