@{
    DomainName = 'corp.lab'
    NetBIOSName = 'CORP'
    DomainDN = 'DC=corp,DC=lab'
    SwitchName = 'WindowsADLab-Internal'
    Network = '192.168.77.0/24'
    DCAddress = '192.168.77.10'
    ScopeStart = '192.168.77.100'
    ScopeEnd = '192.168.77.150'
    Departments = @('Finance', 'HR', 'IT')
    VMRoot = 'H:\My Projects - IT\windows-ad-lab\.lab'
}
