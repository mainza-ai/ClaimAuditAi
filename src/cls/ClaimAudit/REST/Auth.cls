Class ClaimAudit.REST.Auth Extends %CSP.REST
{

ClassMethod GetJWTSecret() As %String
{
    Set tSecret = $System.Util.GetEnviron("JWT_SECRET")
    If tSecret '= "" Quit tSecret
    
    // In production, require JWT_SECRET env var to be set (do not fall back to GUID)
    Set tEnv = $System.Util.GetEnviron("CLAIMAUDIT_ENV")
    If tEnv = "production" {
        // Log critical security error to a timestamped global
        Set ^ClaimAuditSecurityError($ZTS) = "CRITICAL: JWT_SECRET environment variable is NOT set in production!"
        Quit ""
    }
    
    // In dev, fall back to persistent persistent GUID
    Quit ..GetOrCreateSecret()
}

/// Validate a SMART on FHIR JWT token with HS256 signature verification.
ClassMethod ValidateSMARTToken(pToken As %String) As %DynamicObject [ Internal ]
{
    Set tResult = {"active": false}
    Try {
        Set tParts = $LISTFROMSTRING(pToken, ".")
        If $LISTLENGTH(tParts) '= 3 Quit

        Set tHeaderB64 = $LISTGET(tParts, 1)
        Set tPayloadB64 = $LISTGET(tParts, 2)
        Set tSigB64 = $LISTGET(tParts, 3)

        // Verify the signature
        Set tSecret = ..GetJWTSecret()
        If tSecret = "" Quit

        Set tInput = tHeaderB64 _ "." _ tPayloadB64
        Set tExpectedSigBin = $SYSTEM.Encryption.HMACSHA256(tInput, tSecret)
        Set tExpectedSigB64 = ..EncodeBase64Url(tExpectedSigBin)

        If tSigB64 '= tExpectedSigB64 Quit

        Set tPayloadB64Decoded = ..PadBase64Url(tPayloadB64)
        Set tPayloadJson = $SYSTEM.Encryption.Base64Decode(tPayloadB64Decoded)
        Set tClaims = ##class(%DynamicObject).%FromJSON(tPayloadJson)

        // Validate expiration (Unix epoch seconds)
        Set tExp = +tClaims.exp
        If tExp = 0 Quit
        
        // Current UTC Unix timestamp
        Set tNow = ($PIECE($ZTIMESTAMP, ",", 1) - 47117) * 86400 + $PIECE($ZTIMESTAMP, ",", 2)
        If tExp < tNow Quit

        If tClaims.iss '= "https://claimauditai.com/fhir" Quit

        Set tUsername = tClaims.sub
        If tUsername = "" Quit

        zn "%SYS"
        Set tExists = ##class(Security.Users).Exists(tUsername)
        zn "INTEROP"
        If 'tExists Quit

        Set tResult = {
            "active": true,
            "sub": (tClaims.sub),
            "scope": (tClaims.scope),
            "exp": (tClaims.exp),
            "iat": (tClaims.iat),
            "iss": (tClaims.iss),
            "fhirUser": (tClaims.fhirUser),
            "roles": (tClaims.roles),
            "name": (tClaims.name)
        }
    } Catch ex {}
    Quit tResult
}

/// Middleware: validate Bearer token from Authorization header, optionally check role
ClassMethod RequireAuth(pRequiredRole As %String = "") As %Boolean
{
    Try {
        Set tAuthHeader = %request.GetCgiEnv("HTTP_AUTHORIZATION")
        If tAuthHeader = "" {
            Set tAuthHeader = %request.GetCgiEnv("Authorization")
        }
        If tAuthHeader = "" {
            Set %response.Status = 401
            Write {"error": "Authentication required. Include Authorization: Bearer <token>"}.%ToJSON()
            Return 0
        }
        If $EXTRACT(tAuthHeader, 1, 7) '= "Bearer " {
            Set %response.Status = 401
            Write {"error": "Invalid authorization scheme. Use: Bearer <token>"}.%ToJSON()
            Return 0
        }
        Set tToken = $EXTRACT(tAuthHeader, 8, *)
        Set tResult = ..ValidateSMARTToken(tToken)
        If 'tResult.active {
            Set %response.Status = 401
            Write {"error": "Invalid or expired token"}.%ToJSON()
            Return 0
        }
        If pRequiredRole '= "" {
            Set tHasRole = 0
            Try {
                Set tUserRoles = tResult.roles
                If $IsObject(tUserRoles) && (tUserRoles.%Size() > 0) {
                    For tI = 0:1:tUserRoles.%Size()-1 {
                        Set tRole = tUserRoles.%Get(tI)
                        If (tRole = pRequiredRole) || (tRole = "%All") {
                            Set tHasRole = 1
                            Quit
                        }
                    }
                }
            } Catch {}
            If 'tHasRole {
                Set %response.Status = 403
                Write {"error": ("Insufficient permissions. Required role: " _ pRequiredRole)}.%ToJSON()
                Return 0
            }
        }
        Set ^||ClaimAuditUser = tResult.sub
        Set tName = tResult.name
        If tName = "" Set tName = tResult.sub
        Set ^||ClaimAuditUserFullName = tName
        Set ^||ClaimAuditUserFHIRUser = tResult.fhirUser
        Return 1
    } Catch ex {
        Set %response.Status = 500
        Write {"error": ("Internal auth error: " _ ex.DisplayString())}.%ToJSON()
        Return 0
    }
}

