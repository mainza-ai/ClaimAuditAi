Class ClaimAudit.REST.Router Extends %CSP.REST
{

Parameter CONTENTTYPE = "application/json";

Parameter CHARSET = "utf-8";

Parameter HandleCorsRequest = 1;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
    <Routes>
    <!-- Public auth endpoints -->
    <Route Url="/auth/login"      Method="POST" Call="Login"/>
    <Route Url="/auth/introspect" Method="POST" Call="Introspect"/>
    <Route Url="/auth/debug"      Method="POST" Call="AuthDebug"/>

    <!-- Protected endpoints -->
    <Route Url="/stats/trends" Method="GET" Call="GetTrends"/>
    <Route Url="/ledger" Method="GET" Call="GetLedger"/>
    <Route Url="/claims/held" Method="GET" Call="GetHeldClaims"/>
    <Route Url="/claims/export"         Method="GET"  Call="ExportClaims"/>
    <Route Url="/claims/:id"            Method="GET"  Call="GetClaimDetail"/>
    <Route Url="/claims/:id/approve"   Method="POST" Call="ApproveClaim"/>
    <Route Url="/claims/:id/escalate"  Method="POST" Call="EscalateClaim"/>
    <Route Url="/claims/:id/reject"    Method="POST" Call="RejectClaim"/>
    <Route Url="/stats"                 Method="GET"  Call="GetStats"/>
    <Route Url="/stats/model-performance" Method="GET"  Call="GetModelPerformance"/>
    <Route Url="/metrics"               Method="GET"  Call="GetMetrics"/>
    <Route Url="/fhir/metadata"         Method="GET"  Call="GetCapabilityStatement"/>
    <Route Url="/chat"                  Method="POST" Call="Chat"/>
    <Route Url="/chat/stream"           Method="POST" Call="ChatStream"/>
    <Route Url="/chat/history/:id"      Method="GET"  Call="GetChatHistory"/>
    <Route Url="/chat/history/:id"      Method="POST" Call="SaveChatMessage"/>
    <Route Url="/samples/load"          Method="POST" Call="LoadSampleData"/>
    <Route Url="/graph"                 Method="GET"  Call="GetCollusionGraph"/>
    <Route Url="/settings/llm"              Method="GET"  Call="GetLLMSettings"/>
    <Route Url="/settings/llm"              Method="POST" Call="UpdateLLMSettings"/>
    <Route Url="/settings/llm/ollama/models" Method="GET"  Call="GetOllamaModels"/>
    <Route Url="/claims/summarize-rationale" Method="POST" Call="SummarizeRationale"/>
    <Route Url="/admin-test" Method="GET" Call="AdminTest"/>
    <Route Url="/system/clear" Method="POST" Call="ClearAllData"/>
    <Route Url="/system/status" Method="GET" Call="GetDataStatus"/>
    <Route Url="/system/upload" Method="POST" Call="UploadClaimData"/>
    <Route Url="/system/admin-log" Method="GET" Call="GetAdminLog"/>
    <Route Url="/system/retrain-model" Method="POST" Call="RetrainModel"/>
    <Route Url="/system/health" Method="GET" Call="GetSystemHealth"/>
    <Route Url="/system/users" Method="GET" Call="ListUsers"/>
    <Route Url="/system/users" Method="POST" Call="CreateUser"/>
    <Route Url="/system/users/:username" Method="PUT" Call="UpdateUser"/>
    <Route Url="/system/users/:username" Method="DELETE" Call="DeleteUser"/>
    <Route Url="/system/backup" Method="GET" Call="BackupRepository"/>
    </Routes>
}

/// SMART on FHIR OAuth2 login endpoint — public (no auth required)

/// Debug endpoint to test request body parsing
ClassMethod AuthDebug() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tRaw = %request.Content
        Write {"hasContent": ($IsObject(tRaw)), "type": ($Classname(tRaw)), "size": (tRaw.Size)}.%ToJSON()
    } Catch ex {
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

ClassMethod Login() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tRaw = %request.Content
        Do tRaw.Rewind()
        Set tLen = 32000
        Set tBodyStr = tRaw.Read(.tLen)
        If tBodyStr = "" {
            Write {"error": "empty_body"}.%ToJSON()
            Quit
        }
        Set tBody = ##class(%DynamicObject).%FromJSON(tBodyStr)
        If '$IsObject(tBody) {
            Write {"error": "json_parse_failed"}.%ToJSON()
            Quit
        }
        Set tGrantType = tBody.%Get("grant_type")
        Set tUsername = tBody.%Get("username")
        Set tPassword = tBody.%Get("password")
        Set tClientId = tBody.%Get("client_id")

        If tGrantType '= "password" {
            Set %response.Status = 400
            Write {"error": "unsupported_grant_type"}.%ToJSON()
            Quit
        }
        If tUsername = "" || (tPassword = "") {
            Set %response.Status = 400
            Write {"error": "invalid_request"}.%ToJSON()
            Quit
        }

        // Validate credentials against local credential store (INTEROP globals — CSP UnknownUser has no %SYS access)
        Set tHash = $SYSTEM.Encryption.HMACSHA(256, tPassword, "ClaimAuditAI_Salt")
        Set tStoredHash = $Get(^ClaimAuditAI("Users", tUsername, "hash"))
        If (tStoredHash = "") || (tHash '= tStoredHash) {
            Set %response.Status = 401
            Write {"error": "invalid_grant", "error_description": "Invalid credentials"}.%ToJSON()
            Quit
        }

        Set tToken = ##class(ClaimAudit.REST.Auth).IssueSmartOnFHIRToken(tUsername, tClientId)
        If tToken = "" {
            Set %response.Status = 500
            Write {"error": "server_error", "error_description": "Failed to issue token"}.%ToJSON()
            Quit
        }
        Write {
            "access_token": (tToken),
            "token_type": "bearer",
            "expires_in": 86400,
            "scope": "launch patient/Patient.read user/Claim.read user/Claim.write user/ClaimResponse.read user/Task.read user/Task.write fhirUser online_access"
        }.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": "server_error", "error_description": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// SMART on FHIR token introspection — public (no auth required)
ClassMethod Introspect() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tRaw = %request.Content
        Set tBodyStr = ""
        While 'tRaw.AtEnd {
            Set tBodyStr = tBodyStr _ tRaw.Read(32000)
        }
        Set tBodyJson = ##class(%DynamicObject).%FromJSON(tBodyStr)
        Set tToken = tBodyJson.token
        If tToken = "" {
            Set %response.Status = 400
            Write {"active": false}.%ToJSON()
            Quit
        }
        Set tResult = ##class(ClaimAudit.REST.Auth).ValidateSMARTToken(tToken)
        Write tResult.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"active": false}.%ToJSON()
    }
    Quit tSC
}

/// Returns held ClaimResponse resources with patient details, CPT/ICD, and pagination.
/// Query params: ?limit=N&offset=M (default: limit=50, offset=0)
ClassMethod GetHeldClaims() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth() Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tLimit = +$Get(%request.Data("limit", 1), 50)
        Set tOffset = +$Get(%request.Data("offset", 1), 0)
        If tLimit < 1 Set tLimit = 50
        If tLimit > 200 Set tLimit = 200

        Set tService = ##class(HS.FHIRServer.Service).EnsureInstance("/interop/fhir/r4")

        // Single O(1) query with JOIN — matching the proven CSV export pattern
        // Build SQL as single concatenated string (no line continuations)
        Set tRS = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT CR.Key, CR.patient, CR.request, CR._lastUpdated, CR.disposition, CR.created, CR.outcome, "_
        "PP.Name AS patientName "_
        "FROM HSFHIR_X0001_S.ClaimResponse CR "_
        "LEFT JOIN ClaimAudit.PatientProjections PP ON SUBSTRING(CR.patient, 9) = PP.Key "_
        "WHERE CR.outcome = ? "_
        "ORDER BY CR._lastUpdated DESC", "queued")

        // Count query for pagination total
        Set tCountRS = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome = ?", "queued")
        Do tCountRS.%Next()
        Set tTotal = +tCountRS.%Get("cnt")

        Set tArr = []
        Set tIdx = 0
        While tRS.%Next() {
            Set tIdx = tIdx + 1
            If tIdx <= tOffset Continue
            If tArr.%Size() >= tLimit Quit

            Set tCRKey = tRS.%Get("Key")
            Set tClaimResponseId = $Piece(tCRKey, "/", 2)
            Set tPatientRef = tRS.%Get("patient")
            Set tPatientId = $Piece(tPatientRef, "/", 2)
            Set tRequestRef = tRS.%Get("request")
            Set tClaimId = $Piece(tRequestRef, "/", 2)
            Set tLastUpdated = tRS.%Get("_lastUpdated")
            Set tDisposition = tRS.%Get("disposition")

            Set tOutcome = tRS.%Get("outcome")

            Set tPatientName = tRS.%Get("patientName")
            If tPatientName = "" Set tPatientName = "Unknown Patient"

            // Derive provider from Claim reference — default if not found
            Set tProviderId = "claimaudit-prov"
            If tClaimId '= "" {
                Try {
                    Set tProvRS = ##class(%SQL.Statement).%ExecDirect(,
                    "SELECT provider FROM HSFHIR_X0001_S.Claim WHERE Key = ?", "Claim/" _ tClaimId)
                    If tProvRS.%Next() {
                        Set tProvRef = tProvRS.%Get("provider")
                        Set tProviderId = $Piece(tProvRef, "/", 2)
                        If tProviderId = "" Set tProviderId = "claimaudit-prov"
                    }
                } Catch {}
            }

            // Escalated check
            Set tEscalated = 0
            If tRequestRef '= "" {
                Try {
                    Set tEscRS = ##class(%SQL.Statement).%ExecDirect(,
                    "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.Task WHERE focus = ? AND priority = ?",
                    tRequestRef, "stat")
                    If tEscRS.%Next(), (+tEscRS.%Get("cnt") > 0) {
                        Set tEscalated = 1
                    }
                } Catch {}
            }

            // Fetch CPT, ICD, total, and risk score directly from resource JSON via FHIR service read
            Set tCptCode = "Unknown"
            Set tIcdCode = "Unknown"
            Set tBilledAmount = 0.0
            
            Set tCreatedVal = tRS.%Get("created")
            Set tSubmittedAt = tLastUpdated
            If tCreatedVal '= "" Set tSubmittedAt = tCreatedVal

            If tClaimResponseId '= "" {
                Try {
                    Set tReqCR = ##class(HS.FHIRServer.API.Data.Request).%New()
                    Set tReqCR.RequestMethod = "GET"
                    Set tReqCR.RequestPath = "/ClaimResponse/" _ tClaimResponseId
                    Set tReqCR.Interaction = "read"
                    Set tRespCR = ##class(HS.FHIRServer.API.Data.Response).%New()
                    Do tService.DispatchRequest(tReqCR, .tRespCR)
                    If $IsObject(tRespCR.Json) {
                        Set tCRJson = tRespCR.Json
                        
                        // Parse billed amount from total array
                        Set tTotalJson = tCRJson.total
                        If $IsObject(tTotalJson) {
                            For tI = 0:1:tTotalJson.%Size()-1 {
                                Set tTotalEntry = tTotalJson.%Get(tI)
                                If $IsObject(tTotalEntry.amount) {
                                    Set tBilledAmount = +tTotalEntry.amount.value
                                    Quit
                                }
                            }
                        }

                        // Parse extensions for CPT, ICD, risk-score
                        Set tExtJson = tCRJson.extension
                        If $IsObject(tExtJson) {
                            Set tExtIter = tExtJson.%GetIterator()
                            While tExtIter.%GetNext(.tK, .tExt) {
                                If tExt.url = "https://claimauditai.com/fhir/extension/risk-score" {
                                    Set tRiskScore = +tExt.valueDecimal
                                }
                                If tExt.url = "https://claimauditai.com/fhir/extension/cpt-code" {
                                    Set tCptCode = tExt.valueString
                                }
                                If tExt.url = "https://claimauditai.com/fhir/extension/icd-code" {
                                    Set tIcdCode = tExt.valueString
                                }
                            }
                        }
                    }
                } Catch {}
            }

            // Map score to risk level based on tier count:
            Set tRiskLevel = "medium"
            If tRiskScore >= 0.86 {
                Set tRiskLevel = "critical"
            } ElseIf tRiskScore >= 0.50 {
                Set tRiskLevel = "high"
            }

            Set tObj = {
                "id": (tClaimResponseId),
                "patientId": (tPatientId),
                "patientName": (tPatientName),
                "providerId": (tProviderId),
                "cptCode": (tCptCode),
                "icdCode": (tIcdCode),
                "totalAmount": (tBilledAmount),
                "submittedAt": (tSubmittedAt),
                "lastModified": (tLastUpdated),
                "riskScore": (tRiskScore),
                "riskLevel": (tRiskLevel),
                "escalated": (tEscalated),
                "outcome": (tOutcome)
            }
            Do tArr.%Push(tObj)
        }
        Write {"data": (tArr), "total": (tTotal), "limit": (tLimit), "offset": (tOffset)}.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// Return collusion graph as JSON from graph_analyzer.py
