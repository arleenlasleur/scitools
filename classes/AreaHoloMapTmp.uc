// ===========================================================================================
// AreaMapData holographic root class. Provide dotcloud data for map. This is template class,
// do not include. To perform data myleveling process, copy this actor into level under
// another classname and compile changed scripts.
// Do not remove TCPFiller code after adding payload, because this may corrupt actor memory.
// ===========================================================================================
class AreaHoloMapTmp extends actor;
var() vector LevelOffset;
var() string MapData[256];     // max 256 rows x 1024 char each, = 128 vect; 32768 dots total
var() int    MapData_qty;                   // do not render more, laggy
var() string ReactorData[256]; // todo mb less
var() int    ReactorData_qty;
// code scheme (big-endian):
//   node = (x:int16, y:int16, z:int16) -> 8 base64-chars  (same as BSP-dots    20 lines
//   edge = (A:int16, B:int16)          -> 6 base64-chars  (A,B node indices)  120 lines
var() string NodeData[20];  // len = ceil(NodesQty / Slice) <= 20
var() int    NodeData_qty;  // real existing nodes, up to 2560
var() string EdgeData[120]; // len = ceil(EdgesQty / Slice) <= 120
var() int    EdgeData_qty;  // real edges, up to 15360
// ===========================================================================================
var() bool   CallTCPFill;
var   int    StepTCPFill;   // 0=ready, 1=connect, 2=reading
var() string TCPF_DataSourceURL; // default port 4141
var   string IP_str;
var   string Port_str;
var() int    TCPF_PayloadIdx;

var() string ReceivedLines[128];

var STEdTCPClnt TCPF_Link;
var string IncomingBuffer;
var string LastDebugStatus;
// ===========================================================================================

function postbeginplay(){
   self.group = 'areamap';
}

event draweditorselection(canvas c){
    if (CallTCPFill && StepTCPFill == 0){ CallTCPFill=false; StartStep(); }
    if (StepTCPFill > 0 && TCPF_Link != None) ProcessSocketManual();
    DrawSegmentDisplay(c, location +vect(40,0,0), TCPF_PayloadIdx, makecolor(255,255,120));
}

function StartStep(){
    local int ColonIndex;
    if (TCPF_PayloadIdx<0 || TCPF_PayloadIdx>=128) TCPF_PayloadIdx = 0;
    ColonIndex = InStr(TCPF_DataSourceURL, ":");
    IP_str   = (ColonIndex != -1) ? Left(TCPF_DataSourceURL, ColonIndex)    : TCPF_DataSourceURL;
    Port_str = (ColonIndex != -1) ? Mid (TCPF_DataSourceURL, ColonIndex +1) : "4141"; // default

    TCPF_Link = Spawn(class'STEdTCPClnt',,, Location + vect(32, 32, 32));
    if (TCPF_Link==None){ CallTCPFill = false; return; } // spawn failed

    TCPF_Link.LinkMode = MODE_Text;
    TCPF_Link.ReceiveMode = RMODE_Manual;
    TCPF_Link.ConnPort = int(Port_str);
    IncomingBuffer = "";
    StepTCPFill = 1;
    LastDebugStatus = "Resolving...";
    TCPF_Link.Resolve(IP_str);
}

function ProcessSocketManual(){
    local string Chunk;
    local int BytesRead;
    local int NewLinePos;
    local int SafetyLoop;

    // Шаг 1: Ждем подключения и отправляем индекс
    if (StepTCPFill == 1){
        if (TCPF_Link.IsConnected()){
            TCPF_Link.SendText(string(TCPF_PayloadIdx) $ Chr(10));
            StepTCPFill = 2;
            LastDebugStatus = "Sent index " $ TCPF_PayloadIdx $ ", waiting data...";
        }
        return;
    }

    // Шаг 2: Читаем данные напрямую через ReadText (без блокировки по IsDataPending)
    if (StepTCPFill == 2){
        SafetyLoop = 0;
        while (SafetyLoop < 32){
            Chunk = "";
            BytesRead = TCPF_Link.ReadText(Chunk);
            if (BytesRead > 0){
                IncomingBuffer = IncomingBuffer $ Chunk;
                SafetyLoop++;
            }else break;
        }

        // Проверяем наличие \n
        NewLinePos = InStr(IncomingBuffer, Chr(10));
        if (NewLinePos != -1){
            Chunk = Left(IncomingBuffer, NewLinePos);
            if (Right(Chunk, 1) == Chr(13))
                Chunk = Left(Chunk, Len(Chunk) - 1);
            HandleReceivedLine(Chunk);
            CleanupSocket();
            return;
        }

        // Если сервер закрыл соединение
        if (!TCPF_Link.IsConnected()){
            // Контрольная дочитка после закрытия сокета сервером
            Chunk = "";
            while (TCPF_Link.ReadText(Chunk) > 0){
                IncomingBuffer = IncomingBuffer $ Chunk;
                Chunk = "";
            }

            if (IncomingBuffer != ""){
                NewLinePos = InStr(IncomingBuffer, Chr(10));
                if (NewLinePos != -1)
                    IncomingBuffer = Left(IncomingBuffer, NewLinePos);
                if (Right(IncomingBuffer, 1) == Chr(13))
                    IncomingBuffer = Left(IncomingBuffer, Len(IncomingBuffer) - 1);
                HandleReceivedLine(IncomingBuffer);
            }else{ /* closed with empty buffer */ }
            CleanupSocket();
        }
    }
}

