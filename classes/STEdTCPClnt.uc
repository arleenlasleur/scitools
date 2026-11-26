class STEdTCPClnt extends TcpLink;
var int ConnPort;

event Resolved(IpAddr Addr){
    Addr.Port = ConnPort;
    BindPort();
    Open(Addr);
}