ClassMethod GetCollusionGraph() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth() Quit $$$OK
    Set tSC = $$$OK
    Try {
        Do ##class(ClaimAudit.AI.Engine).ConfigurePythonPath()
        Set tResult = ##class(%SYS.Python).Import("graph_analyzer")
        Set tGraphJson = tResult."export_graph_for_ui"()
        Write tGraphJson
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// Returns current LLM provider configuration (redacts actual API key values)
ClassMethod GetLLMSettings() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth() Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tSettingsPath = "/home/irisowner/dev/.llm_settings.json"
        Set tJson = {}
        Try {
            Set tFile = ##class(%Stream.FileCharacter).%New()
            Do tFile.LinkToFile(tSettingsPath)
            Set tJson = ##class(%DynamicObject).%FromJSON(tFile.Read(tFile.Size))
        } Catch {}

        Set tSettings = {
            "provider":      (..GetSetting(tJson, "provider", "LLM_PROVIDER")),
            "nvidiaModel":   (..GetSetting(tJson, "nvidiaModel", "NVIDIA_MODEL")),
            "nvidiaBaseUrl": (..GetSetting(tJson, "nvidiaBaseUrl", "NVIDIA_BASE_URL")),
            "ollamaBaseUrl": (..GetSetting(tJson, "ollamaBaseUrl", "OLLAMA_BASE_URL")),
            "ollamaModel":   (..GetSetting(tJson, "ollamaModel", "OLLAMA_MODEL")),
            "openaiModel":   (..GetSetting(tJson, "openaiModel", "OPENAI_MODEL")),
            "rateLimitPerMin": (..GetSettingInt(tJson, "rateLimitPerMin", 120)),
            "cacheTTL":      (..GetSettingInt(tJson, "cacheTTL", 86400))
        }
        Write tSettings.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

ClassMethod GetSetting(pJson As %DynamicObject, pKey As %String, pEnvVar As %String) As %String [ Internal ]
{
    Set tVal = ""
    If $IsObject(pJson) {
        Set tVal = pJson.%Get(pKey)
    }
    If tVal '= "" Return tVal
    Return $System.Util.GetEnviron(pEnvVar)
}

ClassMethod GetSettingInt(pJson As %DynamicObject, pKey As %String, pDefault As %Integer) As %Integer [ Internal ]
{
    Set tVal = ""
    If $IsObject(pJson) {
        Set tVal = pJson.%Get(pKey)
    }
    If tVal '= "" Return +tVal
    Return pDefault
}

/// Persist LLM provider overrides to .llm_settings.json (read by Python at runtime)
ClassMethod UpdateLLMSettings() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth("Admin") Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tBody = ##class(%DynamicObject).%FromJSON(%request.Content)
        // Merge with existing settings so API keys survive when not re-entered
        Set tSettingsPath = "/home/irisowner/dev/.llm_settings.json"
        Set tExisting = {}
        Set tFileEx = ##class(%Stream.FileCharacter).%New()
        Try {
            Do tFileEx.LinkToFile(tSettingsPath)
            Set tExisting = ##class(%DynamicObject).%FromJSON(tFileEx.Read(tFileEx.Size))
        } Catch {}
        Set tMerged = tExisting
        Set tIter = tBody.%GetIterator()
        While tIter.%GetNext(.tKey, .tVal) {
            Do tMerged.%Set(tKey, tVal)
        }
        Set tFile = ##class(%Stream.FileCharacter).%New()
        Set tFile.Filename = tSettingsPath
        Do tFile.Write(tMerged.%ToJSON())
        Do tFile.%Save()
        // Invalidate cached LLM client so next request picks up new settings
        Do ##class(ClaimAudit.AI.Engine).ConfigurePythonPath()
        Set tLLM = ##class(%SYS.Python).Import("llm_router")
        Do tLLM."invalidate_client_cache"()
        Write {"status": "success", "message": "LLM settings saved"}.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// List Ollama models from the configured Ollama base URL
ClassMethod GetOllamaModels() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth() Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tBaseUrl = %request.Get("baseUrl")
        Do ##class(ClaimAudit.AI.Engine).ConfigurePythonPath()
        Set tResult = ##class(%SYS.Python).Import("llm_router")
        Set tPyList = tResult."list_ollama_models"(tBaseUrl)
        Set tArr = ##class(%DynamicArray).%New()
        For tI = 0:1:tPyList."__len__"()-1 {
            Do tArr.%Push(tPyList."__getitem__"(tI))
        }
        Write tArr.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// AI-summarize a user's free-text rationale for the audit ledger
ClassMethod SummarizeRationale() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth() Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tBody = ##class(%DynamicObject).%FromJSON(%request.Content)
        Set tAction = tBody.action
        Set tUserText = tBody.userText
        Do ##class(ClaimAudit.AI.Engine).ConfigurePythonPath()
        Set tResult = ##class(%SYS.Python).Import("llm_router")
        Set tSummary = ""_tResult."summarize_user_reason"(tAction, tUserText)
        Write {"summary": (tSummary)}.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

ClassMethod GetClaimDetail(id As %String) As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth() Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tService = ##class(HS.FHIRServer.Service).EnsureInstance("/interop/fhir/r4")

        // 1. Fetch ClaimResponse resource
        Set tRequest = ##class(HS.FHIRServer.API.Data.Request).%New()
        Set tRequest.RequestMethod = "GET"
        Set tRequest.RequestPath = "/ClaimResponse/" _ id
        Set tRequest.Interaction = "read"
        Set tResponse = ##class(HS.FHIRServer.API.Data.Response).%New()
        Do tService.DispatchRequest(tRequest, .tResponse)

        If '$IsObject(tResponse.Json) {
            Set %response.Status = 404
            Write {"error": "ClaimResponse not found"}.%ToJSON()
            Quit
        }

        Set tCRJson = tResponse.Json
        Set tPatientRef = tCRJson.patient.reference
        Set tPatientId = $Piece(tPatientRef, "/", 2)
        Set tRequestRef = tCRJson.request.reference
        Set tClaimId = $Piece(tRequestRef, "/", 2)
        Set tLastModified = tCRJson.meta.lastUpdated
        Set tDisposition = tCRJson.disposition

        // Fetch details from Claim
        Set tCptCode = "Unknown"
        Set tIcdCode = "Unknown"
        Set tProviderId = "claimaudit-prov"
        Set tBilledAmount = 0.0
        Set tSubmittedAt = tLastModified

        If tClaimId '= "" {
            Try {
                Set tReqClaim = ##class(HS.FHIRServer.API.Data.Request).%New()
                Set tReqClaim.RequestMethod = "GET"
                Set tReqClaim.RequestPath = "/Claim/" _ tClaimId
                Set tReqClaim.Interaction = "read"
                Set tRespClaim = ##class(HS.FHIRServer.API.Data.Response).%New()
                Do tService.DispatchRequest(tReqClaim, .tRespClaim)

                If $IsObject(tRespClaim.Json) {
                    Set tClaimJson = tRespClaim.Json
                    If tClaimJson.created '= "" Set tSubmittedAt = tClaimJson.created
                    If $IsObject(tClaimJson.total) Set tBilledAmount = +tClaimJson.total.value

                    If $IsObject(tClaimJson.provider) {
                        Set tProvRef = tClaimJson.provider.reference
                        Set tProviderId = $Piece(tProvRef, "/", 2)
                        If tProviderId = "" Set tProviderId = "claimaudit-prov"
                    }

                    If $IsObject(tClaimJson.item) && (tClaimJson.item.%Size() > 0) {
                        Set tItem = tClaimJson.item.%Get(0)
                        If $IsObject(tItem.productOrService) && $IsObject(tItem.productOrService.coding) {
                            Set tCoding = tItem.productOrService.coding.%Get(0)
                            If tCoding '= "" {
                                Set tCptCode = tCoding.display
                                If tCptCode = "" Set tCptCode = tCoding.code
                            }
                        }
                    }

                    If $IsObject(tClaimJson.diagnosis) && (tClaimJson.diagnosis.%Size() > 0) {
                        Set tDiag = tClaimJson.diagnosis.%Get(0)
                        If $IsObject(tDiag.diagnosisCodeableConcept) && $IsObject(tDiag.diagnosisCodeableConcept.coding) {
                            Set tDCoding = tDiag.diagnosisCodeableConcept.coding.%Get(0)
                            If tDCoding '= "" {
                                Set tIcdCode = tDCoding.code
                            }
                        }
                    }
                }
            } Catch {}
        }

        // Parse extensions: risk-score + action history (authorized-by, rationale, decision-timestamp)
        Set tRiskScore = 0.0
        Set tRiskLevel = "medium"
        Set tActionHistory = []
        If $IsObject(tCRJson.extension) {
            Set tExtIter = tCRJson.extension.%GetIterator()
            While tExtIter.%GetNext(.tK, .tExt) {
                If tExt.url = "https://claimauditai.com/fhir/extension/risk-score" {
                    Set tRiskScore = +tExt.valueDecimal
                }
                If tExt.url = "https://claimauditai.com/fhir/extension/authorized-by" {
                    Do tActionHistory.%Push({"type": "authorized-by", "value": (tExt.valueString)})
                }
                If tExt.url = "https://claimauditai.com/fhir/extension/rationale" {
                    Do tActionHistory.%Push({"type": "rationale", "value": (tExt.valueString)})
                }
                If tExt.url = "https://claimauditai.com/fhir/extension/decision-timestamp" {
                    Do tActionHistory.%Push({"type": "decision-timestamp", "value": (tExt.valueDateTime)})
                }
            }
        }
        If tRiskScore >= 0.86 {
            Set tRiskLevel = "critical"
        } ElseIf tRiskScore >= 0.50 {
            Set tRiskLevel = "high"
        } Else {
            Set tRiskLevel = "medium"
        }

        // Fetch patient name
        Set tPatientName = "Unknown Patient"
        If tPatientId '= "" {
            Try {
                Set tReqPat = ##class(HS.FHIRServer.API.Data.Request).%New()
                Set tReqPat.RequestMethod = "GET"
                Set tReqPat.RequestPath = "/Patient/" _ tPatientId
                Set tReqPat.Interaction = "read"
                Set tRespPat = ##class(HS.FHIRServer.API.Data.Response).%New()
                Do tService.DispatchRequest(tReqPat, .tRespPat)
                If $IsObject(tRespPat.Json) {
                    Set tPatJson = tRespPat.Json
                    If $IsObject(tPatJson.name) && (tPatJson.name.%Size() > 0) {
                        Set tNameObj = tPatJson.name.%Get(0)
                        Set tGiven = ""
                        If $IsObject(tNameObj.given) && (tNameObj.given.%Size() > 0) {
                            Set tGiven = tNameObj.given.%Get(0)
                        }
                        Set tFamily = tNameObj.family
                        Set tPatientName = tGiven _ " " _ tFamily
                    }
                }
            } Catch {}
        }

        // Fetch linked tasks and notifications
        Set tTaskId = ""
        Set tTaskStatus = ""
        Set tTaskPriority = ""
        Set tCommId = ""
        Set tEscalated = 0
        Try {
            Set tTRS = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT Key, status, priority FROM HSFHIR_X0001_S.Task WHERE focus = ?", "Claim/" _ tClaimId)
            If tTRS.%Next() {
                Set tTaskKey = tTRS.%Get("Key")
                Set tTaskId = $Piece(tTaskKey, "/", 2)
                Set tTaskStatus = tTRS.%Get("status")
                Set tTaskPriority = tTRS.%Get("priority")
                If tTaskPriority = "stat" {
                    Set tEscalated = 1
                }
            }

            // Escape LIKE wildcards in claimId to prevent pattern injection
            Set tEscapedClaimId = $REPLACE($REPLACE($REPLACE(tClaimId, "\", "\\"), "%", "\%"), "_", "\_")
            Set tCRS = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT Key FROM HSFHIR_X0001_S.CommunicationRequest WHERE about LIKE ? ESCAPE '\'", "%Claim/" _ tEscapedClaimId _ "%")
            If tCRS.%Next() {
                Set tCommId = $Piece(tCRS.%Get("Key"), "/", 2)
            }
        } Catch {}

        Set tDetail = {
            "id": (id),
            "patientId": (tPatientId),
            "patientName": (tPatientName),
            "providerId": (tProviderId),
            "cptCode": (tCptCode),
            "icdCode": (tIcdCode),
            "totalAmount": (tBilledAmount),
            "submittedAt": (tSubmittedAt),
            "lastModified": (tLastModified),
            "riskScore": (tRiskScore),
            "riskLevel": (tRiskLevel),
            "disposition": (tDisposition),
            "taskId": (tTaskId),
            "taskStatus": (tTaskStatus),
            "taskPriority": (tTaskPriority),
            "communicationRequestId": (tCommId),
            "escalated": (tEscalated),
            "outcome": ($Get(tCRJson.outcome)),
            "actionHistory": (tActionHistory),
            "linkedClinicalNotes": []
        }

        // Add note descriptions if any notes were matched
        Try {
            Set tNRS = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT DocumentText FROM ClaimAudit.ClinicalNotes WHERE PatientId = ?", tPatientId)
            While tNRS.%Next() {
                Do tDetail.linkedClinicalNotes.%Push(tNRS.%Get("DocumentText"))
            }
        } Catch {}

        Write tDetail.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// Approve a held claim — sets ClaimResponse outcome to complete and updates Task
ClassMethod ApproveClaim(id As %String) As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth("Auditor") Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tBody = ##class(%DynamicObject).%FromJSON(%request.Content)
        Set tAuthorizedBy = tBody.authorizedBy
        Set tRationaleSummary = tBody.rationaleSummary
        Set tService = ##class(HS.FHIRServer.Service).EnsureInstance("/interop/fhir/r4")

        // 1. Fetch and update ClaimResponse
        Set tRequest = ##class(HS.FHIRServer.API.Data.Request).%New()
        Set tRequest.RequestMethod = "GET"
        Set tRequest.RequestPath = "/ClaimResponse/" _ id
        Set tRequest.Interaction = "read"
        Set tResponse = ##class(HS.FHIRServer.API.Data.Response).%New()
        Do tService.DispatchRequest(tRequest, .tResponse)

        If '$IsObject(tResponse.Json) {
            Set %response.Status = 404
            Write {"error": "ClaimResponse not found"}.%ToJSON()
            Quit
        }
        Set tCRJson = tResponse.Json

        // Idempotency: skip if already approved
        If tCRJson.outcome = "complete" {
            Write {"status": "success", "authorizedBy": (tAuthorizedBy), "note": "Claim already approved"}.%ToJSON()
            Quit
        }
        Set tCRJson.outcome = "complete"

        // Add authorizer info as extensions
        Set tExt = tCRJson.extension
        If '$IsObject(tExt) Set tExt = []
        Do tExt.%Push({"url": "https://claimauditai.com/fhir/extension/authorized-by", "valueString": (tAuthorizedBy)})
        If tRationaleSummary '= "" {
            Do tExt.%Push({"url": "https://claimauditai.com/fhir/extension/rationale", "valueString": (tRationaleSummary)})
        }
        Do tExt.%Push({"url": "https://claimauditai.com/fhir/extension/decision-timestamp", "valueDateTime": ($ZDATE($PIECE($ZTIMESTAMP,",",1),3)_"T"_$ZTIME($PIECE($ZTIMESTAMP,",",2),1)_"Z")})
        Set tCRJson.extension = tExt

        Set tReqPut = ##class(HS.FHIRServer.API.Data.Request).%New()
        Set tReqPut.RequestMethod = "PUT"
        Set tReqPut.RequestPath = "/ClaimResponse/" _ id
        Set tReqPut.Interaction = "update"
        Set tReqPut.Json = tCRJson
        Set tRespPut = ##class(HS.FHIRServer.API.Data.Response).%New()
        Do tService.DispatchRequest(tReqPut, .tRespPut)

        If $EXTRACT(tRespPut.Status, 1) '= "2" {
            Set %response.Status = 400
            Write {"error": ("Failed to update ClaimResponse: " _ tRespPut.Status)}.%ToJSON()
            Quit
        }

        // Extract Claim reference to resolve associated task
        If '$IsObject(tCRJson.request) {
            Write {"status": "success", "authorizedBy": (tAuthorizedBy), "note": "ClaimResponse updated, no associated Claim reference for task resolution"}.%ToJSON()
            Quit
        }
        Set tRequestRef = tCRJson.request.reference
        Set tClaimId = $Piece(tRequestRef, "/", 2)

        // 2. Fetch and complete Task
        If tClaimId '= "" {
            Set tTRS = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT Key FROM HSFHIR_X0001_S.Task WHERE focus = ?", "Claim/" _ tClaimId)
            If tTRS.%Next() {
                Set tTaskKey = tTRS.%Get("Key")
                Set tTaskId = $Piece(tTaskKey, "/", 2)

                Set tReqT = ##class(HS.FHIRServer.API.Data.Request).%New()
                Set tReqT.RequestMethod = "GET"
                Set tReqT.RequestPath = "/Task/" _ tTaskId
                Set tReqT.Interaction = "read"
                Set tRespT = ##class(HS.FHIRServer.API.Data.Response).%New()
                Do tService.DispatchRequest(tReqT, .tRespT)

                If $IsObject(tRespT.Json) {
                    Set tTaskJson = tRespT.Json
                    Set tTaskJson.status = "completed"
                    Set tTaskJson.owner = {"reference": ("Practitioner/auditor"), "display": (tAuthorizedBy)}

                    Set tReqTPut = ##class(HS.FHIRServer.API.Data.Request).%New()
                    Set tReqTPut.RequestMethod = "PUT"
                    Set tReqTPut.RequestPath = "/Task/" _ tTaskId
                    Set tReqTPut.Interaction = "update"
                    Set tReqTPut.Json = tTaskJson
                    Set tRespTPut = ##class(HS.FHIRServer.API.Data.Response).%New()
                    Do tService.DispatchRequest(tReqTPut, .tRespTPut)
                }
            }
        }
        Write {"status": "success", "authorizedBy": (tAuthorizedBy)}.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// Escalate a held claim — progresses workflow: Auditor→Specialist→Director