function HandleReceivedLine(string Data){
    if (Data == "EOF"){
        LastDebugStatus = "EOF reached -> Reset to 0";
        TCPF_PayloadIdx = 0;
    }else{
        if (Len(Data) > 1024)
            Data = Left(Data, 1024);

        if (TCPF_PayloadIdx < 128){
            ReceivedLines[TCPF_PayloadIdx] = Data;
            LastDebugStatus = "OK! Received " $ Len(Data) $ " chars";
            TCPF_PayloadIdx++;
        }

        if (TCPF_PayloadIdx >= 128)
            TCPF_PayloadIdx = 0;
    }
    CallTCPFill = false;
}

function CleanupSocket(){
    if (TCPF_Link != None){
        TCPF_Link.Close();
        TCPF_Link.Destroy();
        TCPF_Link = None;
    }
    StepTCPFill = 0;
    CallTCPFill = false;
}

function DrawSegmentDisplay(canvas c, vector location, float value, color pc){
    local int i;
    local vector off_r, off_d, offn_r, offdd, sonr;
    local byte sn[5];
    local float snf;
    local bool sa, sb, sc, sd, se, sf, sg;

    off_r  = vect(4, 0, 0);    // horz segment length
    off_d  = vect(0,  0, -4);  // vert
    offn_r = vect(6, 0, 0);   // char tracking

    offdd  = off_d * 2;
    snf = FClamp(value, 0, 99999);                     // parse input
    sn[0] = byte(snf / 10000); snf -= sn[0] * 10000;
    sn[1] = byte(snf / 1000);  snf -= sn[1] * 1000;
    sn[2] = byte(snf / 100);   snf -= sn[2] * 100;
    sn[3] = byte(snf / 10);    snf -= sn[3] * 10;
    sn[4] = byte(snf);
    for (i = 0; i < 5; i++){            // segment truthtable
        sa = true;  if (sn[i] == 1 || sn[i] == 4)                   sa = false; //  **a*
        sb = true;  if (sn[i] == 5 || sn[i] == 6)                   sb = false; // f    *
        sc = true;  if (sn[i] == 2)                                 sc = false; // *    b
        sd = true;  if (sn[i] == 1 || sn[i] == 4 || sn[i] == 7)     sd = false; //  **g*
        se = false; if (sn[i] != 4 && sn[i] % 2 == 0)               se = true;  // e    *
        sf = true;  if ((sn[i] >= 1 && sn[i] <= 3) || sn[i] == 7)   sf = false; // *    c
        sg = true;  if (sn[i] == 0 || sn[i] == 1 || sn[i] == 7)     sg = false; //  **d*
        sonr = location + offn_r * i;   // top left of current digit
        if (sa) c.draw3dline(pc, sonr,                 sonr + off_r);           // a
        if (sb) c.draw3dline(pc, sonr + off_r,         sonr + off_r + off_d);   // b
        if (sc) c.draw3dline(pc, sonr + off_r + off_d, sonr + off_r + offdd);   // c
        if (sd) c.draw3dline(pc, sonr + offdd,         sonr + off_r + offdd);   // d
        if (se) c.draw3dline(pc, sonr + off_d,         sonr + offdd);           // e
        if (sf) c.draw3dline(pc, sonr,                 sonr + off_d);           // f
        if (sg) c.draw3dline(pc, sonr + off_d,         sonr + off_r + off_d);   // g
    }
}

defaultproperties{
   bHidden=true
   bCollideWhenPlacing=false
   bStatic=true
   bNoDelete=true
   MapData_qty=0
   ReactorData_qty=0
   NodeData_qty=0
   EdgeData_qty=0
   bEditorSelectRender=true
   RemoteRole=ROLE_SimulatedProxy
   bAlwaysRelevant=true

   CallTCPFill=false
   TCPF_PayloadIdx=0
   StepTCPFill=0
   TCPF_DataSourceURL=127.0.0.1:4141
}


