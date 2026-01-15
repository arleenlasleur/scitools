class STInvFontInfo extends Info;
var font SavedFont;

function font GetInvFont(){
        if(SavedFont != None) return SavedFont;
        SavedFont = GetStaticFont();
        return SavedFont;
}

static function font GetStaticFont(){
        return Font(DynamicLoadObject("scitools.scifontbig", class'Font'));
}

defaultproperties{
        SavedFont=None
}