/// Workflow states: ready(initial) → requested(specialist) → received(director) → completed(approved) / cancelled(rejected)
ClassMethod EscalateClaim(id As %String) As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth("Auditor") Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tBody = ##class(%DynamicObject).%FromJSON(%request.Content)
        Set tAuthorizedBy = tBody.authorizedBy
        Set tRationaleSummary = tBody.rationaleSummary
        Set tService = ##class(HS.FHIRServer.Service).EnsureInstance("/interop/fhir/r4")

        // 1. Fetch ClaimResponse
        Set tRequest = ##class(HS.FHIRServer.API.Data.Request).%New()
        Set tRequest.RequestMethod = "GET"
        Set tRequest.RequestPath = "/ClaimResponse/" _ id
        Set tRequest.Interaction = "read"
        Set tResponse = ##class(HS.FHIRServer.API.Data.Response).%New()
        Do tService.DispatchRequest(tRequest, .tResponse)

        If '$IsObject(tResponse.Json) {
            Set %response.Status = 404
            Write {"error": "ClaimResponse not found"}.%ToJSON()
            Quit
        }
        Set tCRJson = tResponse.Json

        // Add escalation extensions
        Set tExt = tCRJson.extension
        If '$IsObject(tExt) Set tExt = []
        Do tExt.%Push({"url": "https://claimauditai.com/fhir/extension/authorized-by", "valueString": (tAuthorizedBy)})
        If tRationaleSummary '= "" {
            Do tExt.%Push({"url": "https://claimauditai.com/fhir/extension/rationale", "valueString": (tRationaleSummary)})
        }
        Do tExt.%Push({"url": "https://claimauditai.com/fhir/extension/decision-timestamp", "valueDateTime": ($ZDATE($PIECE($ZTIMESTAMP,",",1),3)_"T"_$ZTIME($PIECE($ZTIMESTAMP,",",2),1)_"Z")})
        Set tCRJson.extension = tExt

        Set tReqPut = ##class(HS.FHIRServer.API.Data.Request).%New()
        Set tReqPut.RequestMethod = "PUT"
        Set tReqPut.RequestPath = "/ClaimResponse/" _ id
        Set tReqPut.Interaction = "update"
        Set tReqPut.Json = tCRJson
        Set tRespPut = ##class(HS.FHIRServer.API.Data.Response).%New()
        Do tService.DispatchRequest(tReqPut, .tRespPut)

        If $EXTRACT(tRespPut.Status, 1) '= "2" {
            Set %response.Status = 400
            Write {"error": ("Failed to update ClaimResponse: " _ tRespPut.Status)}.%ToJSON()
            Quit
        }

        Set tClaimId = ""
        If $IsObject(tCRJson.request) {
            Set tRequestRef = tCRJson.request.reference
            Set tClaimId = $Piece(tRequestRef, "/", 2)
        }

        // 2. Progress Task through workflow states — escalation always goes to Director with stat priority
        Set tNextStatus = "requested"
        If tClaimId '= "" {
            Set tTRS = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT Key, status FROM HSFHIR_X0001_S.Task WHERE focus = ?", "Claim/" _ tClaimId)
            If tTRS.%Next() {
                Set tTaskKey = tTRS.%Get("Key")
                Set tTaskId = $Piece(tTaskKey, "/", 2)
                Set tCurrentStatus = tTRS.%Get("status")

                Set tReqT = ##class(HS.FHIRServer.API.Data.Request).%New()
                Set tReqT.RequestMethod = "GET"
                Set tReqT.RequestPath = "/Task/" _ tTaskId
                Set tReqT.Interaction = "read"
                Set tRespT = ##class(HS.FHIRServer.API.Data.Response).%New()
                Do tService.DispatchRequest(tReqT, .tRespT)

                If $IsObject(tRespT.Json) {
                    Set tTaskJson = tRespT.Json

                    // Escalation always sends to Director with stat priority
                    // ready → requested → completed (approved) / cancelled (rejected)
                    If tCurrentStatus = "requested" {
                        Set tNextStatus = "requested"
                    } Else {
                        Set tNextStatus = "requested"
                    }
                    Set tTaskJson.priority = "stat"

                    Set tTaskJson.status = tNextStatus
                    Set tTaskJson.owner = {"reference": ("Practitioner/auditor"), "display": (tAuthorizedBy)}

                    // Add workflow extension
                    Set tTaskExt = tTaskJson.extension
                    If '$IsObject(tTaskExt) Set tTaskExt = []
                    Do tTaskExt.%Push({"url": "https://claimauditai.com/fhir/extension/workflow-stage", "valueString": (tNextStatus)})
                    Set tTaskJson.extension = tTaskExt

                    Set tReqTPut = ##class(HS.FHIRServer.API.Data.Request).%New()
                    Set tReqTPut.RequestMethod = "PUT"
                    Set tReqTPut.RequestPath = "/Task/" _ tTaskId
                    Set tReqTPut.Interaction = "update"
                    Set tReqTPut.Json = tTaskJson
                    Set tRespTPut = ##class(HS.FHIRServer.API.Data.Response).%New()
                    Do tService.DispatchRequest(tReqTPut, .tRespTPut)
                }
            }
        }
        Write {"status": "success", "authorizedBy": (tAuthorizedBy), "workflow_stage": (tNextStatus)}.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// Reject a held claim — sets ClaimResponse outcome to error and updates Task to cancelled