/*
// Пример целевых массивов (подставьте ваши точные размеры)

var string MapData;     // 256 * 128 = 32768 точек
var string ReactorData;
var string NodeData;
var string EdgeData;


function ProcessSocketManual(){
    local string Chunk, Line;
    local int BytesRead, NewLinePos, LinesThisFrame;

    // Шаг 1: Подключение и отправка команды старта
    if (StepTCPFill == 1)
    {
        if (TCPF_Link.IsConnected())
        {
            TCPF_Link.SendText("GET_ALL" $ Chr(10));
            StepTCPFill = 2;
            LastDebugStatus = "Streaming data...";
        }
        return;
    }

    // Шаг 2: Потоковое чтение всего объема до EOF
    if (StepTCPFill == 2)
    {
        // Набираем в буфер до ~8 КБ за раз (хватает на 7-8 строк по 1038 байт)
        while (Len(IncomingBuffer) < 8192)
        {
            Chunk = "";
            BytesRead = TCPF_Link.ReadText(Chunk);
            if (BytesRead > 0)
                IncomingBuffer = IncomingBuffer $ Chunk;
            else
                break;
        }

        // Разбираем до 30 строк за один кадр рендера вьюпорта
        LinesThisFrame = 0;
        NewLinePos = InStr(IncomingBuffer, Chr(10));
        while (NewLinePos != -1 && LinesThisFrame < 30)
        {
            Line = Left(IncomingBuffer, NewLinePos);
            IncomingBuffer = Mid(IncomingBuffer, NewLinePos + 1);

            if (Right(Line, 1) == Chr(13))
                Line = Left(Line, Len(Line) - 1);

            if (Line == "EOF")
            {
                LastDebugStatus = "Done! Loaded " $ TCPF_PayloadIdx $ " lines.";
                CleanupSocket();
                return;
            }

            ParseT3DPropertyLine(Line);
            TCPF_PayloadIdx++;
            LinesThisFrame++;

            NewLinePos = InStr(IncomingBuffer, Chr(10));
        }

        // Если сервер закрыл соединение сам, дочитываем остаток
        if (!TCPF_Link.IsConnected())
        {
            Chunk = "";
            while (TCPF_Link.ReadText(Chunk) > 0)
            {
                IncomingBuffer = IncomingBuffer $ Chunk;
                Chunk = "";
            }

            while (InStr(IncomingBuffer, Chr(10)) != -1)
            {
                NewLinePos = InStr(IncomingBuffer, Chr(10));
                Line = Left(IncomingBuffer, NewLinePos);
                IncomingBuffer = Mid(IncomingBuffer, NewLinePos + 1);
                if (Right(Line, 1) == Chr(13))
                    Line = Left(Line, Len(Line) - 1);
                if (Line != "" && Line != "EOF")
                    ParseT3DPropertyLine(Line);
            }
            CleanupSocket();
        }
    }
}

// Парсер строк вида: "   MapData(0)=N0rhl;..." или "   MapData_qty=32768"
function ParseT3DPropertyLine(string RawLine)
{
    local int EqPos, OpenParen, CloseParen, ArrIdx;
    local string LeftPart, VarName, Payload;

    // 1. Убираем лидирующие пробелы и табуляции
    while (Left(RawLine, 1) == " " || Left(RawLine, 1) == Chr(9))
    {
        RawLine = Mid(RawLine, 1);
    }

    if (RawLine == "")
        return;

    // 2. Делим по первому знаку '='
    EqPos = InStr(RawLine, "=");
    if (EqPos == -1)
        return;

    LeftPart = Left(RawLine, EqPos);
    Payload  = Mid(RawLine, EqPos + 1);

    // 3. Проверяем, есть ли индекс массива в скобках: VarName(Index)
    OpenParen = InStr(LeftPart, "(");
    if (OpenParen != -1)
    {
        CloseParen = InStr(LeftPart, ")");
        VarName = Left(LeftPart, OpenParen);
        ArrIdx  = int(Mid(LeftPart, OpenParen + 1, CloseParen - OpenParen - 1));
    }
    else
    {
        VarName = LeftPart;
        ArrIdx  = -1;
    }

    // 4. Записываем полезную нагрузку в целевую переменную
    switch (VarName)
    {
        case "MapData_qty":
            MapData_qty = int(Payload);
            break;
        case "MapData":
            if (ArrIdx >= 0 && ArrIdx < 256)
                MapData[ArrIdx] = Payload;
            break;

        case "ReactorData_qty":
            ReactorData_qty = int(Payload);
            break;
        case "ReactorData":
            if (ArrIdx >= 0 && ArrIdx < 128)
                ReactorData[ArrIdx] = Payload;
            break;

        case "NodeData_qty":
            NodeData_qty = int(Payload);
            break;
        case "NodeData":
            if (ArrIdx >= 0 && ArrIdx < 128)
                NodeData[ArrIdx] = Payload;
            break;

        case "EdgeData_qty":
            EdgeData_qty = int(Payload);
            break;
        case "EdgeData":
            if (ArrIdx >= 0 && ArrIdx < 128)
                EdgeData[ArrIdx] = Payload;
            break;
    }
}

*/