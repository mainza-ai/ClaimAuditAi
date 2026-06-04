Class ClaimAudit.REST.Auth Extends %CSP.REST
{

ClassMethod GetJWTSecret() As %String
{
    Set tSecret = $System.Util.GetEnviron("JWT_SECRET")
    If tSecret '= "" Quit tSecret
    
    // In production, require JWT_SECRET env var to be set (do not fall back to GUID)
    Set tEnv = $System.Util.GetEnviron("CLAIMAUDIT_ENV")
    If tEnv = "production" {
        // Log critical security error to a timestamped global and throw a hard exception
        Set ^ClaimAuditSecurityError($ZTS) = "CRITICAL: JWT_SECRET environment variable is NOT set in production!"
        Throw ##class(%Exception.General).%New("JWTSecretMissing", 500, , "CRITICAL: JWT_SECRET environment variable is NOT set in production!")
    }
    
    // In dev, fall back to persistent persistent GUID
    Quit ..GetOrCreateSecret()
}

/// Validate a SMART on FHIR JWT token with RS256 (JWKS/Keycloak) or HS256 (local HMAC) signature verification.
ClassMethod ValidateSMARTToken(pToken As %String) As %DynamicObject [ Internal ]
{
    Set tResult = {"active": false}
    Try {
        Set tParts = $LISTFROMSTRING(pToken, ".")
        If $LISTLENGTH(tParts) '= 3 Quit

        Set tHeaderB64 = $LISTGET(tParts, 1)
        Set tPayloadB64 = $LISTGET(tParts, 2)
        Set tSigB64 = $LISTGET(tParts, 3)

        // Parse JWS header for signature parameters
        Set tHeaderB64Decoded = ..PadBase64Url(tHeaderB64)
        Set tHeaderJsonStr = $SYSTEM.Encryption.Base64Decode(tHeaderB64Decoded)
        Set tHeader = ##class(%DynamicObject).%FromJSON(tHeaderJsonStr)
        Set tAlg = tHeader.alg
        Set tKid = tHeader.kid

        Set tInput = tHeaderB64 _ "." _ tPayloadB64

        // 1. Signature Verification
        If tAlg = "RS256" {
            Set tJWKS = ..GetJWKSKeys()
            If '$IsObject(tJWKS) || '$IsObject(tJWKS.keys) Quit
            
            Set tKeyFound = 0
            Set tCertPEM = ""
            Set tKeysIter = tJWKS.keys.%GetIterator()
            While tKeysIter.%GetNext(.tK, .tJWK) {
                If tJWK.kid = tKid {
                    Set tKeyFound = 1
                    Set tX5c = tJWK.x5c.%Get(0)
                    If tX5c '= "" {
                        Set tCertPEM = "-----BEGIN CERTIFICATE-----" _ $CHAR(10)
                        Set tLen = $LENGTH(tX5c)
                        For tI = 1:64:tLen {
                            Set tCertPEM = tCertPEM _ $EXTRACT(tX5c, tI, tI+63) _ $CHAR(10)
                        }
                        Set tCertPEM = tCertPEM _ "-----END CERTIFICATE-----" _ $CHAR(10)
                    }
                    Quit
                }
            }
            If 'tKeyFound || (tCertPEM = "") Quit
            
            Set tSigBin = $SYSTEM.Encryption.Base64Decode(..PadBase64Url(tSigB64))
            Set tValid = $SYSTEM.Encryption.RSASHAVerify(256, tInput, tSigBin, tCertPEM)
            If 'tValid Quit
        } ElseIf tAlg = "HS256" {
            Set tSecret = ..GetJWTSecret()
            If tSecret = "" Quit

            Set tExpectedSigBin = $SYSTEM.Encryption.HMACSHA(256, tInput, tSecret)
            Set tExpectedSigB64 = ..EncodeBase64Url(tExpectedSigBin)

            If tSigB64 '= tExpectedSigB64 Quit
        } Else {
            Quit
        }

        // 2. Claims Validation
        Set tPayloadB64Decoded = ..PadBase64Url(tPayloadB64)
        Set tPayloadJson = $SYSTEM.Encryption.Base64Decode(tPayloadB64Decoded)
        Set tClaims = ##class(%DynamicObject).%FromJSON(tPayloadJson)

        // Validate expiration (Unix epoch seconds)
        Set tExp = +tClaims.exp
        If tExp = 0 Quit
        
        Set tNow = ($PIECE($ZTIMESTAMP, ",", 1) - 47117) * 86400 + $PIECE($ZTIMESTAMP, ",", 2)
        If tExp < tNow Quit

        // Verify Issuer compatibility
        Set tExpectedIssuer = $System.Util.GetEnviron("JWKS_ISSUER")
        If tExpectedIssuer = "" Set tExpectedIssuer = "https://claimauditai.com/fhir"
        If (tClaims.iss '= "https://claimauditai.com/fhir") && (tExpectedIssuer '= "") && (tClaims.iss '= tExpectedIssuer) Quit

        Set tUsername = tClaims.sub
        If tUsername = "" Quit

        // Extract roles (Keycloak realm_access mapping support)
        Set tRoles = tClaims.roles
        If '$IsObject(tRoles) && $IsObject(tClaims."realm_access") {
            Set tRoles = tClaims."realm_access".roles
        }
        If '$IsObject(tRoles) Set tRoles = []

        Set tResult = {
            "active": true,
            "sub": (tClaims.sub),
            "scope": (tClaims.scope),
            "exp": (tClaims.exp),
            "iat": (tClaims.iat),
            "iss": (tClaims.iss),
            "fhirUser": (tClaims.fhirUser),
            "roles": (tRoles),
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
            Set tReqLevel = ..GetRoleLevel(pRequiredRole)
            Try {
                Set tUserRoles = tResult.roles
                If $IsObject(tUserRoles) && (tUserRoles.%Size() > 0) {
                    For tI = 0:1:tUserRoles.%Size()-1 {
                        Set tRole = tUserRoles.%Get(tI)
                        Set tUserLevel = ..GetRoleLevel(tRole)
                        If tUserLevel >= tReqLevel {
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

ClassMethod GetRoleLevel(pRole As %String) As %Integer [ Private ]
{
    If pRole = "Viewer" Return 1
    If pRole = "Auditor" Return 2
    If pRole = "Specialist" Return 3
    If pRole = "Director" Return 4
    If (pRole = "Admin") || (pRole = "Tech Owner / Admin") Return 5
    If pRole = "%All" Return 5
    Return 0
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
        // Since the process is already logged in as the user, we can get their roles from $Roles.
        // Default FullName based on common local users.
        Set tFullName = pUsername
        If pUsername = "admin" Set tFullName = "ClaimAuditAI Admin"
        If pUsername = "auditor" Set tFullName = "ClaimAuditAI Auditor"
        If pUsername = "viewer" Set tFullName = "ClaimAuditAI Viewer"

        Set tRolesStr = $Roles
        Set tRoles = []
        For tI = 1:1:$Length(tRolesStr, ",") {
            Set tRole = $Piece(tRolesStr, ",", tI)
            If tRole = "ClaimAdmin" Do tRoles.%Push("Admin")
            If tRole = "ClaimAuditor" Do tRoles.%Push("Auditor")
            If tRole = "ClaimViewer" Do tRoles.%Push("Viewer")
            If tRole = "Admin" Do tRoles.%Push("Admin")
            If tRole = "Auditor" Do tRoles.%Push("Auditor")
            If tRole = "Viewer" Do tRoles.%Push("Viewer")
        }

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
        Set tSigBin = $SYSTEM.Encryption.HMACSHA(256, tInput, tSecret)
        Set tSigB64 = ..EncodeBase64Url(tSigBin)

        Set tResult = tInput _ "." _ tSigB64
        Set tResult = $REPLACE($REPLACE(tResult, $CHAR(13), ""), $CHAR(10), "")
    } Catch ex {
        Set ^ClaimAuditLastLoginError = ex.DisplayString()
    }
    Quit tResult
}

ClassMethod GetJWKSKeys() As %DynamicObject
{
    Set tJWKS = $Get(^ClaimAuditJWKS("keys"))
    Set tLastFetch = +$Get(^ClaimAuditJWKS("lastFetch"))
    
    // Current UTC Unix timestamp
    Set tNow = ($PIECE($ZTIMESTAMP, ",", 1) - 47117) * 86400 + $PIECE($ZTIMESTAMP, ",", 2)
    
    // Cache keys for 1 hour / 3600 seconds
    If (tJWKS '= "") && ((tNow - tLastFetch) < 3600) {
        Return ##class(%DynamicObject).%FromJSON(tJWKS)
    }
    
    Set tUri = $System.Util.GetEnviron("JWKS_URI")
    If tUri = "" Quit ""
    
    Try {
        Set tServer = ""
        Set tPort = 80
        Set tHttps = 0
        
        Set tProto = $Piece(tUri, "://", 1)
        Set tRest = $Piece(tUri, "://", 2)
        
        Set tHostPort = $Piece(tRest, "/", 1)
        Set tPath = "/" _ $Piece(tRest, "/", 2, *)
        
        If tHostPort [ ":" {
            Set tServer = $Piece(tHostPort, ":", 1)
            Set tPort = +$Piece(tHostPort, ":", 2)
        } Else {
            Set tServer = tHostPort
            If tProto = "https" {
                Set tPort = 443
                Set tHttps = 1
            } Else {
                Set tPort = 80
            }
        }
        
        Set tRequest = ##class(%Net.HttpRequest).%New()
        Set tRequest.Server = tServer
        Set tRequest.Port = tPort
        Set tRequest.Timeout = 5
        
        If tProto = "https" {
            Set tRequest.Https = 1
            // Use standard SSL configuration if defined
            Set tRequest.SSLConfiguration = "Default"
        }
        
        Set tSC = tRequest.Get(tPath)
        If $$$ISOK(tSC) && $IsObject(tRequest.HttpResponse) && (tRequest.HttpResponse.StatusCode = 200) {
            Set tDataStream = tRequest.HttpResponse.Data
            Do tDataStream.Rewind()
            Set tResponse = tDataStream.Read(tDataStream.Size)
            Set tKeys = ##class(%DynamicObject).%FromJSON(tResponse)
            If $IsObject(tKeys) {
                Set ^ClaimAuditJWKS("keys") = tResponse
                Set ^ClaimAuditJWKS("lastFetch") = tNow
                Return tKeys
            }
        }
    } Catch {}
    
    // Fallback to expired cache if new fetch failed (resilience)
    If tJWKS '= "" Return ##class(%DynamicObject).%FromJSON(tJWKS)
    Return ""
}

ClassMethod GetOrCreateSecret() As %String [ Internal ]
{
    Set tSecret = $Get(^ClaimAuditAI("Secret"))
    If tSecret = "" {
        Set tSecret = $SYSTEM.Util.CreateGUID()
        Set ^ClaimAuditAI("Secret") = tSecret
    }
    Quit tSecret
}

}