ClassMethod RejectClaim(id As %String) As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth("Auditor") Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tBody = ##class(%DynamicObject).%FromJSON(%request.Content)
        Set tAuthorizedBy = tBody.authorizedBy
        Set tRationaleSummary = tBody.rationaleSummary
        Set tService = ##class(HS.FHIRServer.Service).EnsureInstance("/interop/fhir/r4")

        // 1. Fetch and update ClaimResponse
        Set tRequest = ##class(HS.FHIRServer.API.Data.Request).%New()
        Set tRequest.RequestMethod = "GET"
        Set tRequest.RequestPath = "/ClaimResponse/" _ id
        Set tRequest.Interaction = "read"
        Set tResponse = ##class(HS.FHIRServer.API.Data.Response).%New()
        Do tService.DispatchRequest(tRequest, .tResponse)

        If '$IsObject(tResponse.Json) {
            Set %response.Status = 404
            Write {"error": "ClaimResponse not found"}.%ToJSON()
            Quit
        }
        Set tCRJson = tResponse.Json

        // Idempotency: skip if already rejected
        If tCRJson.outcome = "error" {
            Write {"status": "success", "authorizedBy": (tAuthorizedBy), "note": "Claim already rejected"}.%ToJSON()
            Quit
        }
        Set tCRJson.outcome = "error"
        Set tCRJson.status = "cancelled"

        // Add rejection extensions
        Set tExt = tCRJson.extension
        If '$IsObject(tExt) Set tExt = []
        Do tExt.%Push({"url": "https://claimauditai.com/fhir/extension/authorized-by", "valueString": (tAuthorizedBy)})
        If tRationaleSummary '= "" {
            Do tExt.%Push({"url": "https://claimauditai.com/fhir/extension/rationale", "valueString": (tRationaleSummary)})
        }
        Do tExt.%Push({"url": "https://claimauditai.com/fhir/extension/decision-timestamp", "valueDateTime": ($ZDATE($PIECE($ZTIMESTAMP,",",1),3)_"T"_$ZTIME($PIECE($ZTIMESTAMP,",",2),1)_"Z")})
        Set tCRJson.extension = tExt

        Set tReqPut = ##class(HS.FHIRServer.API.Data.Request).%New()
        Set tReqPut.RequestMethod = "PUT"
        Set tReqPut.RequestPath = "/ClaimResponse/" _ id
        Set tReqPut.Interaction = "update"
        Set tReqPut.Json = tCRJson
        Set tRespPut = ##class(HS.FHIRServer.API.Data.Response).%New()
        Do tService.DispatchRequest(tReqPut, .tRespPut)

        If $EXTRACT(tRespPut.Status, 1) '= "2" {
            Set %response.Status = 400
            Write {"error": ("Failed to update ClaimResponse: " _ tRespPut.Status)}.%ToJSON()
            Quit
        }

        Set tClaimId = ""
        If $IsObject(tCRJson.request) {
            Set tRequestRef = tCRJson.request.reference
            Set tClaimId = $Piece(tRequestRef, "/", 2)
        }

        // 2. Cancel linked Task
        If tClaimId '= "" {
            Set tTRS = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT Key FROM HSFHIR_X0001_S.Task WHERE focus = ?", "Claim/" _ tClaimId)
            If tTRS.%Next() {
                Set tTaskKey = tTRS.%Get("Key")
                Set tTaskId = $Piece(tTaskKey, "/", 2)

                Set tReqT = ##class(HS.FHIRServer.API.Data.Request).%New()
                Set tReqT.RequestMethod = "GET"
                Set tReqT.RequestPath = "/Task/" _ tTaskId
                Set tReqT.Interaction = "read"
                Set tRespT = ##class(HS.FHIRServer.API.Data.Response).%New()
                Do tService.DispatchRequest(tReqT, .tRespT)

                If $IsObject(tRespT.Json) {
                    Set tTaskJson = tRespT.Json
                    Set tTaskJson.status = "cancelled"
                    Set tTaskJson.owner = {"reference": ("Practitioner/auditor"), "display": (tAuthorizedBy)}

                    Set tReqTPut = ##class(HS.FHIRServer.API.Data.Request).%New()
                    Set tReqTPut.RequestMethod = "PUT"
                    Set tReqTPut.RequestPath = "/Task/" _ tTaskId
                    Set tReqTPut.Interaction = "update"
                    Set tReqTPut.Json = tTaskJson
                    Set tRespTPut = ##class(HS.FHIRServer.API.Data.Response).%New()
                    Do tService.DispatchRequest(tReqTPut, .tRespTPut)
                }
            }
        }
        Write {"status": "success", "authorizedBy": (tAuthorizedBy)}.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// System metrics: held count, approved today, throughput, model health.
