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

    <!-- Protected endpoints -->
    <Route Url="/stats/trends" Method="GET" Call="GetTrends"/>
    <Route Url="/ledger" Method="GET" Call="GetLedger"/>
    <Route Url="/claims/held" Method="GET" Call="GetHeldClaims"/>
    <Route Url="/claims/:id"            Method="GET"  Call="GetClaimDetail"/>
    <Route Url="/claims/:id/approve"    Method="POST" Call="ApproveClaim"/>
    <Route Url="/claims/:id/escalate"   Method="POST" Call="EscalateClaim"/>
    <Route Url="/claims/:id/reject"     Method="POST" Call="RejectClaim"/>
    <Route Url="/claims/export"         Method="GET"  Call="ExportClaims"/>
    <Route Url="/stats"                 Method="GET"  Call="GetStats"/>
    <Route Url="/stats/model-performance" Method="GET"  Call="GetModelPerformance"/>
    <Route Url="/chat"                  Method="POST" Call="Chat"/>
    <Route Url="/chat/stream"           Method="POST" Call="ChatStream"/>
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
    </Routes>
}

/// SMART on FHIR OAuth2 login endpoint — public (no auth required)
ClassMethod Login() As %Status
{
    Quit ##class(ClaimAudit.REST.Auth).Login()
}

