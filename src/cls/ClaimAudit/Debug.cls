Class ClaimAudit.Debug Extends %RegisteredObject
{

ClassMethod GrantRolesToUnknownUser() As %Status
{
    Set tSC = $$$OK
    Try {
        zn "%SYS"
        Set tSC = ##class(Security.Users).Get("UnknownUser", .u)
        If $$$ISOK(tSC) {
            Set u("Roles") = "%DB_INTEROP-CODE,%DB_INTEROP-DATA,%All"
            Set tSC = ##class(Security.Users).Modify("UnknownUser", .u)
        }
        zn "INTEROP"
    } Catch ex {
        zn "INTEROP"
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