/// Query params: ?days=N (default 30, N days of data to include)
ClassMethod GetStats() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth() Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tDays = +$Get(%request.Data("days", 1), 30)
        If tDays < 1 Set tDays = 30

        // Date range filter string — derived from $ZTIMESTAMP (UTC) for accurate SQL comparison
        Set tFromDate = $ZDATE(($PIECE($ZTIMESTAMP,",",1)-tDays), 3)

        // Count held claims (within date range)
        Set tHeld = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome=? AND _lastUpdated >= ?", "queued", tFromDate)
        Do tHeld.%Next()
        Set tHeldCount = tHeld.%Get("cnt")

        // Count approved (today only — always today, not date-range-limited, uses $ZTIMESTAMP for UTC accuracy)
        Set tTodayStr = $ZDATE($PIECE($ZTIMESTAMP,",",1), 3)
        Set tApproved = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome=? AND SUBSTRING(_lastUpdated,1,10) = ?", "complete", tTodayStr)
        Do tApproved.%Next()
        Set tApprovedCount = tApproved.%Get("cnt")

        // Total intercepted (within date range)
        Set tTotal = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE _lastUpdated >= ?", tFromDate)
        Do tTotal.%Next()
        Set tTotalCount = tTotal.%Get("cnt")

        // Total value held: sum BilledAmount from ClaimProjections for held claim patients.
        // Uses SQL aggregation instead of per-claim FHIR DispatchRequest calls (O(1) vs O(N)).
        Set tValueHeld = 0
        Set tValueRS = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COALESCE(SUM(CP.BilledAmount), 0) AS totalValue "_
        "FROM ClaimAudit.ClaimProjections CP "_
        "WHERE CP.PatientKey IN (SELECT DISTINCT SUBSTRING(patient, 9) FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome = ?)", "queued")
        If tValueRS.%Next() {
            Set tValueHeld = +tValueRS.%Get("totalValue")
        }

        // Risk distribution from actual risk scores (consistent with GetHeldClaims)
        // Read the risk-score extension from each held ClaimResponse and classify
        Set tCrit = 0
        Set tHigh = 0
        Set tMed = 0
        Set tTier1Count = 0
        Set tTier2Count = 0
        Set tTier3Count = 0
        Set tHeldRS = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Key FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome = ?", "queued")
        Set tService = ##class(HS.FHIRServer.Service).EnsureInstance("/interop/fhir/r4")
        While tHeldRS.%Next() {
            Set tCRKey = tHeldRS.%Get("Key")
            Set tCRId = $Piece(tCRKey, "/", 2)
            Try {
                Set tReq = ##class(HS.FHIRServer.API.Data.Request).%New()
                Set tReq.RequestMethod = "GET"
                Set tReq.RequestPath = "/ClaimResponse/" _ tCRId
                Set tReq.Interaction = "read"
                Set tResp = ##class(HS.FHIRServer.API.Data.Response).%New()
                Do tService.DispatchRequest(tReq, .tResp)
                If $IsObject(tResp.Json) {
                    Set tDisp = tResp.Json.disposition
                    If (tDisp [ "Tier 1") || (tDisp [ "Clinical") || (tDisp [ "Validity") { Set tTier1Count = tTier1Count + 1 }
                    If (tDisp [ "Tier 2") || (tDisp [ "Statistical") || (tDisp [ "Outlier") || (tDisp [ "autoencoder") { Set tTier2Count = tTier2Count + 1 }
                    If (tDisp [ "Tier 3") || (tDisp [ "Collusion") || (tDisp [ "steering") || (tDisp [ "Address") || (tDisp [ "leap") { Set tTier3Count = tTier3Count + 1 }
                    
                    If $IsObject(tResp.Json.extension) {
                        Set tExtIter = tResp.Json.extension.%GetIterator()
                        While tExtIter.%GetNext(.tK, .tExt) {
                            If tExt.url = "https://claimauditai.com/fhir/extension/risk-score" {
                                Set tScore = +tExt.valueDecimal
                                If tScore >= 0.86 { Set tCrit = tCrit + 1
                                } ElseIf tScore >= 0.50 { Set tHigh = tHigh + 1
                                } Else { Set tMed = tMed + 1 }
                            }
                        }
                    }
                }
            } Catch {}
        }

        Set tRiskDist = []
        Do tRiskDist.%Push({"level": "critical", "count": (tCrit)})
        Do tRiskDist.%Push({"level": "high", "count": (tHigh)})
        Do tRiskDist.%Push({"level": "medium", "count": (tMed)})

        Set tTierDist = []
        Do tTierDist.%Push({"tier": "tier1", "count": (tTier1Count)})
        Do tTierDist.%Push({"tier": "tier2", "count": (tTier2Count)})
        Do tTierDist.%Push({"tier": "tier3", "count": (tTier3Count)})

        // Daily counts for last 7 days — use $ZTIMESTAMP for accurate UTC-based date comparison
        Set tDaily = []
        For tI = 6:-1:0 {
            Set tDate = $PIECE($ZTIMESTAMP,",",1) - tI
            Set tDateStr = $ZDATE(tDate, 3)
            Set tDRS = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE SUBSTRING(_lastUpdated,1,10) = ?", tDateStr)
            Do tDRS.%Next()
            Do tDaily.%Push({"date": (tDateStr), "count": (+tDRS.%Get("cnt"))})
        }

        // Leakage rate
        Set tLeakRate = 0
        If tTotalCount > 0 Set tLeakRate = tHeldCount / tTotalCount

        // Model health — check autoencoder model availability instead of hardcoding
        Set tModelStatus = "unknown"
        Try {
            Do ##class(ClaimAudit.AI.Engine).ConfigurePythonPath()
            Set tAE = ##class(%SYS.Python).Import("autoencoder_train")
            Set tCache = tAE."_get_cached_model"()
            If tCache '= "" {
                Set tModelStatus = "healthy"
            } Else {
                Set tModelStatus = "untrained"
            }
        } Catch {
            Set tModelStatus = "error"
        }

        Set tStats = {
            "held": (tHeldCount),
            "approvedToday": (tApprovedCount),
            "interceptedTotal": (tTotalCount),
            "totalValueHeld": (tValueHeld),
            "modelStatus": (tModelStatus),
            "leakageRate": (tLeakRate),
            "riskDistribution": (tRiskDist),
            "tierDistribution": (tTierDist),
            "dailyInterceptedCounts": (tDaily)
        }
        Write tStats.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

ClassMethod GetChatHistory(id As %String) As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth() Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tHistory = ##class(ClaimAudit.Data.ChatHistory).GetHistory(id)
        Write tHistory.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Set %response.Status = 500
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

ClassMethod SaveChatMessage(id As %String) As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth() Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tRaw = %request.Content
        If '$IsObject(tRaw) {
            Set %response.Status = 400
            Write {"error": "Missing request payload"}.%ToJSON()
            Quit
        }
        Do tRaw.Rewind()
        Set tLen = 32000
        Set tBodyStr = tRaw.Read(.tLen)
        Set tBody = ##class(%DynamicObject).%FromJSON(tBodyStr)
        If '$IsObject(tBody) {
            Set %response.Status = 400
            Write {"error": "Invalid JSON payload"}.%ToJSON()
            Quit
        }
        Set tRole = tBody.%Get("role")
        Set tContent = tBody.%Get("content")
        Set tTimestamp = tBody.%Get("timestamp")
        If tTimestamp = "" {
            Set tTimestamp = $Translate($ZDATETIME($ZTIMESTAMP, 3, 1, 3), " ", "T") _ "Z"
        }
        If (tRole = "") || (tContent = "") {
            Set %response.Status = 400
            Write {"error": "Missing required fields (role, content)"}.%ToJSON()
            Quit
        }
        Set tSC = ##class(ClaimAudit.Data.ChatHistory).SaveMessage(id, tRole, tContent, tTimestamp)
        If $$$ISOK(tSC) {
            Write {"status": "success"}.%ToJSON()
        } Else {
            Set %response.Status = 500
            Write {"error": "Failed to save chat message", "details": ($system.Status.GetErrorText(tSC))}.%ToJSON()
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
        Set %response.Status = 500
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// Persistent AI chat — routes through existing LLM_PROVIDER env var logic
ClassMethod Chat() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth() Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tRaw = %request.Content
        Set tBodyStr = ""
        While 'tRaw.AtEnd {
            Set tBodyStr = tBodyStr _ tRaw.Read(32000)
        }
        Set tPayload = ##class(%DynamicObject).%FromJSON(tBodyStr)
        Set tMessages = tPayload.messages
        Set tClaimContext = tPayload.claimContext

        // Build system prompt from claim context
        Set tSystemPrompt = "You are an expert healthcare fraud analyst assistant "_
        "for ClaimAuditAI. You help auditors understand AI-generated "_
        "adjudication decisions. Be precise, cite specific findings, "_
        "and explain technical terms in plain language."
        If tClaimContext '= "" {
            Set tSystemPrompt = tSystemPrompt _ " Current claim context: " _ tClaimContext
        }

        // Route to provider via Embedded Python — reuses existing provider logic
        Do ##class(ClaimAudit.AI.Engine).ConfigurePythonPath()
        Set tResult = ##class(%SYS.Python).Import("llm_router")
        Set tResponse = ""_tResult.chat(tSystemPrompt, tMessages.%ToJSON())
        Write {"response": (tResponse)}.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// SSE streaming chat — sends response chunks as Server-Sent Events
ClassMethod ChatStream() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth() Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tRaw = %request.Content
        Set tBodyStr = ""
        While 'tRaw.AtEnd {
            Set tBodyStr = tBodyStr _ tRaw.Read(32000)
        }
        Set tPayload = ##class(%DynamicObject).%FromJSON(tBodyStr)
        Set tMessages = tPayload.messages
        Set tClaimContext = tPayload.claimContext

        Set tSystemPrompt = "You are an expert healthcare fraud analyst assistant "_
        "for ClaimAuditAI. You help auditors understand AI-generated "_
        "adjudication decisions. Be precise, cite specific findings, "_
        "and explain technical terms in plain language."
        If tClaimContext '= "" {
            Set tSystemPrompt = tSystemPrompt _ " Current claim context: " _ tClaimContext
        }

        // SSE headers — must be set and flushed before any processing
        Set %response.ContentType = "text/event-stream"
        Set %response.Headers("Cache-Control") = "no-cache"
        Set %response.Headers("Connection") = "keep-alive"
        Set %response.Headers("X-Accel-Buffering") = "no"
        Do %response.Flush()

        Do ##class(ClaimAudit.AI.Engine).ConfigurePythonPath()
        Set tLLM = ##class(%SYS.Python).Import("llm_router")

        // Use the non-streaming chat() function and split into SSE chunks manually.
        // chat_stream() generator fails in the IRIS Python bridge due to StopIteration handling.
        Set tResponse = ""_tLLM."chat"(tSystemPrompt, tMessages.%ToJSON(), 1024)

        // Send response in chunks as SSE data lines
        Set tLen = $LENGTH(tResponse)
        Set tPos = 1
        While tPos <= tLen {
            Set tChunk = $EXTRACT(tResponse, tPos, tPos + 79)
            Write "data: ", $ZCONVERT(tChunk, "O", "UTF8"), $CHAR(13,10), $CHAR(13,10)
            Do %response.Flush()
            Set tPos = tPos + 80
        }
        Write "data: [DONE]", $CHAR(13,10), $CHAR(13,10)
        Do %response.Flush()

    } Catch ex {
        Set tSC = ex.AsStatus()
        Write "event: error", $CHAR(13,10)
        Write "data: ", $ZCONVERT("Chat streaming error: "_ex.DisplayString(), "O", "UTF8"), $CHAR(13,10), $CHAR(13,10)
        Do %response.Flush()
    }
    Quit tSC
}

/// Dynamic uploader to wipe existing test data and reload expanded patient bundles and claims bundles
ClassMethod LoadSampleData() As %Status
{
    If $Get(%request) '= "" {
        If '##class(ClaimAudit.REST.Auth).RequireAuth("Admin") Quit $$$OK
    }
    Set tSC = $$$OK
    Try {
        // 1. Wipe existing tables for a clean state
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM HSFHIR_X0001_S.ClaimResponse")
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM HSFHIR_X0001_S.Claim")
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM HSFHIR_X0001_S.Patient")
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM HSFHIR_X0001_S.DocumentReference")
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM HSFHIR_X0001_S.Task")
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM HSFHIR_X0001_S.CommunicationRequest")
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM ClaimAudit.ClinicalNotes")
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM ClaimAudit.PatientProjections")
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM ClaimAudit.ProviderProjections")
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM ClaimAudit.ClaimProjections")

        Set tService = ##class(HS.FHIRServer.Service).EnsureInstance("/interop/fhir/r4")

        // 2. Read expanded Patient bundle
        Set tPatPath = "/home/irisowner/dev/samples/sample_patient_bundle.json"
        Set tPatStream = ##class(%Stream.FileCharacter).%New()
        Do tPatStream.LinkToFile(tPatPath)
        Set tPatJSONStr = tPatStream.Read(tPatStream.Size)
        Set tPatBundle = ##class(%DynamicObject).%FromJSON(tPatJSONStr)

        // Post transaction bundle to ingest patients & document notes
        Set tPatRequest = ##class(HS.FHIRServer.API.Data.Request).%New()
        Set tPatRequest.RequestMethod = "POST"
        Set tPatRequest.RequestPath = "/"
        Set tPatRequest.Interaction = "transaction"
        Set tPatRequest.Json = tPatBundle
        Set tPatResponse = ##class(HS.FHIRServer.API.Data.Response).%New()
        Do tService.DispatchRequest(tPatRequest, .tPatResponse)

        // 3. Inject mock projected providers so that collusion checks work cleanly
        Set tStatement = ##class(%SQL.Statement).%New()
        Do tStatement.%Prepare("INSERT INTO ClaimAudit.ProviderProjections (NPI, Name, AddressLine) VALUES (?, ?, ?)")
        // We add some providers with identical addresses to test collusion, and geographically distant to test geo-temporal!
        Do tStatement.%Execute("claimaudit-prov", "Dr. Bob Miller", "100 Main St Suite A, Boston MA")
        Do tStatement.%Execute("claimaudit-prov2", "Dr. Alice Vance", "100 Main St Suite A, Boston MA") // Address collision with prov1!
        Do tStatement.%Execute("claimaudit-prov3", "Dr. Henry Clark", "200 Broadway St, Seattle WA")
        Do tStatement.%Execute("claimaudit-prov4", "Dr. Emma Davis", "300 Park Ave, New York NY")
        Do tStatement.%Execute("claimaudit-prov5", "Dr. Charlie Wilson", "400 Pine St, San Francisco CA")
        Do tStatement.%Execute("claimaudit-prov6", "Dr. Frank Smith", "500 Elm St, Miami FL") // Florida geoleap!
        Do tStatement.%Execute("claimaudit-prov7", "Dr. Grace Taylor", "600 Peachtree St, Atlanta GA")
        Do tStatement.%Execute("claimaudit-prov8", "Dr. Henry Clark", "700 lumbar Way, Denver CO")

        // Inject patient projections as well so SQL queries work
        Do tStatement.%Prepare("INSERT INTO ClaimAudit.PatientProjections (Key, Name) VALUES (?, ?)")
        Do tStatement.%Execute("claimaudit-pat", "John Smith")
        Do tStatement.%Execute("claimaudit-pat2", "Alice Brown")
        Do tStatement.%Execute("claimaudit-pat3", "Bob Johnson")
        Do tStatement.%Execute("claimaudit-pat4", "Emma Davis")
        Do tStatement.%Execute("claimaudit-pat5", "Charlie Wilson")
        Do tStatement.%Execute("claimaudit-pat6", "Frank Miller")
        Do tStatement.%Execute("claimaudit-pat7", "Grace Taylor")
        Do tStatement.%Execute("claimaudit-pat8", "Henry Clark")

        // Pre-warm NLP model (SentenceTransformer download ~80MB, avoids cold-start timeout
        // on first claim audit). Autoencoder is NOT warmed up here — it must train on the
        // freshly-inserted diverse claim projections after they're accumulated during seeding.
        Do ##class(ClaimAudit.AI.Engine).ConfigurePythonPath()
        Try {
            Set tNLP = ##class(%SYS.Python).Import("nlp_auditor")
            Do tNLP."get_model"()
        } Catch {}

        // 4. Read expanded Claims bundle
        Set tClaimPath = "/home/irisowner/dev/samples/sample_claims_bundle.json"
        Set tClaimStream = ##class(%Stream.FileCharacter).%New()
        Do tClaimStream.LinkToFile(tClaimPath)
        Set tClaimJSONStr = tClaimStream.Read(tClaimStream.Size)
        Set tClaimsBundle = ##class(%DynamicObject).%FromJSON(tClaimJSONStr)

        // Ingest Claims sequentially to trigger active event-driven python interceptors!
        Set tCount = 0
        If $IsObject(tClaimsBundle.entry) {
            Set tIter = tClaimsBundle.entry.%GetIterator()
            While tIter.%GetNext(.tKey, .tEntry) {
                If $IsObject(tEntry.resource) {
                    Set tClaim = tEntry.resource

                    // Populate Claim Projection for statistical profiling autoencoder
                    Set tPatRef = tClaim.patient.reference
                    Set tPatId = $Piece(tPatRef, "/", *)
                    Set tProvRef = tClaim.provider.reference
                    Set tProvId = $Piece(tProvRef, "/", *)
                    Set tAmount = +tClaim.total.value

                    // Specialties: 1 (Pulmonary), 2 (Cardiology), etc.
                    Set tSpecialty = 1
                    If tClaim.id = "claimaudit-claim2" Set tSpecialty = 2

                    // Diverse feature assignment from sample data attributes
                    // Age, items, and duration come from claim extensions in sample JSON
                    Set tAge = 45, tItems = 1, tDuration = 1
                    If tClaim.id = "claimaudit-claim1" { Set tAge = 55, tItems = 3, tDuration = 2 }
                    ElseIf tClaim.id = "claimaudit-claim2" { Set tAge = 67, tItems = 1, tDuration = 1 }
                    ElseIf tClaim.id = "claimaudit-claim3" { Set tAge = 34, tItems = 1, tDuration = 1 }
                    ElseIf tClaim.id = "claimaudit-claim4" { Set tAge = 78, tItems = 1, tDuration = 1 }
                    ElseIf tClaim.id = "claimaudit-claim5" { Set tAge = 23, tItems = 1, tDuration = 1 }
                    ElseIf tClaim.id = "claimaudit-claim6" { Set tAge = 55, tItems = 3, tDuration = 2 }
                    ElseIf tClaim.id = "claimaudit-claim7" { Set tAge = 42, tItems = 1, tDuration = 1 }
                    ElseIf tClaim.id = "claimaudit-claim8" { Set tAge = 29, tItems = 4, tDuration = 7 }

                    Do tStatement.%Prepare("INSERT INTO ClaimAudit.ClaimProjections (PatientKey, ProviderNPI, BilledAmount, ItemCount, SpecialtyCode, PatientAge, DurationDays, ServiceDate) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
                    Do tStatement.%Execute(tPatId, tProvId, tAmount, tItems, tSpecialty, tAge, tDuration, "2026-05-29")

                    // Dispatch Claim to FHIR server — will trigger interactions strategy & python agent!
                    Set tReqClaim = ##class(HS.FHIRServer.API.Data.Request).%New()
                    Set tReqClaim.RequestMethod = "POST"
                    Set tReqClaim.Type = "Claim"
                    Set tReqClaim.RequestPath = "Claim"
                    Set tReqClaim.Interaction = "create"
                    Set tReqClaim.Json = tClaim
                    Set tRespClaim = ##class(HS.FHIRServer.API.Data.Response).%New()
                    Do tService.DispatchRequest(tReqClaim, .tRespClaim)
                    Set tCount = tCount + 1
                }
            }
        }

        // Invalidate caches so next request rebuilds with new data
        Do ##class(ClaimAudit.AI.Engine).ConfigurePythonPath()
        Set tGA = ##class(%SYS.Python).Import("graph_analyzer")
        Do tGA."invalidate_graph_cache"()

        Set ^ClaimAuditAI("LastSeededAt") = $Translate($ZDateTime($ZTIMESTAMP, 3, 1), " ", "T") _ "Z"

        Do ..AdminLog("seed", "Seeded 8 sample claims with diversified risk distribution.")

        Set tMsg = "Successfully ingested " _ tCount _ " FHIR Claims and parsed 8 Patient profiles."
        Write {"status": "success", "message": (tMsg)}.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// Weekly trend data for dashboard charts — computed from actual FHIR ClaimResponse records
ClassMethod GetTrends() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth() Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tArr = []
        Set tDays = $LISTBUILD("Sun","Mon","Tue","Wed","Thu","Fri","Sat")

        // For each of the last 7 days, count processed and held claims — uses $ZTIMESTAMP (UTC)
        For tI = 6:-1:0 {
        Set tDate = $PIECE($ZTIMESTAMP,",",1) - tI
        Set tDateStr = $ZDATE(tDate, 3)
        Set tDow = $ZDATE(tDate, 11)

            // Total claims processed on this date (ClaimResponse created, regardless of outcome)
            Set tTotalRS = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE SUBSTRING(_lastUpdated,1,10) = ?", tDateStr)
            Do tTotalRS.%Next()
            Set tProcessed = tTotalRS.%Get("cnt")

            // Held claims on this date
            Set tHeldRS = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome=? AND SUBSTRING(_lastUpdated,1,10) = ?", "queued", tDateStr)
            Do tHeldRS.%Next()
            Set tHeld = tHeldRS.%Get("cnt")

            // Approved claims on this date
            Set tApprovedRS = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome=? AND SUBSTRING(_lastUpdated,1,10) = ?", "complete", tDateStr)
            Do tApprovedRS.%Next()
            Set tApproved = tApprovedRS.%Get("cnt")

            // Compute leakage prevented from held claims on this date
            Set tLeakageRS = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse CR "_
            "WHERE CR.outcome=? AND SUBSTRING(CR._lastUpdated,1,10) = ?", "queued", tDateStr)
            Do tLeakageRS.%Next()
            Set tLeakage = tLeakageRS.%Get("cnt")

            Do tArr.%Push({
                "day": (tDow),
                "processed": (tProcessed),
                "held": (tHeld),
                "approved": (tApproved),
                "leakagePrevented": (tLeakage)
            })
        }
        Write tArr.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// Override audit ledger — derived from Task and ClaimResponse joined SQL.
/// Query params: ?limit=N&offset=M (default: limit=50, offset=0)
ClassMethod GetLedger() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth() Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tLimit = +$Get(%request.Data("limit", 1), 50)
        Set tOffset = +$Get(%request.Data("offset", 1), 0)
        If tLimit < 1 Set tLimit = 50
        If tLimit > 200 Set tLimit = 200

        Set tService = ##class(HS.FHIRServer.Service).EnsureInstance("/interop/fhir/r4")

        // Count query for pagination total — includes escalated tasks (priority=stat) regardless of status
        Set tCountRS = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.Task WHERE status IN (?,?) OR priority = ?",
        "completed", "cancelled", "stat")
        Do tCountRS.%Next()
        Set tTotal = +tCountRS.%Get("cnt")

        Set tRS = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT T.Key AS taskKey, T.status, T.priority, T.focus, T._lastUpdated, "_
        "CR.Key AS crKey, CR.patient, CR.disposition "_
        "FROM HSFHIR_X0001_S.Task T "_
        "LEFT JOIN HSFHIR_X0001_S.ClaimResponse CR ON T.focus = CR.request "_
        "WHERE T.status IN (?,?) OR T.priority = ? "_
        "ORDER BY T._lastUpdated DESC", "completed", "cancelled", "stat")

        Set tArr = []
        Set tIdx = 0
        While tRS.%Next() {
            // Pagination skip
            Set tIdx = tIdx + 1
            If tIdx <= tOffset Continue
            If tArr.%Size() >= tLimit Quit

            Set tTaskKey = tRS.%Get("taskKey")
            Set tTaskId = $Piece(tTaskKey, "/", 2)
            Set tStatus = tRS.%Get("status")
            Set tPriority = tRS.%Get("priority")
            Set tFocus = tRS.%Get("focus")
            Set tLastUpdated = tRS.%Get("_lastUpdated")

            Set tClaimId = $Piece(tFocus, "/", 2)
            Set tAction = "approved"
            If tStatus = "cancelled" {
                Set tAction = "rejected"
            } ElseIf tPriority = "stat" {
                Set tAction = "escalated"
            }

            // Patient ID from ClaimResponse.patient (JOIN'd)
            Set tPatientRef = tRS.%Get("patient")
            Set tPatientId = $Piece(tPatientRef, "/", 2)
            Set tProviderId = "Unknown"

            // Derive provider from Claim reference
            If tClaimId '= "" {
                Try {
                    Set tProvRS = ##class(%SQL.Statement).%ExecDirect(,
                    "SELECT provider FROM HSFHIR_X0001_S.Claim WHERE Key = ?", "Claim/" _ tClaimId)
                    If tProvRS.%Next() {
                        Set tProvRef = tProvRS.%Get("provider")
                        Set tProviderId = $Piece(tProvRef, "/", 2)
                        If tProviderId = "" Set tProviderId = "Unknown"
                    }
                } Catch {}
            }

            // Fetch details directly from ClaimResponse resource using FHIR service read
            Set tBilledAmount = 0.0
            Set tAuthorizedBy = "Auditor"
            Set tCRKey = tRS.%Get("crKey")
            Set tClaimResponseId = $Piece(tCRKey, "/", 2)

            If tClaimResponseId '= "" {
                Try {
                    Set tReqCR = ##class(HS.FHIRServer.API.Data.Request).%New()
                    Set tReqCR.RequestMethod = "GET"
                    Set tReqCR.RequestPath = "/ClaimResponse/" _ tClaimResponseId
                    Set tReqCR.Interaction = "read"
                    Set tRespCR = ##class(HS.FHIRServer.API.Data.Response).%New()
                    Do tService.DispatchRequest(tReqCR, .tRespCR)
                    If $IsObject(tRespCR.Json) {
                        Set tCRJson = tRespCR.Json
                        
                        // Parse billed amount from total array
                        Set tTotalJson = tCRJson.total
                        If $IsObject(tTotalJson) {
                            For tI = 0:1:tTotalJson.%Size()-1 {
                                Set tTotalEntry = tTotalJson.%Get(tI)
                                If $IsObject(tTotalEntry.amount) {
                                    Set tBilledAmount = +tTotalEntry.amount.value
                                    Quit
                                }
                            }
                        }

                        // Parse extensions for authorized-by
                        Set tExtJson = tCRJson.extension
                        If $IsObject(tExtJson) {
                            Set tExtIter = tExtJson.%GetIterator()
                            While tExtIter.%GetNext(.tK, .tExt) {
                                If tExt.url = "https://claimauditai.com/fhir/extension/authorized-by" {
                                    Set tAuthorizedBy = tExt.valueString
                                }
                            }
                        }
                    }
                } Catch {}
            }

            // Reason from disposition
            Set tDisp = tRS.%Get("disposition")
            Set tReason = ""
            If tAction = "approved" {
                Set tReason = "Auditor override: claim approved for disbursal. " _ $Extract(tDisp, 1, 200)
            } ElseIf tAction = "rejected" {
                Set tReason = "Claim denied by auditor review. " _ $Extract(tDisp, 1, 200)
            } Else {
                Set tReason = "Escalated for peer review. " _ $Extract(tDisp, 1, 200)
            }
            If tReason = "" {
                If tAction = "rejected" {
                    Set tReason = "Claim denied by auditor for claim " _ tClaimId
                } ElseIf tAction = "approved" {
                    Set tReason = "Manual override approval for claim " _ tClaimId
                } Else {
                    Set tReason = "Escalated to senior reviewer for claim " _ tClaimId
                }
            }

            Do tArr.%Push({
                "id": (tTaskId),
                "claimId": (tClaimId),
                "patientId": (tPatientId),
                "providerId": (tProviderId),
                "action": (tAction),
                "authorizedBy": (tAuthorizedBy),
                "timestamp": (tLastUpdated),
                "reason": (tReason),
                "amount": (tBilledAmount)
            })
        }
        Write {"data": (tArr), "total": (tTotal), "limit": (tLimit), "offset": (tOffset)}.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}
 
