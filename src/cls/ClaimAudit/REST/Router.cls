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
    <Route Url="/stats"                 Method="GET"  Call="GetStats"/>
    <Route Url="/chat"                  Method="POST" Call="Chat"/>
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

/// Returns all ClaimResponse resources with outcome=queued (HOLD status) mapped with Claim details
ClassMethod GetHeldClaims() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth() Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tService = ##class(HS.FHIRServer.Service).EnsureInstance("/interop/fhir/r4")
        Set tRS = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Key, patient, request, _lastUpdated, disposition FROM HSFHIR_X0001_S.ClaimResponse "_
        "WHERE outcome = ? ORDER BY _lastUpdated DESC", "queued")

        Set tArr = []
        While tRS.%Next() {
            Set tClaimResponseKey = tRS.%Get("Key")
            Set tClaimResponseId = $Piece(tClaimResponseKey, "/", 2)
            Set tPatientRef = tRS.%Get("patient")
            Set tPatientId = $Piece(tPatientRef, "/", 2)
            Set tRequestRef = tRS.%Get("request")
            Set tClaimId = $Piece(tRequestRef, "/", 2)
            Set tLastUpdated = tRS.%Get("_lastUpdated")
            Set tDisposition = tRS.%Get("disposition")

            // Default values in case Claim fetch fails
            Set tCptCode = "Unknown"
            Set tIcdCode = "Unknown"
            Set tBilledAmount = 0.0
            Set tSubmittedAt = tLastUpdated

            // Programmatically fetch patient name from FHIR Patient resource
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

            // Programmatically fetch the associated Claim resource to read details
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

                        // Parse CPT code
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

                        // Parse ICD code
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

            // Fallback: if Claim fetch failed (Claim not persisted by interceptor),
            // read the total from the ClaimResponse's own stored JSON
            If tBilledAmount = 0 {
                Try {
                    Set tReqCR = ##class(HS.FHIRServer.API.Data.Request).%New()
                    Set tReqCR.RequestMethod = "GET"
                    Set tReqCR.RequestPath = "/ClaimResponse/" _ tClaimResponseId
                    Set tReqCR.Interaction = "read"
                    Set tRespCR = ##class(HS.FHIRServer.API.Data.Response).%New()
                    Do tService.DispatchRequest(tReqCR, .tRespCR)
                    If $IsObject(tRespCR.Json) && $IsObject(tRespCR.Json.total) && (tRespCR.Json.total.%Size() > 0) {
                        Set tTotalItem = tRespCR.Json.total.%Get(0)
                        If $IsObject(tTotalItem.amount) {
                            Set tBilledAmount = +tTotalItem.amount.value
                        }
                    }
                } Catch {}
            }

            // Derive risk level from disposition keywords (consistent with GetStats)
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

            // Check if this claim was escalated to director
            Set tEscalated = 0
            If tClaimId '= "" {
                Set tTRS = ##class(%SQL.Statement).%ExecDirect(,
                "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.Task WHERE focus = ? AND priority = ?", "Claim/" _ tClaimId, "stat")
                If tTRS.%Next() {
                    If tTRS.%Get("cnt") > 0 Set tEscalated = 1
                }
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
        Write tArr.%ToJSON()
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

/// Escalate a held claim — sets Task priority to stat, keeps ClaimResponse queued with escalated flag
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

        // 2. Fetch and escalate Task
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
                    Set tTaskJson.priority = "stat"
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

/// System metrics: held count, approved today, throughput, model health
ClassMethod GetStats() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth() Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tService = ##class(HS.FHIRServer.Service).EnsureInstance("/interop/fhir/r4")

        // Count held claims
        Set tHeld = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome=?", "queued")
        Do tHeld.%Next()
        Set tHeldCount = tHeld.%Get("cnt")

        // Count approved (today only)
        Set tTodayStr = $ZDATE($PIECE($HOROLOG,",",1), 3)
        Set tApproved = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome=? AND SUBSTRING(_lastUpdated,1,10) = ?", "complete", tTodayStr)
        Do tApproved.%Next()
        Set tApprovedCount = tApproved.%Get("cnt")

        // Total intercepted
        Set tTotal = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse")
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

/// Override audit ledger — derived from Task and ClaimResponse history
ClassMethod GetLedger() As %Status
{
    If '##class(ClaimAudit.REST.Auth).RequireAuth() Quit $$$OK
    Set tSC = $$$OK
    Try {
        Set tArr = []
        Set tService = ##class(HS.FHIRServer.Service).EnsureInstance("/interop/fhir/r4")

        // Query completed tasks (approved), stat-priority tasks (escalated), and cancelled tasks (rejected)
        Set tRS = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Key, status, priority, focus, _lastUpdated FROM HSFHIR_X0001_S.Task "_
        "WHERE status IN (?,?) OR (status = ? AND priority = ?) ORDER BY _lastUpdated DESC", "completed", "cancelled", "ready", "stat")

        While tRS.%Next() {
            Set tTaskKey = tRS.%Get("Key")
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

            // Fetch claim details for amount and context
            Set tBilledAmount = 0
            Set tPatientId = ""
            Set tProviderId = ""
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
                        If $IsObject(tClaimJson.total) Set tBilledAmount = +tClaimJson.total.value
                        If tClaimJson.patient.reference '= "" Set tPatientId = $Piece(tClaimJson.patient.reference, "/", 2)
                        If tClaimJson.provider.reference '= "" Set tProviderId = $Piece(tClaimJson.provider.reference, "/", 2)
                    }
                } Catch {}
            }

            // Fetch ClaimResponse disposition and authorizedBy for override rationale
            Set tReason = ""
            Set tAuthorizedBy = "Auditor"
            Try {
                Set tCRRS = ##class(%SQL.Statement).%ExecDirect(,
                "SELECT Key, disposition FROM HSFHIR_X0001_S.ClaimResponse WHERE request = ?", "Claim/" _ tClaimId)
                If tCRRS.%Next() {
                    Set tCRKey = tCRRS.%Get("Key")
                    Set tCRId = $Piece(tCRKey, "/", 2)
                    Set tDisp = tCRRS.%Get("disposition")
                    If tAction = "approved" {
                        Set tReason = "Auditor override: claim approved for disbursal. " _ $Extract(tDisp, 1, 200)
                    } ElseIf tAction = "rejected" {
                        Set tReason = "Claim denied by auditor review. " _ $Extract(tDisp, 1, 200)
                    } Else {
                        Set tReason = "Escalated for peer review. " _ $Extract(tDisp, 1, 200)
                    }
                    // Read authorizedBy from ClaimResponse FHIR extension
                    If tCRId '= "" {
                        Try {
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
                        } Catch {}
                    }
                }
            } Catch {}

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
        Write tArr.%ToJSON()
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

}