ClassMethod GetCurrentUser() As %String
{
    Quit $Get(^||ClaimAuditUser, "")
}

ClassMethod GetCurrentUserFullName() As %String
{
    Quit $Get(^||ClaimAuditUserFullName, "")
}

ClassMethod EncodeBase64Url(pStr As %String) As %String [ Internal ]
{
    Set tEncoded = $SYSTEM.Encryption.Base64Encode(pStr)
    Set tEncoded = $REPLACE($REPLACE(tEncoded, $CHAR(13), ""), $CHAR(10), "")
    Set tEncoded = $TRANSLATE(tEncoded, "+/", "-_")
    Set tEncoded = $REPLACE(tEncoded, "=", "")
    Quit tEncoded
}

ClassMethod PadBase64Url(pStr As %String) As %String [ Internal ]
{
    Set tStr = $REPLACE($REPLACE(pStr, $CHAR(13), ""), $CHAR(10), "")
    Set tStr = $TRANSLATE(tStr, "-_", "+/")
    Set tPadding = 4 - ($LENGTH(tStr) # 4)
    If tPadding < 4 {
        For tI = 1:1:tPadding Set tStr = tStr _ "="
    }
    Quit tStr
}

ClassMethod IssueSmartOnFHIRToken(pUsername As %String, pClientId As %String = "claimaudit-ui") As %String [ Internal ]
{
    Set tResult = ""
    Try {
        zn "%SYS"
        Set tUserProps = ##class(Security.Users).Get(pUsername, .tProps)
        Set tFullName = $Get(tProps("FullName"), pUsername)
        Set tRoles = []
        Set tSub = ""
        For {
            Set tSub = $Order(^SYS("Security", "Users", pUsername, "Roles", tSub))
            If tSub = "" Quit
            Do tRoles.%Push(tSub)
        }
        zn "INTEROP"

        Set tSecret = ..GetJWTSecret()
        If tSecret = "" Quit

        // Current Unix epoch seconds
        Set tNow = ($PIECE($ZTIMESTAMP, ",", 1) - 47117) * 86400 + $PIECE($ZTIMESTAMP, ",", 2)
        
        // Expiry configurable via JWT_EXPIRY env var (defaults to 1 day / 86400s)
        Set tExpirySeconds = +$System.Util.GetEnviron("JWT_EXPIRY")
        If tExpirySeconds <= 0 Set tExpirySeconds = 86400

        Set tHeader = {"alg": "HS256", "typ": "JWT"}
        Set tHeaderJson = tHeader.%ToJSON()
        Set tHeaderB64 = ..EncodeBase64Url(tHeaderJson)

        Set tPayload = {
            "sub": (pUsername),
            "iss": "https://claimauditai.com/fhir",
            "aud": (pClientId),
            "iat": (tNow),
            "exp": (tNow + tExpirySeconds),
            "name": (tFullName),
            "fhirUser": ("Practitioner/" _ pUsername),
            "roles": (tRoles),
            "scope": "launch patient/Patient.read user/Claim.read user/Claim.write user/ClaimResponse.read user/Task.read user/Task.write fhirUser online_access"
        }
        Set tPayloadJson = tPayload.%ToJSON()
        Set tPayloadB64 = ..EncodeBase64Url(tPayloadJson)

        Set tInput = tHeaderB64 _ "." _ tPayloadB64
        Set tSigBin = $SYSTEM.Encryption.HMACSHA256(tInput, tSecret)
        Set tSigB64 = ..EncodeBase64Url(tSigBin)

        Set tResult = tInput _ "." _ tSigB64
        Set tResult = $REPLACE($REPLACE(tResult, $CHAR(13), ""), $CHAR(10), "")
    } Catch ex {
        zn "INTEROP"
    }
    Quit tResult
}

ClassMethod GetOrCreateSecret() As %String [ Internal ]
{
    Set tSecret = $Get(^%SYS("ClaimAuditAI", "Secret"))
    If tSecret = "" {
        Set tSecret = $SYSTEM.Util.CreateGUID()
        Set ^%SYS("ClaimAuditAI", "Secret") = tSecret
    }
    Quit tSecret
}

}