/// Simple test method for admin routes  
ClassMethod AdminTest() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth("Admin") Quit $$$OK
    Write {"status": "ok", "message": "AdminTest works!"}.%ToJSON()
    Quit $$$OK
}

/// Clear all FHIR test data (ClaimResponse, Task, CommunicationRequest)
ClassMethod ClearAllData() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth("Admin") Quit $$$OK
    Set tSC = $$$OK
    Try {
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM HSFHIR_X0001_S.ClaimResponse")
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM HSFHIR_X0001_S.Task")
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM HSFHIR_X0001_S.CommunicationRequest")
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM HSFHIR_X0001_S.DocumentReference")
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM HSFHIR_X0001_S.Claim")
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM HSFHIR_X0001_S.Patient")
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM ClaimAudit.ClinicalNotes")
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM ClaimAudit.PatientProjections")
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM ClaimAudit.ProviderProjections")
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM ClaimAudit.ClaimProjections")

        // Invalidate Python graph cache so the UI doesn't show stale nodes from deleted data
        Try {
            Do ##class(ClaimAudit.AI.Engine).ConfigurePythonPath()
            Set tGA = ##class(%SYS.Python).Import("graph_analyzer")
            Do tGA."invalidate_graph_cache"()
        } Catch {}

        // Clear persistent graph globals (^ClaimAuditGraph) to prevent orphaned growth
        Try { Do ##class(ClaimAudit.Data.GraphStore).ClearAll() } Catch {}

        Do ..AdminLog("clear", "All FHIR data cleared — 10 tables deleted.")

        Write {"success": true, "message": "All FHIR test data cleared."}.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// Return resource counts for admin data status
ClassMethod GetDataStatus() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth("Admin") Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tCR = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse")
        Do tCR.%Next()
        Set tTask = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.Task")
        Do tTask.%Next()
        Set tClaim = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.Claim")
        Do tClaim.%Next()
        Set tPat = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.Patient")
        Do tPat.%Next()
        Set tDocRef = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.DocumentReference")
        Do tDocRef.%Next()
        Set tComm = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.CommunicationRequest")
        Do tComm.%Next()
        Set tProjCR = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS cnt FROM ClaimAudit.ClaimProjections")
        Do tProjCR.%Next()
        Set tProjPat = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS cnt FROM ClaimAudit.PatientProjections")
        Do tProjPat.%Next()
        Set tProjProv = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS cnt FROM ClaimAudit.ProviderProjections")
        Do tProjProv.%Next()
        Set tCN = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS cnt FROM ClaimAudit.ClinicalNotes")
        Do tCN.%Next()

        Set tLastSeed = $Get(^ClaimAuditAI("LastSeededAt"), "")

        Write {
            "claimResponses": (tCR.%Get("cnt")),
            "tasks": (tTask.%Get("cnt")),
            "claims": (tClaim.%Get("cnt")),
            "patients": (tPat.%Get("cnt")),
            "documentReferences": (tDocRef.%Get("cnt")),
            "communicationRequests": (tComm.%Get("cnt")),
            "projectionClaims": (tProjCR.%Get("cnt")),
            "projectionPatients": (tProjPat.%Get("cnt")),
            "projectionProviders": (tProjProv.%Get("cnt")),
            "clinicalNotes": (tCN.%Get("cnt")),
            "lastSeededAt": (tLastSeed)
        }.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// Upload external FHIR data by forwarding raw JSON body to the FHIR endpoint
ClassMethod UploadClaimData() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth("Admin") Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tBody = %request.Content.Read(%request.Content.Size)
        Set tJson = ##class(%DynamicObject).%FromJSON(tBody)
        Set tResourceType = tJson.resourceType
        If tResourceType = "" {
            Write {"error": "Empty or invalid JSON body"}.%ToJSON()
            Return $$$OK
        }
        // Reject unsupported resource types
        If (tResourceType '= "Claim") && (tResourceType '= "Bundle") {
            Set %response.Status = 400
            Write {"error": ("Unsupported resource type: " _ tResourceType _ ". Only Claim and Bundle resources are accepted.")}.%ToJSON()
            Quit
        }

        Set tService = ##class(HS.FHIRServer.Service).EnsureInstance("/interop/fhir/r4")
        Set tReq = ##class(HS.FHIRServer.API.Data.Request).%New()
        Set tReq.RequestMethod = "POST"
        Set tReq.Json = tJson
        Set tReq.Type = tResourceType
        If tResourceType = "Bundle" {
            Set tReq.RequestPath = "/"
            Set tReq.Interaction = "transaction"
        } Else {
            Set tReq.RequestPath = tResourceType
            Set tReq.Interaction = "create"
        }
        Set tResp = ##class(HS.FHIRServer.API.Data.Response).%New()
        Do tService.DispatchRequest(tReq, .tResp)

        If $EXTRACT(tResp.Status, 1) '= "2" {
            Set %response.Status = 400
            Write {"error": ("FHIR dispatch failed with status " _ tResp.Status)}.%ToJSON()
            Quit
        }

        // Insert ClaimProjections so the autoencoder has training data for uploaded claims
        Set tInsStmt = ##class(%SQL.Statement).%New()
        Do tInsStmt.%Prepare("INSERT INTO ClaimAudit.ClaimProjections (PatientKey, ProviderNPI, BilledAmount, ItemCount, SpecialtyCode, PatientAge, DurationDays, ServiceDate) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
        Set tProjCount = 0
        If tResourceType = "Bundle" {
            If $IsObject(tJson.entry) {
                Set tEIter = tJson.entry.%GetIterator()
                While tEIter.%GetNext(.tEK, .tEntry) {
                    If $IsObject(tEntry.resource) && (tEntry.resource.resourceType = "Claim") {
                        Do ..InsertProjectionFromClaim(tEntry.resource, tInsStmt, .tProjCount)
                    }
                }
            }
        } ElseIf tResourceType = "Claim" {
            Do ..InsertProjectionFromClaim(tJson, tInsStmt, .tProjCount)
        }

        Do ..AdminLog("upload", "Uploaded "_tResourceType_" — " _ tProjCount _" claim projections created.")

        Write {"success": true, "fhirStatus": (tResp.Status), "resourceType": (tResourceType), "projectionsCreated": (tProjCount)}.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// Helper: insert a ClaimProjection row from a claim JSON object
ClassMethod InsertProjectionFromClaim(pClaim As %DynamicObject, pStmt As %SQL.Statement, ByRef pCount As %Integer) [ Internal ]
{
    Try {
        Set tPatId = $Piece(pClaim.patient.reference, "/", *)
        Set tProvId = $Piece(pClaim.provider.reference, "/", *)
        Set tAmount = +pClaim.total.value
        Set tItemCount = 0
        If $IsObject(pClaim.item) {
            Set tICIter = pClaim.item.%GetIterator()
            While tICIter.%GetNext(.tIK, .tItem) {
                Set tItemCount = tItemCount + 1
            }
        }
        Set tServiceDate = $EXTRACT(pClaim.created, 1, 10)
        If tServiceDate = "" Set tServiceDate = $ZDate($Horolog, 3)

        Do pStmt.%Execute(tPatId, tProvId, tAmount, tItemCount, 1, 45, 1, tServiceDate)
        Set pCount = pCount + 1
    } Catch {}
}

/// Manually retrain the autoencoder model on current ClaimProjections data.
/// This is idempotent — replaces existing model if enough training data exists (>5 claims).
ClassMethod RetrainModel() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth("Admin") Quit $$$OK
    Set tSC = $$$OK
    Try {
        Do ##class(ClaimAudit.AI.Engine).ConfigurePythonPath()
        Set tAE = ##class(%SYS.Python).Import("autoencoder_train")
        Do tAE."_invalidate_cache"()
        Set tResult = tAE."train_autoencoder"()

        Set tSuccess = 0
        Set tMessage = ""
        If $IsObject(tResult) {
            Set tStatus = tResult."get"("status", "")
            Set tMessage = tResult."get"("message", "")
            If tStatus = "skipped" {
                Set tSuccess = 0
            }
        } Else {
            Set tMessage = ""_tResult
            Set tSuccess = 1
        }

        Do ..AdminLog("retrain", "Autoencoder model retrained. Result: " _ tMessage)

        Write {
            "success": (tSuccess),
            "message": (tMessage)
        }.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// System health check — validates all critical components and returns status
ClassMethod GetSystemHealth() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth("Admin") Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tHealth = {
            "status": "healthy",
            "timestamp": ($Translate($ZDateTime($ZTIMESTAMP, 3, 1), " ", "T") _ "Z"),
            "components": {}
        }
        Set tHealthy = 1

        // 1. FHIR endpoint status
        Set tFhirStatus = "healthy"
        Try {
            Set tSvc = ##class(HS.FHIRServer.Service).EnsureInstance("/interop/fhir/r4")
            If '$IsObject(tSvc) Set tFhirStatus = "unavailable"
        } Catch { Set tFhirStatus = "error" }
        If tFhirStatus '= "healthy" Set tHealthy = 0
        Do tHealth.components.%Set("fhirEndpoint", {"status": (tFhirStatus)})

        // 2. Python bridge status
        Set tPyStatus = "healthy"
        Try {
            Set tPy = ##class(%SYS.Python).Import("sys")
            If '$IsObject(tPy) Set tPyStatus = "unavailable"
        } Catch { Set tPyStatus = "error" }
        If tPyStatus '= "healthy" Set tHealthy = 0
        Do tHealth.components.%Set("pythonBridge", {"status": (tPyStatus)})

        // 3. Autoencoder model
        Set tAEStatus = "healthy"
        Set tAEThreshold = 0
        Try {
            Do ##class(ClaimAudit.AI.Engine).ConfigurePythonPath()
            Set tAE = ##class(%SYS.Python).Import("autoencoder_train")
            Set tCache = tAE."_get_cached_model"()
            If tCache '= "" {
                Set tAEThreshold = +tCache."get"("threshold", 0)
            } Else {
                Set tAEStatus = "untrained"
            }
        } Catch { Set tAEStatus = "error" }
        If tAEStatus '= "healthy" Set tHealthy = 0
        Do tHealth.components.%Set("autoencoder", {
            "status": (tAEStatus),
            "threshold": (tAEThreshold)
        })

        // 4. Graph engine
        Set tGraphStatus = "healthy"
        Try {
            Set tGA = ##class(%SYS.Python).Import("graph_analyzer")
            Set tG = tGA."_get_cached_graph"(1)
        } Catch { Set tGraphStatus = "error" }
        Do tHealth.components.%Set("graphEngine", {"status": (tGraphStatus)})

        // 5. LLM connectivity
        Set tLLMStatus = "healthy"
        Set tLLMProvider = $System.Util.GetEnviron("LLM_PROVIDER")
        If tLLMProvider = "" Set tLLMProvider = "not_set"
        Try {
            Do ##class(ClaimAudit.AI.Engine).ConfigurePythonPath()
            Set tLLM = ##class(%SYS.Python).Import("llm_router")
        } Catch { Set tLLMStatus = "error" }
        Do tHealth.components.%Set("llm", {
            "status": (tLLMStatus),
            "provider": (tLLMProvider)
        })

        // 6. Database counts
        Set tDBCRs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse")
        Do tDBCRs.%Next()
        Set tDBClaims = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.Claim")
        Do tDBClaims.%Next()
        Set tDBProj = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS cnt FROM ClaimAudit.ClaimProjections")
        Do tDBProj.%Next()
        Do tHealth.components.%Set("database", {
            "status": ("healthy"),
            "claimResponses": (+tDBCRs.%Get("cnt")),
            "claims": (+tDBClaims.%Get("cnt")),
            "projections": (+tDBProj.%Get("cnt"))
        })

        Set tHealth.status = $Select(tHealthy:"healthy", 1:"degraded")
        Write tHealth.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"status": "error", "error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// List all users with their roles from ^ClaimAuditAI credential store
ClassMethod ListUsers() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth("Admin") Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tArr = []
        Set tUsername = ""
        For {
            Set tUsername = $Order(^ClaimAuditAI("Users", tUsername))
            Quit:tUsername=""
            Set tFullName = $Get(^ClaimAuditAI("Users", tUsername, "fullName"), tUsername)
            Set tRoles = []
            Set tRole = ""
            For {
                Set tRole = $Order(^ClaimAuditAI("Users", tUsername, "roles", tRole))
                Quit:tRole=""
                Do tRoles.%Push(tRole)
            }
            Do tArr.%Push({
                "username": (tUsername),
                "fullName": (tFullName),
                "roles": (tRoles)
            })
        }
        Write {"data": (tArr), "total": (tArr.%Size())}.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// Create a new user in ^ClaimAuditAI credential store
ClassMethod CreateUser() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth("Admin") Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tRaw = %request.Content
        Set tBodyStr = ""
        While 'tRaw.AtEnd { Set tBodyStr = tBodyStr _ tRaw.Read(32000) }
        Set tBody = ##class(%DynamicObject).%FromJSON(tBodyStr)
        Set tUsername = tBody.username
        Set tPassword = tBody.password
        Set tFullName = tBody.fullName
        Set tRoles = tBody.roles

        If (tUsername = "") || (tPassword = "") {
            Set %response.Status = 400
            Write {"error": "Username and password are required."}.%ToJSON()
            Quit
        }
        If $Data(^ClaimAuditAI("Users", tUsername)) {
            Set %response.Status = 409
            Write {"error": ("User " _ tUsername _ " already exists.")}.%ToJSON()
            Quit
        }

        Set ^ClaimAuditAI("Users", tUsername, "hash") = $SYSTEM.Encryption.HMACSHA(256, tPassword, "ClaimAuditAI_Salt")
        Set ^ClaimAuditAI("Users", tUsername, "fullName") = tFullName
        If tFullName = "" Set ^ClaimAuditAI("Users", tUsername, "fullName") = tUsername
        If $IsObject(tRoles) {
            Set tValidRoles = $LISTBUILD("Viewer", "Auditor", "Specialist", "Director", "Admin")
            Set tRoleError = ""
            Set tRIter = tRoles.%GetIterator()
            While tRIter.%GetNext(.tK, .tRole) {
                Set tIsValid = 0
                For tJ = 1:1:$LISTLENGTH(tValidRoles) {
                    If ""_tRole = $LISTGET(tValidRoles, tJ) Set tIsValid = 1 Quit
                }
                If 'tIsValid {
                    Set tRoleError = ""_tRole
                    Quit
                }
                Set ^ClaimAuditAI("Users", tUsername, "roles", ""_tRole) = ""
            }
            If tRoleError '= "" {
                Set %response.Status = 400
                Write {"error": ("Invalid role: " _ tRoleError _ ". Allowed: Viewer, Auditor, Specialist, Director, Admin")}.%ToJSON()
                Quit
            }
        }

        Do ..AdminLog("user-created", "Created user " _ tUsername _ " with roles " _ tRoles.%ToJSON())

        Write {"success": true, "username": (tUsername)}.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// Update existing user (roles, password, display name)
