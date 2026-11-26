class STInvFontInfo extends Info;
var font SavedFont;
var bool WhiteFont;

function font GetInvFont(){
   if(SavedFont != None) return SavedFont;
   SavedFont = WhiteFont ? GetStaticFontW() : GetStaticFont();
   return SavedFont;
}

static function font GetStaticFont(){
   return Font(DynamicLoadObject("scitools.scifontbig", class'Font'));
}
static function font GetStaticFontW(){
   return Font(DynamicLoadObject("scitools.scifontbigw", class'Font'));
}

defaultproperties{
   SavedFont=None
   WhiteFont=false
}