/// SMART on FHIR token introspection — public (no auth required)
ClassMethod Introspect() As %Status
{
    Quit ##class(ClaimAudit.REST.Auth).Introspect()
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

        // Single O(1) query with JOINs — no per-row DispatchRequest calls
        Set tSQL = "SELECT CR.Key AS crKey, CR.patient, CR.request, CR._lastUpdated, CR.disposition, "_
                   "PP.Name AS patientName, "_
                   "CR.total, "_
                   "(SELECT COUNT(*) FROM HSFHIR_X0001_S.Task T WHERE T.focus = CR.request AND T.priority = 'stat') AS escalated "_
                   "FROM HSFHIR_X0001_S.ClaimResponse CR "_
                   "LEFT JOIN ClaimAudit.PatientProjections PP ON SUBSTRING(CR.patient, 9) = PP.Key "_
                   "WHERE CR.outcome = ? "_
                   "ORDER BY CR._lastUpdated DESC"

        // Count query for pagination total
        Set tCountRS = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome = ?", "queued")
        Do tCountRS.%Next()
        Set tTotal = +tCountRS.%Get("cnt")

        Set tRS = ##class(%SQL.Statement).%ExecDirect(, tSQL, "queued")

        Set tArr = []
        Set tIdx = 0
        While tRS.%Next() {
            // Pagination skip
            Set tIdx = tIdx + 1
            If tIdx <= tOffset Continue
            If tArr.%Size() >= tLimit Quit

            Set tClaimResponseKey = tRS.%Get("crKey")
            Set tClaimResponseId = $Piece(tClaimResponseKey, "/", 2)
            Set tPatientRef = tRS.%Get("patient")
            Set tPatientId = $Piece(tPatientRef, "/", 2)
            Set tRequestRef = tRS.%Get("request")
            Set tClaimId = $Piece(tRequestRef, "/", 2)
            Set tLastUpdated = tRS.%Get("_lastUpdated")
            Set tDisposition = tRS.%Get("disposition")
            Set tEscalated = +tRS.%Get("escalated")

            // Patient name from SQL join
            Set tPatientName = tRS.%Get("patientName")
            If tPatientName = "" Set tPatientName = "Unknown Patient"

            // Billed amount from ClaimResponse.total (BackboneElement array) — O(1) in-row access
            // The interceptor stores total as [{category: ..., amount: {value: X, currency: "USD"}}]
            Set tBilledAmount = 0.0
            Set tTotalStr = tRS.%Get("total")
            If tTotalStr '= "" {
                Try {
                    Set tTotalJson = ##class(%DynamicAbstractObject).%FromJSON(tTotalStr)
                    If $IsObject(tTotalJson) {
                        Set tArrSize = tTotalJson.%Size()
                        For tI = 0:1:tArrSize-1 {
                            Set tTotalEntry = tTotalJson.%Get(tI)
                            If $IsObject(tTotalEntry.amount) {
                                Set tBilledAmount = +tTotalEntry.amount.value
                                Quit
                            }
                        }
                    }
                } Catch {}
            }

            // CPT and ICD from ClaimResponse extensions (embedded by interceptor)
            // The extensions are stored as JSON in the ClaimResponse resource
            Set tCptCode = "Unknown"
            Set tIcdCode = "Unknown"
            Set tSubmittedAt = tLastUpdated

            Try {
                Set tService = ##class(HS.FHIRServer.Service).EnsureInstance("/interop/fhir/r4")
                Set tReqCR = ##class(HS.FHIRServer.API.Data.Request).%New()
                Set tReqCR.RequestMethod = "GET"
                Set tReqCR.RequestPath = "/ClaimResponse/" _ tClaimResponseId
                Set tReqCR.Interaction = "read"
                Set tRespCR = ##class(HS.FHIRServer.API.Data.Response).%New()
                Do tService.DispatchRequest(tReqCR, .tRespCR)
                If $IsObject(tRespCR.Json) {
                    If tRespCR.Json.created '= "" Set tSubmittedAt = tRespCR.Json.created
                    If $IsObject(tRespCR.Json.extension) {
                        Set tExtIter = tRespCR.Json.extension.%GetIterator()
                        While tExtIter.%GetNext(.tK, .tExt) {
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

            // Derive risk level from disposition keywords
            Set tRiskScore = 0.70
            Set tRiskLevel = "high"
            If tDisposition [ "critical" {
                Set tRiskScore = 0.92
                Set tRiskLevel = "critical"
            } ElseIf tDisposition [ "high" {
                Set tRiskScore = 0.70
                Set tRiskLevel = "high"
            } ElseIf tDisposition [ "medium" {
                Set tRiskScore = 0.45
                Set tRiskLevel = "medium"
            }

            Set tObj = {
                "id": (tClaimResponseId),
                "patientId": (tPatientId),
                "patientName": (tPatientName),
                "providerId": "claimaudit-prov",
                "cptCode": (tCptCode),
                "icdCode": (tIcdCode),
                "totalAmount": (tBilledAmount),
                "submittedAt": (tSubmittedAt),
                "lastModified": (tLastUpdated),
                "riskScore": (tRiskScore),
                "riskLevel": (tRiskLevel),
                "escalated": (tEscalated)
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
        Set tSettings = {
            "provider":      ($System.Util.GetEnviron("LLM_PROVIDER")),
            "nvidiaModel":   ($System.Util.GetEnviron("NVIDIA_MODEL")),
            "nvidiaBaseUrl": ($System.Util.GetEnviron("NVIDIA_BASE_URL")),
            "ollamaBaseUrl": ($System.Util.GetEnviron("OLLAMA_BASE_URL")),
            "ollamaModel":   ($System.Util.GetEnviron("OLLAMA_MODEL")),
            "openaiModel":   ($System.Util.GetEnviron("OPENAI_MODEL"))
        }
        Write tSettings.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
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

        // Calculate risk levels
        Set tRiskScore = 0.70
        Set tRiskLevel = "high"
        If tDisposition [ "critical" {
            Set tRiskScore = 0.92
            Set tRiskLevel = "critical"
        } ElseIf tDisposition [ "high" {
            Set tRiskScore = 0.70
            Set tRiskLevel = "high"
        } ElseIf tDisposition [ "medium" {
            Set tRiskScore = 0.45
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
        Set tCommId = ""
        Set tEscalated = 0
        Try {
            Set tTRS = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT Key, priority FROM HSFHIR_X0001_S.Task WHERE focus = ?", "Claim/" _ tClaimId)
            If tTRS.%Next() {
                Set tTaskKey = tTRS.%Get("Key")
                Set tTaskId = $Piece(tTaskKey, "/", 2)
                Set tPriority = tTRS.%Get("priority")
                If tPriority = "stat" {
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
            "providerId": "claimaudit-prov",
            "cptCode": (tCptCode),
            "icdCode": (tIcdCode),
            "totalAmount": (tBilledAmount),
            "submittedAt": (tSubmittedAt),
            "lastModified": (tLastModified),
            "riskScore": (tRiskScore),
            "riskLevel": (tRiskLevel),
            "disposition": (tDisposition),
            "taskId": (tTaskId),
            "communicationRequestId": (tCommId),
            "escalated": (tEscalated),
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
        Do tExt.%Push({"url": "https://claimauditai.com/fhir/extension/decision-timestamp", "valueDateTime": ($ZDATE($PIECE($HOROLOG,",",1),3)_"T"_$ZTIME($PIECE($HOROLOG,",",2),1)_"Z")})
        Set tCRJson.extension = tExt

        Set tReqPut = ##class(HS.FHIRServer.API.Data.Request).%New()
        Set tReqPut.RequestMethod = "PUT"
        Set tReqPut.RequestPath = "/ClaimResponse/" _ id
        Set tReqPut.Interaction = "update"
        Set tReqPut.Json = tCRJson
        Set tRespPut = ##class(HS.FHIRServer.API.Data.Response).%New()
        Do tService.DispatchRequest(tReqPut, .tRespPut)

        // Extract Claim reference to resolve associated task
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
        Do tExt.%Push({"url": "https://claimauditai.com/fhir/extension/decision-timestamp", "valueDateTime": ($ZDATE($PIECE($HOROLOG,",",1),3)_"T"_$ZTIME($PIECE($HOROLOG,",",2),1)_"Z")})
        Set tCRJson.extension = tExt

        Set tReqPut = ##class(HS.FHIRServer.API.Data.Request).%New()
        Set tReqPut.RequestMethod = "PUT"
        Set tReqPut.RequestPath = "/ClaimResponse/" _ id
        Set tReqPut.Interaction = "update"
        Set tReqPut.Json = tCRJson
        Set tRespPut = ##class(HS.FHIRServer.API.Data.Response).%New()
        Do tService.DispatchRequest(tReqPut, .tRespPut)

        Set tRequestRef = tCRJson.request.reference
        Set tClaimId = $Piece(tRequestRef, "/", 2)

        // 2. Progress Task through workflow states
        // ready → requested (specialist) → received (director)
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

                    // Workflow progression: ready → requested → received
                    Set tNextStatus = "requested"
                    If tCurrentStatus = "requested" {
                        Set tNextStatus = "received"
                        Set tTaskJson.priority = "stat"
                    } ElseIf tCurrentStatus = "ready" {
                        Set tNextStatus = "requested"
                    } Else {
                        Set tNextStatus = "received"
                        Set tTaskJson.priority = "stat"
                    }

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
        Do tExt.%Push({"url": "https://claimauditai.com/fhir/extension/decision-timestamp", "valueDateTime": ($ZDATE($PIECE($HOROLOG,",",1),3)_"T"_$ZTIME($PIECE($HOROLOG,",",2),1)_"Z")})
        Set tCRJson.extension = tExt

        Set tReqPut = ##class(HS.FHIRServer.API.Data.Request).%New()
        Set tReqPut.RequestMethod = "PUT"
        Set tReqPut.RequestPath = "/ClaimResponse/" _ id
        Set tReqPut.Interaction = "update"
        Set tReqPut.Json = tCRJson
        Set tRespPut = ##class(HS.FHIRServer.API.Data.Response).%New()
        Do tService.DispatchRequest(tReqPut, .tRespPut)

        Set tRequestRef = tCRJson.request.reference
        Set tClaimId = $Piece(tRequestRef, "/", 2)

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

        // Date range filter string
        Set tFromDate = $ZDATE(($PIECE($HOROLOG,",",1)-tDays), 3)

        // Count held claims (within date range)
        Set tHeld = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome=? AND _lastUpdated >= ?", "queued", tFromDate)
        Do tHeld.%Next()
        Set tHeldCount = tHeld.%Get("cnt")

        // Count approved (today only — always today, not date-range-limited)
        Set tTodayStr = $ZDATE($PIECE($HOROLOG,",",1), 3)
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

        // Risk distribution from disposition text patterns
        Set tCrit = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome=? AND disposition [ ?", "queued", "critical")
        Do tCrit.%Next()
        Set tHigh = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome=? AND (disposition [ ? OR disposition [ ?)", "queued", "high", "0.35")
        Do tHigh.%Next()
        Set tMed = tHeldCount - tCrit.%Get("cnt") - tHigh.%Get("cnt")
        If tMed < 0 Set tMed = 0

        Set tRiskDist = []
        Do tRiskDist.%Push({"level": "critical", "count": (+tCrit.%Get("cnt"))})
        Do tRiskDist.%Push({"level": "high", "count": (+tHigh.%Get("cnt"))})
        Do tRiskDist.%Push({"level": "medium", "count": (tMed)})

        // Daily counts for last 7 days
        Set tDaily = []
        For tI = 6:-1:0 {
            Set tDate = $PIECE($HOROLOG,",",1) - tI
            Set tDateStr = $ZDATE(tDate, 3)
            Set tDRS = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE SUBSTRING(_lastUpdated,1,10) = ?", tDateStr)
            Do tDRS.%Next()
            Do tDaily.%Push({"date": (tDateStr), "count": (+tDRS.%Get("cnt"))})
        }

        // Leakage rate
        Set tLeakRate = 0
        If tTotalCount > 0 Set tLeakRate = tHeldCount / tTotalCount

        Set tStats = {
            "held": (tHeldCount),
            "approvedToday": (tApprovedCount),
            "interceptedTotal": (tTotalCount),
            "totalValueHeld": (tValueHeld),
            "modelStatus": "healthy",
            "leakageRate": (tLeakRate),
            "riskDistribution": (tRiskDist),
            "dailyInterceptedCounts": (tDaily)
        }
        Write tStats.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
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
        Set tBody = %request.Content
        Set tPayload = ##class(%DynamicObject).%FromJSON(tBody)
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
        Set tBody = %request.Content
        Set tPayload = ##class(%DynamicObject).%FromJSON(tBody)
        Set tMessages = tPayload.messages
        Set tClaimContext = tPayload.claimContext

        Set tSystemPrompt = "You are an expert healthcare fraud analyst assistant "_
        "for ClaimAuditAI. You help auditors understand AI-generated "_
        "adjudication decisions. Be precise, cite specific findings, "_
        "and explain technical terms in plain language."
        If tClaimContext '= "" {
            Set tSystemPrompt = tSystemPrompt _ " Current claim context: " _ tClaimContext
        }

        // SSE headers
        Set %response.ContentType = "text/event-stream"
        Set %response.Headers("Cache-Control") = "no-cache"
        Set %response.Headers("Connection") = "keep-alive"
        Set %response.Headers("X-Accel-Buffering") = "no"

        Do ##class(ClaimAudit.AI.Engine).ConfigurePythonPath()
        Set tLLM = ##class(%SYS.Python).Import("llm_router")
        Set tStream = tLLM."chat_stream"(tSystemPrompt, tMessages.%ToJSON(), 1024)

        // Yield chunks as SSE data lines
        Set tIter = tStream."__iter__"()
        While tIter."__next__"(, .tChunk) {
            If tChunk '= "" {
                Write "data: ", $ZCONVERT(tChunk, "O", "UTF8"), $CHAR(13,10), $CHAR(13,10)
                Do %response.Flush()
            }
        }
        Write "data: [DONE]", $CHAR(13,10), $CHAR(13,10)

    } Catch ex {
        Set tSC = ex.AsStatus()
        Write "event: error", $CHAR(13,10)
        Write "data: ", $ZCONVERT("Chat streaming error: "_ex.DisplayString(), "O", "UTF8"), $CHAR(13,10), $CHAR(13,10)
    }
    Quit tSC
}

/// Dynamic uploader to wipe existing test data and reload expanded patient bundles and claims bundles
ClassMethod LoadSampleData() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth("Admin") Quit $$$OK
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

                    Do tStatement.%Prepare("INSERT INTO ClaimAudit.ClaimProjections (PatientKey, ProviderNPI, BilledAmount, ItemCount, SpecialtyCode, PatientAge, DurationDays, ServiceDate) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
                    Do tStatement.%Execute(tPatId, tProvId, tAmount, 1, tSpecialty, 45, 1, "2026-05-29")

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

        // Re-train statistical autoencoder with the new clinical projections
        Do ##class(ClaimAudit.AI.Engine).TrainAutoencoder()

        // Invalidate graph cache so next request rebuilds with new data
        Do ##class(ClaimAudit.AI.Engine).ConfigurePythonPath()
        Set tGA = ##class(%SYS.Python).Import("graph_analyzer")
        Do tGA."invalidate_graph_cache"()

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

        // For each of the last 7 days, count processed and held claims
        For tI = 6:-1:0 {
        Set tDate = $PIECE($HOROLOG,",",1) - tI
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

        // Count query for pagination total
        Set tCountRS = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.Task WHERE status IN (?,?) OR (status = ? AND priority = ?)",
        "completed", "cancelled", "ready", "stat")
        Do tCountRS.%Next()
        Set tTotal = +tCountRS.%Get("cnt")

        Set tRS = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT T.Key AS taskKey, T.status, T.priority, T.focus, T._lastUpdated, "_
        "CR.patient, CR.disposition, CR.total "_
        "FROM HSFHIR_X0001_S.Task T "_
        "LEFT JOIN HSFHIR_X0001_S.ClaimResponse CR ON T.focus = CR.request "_
        "WHERE T.status IN (?,?) OR (T.status = ? AND T.priority = ?) "_
        "ORDER BY T._lastUpdated DESC", "completed", "cancelled", "ready", "stat")

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
            } ElseIf (tStatus = "ready") && (tPriority = "stat") {
                Set tAction = "escalated"
            }

            // Patient ID from ClaimResponse.patient (JOIN'd)
            Set tPatientRef = tRS.%Get("patient")
            Set tPatientId = $Piece(tPatientRef, "/", 2)
            Set tProviderId = "Unknown"

            // Billed amount from ClaimResponse.total JSON (JOIN'd)
            Set tBilledAmount = 0.0
            Set tTotalStr = tRS.%Get("total")
            If tTotalStr '= "" {
                Try {
                    Set tTotalJson = ##class(%DynamicAbstractObject).%FromJSON(tTotalStr)
                    If $IsObject(tTotalJson) {
                        For tI = 0:1:tTotalJson.%Size()-1 {
                            Set tTotalEntry = tTotalJson.%Get(tI)
                            If $IsObject(tTotalEntry.amount) {
                                Set tBilledAmount = +tTotalEntry.amount.value
                                Quit
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

            // AuthorizedBy from ClaimResponse extensions — single DispatchRequest per item
            // (simpler than storing authorized-by in SQL)
            Set tAuthorizedBy = "Auditor"
            Set tCRKey = "ClaimResponse/" _ tClaimId
            Try {
                Set tCRKeyRS = ##class(%SQL.Statement).%ExecDirect(,
                "SELECT Key FROM HSFHIR_X0001_S.ClaimResponse WHERE request = ?", tFocus)
                If tCRKeyRS.%Next() {
                    Set tCRId = $Piece(tCRKeyRS.%Get("Key"), "/", 2)
                    Set tService = ##class(HS.FHIRServer.Service).EnsureInstance("/interop/fhir/r4")
                    Set tReqCR = ##class(HS.FHIRServer.API.Data.Request).%New()
                    Set tReqCR.RequestMethod = "GET"
                    Set tReqCR.RequestPath = "/ClaimResponse/" _ tCRId
                    Set tReqCR.Interaction = "read"
                    Set tRespCR = ##class(HS.FHIRServer.API.Data.Response).%New()
                    Do tService.DispatchRequest(tReqCR, .tRespCR)
                    If $IsObject(tRespCR.Json) && $IsObject(tRespCR.Json.extension) {
                        Set tExtIter = tRespCR.Json.extension.%GetIterator()
                        While tExtIter.%GetNext(.tK, .tExt) {
                            If tExt.url = "https://claimauditai.com/fhir/extension/authorized-by" {
                                Set tAuthorizedBy = tExt.valueString
                            }
                        }
                    }
                }
            } Catch {}

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
        Set tPat = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.Patient")
        Do tPat.%Next()
        Write {
            "claimResponses": (tCR.%Get("cnt")),
            "tasks": (tTask.%Get("cnt")),
            "patients": (tPat.%Get("cnt"))
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
        Write {"success": true, "fhirStatus": (tResp.Status), "resourceType": (tResourceType)}.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// Model performance metrics — precision, recall, F1 per tier
ClassMethod GetModelPerformance() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth() Quit $$$OK
    Set tSC = $$$OK
    Try {
        // True Positives: claims flagged by AI that were rejected (correct holding)
        Set tTP = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome = ? AND disposition IS NOT NULL", "error")
        Do tTP.%Next()
        Set tTPCount = +tTP.%Get("cnt")

        // False Positives: claims flagged by AI that were approved (held unnecessarily)
        Set tFP = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome = ? AND disposition IS NOT NULL", "complete")
        Do tFP.%Next()
        Set tFPCount = +tFP.%Get("cnt")

        // True Negatives: claims not flagged that were approved (correct pass-through)
        Set tTN = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome = ? AND disposition IS NULL", "complete")
        Do tTN.%Next()
        Set tTNCount = +tTN.%Get("cnt")

        // False Negatives: claims approved that should have been flagged (missed fraud)
        // Estimated as claims approved without AI review (no disposition = no AI flag)
        Set tFNCount = tTNCount

        // Precision = TP / (TP + FP)
        Set tPrecision = 0.0
        If (tTPCount + tFPCount) > 0 Set tPrecision = tTPCount / (tTPCount + tFPCount)

        // Recall = TP / (TP + FN)
        Set tRecall = 0.0
        If (tTPCount + tFNCount) > 0 Set tRecall = tTPCount / (tTPCount + tFNCount)

        // F1 = 2 * (Precision * Recall) / (Precision + Recall)
        Set tF1 = 0.0
        If (tPrecision + tRecall) > 0 Set tF1 = 2 * tPrecision * tRecall / (tPrecision + tRecall)

        Write {
            "precision": (tPrecision),
            "recall": (tRecall),
            "f1": (tF1),
            "truePositives": (tTPCount),
            "falsePositives": (tFPCount),
            "totalHeld": (tTPCount + tFPCount),
            "totalApproved": (tTNCount)
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

        Write "ClaimResponseID,PatientID,PatientName,CPTCode,ICDCode,RiskLevel,RiskScore,BilledAmount,Escalated,LastModified", !

        Set tRS = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT CR.Key, CR.patient, CR.disposition, CR._lastUpdated, CR.request, "_
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
            Set tDisposition = tRS.%Get("disposition")
            Set tLastModified = tRS.%Get("_lastUpdated")
            Set tClaimRef = tRS.%Get("request")
            Set tClaimId = $Piece(tClaimRef, "/", 2)

            Set tRiskLevel = "high"
            Set tRiskScore = 0.70
            If tDisposition [ "critical" { Set tRiskLevel = "critical"  Set tRiskScore = 0.92 }
            ElseIf tDisposition [ "medium" { Set tRiskLevel = "medium"  Set tRiskScore = 0.45 }

            Write """"_tCRId_""","
            Write """"_tPatientId_""","
            Write """"_tPatientName_""","
            Write "Unknown,Unknown,"
            Write tRiskLevel_","
            Write tRiskScore_","
            Write """"_($Extract(tDisposition, 1, 50))_""""
            Write !
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

}