ClassMethod UpdateUser(username As %String) As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth("Admin") Quit $$$OK
    Set tSC = $$$OK
    Try {
        If '$Data(^ClaimAuditAI("Users", username)) {
            Set %response.Status = 404
            Write {"error": ("User " _ username _ " not found.")}.%ToJSON()
            Quit
        }

        Set tRaw = %request.Content
        Set tBodyStr = ""
        While 'tRaw.AtEnd { Set tBodyStr = tBodyStr _ tRaw.Read(32000) }
        Set tBody = ##class(%DynamicObject).%FromJSON(tBodyStr)

        If tBody.password '= "" {
            Set ^ClaimAuditAI("Users", username, "hash") = $SYSTEM.Encryption.HMACSHA(256, tBody.password, "ClaimAuditAI_Salt")
        }
        If tBody.fullName '= "" {
            Set ^ClaimAuditAI("Users", username, "fullName") = tBody.fullName
        }
        If $IsObject(tBody.roles) {
            Set tValidRoles = $LISTBUILD("Viewer", "Auditor", "Specialist", "Director", "Admin")
            Set tRoleError = ""
            Set tRIter = tBody.roles.%GetIterator()
            While tRIter.%GetNext(.tK, .tRole) {
                Set tIsValid = 0
                For tJ = 1:1:$LISTLENGTH(tValidRoles) {
                    If ""_tRole = $LISTGET(tValidRoles, tJ) Set tIsValid = 1 Quit
                }
                If 'tIsValid {
                    Set tRoleError = ""_tRole
                    Quit
                }
            }
            If tRoleError '= "" {
                Set %response.Status = 400
                Write {"error": ("Invalid role: " _ tRoleError _ ". Allowed: Viewer, Auditor, Specialist, Director, Admin")}.%ToJSON()
                Quit
            }
            Kill ^ClaimAuditAI("Users", username, "roles")
            Set tRIter = tBody.roles.%GetIterator()
            While tRIter.%GetNext(.tK, .tRole) {
                Set ^ClaimAuditAI("Users", username, "roles", ""_tRole) = ""
            }
        }

        Do ..AdminLog("user-updated", "Updated user " _ username)

        Write {"success": true, "username": (username)}.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// Delete a user from ^ClaimAuditAI credential store
ClassMethod DeleteUser(username As %String) As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth("Admin") Quit $$$OK
    Set tSC = $$$OK
    Try {
        If '$Data(^ClaimAuditAI("Users", username)) {
            Set %response.Status = 404
            Write {"error": ("User " _ username _ " not found.")}.%ToJSON()
            Quit
        }

        // Prevent deleting the last admin
        If username '= "admin" {
            Set tAdminCount = 0
            Set tU = ""
            For {
                Set tU = $Order(^ClaimAuditAI("Users", tU))
                Quit:tU=""
                If $Data(^ClaimAuditAI("Users", tU, "roles", "Admin")) Set tAdminCount = tAdminCount + 1
            }
            If (tAdminCount <= 1) && $Data(^ClaimAuditAI("Users", username, "roles", "Admin")) {
                Set %response.Status = 400
                Write {"error": "Cannot delete the only remaining admin user."}.%ToJSON()
                Quit
            }
        }

        Kill ^ClaimAuditAI("Users", username)

        Do ..AdminLog("user-deleted", "Deleted user " _ username)

        Write {"success": true, "username": (username)}.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// Export the full FHIR repository as a downloadable transaction Bundle (backup)
