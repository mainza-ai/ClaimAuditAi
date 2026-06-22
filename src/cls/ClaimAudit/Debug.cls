Class ClaimAudit.Debug Extends %RegisteredObject
{

ClassMethod GrantRolesToUnknownUser() As %Status
{
    Set tSC = $$$OK
    Try {
        zn "%SYS"
        Set tSC = ##class(Security.Users).Get("UnknownUser", .u)
        If $$$ISOK(tSC) {
            Set u("Roles") = "%DB_INTEROP-CODE,%DB_INTEROP-DATA,%HS_DB_INTEROP,%DB_INTEROPX0001R,%DB_INTEROPX0001V,%HS_ServiceRole,%HS_Administrator"
            Set tSC = ##class(Security.Users).Modify("UnknownUser", .u)
        }

        // Elevate roles for authenticated API users
        Set users = $ListBuild("admin", "auditor", "viewer", "specialist", "director")
        For i=1:1:$ListLength(users) {
            Set username = $ListGet(users, i)
            Set tSC = ##class(Security.Users).Get(username, .u)
            If $$$ISOK(tSC) {
                Set currentRoles = u("Roles")
                For role = "%HS_DB_INTEROP", "%DB_INTEROPX0001R", "%DB_INTEROPX0001V", "%HS_ServiceRole", "%HS_Administrator" {
                    If ("," _ currentRoles _ ",") '[ ("," _ role _ ",") {
                        If currentRoles '= "" Set currentRoles = currentRoles _ ","
                        Set currentRoles = currentRoles _ role
                    }
                }
                Set u("Roles") = currentRoles
                Do ##class(Security.Users).Modify(username, .u)
            }
        }
        zn "INTEROP"

        // Grant SQL privileges to UnknownUser and %HS_DB_INTEROP role for all schemas
        Do ##class(%SQL.Statement).%ExecDirect(, "GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA HSFHIR_X0001_S TO UnknownUser, %HS_DB_INTEROP")
        Do ##class(%SQL.Statement).%ExecDirect(, "GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA HSFHIR_X0001_R TO UnknownUser, %HS_DB_INTEROP")
        Do ##class(%SQL.Statement).%ExecDirect(, "GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA HSFHIR_X0001_V TO UnknownUser, %HS_DB_INTEROP")
        Do ##class(%SQL.Statement).%ExecDirect(, "GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA ClaimAudit TO UnknownUser, %HS_DB_INTEROP")
    } Catch ex {
        zn "INTEROP"
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