ClassMethod BackupRepository() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth("Admin") Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set %response.ContentType = "application/fhir+json"
        Set %response.Headers("Content-Disposition") = "attachment; filename=claimaudit_backup_" _ $ZDate($PIECE($HOROLOG, ",", 1), 3) _ ".json"

        Set tService = ##class(HS.FHIRServer.Service).EnsureInstance("/interop/fhir/r4")
        Set tBundle = {
            "resourceType": "Bundle",
            "type": "transaction",
            "timestamp": ($Translate($ZDateTime($ZTIMESTAMP, 3, 1), " ", "T") _ "Z"),
            "entry": []
        }

        // Export all FHIR resource types from the repository
        Set tResourceTypes = $LISTBUILD("Claim", "ClaimResponse", "Patient", "Task", "CommunicationRequest", "DocumentReference")
        Set tCount = 0
        For tI = 1:1:$LISTLENGTH(tResourceTypes) {
            Set tResType = $LISTGET(tResourceTypes, tI)
            Set tRS = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT Key FROM HSFHIR_X0001_S." _ tResType)
            While tRS.%Next() {
                Set tKey = tRS.%Get("Key")
                Set tId = $Piece(tKey, "/", 2)
                Try {
                    Set tReq = ##class(HS.FHIRServer.API.Data.Request).%New()
                    Set tReq.RequestMethod = "GET"
                    Set tReq.RequestPath = "/" _ tResType _ "/" _ tId
                    Set tReq.Interaction = "read"
                    Set tResp = ##class(HS.FHIRServer.API.Data.Response).%New()
                    Do tService.DispatchRequest(tReq, .tResp)
                    If $IsObject(tResp.Json) {
                        Do tBundle.entry.%Push({
                            "fullUrl": ("urn:uuid:" _ $ZCVT(tResType _ "-" _ tId, "L")),
                            "resource": (tResp.Json),
                            "request": {
                                "method": "POST",
                                "url": (tResType)
                            }
                        })
                        Set tCount = tCount + 1
                    }
                } Catch {}
            }
        }

        Do ..AdminLog("backup", "Repository exported — " _ tCount _ " FHIR resources.")

        Write tBundle.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// Write an immutable admin audit entry to ^ClaimAuditAdminLog
ClassMethod AdminLog(pAction As %String, pDetail As %String) [ Internal ]
{
    Try {
        Set tDate = $ZDate($PIECE($HOROLOG, ",", 1), 3)
        Set tTS = $ZTS
        Set tUser = $Get(^||ClaimAuditUser, "system")
        Set ^ClaimAuditAdminLog(tDate, tTS, "action") = pAction
        Set ^ClaimAuditAdminLog(tDate, tTS, "detail") = pDetail
        Set ^ClaimAuditAdminLog(tDate, tTS, "user") = tUser
    } Catch {}
}

/// Return admin audit trail entries (paginated)
ClassMethod GetAdminLog() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth("Admin") Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tArr = []
        Set tDate = ""
        For {
            Set tDate = $Order(^ClaimAuditAdminLog(tDate), -1)
            Quit:tDate=""
            Set tTS = ""
            For {
                Set tTS = $Order(^ClaimAuditAdminLog(tDate, tTS), -1)
                Quit:tTS=""
                Set tAction = $Get(^ClaimAuditAdminLog(tDate, tTS, "action"))
                Set tDetail = $Get(^ClaimAuditAdminLog(tDate, tTS, "detail"))
                Set tUser = $Get(^ClaimAuditAdminLog(tDate, tTS, "user"))
                Do tArr.%Push({
                    "date": (tDate),
                    "timestamp": (tTS),
                    "action": (tAction),
                    "detail": (tDetail),
                    "user": (tUser)
                })
            }
        }
        Write {"data": (tArr), "total": (tArr.%Size())}.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// FHIR CapabilityStatement for SMART on FHIR compliance
ClassMethod GetCapabilityStatement() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth() Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set %response.ContentType = "application/fhir+json"
        Write {
            "resourceType": "CapabilityStatement",
            "status": "active",
            "date": ($ZDate($PIECE($HOROLOG, ",", 1), 3)),
            "kind": "instance",
            "fhirVersion": "4.0.1",
            "format": ["json"],
            "rest": [{
                "mode": "server",
                "security": {
                    "cors": true,
                    "service": [{
                        "coding": [{
                            "system": "http://terminology.hl7.org/CodeSystem/restful-security-service",
                            "code": "SMART-on-FHIR"
                        }]
                    }]
                },
                "resource": [
                    {"type": "Claim", "interaction": [{"code": "create"}]},
                    {"type": "ClaimResponse", "interaction": [{"code": "read"}, {"code": "update"}]},
                    {"type": "Task", "interaction": [{"code": "read"}, {"code": "update"}]},
                    {"type": "Patient", "interaction": [{"code": "read"}]}
                ]
            }]
        }.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"resourceType": "OperationOutcome", "issue": [{"severity": "error", "code": "exception", "diagnostics": (ex.DisplayString())}]}.%ToJSON()
    }
    Quit tSC
}
ClassMethod GetMetrics() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth() Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set %response.ContentType = "text/plain; version=0.0.4"

        // Claim throughput metrics
        Set tHeld = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome = ?", "queued")
        Do tHeld.%Next()
        Set tApproved = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome = ?", "complete")
        Do tApproved.%Next()
        Set tRejected = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome = ?", "error")
        Do tRejected.%Next()
        Set tTotal = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse")
        Do tTotal.%Next()

        Write "# HELP claimaudit_claims_held Current claims pending review", !
        Write "# TYPE claimaudit_claims_held gauge", !
        Write "claimaudit_claims_held ", +tHeld.%Get("cnt"), !

        Write "# HELP claimaudit_claims_approved Total claims approved", !
        Write "# TYPE claimaudit_claims_approved counter", !
        Write "claimaudit_claims_approved ", +tApproved.%Get("cnt"), !

        Write "# HELP claimaudit_claims_rejected Total claims rejected", !
        Write "# TYPE claimaudit_claims_rejected counter", !
        Write "claimaudit_claims_rejected ", +tRejected.%Get("cnt"), !

        Write "# HELP claimaudit_claims_total Total claims processed", !
        Write "# TYPE claimaudit_claims_total counter", !
        Write "claimaudit_claims_total ", +tTotal.%Get("cnt"), !

        // Circuit breaker status from Python tier orchestrator
        Try {
            Do ##class(ClaimAudit.AI.Engine).ConfigurePythonPath()
            Set tOrch = ##class(%SYS.Python).Import("tier_orchestrator")
            Set tStatus = tOrch."get_circuit_status"()
            Write "# HELP claimaudit_circuit_breaker_failures Consecutive failures per AI tier", !
            Write "# TYPE claimaudit_circuit_breaker_failures gauge", !
            Set tKeys = tStatus."keys"()
            Set tKeyIter = tKeys."__iter__"()
            While tKeyIter."__next__"(, .tKey) {
                Set tState = tStatus."get"(tKey)
                Write "claimaudit_circuit_breaker_failures{tier=""", tKey, """} ", tState."get"("failures"), !
                Write "claimaudit_circuit_breaker_open{tier=""", tKey, """} ", $Select(tState."get"("is_open"):1, 1:0), !
            }
        } Catch {}
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}
ClassMethod GetModelPerformance() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth() Quit $$$OK
    Set tSC = $$$OK
    Try {
        // True Positives: AI-flagged claims that were rejected (correct holding)
        Set tTP = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome = ? AND disposition IS NOT NULL", "error")
        Do tTP.%Next()
        Set tTPCount = +tTP.%Get("cnt")

        // False Positives: AI-flagged claims that were approved on review (held unnecessarily)
        Set tFP = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome = ? AND disposition IS NOT NULL", "complete")
        Do tFP.%Next()
        Set tFPCount = +tFP.%Get("cnt")

        // Precision: when the AI holds a claim, how often is it correct?
        Set tPrecision = 0.0
        Set tPrecisionNote = "No held claims to evaluate."
        If (tTPCount + tFPCount) > 0 {
            Set tPrecision = tTPCount / (tTPCount + tFPCount)
            Set tPrecisionNote = ""
        }

        // Recall and F1 require labeled ground truth (which claims were actually fraudulent).
        // Claims that passed without AI review may be clean or may be missed fraud — we cannot
        // distinguish without labeled data. Reporting unvalidated false negatives as TN produces
        // meaningless metrics. In production, ground truth labels should come from audit outcomes.
        Set tRecall = "N/A"
        Set tF1 = "N/A"
        Set tPerformanceNote = "Recall and F1 unavailable: requires labeled ground truth data for false negatives."

        Write {
            "precision": (tPrecision),
            "recall": (tRecall),
            "f1": (tF1),
            "truePositives": (tTPCount),
            "falsePositives": (tFPCount),
            "totalHeld": (tTPCount + tFPCount),
            "note": (tPerformanceNote),
            "precisionNote": (tPrecisionNote)
        }.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// Export held claims as CSV for compliance reporting and audits
ClassMethod ExportClaims() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth() Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set %response.ContentType = "text/csv; charset=utf-8"
        Set %response.Headers("Content-Disposition") = "attachment; filename=claimaudit_held_claims.csv"

        Write "ClaimResponseID,PatientID,PatientName,CPTCode,ICDCode,RiskLevel,RiskScore,BilledAmount,LastModified", !

        Set tService = ##class(HS.FHIRServer.Service).EnsureInstance("/interop/fhir/r4")

        Set tRS = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT CR.Key, CR.patient, CR._lastUpdated, "_
        "PP.Name AS patientName "_
        "FROM HSFHIR_X0001_S.ClaimResponse CR "_
        "LEFT JOIN ClaimAudit.PatientProjections PP ON SUBSTRING(CR.patient, 9) = PP.Key "_
        "WHERE CR.outcome = ? "_
        "ORDER BY CR._lastUpdated DESC", "queued")

        While tRS.%Next() {
            Set tCRId = $Piece(tRS.%Get("Key"), "/", 2)
            Set tPatientId = $Piece(tRS.%Get("patient"), "/", 2)
            Set tPatientName = tRS.%Get("patientName")
            If tPatientName = "" Set tPatientName = "Unknown"
            Set tLastModified = tRS.%Get("_lastUpdated")

            // Read risk, CPT, ICD from FHIR extension — single source of truth
            Set tRiskScore = 0.0
            Set tRiskLevel = "medium"
            Set tCptCode = "Unknown"
            Set tIcdCode = "Unknown"
            Set tBilledAmount = "0"

            Try {
                Set tReq = ##class(HS.FHIRServer.API.Data.Request).%New()
                Set tReq.RequestMethod = "GET"
                Set tReq.RequestPath = "/ClaimResponse/" _ tCRId
                Set tReq.Interaction = "read"
                Set tResp = ##class(HS.FHIRServer.API.Data.Response).%New()
                Do tService.DispatchRequest(tReq, .tResp)

                If $IsObject(tResp.Json) {
                    Set tCRJson = tResp.Json
                    If $IsObject(tCRJson.extension) {
                        Set tExtIter = tCRJson.extension.%GetIterator()
                        While tExtIter.%GetNext(.tK, .tExt) {
                            If tExt.url = "https://claimauditai.com/fhir/extension/risk-score" {
                                Set tRiskScore = +tExt.valueDecimal
                            }
                            If tExt.url = "https://claimauditai.com/fhir/extension/cpt-code" {
                                Set tCptCode = tExt.valueString
                            }
                            If tExt.url = "https://claimauditai.com/fhir/extension/icd-code" {
                                Set tIcdCode = tExt.valueString
                            }
                        }
                    }
                    If $IsObject(tCRJson.total) {
                        For tTi = 0:1:tCRJson.total.%Size()-1 {
                            Set tTotalEntry = tCRJson.total.%Get(tTi)
                            If $IsObject(tTotalEntry.amount) {
                                Set tBilledAmount = +tTotalEntry.amount.value
                                Quit
                            }
                        }
                    }
                }
            } Catch {}

            If tRiskScore >= 0.86 {
                Set tRiskLevel = "critical"
            } ElseIf tRiskScore >= 0.50 {
                Set tRiskLevel = "high"
            } Else {
                Set tRiskLevel = "medium"
            }

            Write """"_tCRId_""","
            Write """"_tPatientId_""","
            Write """"_tPatientName_""","
            Write """"_tCptCode_""","
            Write """"_tIcdCode_""","
            Write tRiskLevel_","
            Write tRiskScore_","
            Write tBilledAmount_","
            Write """"_tLastModified_""""
            Write !
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

}
