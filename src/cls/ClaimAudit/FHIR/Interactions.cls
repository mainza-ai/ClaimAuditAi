Class ClaimAudit.FHIR.Interactions Extends HS.FHIRServer.Storage.Json.Interactions
{

/// Intercept requests before they are processed by the storage engine
Method OnBeforeRequest(pFHIRService As HS.FHIRServer.API.Service, pFHIRRequest As HS.FHIRServer.API.Data.Request, pTimeout As %Integer)
{
    // Clean process private flag variables for this thread only for new Claim requests
    If (pFHIRRequest.Type = "Claim") || (pFHIRRequest.Type = "Bundle") {
        Kill ^||ClaimAuditFlag
    }
    
    // Intercept POST/PUT Claim creations (direct or inside Bundle entries)
    If $IsObject(pFHIRRequest.Json) {
        If pFHIRRequest.Type = "Claim" {
            Do ..AuditSingleClaim(pFHIRRequest.Json)
        } ElseIf (pFHIRRequest.Type = "Bundle") && $IsObject(pFHIRRequest.Json.entry) {
            Set tIter = pFHIRRequest.Json.entry.%GetIterator()
            While tIter.%GetNext(.tKey, .tEntry) {
                If $IsObject(tEntry.resource) && (tEntry.resource.resourceType = "Claim") {
                    Do ..AuditSingleClaim(tEntry.resource)
                }
            }
        }
    }
    
    // Continue standard interceptor processing

    Quit $$$OK
}

/// Run the three-tier audit engine on a single Claim JSON object and record flags
Method AuditSingleClaim(pClaimJson As %DynamicObject, pIndex As %String = "single") [ Private ]
{
    Set tSC = ##class(ClaimAudit.AI.Engine).AuditClaim(pClaimJson, .tAuditResult)
    If tAuditResult.flagged = 1 {
        // Use tier reasons directly - LLM generation is deferred to JIT on-demand
        // to prevent synchronous timeouts during ingestion
        Set tReasons = tAuditResult.reasons
        Set tReasonStr = ""
        Set tReasonIter = tReasons.%GetIterator()
        While tReasonIter.%GetNext(.tK, .tVR) {
            If tReasonStr '= "" Set tReasonStr = tReasonStr _ " | "
            Set tReasonStr = tReasonStr _ tVR
        }
        
        Set summary = "Payment Integrity Adjudication HOLD Notification. " _ tReasonStr
        
        // Record audit flags and summaries in thread-safe process memory
        Set ^||ClaimAuditFlag(pIndex, "flagged") = 1
        Set ^||ClaimAuditFlag(pIndex, "summary") = summary
        Set ^||ClaimAuditFlag(pIndex, "score") = tAuditResult.score
        Set ^||ClaimAuditFlag(pIndex, "patientId") = tAuditResult.patientId
        Set ^||ClaimAuditFlag(pIndex, "providerNpi") = tAuditResult.providerNpi
        Set ^||ClaimAuditFlag(pIndex, "billedAmount") = tAuditResult.billedAmount
        If $IsObject(tAuditResult.tierResults) {
            Set ^||ClaimAuditFlag(pIndex, "tierResults") = tAuditResult.tierResults.%ToJSON()
        }

        If $IsObject(pClaimJson.patient) {
            Set ^||ClaimAuditFlag(pIndex, "patient") = pClaimJson.patient.%ToJSON()
        }
        If $IsObject(pClaimJson.type) {
            Set ^||ClaimAuditFlag(pIndex, "type") = pClaimJson.type.%ToJSON()
        }
        If $IsObject(pClaimJson.total) {
            Set ^||ClaimAuditFlag(pIndex, "total") = pClaimJson.total.%ToJSON()
        }

        // Store CPT codes list
        Set tCptArr = ##class(%DynamicArray).%New()
        If $IsObject(pClaimJson.item) {
            Set tItemIter = pClaimJson.item.%GetIterator()
            While tItemIter.%GetNext(.tItemK, .tItem) {
                If $IsObject(tItem.productOrService) && $IsObject(tItem.productOrService.coding) {
                    Set tCodingIter = tItem.productOrService.coding.%GetIterator()
                    While tCodingIter.%GetNext(.tCodingK, .tCoding) {
                        Set tCPT = tCoding.code
                        If tCPT '= "" Do tCptArr.%Push(tCPT)
                    }
                }
            }
        }
        Set ^||ClaimAuditFlag(pIndex, "cptCodes") = tCptArr.%ToJSON()

        // Store ICD codes list
        Set tIcdArr = ##class(%DynamicArray).%New()
        If $IsObject(pClaimJson.diagnosis) {
            Set tDiagIter = pClaimJson.diagnosis.%GetIterator()
            While tDiagIter.%GetNext(.tDiagK, .tDiag) {
                If $IsObject(tDiag.diagnosisCodeableConcept) && $IsObject(tDiag.diagnosisCodeableConcept.coding) {
                    Set tCodingIter = tDiag.diagnosisCodeableConcept.coding.%GetIterator()
                    While tCodingIter.%GetNext(.tCodingK, .tCoding) {
                        Set tICD = tCoding.code
                        If tICD '= "" Do tIcdArr.%Push(tICD)
                    }
                }
            }
        }
        Set ^||ClaimAuditFlag(pIndex, "icdCodes") = tIcdArr.%ToJSON()
        
        Set ^||ClaimAuditFlag("any_flagged") = 1
    }
}

/// Intercept requests AFTER they have been processed by the storage engine
Method OnAfterRequest(pFHIRService As HS.FHIRServer.API.Service, pFHIRRequest As HS.FHIRServer.API.Data.Request, pFHIRResponse As HS.FHIRServer.API.Data.Response, pTimeout As %Integer)
{
    // Execute standard post-processing
    Do ##super(pFHIRService, pFHIRRequest, pFHIRResponse)
    
    Set ^ClaimAuditLog($ZTS, "type") = pFHIRRequest.Type
    Set ^ClaimAuditLog($ZTS, "status") = pFHIRResponse.Status
    Set ^ClaimAuditLog($ZTS, "isjson") = $IsObject(pFHIRRequest.Json)
    
    // Intercept POST/PUT DocumentReference creations to index progress notes
    If (pFHIRRequest.Type = "DocumentReference") && $IsObject(pFHIRRequest.Json) && ($Extract(pFHIRResponse.Status, 1) = "2") {
        Try {
            Set docId = pFHIRResponse.Id
            If docId = "" Set docId = $Piece(pFHIRResponse.ETag, "/", 1)
            
            Set docJson = pFHIRRequest.Json
            Set patientRef = ""
            If $IsObject(docJson.subject) {
                Set patientRef = docJson.subject.reference
            }
            Set patientId = $Piece(patientRef, "/", *)
            
            // Extract note date
            Set docDate = ""
            If docJson.date '= "" {
                Set docDate = $Extract(docJson.date, 1, 10)
            } ElseIf docJson.created '= "" {
                Set docDate = $Extract(docJson.created, 1, 10)
            }
            
            // Extract the base64 clinical note data
            Set base64Data = ""
            If $IsObject(docJson.content) && (docJson.content.%Size() > 0) {
                Set contentItem = docJson.content.%Get(0)
                If $IsObject(contentItem.attachment) {
                    Set base64Data = contentItem.attachment.data
                }
            }
            
            If (patientId '= "") && (docId '= "") && (base64Data '= "") {
                // Decode base64 note text
                Set decodedNote = $system.Encryption.Base64Decode(base64Data)
                
                // Index the note in the vector database with date
                Set tSC = ##class(ClaimAudit.AI.Engine).IndexNote(patientId, docId, decodedNote, docDate)
                If $$$ISERR(tSC) {
                    Set ^ClaimAuditIndexError($ZTS) = $System.Status.GetErrorText(tSC)
                }
            }
        } Catch ex {
            Set ^ClaimAuditIndexError($ZTS) = ex.DisplayString()
        }
    }

    // If the request was a Bundle, unpack and index any DocumentReference resources inside
    If $IsObject(pFHIRRequest.Json) && (pFHIRRequest.Json.resourceType = "Bundle") && ($Extract(pFHIRResponse.Status, 1) = "2") {
        Try {
            Set bundleJson = pFHIRRequest.Json
            If $IsObject(bundleJson.entry) {
                Set iter = bundleJson.entry.%GetIterator()
                While iter.%GetNext(.key, .entry) {
                    If $IsObject(entry.resource) && (entry.resource.resourceType = "DocumentReference") {
                        Set docJson = entry.resource
                        Set docId = docJson.id
                        If docId = "" {
                            If $IsObject(entry.request) && (entry.request.url '= "") {
                                Set docId = $Piece(entry.request.url, "/", *)
                            }
                        }
                        
                        Set patientRef = ""
                        If $IsObject(docJson.subject) {
                            Set patientRef = docJson.subject.reference
                        }
                        Set patientId = $Piece(patientRef, "/", *)
                        
                        Set docDate = ""
                        If docJson.date '= "" {
                            Set docDate = $Extract(docJson.date, 1, 10)
                        } ElseIf docJson.created '= "" {
                            Set docDate = $Extract(docJson.created, 1, 10)
                        }
                        
                        Set base64Data = ""
                        If $IsObject(docJson.content) && (docJson.content.%Size() > 0) {
                            Set contentItem = docJson.content.%Get(0)
                            If $IsObject(contentItem.attachment) {
                                Set base64Data = contentItem.attachment.data
                            }
                        }
                        
                        If (patientId '= "") && (docId '= "") && (base64Data '= "") {
                            Set decodedNote = $system.Encryption.Base64Decode(base64Data)
                            Do ##class(ClaimAudit.AI.Engine).IndexNote(patientId, docId, decodedNote, docDate)
                        }
                    }
                }
            }
        } Catch ex {
            Set ^ClaimAuditIndexError($ZTS) = ex.DisplayString()
        }
    }
    
    // If single claim request was flagged as an anomaly, mutate response and save audit records
    If (pFHIRRequest.Type = "Claim") && ($Get(^||ClaimAuditFlag("single", "flagged")) = 1) {
        Try {
            // Retrieve all data from process-private global first to ensure it's not lost
            Set summary = $Get(^||ClaimAuditFlag("single", "summary"))
            Set score = $Get(^||ClaimAuditFlag("single", "score"))
            Set tCptCodesJSON = $Get(^||ClaimAuditFlag("single", "cptCodes"))
            Set tIcdCodesJSON = $Get(^||ClaimAuditFlag("single", "icdCodes"))
            Set totalStr = $Get(^||ClaimAuditFlag("single", "total"))
            Set tProviderNpi = $Get(^||ClaimAuditFlag("single", "providerNpi"))
            Set tTierResultsJSON = $Get(^||ClaimAuditFlag("single", "tierResults"))
            
            Set patientStr = $Get(^||ClaimAuditFlag("single", "patient"))
            Set patientRef = ""
            If patientStr '= "" {
                Set patientRef = ##class(%DynamicObject).%FromJSON(patientStr)
            } Else {
                Set patientRef = { "reference": "Patient/unknown" }
            }
            
            Set typeStr = $Get(^||ClaimAuditFlag("single", "type"))
            Set claimType = ""
            If typeStr '= "" {
                Set claimType = ##class(%DynamicObject).%FromJSON(typeStr)
            } Else {
                Set claimType = {
                    "coding": [
                        {
                            "system": "http://terminology.hl7.org/CodeSystem/claim-type",
                            "code": "professional"
                        }
                    ]
                }
            }
            
            // Clear flags now that all variables are retrieved to prevent infinite recursion
            Kill ^||ClaimAuditFlag

            Set claimId = pFHIRResponse.Id
            If claimId = "" Set claimId = $Piece(pFHIRResponse.ETag, "/", 1)
            If claimId = "" Set claimId = pFHIRRequest.Json.id

            Set claimJson = pFHIRRequest.Json
            Set createdTime = $Translate($ZDateTime($ZTIMESTAMP, 3, 1), " ", "T") _ "Z"

            // Construct native FHIR transaction Bundle containing ClaimResponse, Task, and CommunicationRequest
            Set bundle = {
                "resourceType": "Bundle",
                "type": "transaction",
                "entry": []
            }

            // 1. Create FHIR ClaimResponse resource with "outcome" = "queued" (PENDED/HOLD status)
            Set claimResponse = {
                "resourceType": "ClaimResponse",
                "status": "active",
                "use": "claim",
                "type": (claimType),
                "patient": (patientRef),
                "created": (createdTime),
                "insurer": { "reference": "Organization/claimaudit-payer" },
                "outcome": "queued",
                "disposition": (summary),
                "request": { "reference": ("Claim/" _ claimId) }
            }
            
            If totalStr '= "" {
                Set totalAmount = ##class(%DynamicObject).%FromJSON(totalStr)
                Set tTotalObj = {
                    "category": {"coding": [{"system": "http://terminology.hl7.org/CodeSystem/adjudication", "code": "submitted"}]},
                    "amount": (totalAmount)
                }
                Set tTotalArr = ##class(%DynamicArray).%New()
                Do tTotalArr.%Push(tTotalObj)
                Set claimResponse.total = tTotalArr
            } ElseIf $IsObject(claimJson) && $IsObject(claimJson.total) {
                Set tTotalObj = {
                    "category": {"coding": [{"system": "http://terminology.hl7.org/CodeSystem/adjudication", "code": "submitted"}]},
                    "amount": (claimJson.total)
                }
                Set tTotalArr = ##class(%DynamicArray).%New()
                Do tTotalArr.%Push(tTotalObj)
                Set claimResponse.total = tTotalArr
            }

            // Embed CPT, ICD, risk score, and full explanation as extensions so they can be read without the Claim resource and bypass length limitations
            Set tExtensions = []
            Do tExtensions.%Push({"url": "https://claimauditai.com/fhir/extension/risk-score", "valueDecimal": (score)})
            Do tExtensions.%Push({"url": "https://claimauditai.com/fhir/extension/explanation", "valueString": (summary)})
            If tCptCodesJSON '= "" {
                Do tExtensions.%Push({"url": "https://claimauditai.com/fhir/extension/cpt-codes", "valueString": (tCptCodesJSON)})
                Set tCptArr = ##class(%DynamicArray).%FromJSON(tCptCodesJSON)
                If tCptArr.%Size() > 0 {
                    Do tExtensions.%Push({"url": "https://claimauditai.com/fhir/extension/cpt-code", "valueString": (tCptArr.%Get(0))})
                }
            }
            If tIcdCodesJSON '= "" {
                Do tExtensions.%Push({"url": "https://claimauditai.com/fhir/extension/icd-codes", "valueString": (tIcdCodesJSON)})
                Set tIcdArr = ##class(%DynamicArray).%FromJSON(tIcdCodesJSON)
                If tIcdArr.%Size() > 0 {
                    Do tExtensions.%Push({"url": "https://claimauditai.com/fhir/extension/icd-code", "valueString": (tIcdArr.%Get(0))})
                }
            }
            If tProviderNpi '= "" {
                Do tExtensions.%Push({"url": "https://claimauditai.com/fhir/extension/provider-npi", "valueString": (tProviderNpi)})
            }
            If tTierResultsJSON '= "" {
                Do tExtensions.%Push({"url": "https://claimauditai.com/fhir/extension/tier-results", "valueString": (tTierResultsJSON)})
            }
            Set claimResponse.extension = tExtensions

            Set crEntry = {
                "fullUrl": "https://claimauditai.com/fhir/ClaimResponse/claimresponse-1",
                "resource": (claimResponse),
                "request": {
                    "method": "POST",
                    "url": "ClaimResponse"
                }
            }
            Do bundle.entry.%Push(crEntry)

            // 2. Create FHIR Task resource to route to manual audit review queues
            Set auditTask = {
                "resourceType": "Task",
                "status": "ready",
                "intent": "order",
                "priority": "urgent",
                "code": {
                    "coding": [
                        {
                            "system": "http://hl7.org/fhir/CodeSystem/task-code",
                            "code": "review",
                            "display": "Claim Audit Review"
                        }
                    ]
                },
                "focus": { "reference": ("Claim/" _ claimId) },
                "owner": { "reference": "Practitioner/claimaudit-auditor" },
                "description": ("Adjudication Score: " _ score _ ". Risk Reasons: " _ summary)
            }
            Set taskEntry = {
                "fullUrl": "urn:uuid:task-1",
                "resource": (auditTask),
                "request": {
                    "method": "POST",
                    "url": "Task"
                }
            }
            Do bundle.entry.%Push(taskEntry)

            // 3. Create FHIR CommunicationRequest containing Hold Notification for Provider (linked to temporary ClaimResponse UUID)
            Set commRequest = {
                "resourceType": "CommunicationRequest",
                "status": "active",
                "category": [
                    {
                        "coding": [
                            {
                               "system": "http://terminology.hl7.org/CodeSystem/communication-category",
                                "code": "notification",
                                "display": "Claim Hold Notification"
                              }
                        ]
                    }
                ],
                "payload": [
                    {
                        "contentString": (summary)
                    }
                ],
                "about": [
                    { "reference": ("Claim/" _ claimId) },
                    { "reference": "https://claimauditai.com/fhir/ClaimResponse/claimresponse-1" }
                ]
            }
            Set commEntry = {
                "fullUrl": "urn:uuid:communicationrequest-1",
                "resource": (commRequest),
                "request": {
                    "method": "POST",
                    "url": "CommunicationRequest"
                }
            }
            Do bundle.entry.%Push(commEntry)

            // Submit the entire transaction Bundle atomically
            Set tRequestBundle = ##class(HS.FHIRServer.API.Data.Request).%New()
            Set tRequestBundle.RequestMethod = "POST"
            Set tRequestBundle.RequestPath = "" // Transaction Bundle root
            Set tRequestBundle.Interaction = "transaction"
            Set tRequestBundle.Json = bundle
            Set tResponseBundle = ##class(HS.FHIRServer.API.Data.Response).%New()
            Do pFHIRService.DispatchRequest(tRequestBundle, .tResponseBundle)

            If ($Extract(tResponseBundle.Status, 1) '= "2") {
                Set ^ClaimAuditStatusLog($ZTS, "Bundle", "status") = tResponseBundle.Status
                If $IsObject(tResponseBundle.Json) {
                    Set ^ClaimAuditStatusLog($ZTS, "Bundle", "error") = tResponseBundle.Json.%ToJSON()
                }
                Set pFHIRResponse.Status = 500
                Set pFHIRResponse.Json = {"error": "Failed to execute atomic FHIR transaction Bundle"}
                Quit
            }

            // Extract created ClaimResponse ID from transaction-response
            Set tCreatedCRId = ""
            If $IsObject(tResponseBundle.Json) && $IsObject(tResponseBundle.Json.entry) {
                Set tCRRespEntry = tResponseBundle.Json.entry.%Get(0)
                If $IsObject(tCRRespEntry) && $IsObject(tCRRespEntry.response) {
                    Set tLocation = tCRRespEntry.response.location
                    Set tCreatedCRId = $Piece(tLocation, "/", 2)
                }
            }
            If tCreatedCRId '= "" {
                Set claimResponse.id = tCreatedCRId
            }

            Set ^ClaimAuditStatusLog($ZTS, "Bundle", "status") = tResponseBundle.Status
            Set ^ClaimAuditStatusLog($ZTS, "Bundle", "id") = tCreatedCRId

            // Mutate outgoing response HTTP payload to return the queued ClaimResponse to submitting provider
            Set pFHIRResponse.Json = claimResponse
            Set pFHIRResponse.Status = 202

        } Catch ex {
            Set ^ClaimAuditError($ZTS) = ex.DisplayString()
        }
    }
    
    // If batch/transaction Bundle claim requests were flagged, mutate response entries and create hold records
    If (pFHIRRequest.Type = "Bundle") && ($Get(^||ClaimAuditFlag("any_flagged")) = 1) && ($Extract(pFHIRResponse.Status, 1) = "2") {
        Try {
            // Construct a single native FHIR transaction Bundle containing holds for all flagged claims
            Set holdsBundle = {
                "resourceType": "Bundle",
                "type": "transaction",
                "entry": []
            }
            
            // Temporary storage for mapping and response mutation
            Set tFlaggedEntries = ##class(%ArrayOfDataTypes).%New()
            Set tTempClaimResponse = ##class(%ArrayOfDataTypes).%New()
            
            Set tRespIter = pFHIRResponse.Json.entry.%GetIterator()
            While tRespIter.%GetNext(.tKey, .tRespEntry) {
                If $Get(^||ClaimAuditFlag(tKey, "flagged")) = 1 {
                    Set tLocation = ""
                    If $IsObject(tRespEntry) && $IsObject(tRespEntry.response) {
                        Set tLocation = tRespEntry.response.location
                    }
                    Set tClaimId = $Piece(tLocation, "/", 2)
                    If tClaimId = "" {
                        Set tReqEntry = pFHIRRequest.Json.entry.%Get(tKey)
                        If $IsObject(tReqEntry) && $IsObject(tReqEntry.resource) {
                            Set tClaimId = tReqEntry.resource.id
                        }
                    }
                    
                    If tClaimId '= "" {
                        Do tFlaggedEntries.SetAt(tClaimId, tKey)
                        
                        Set summary = ^||ClaimAuditFlag(tKey, "summary")
                        Set score = ^||ClaimAuditFlag(tKey, "score")
                        Set tCptCodesJSON = $Get(^||ClaimAuditFlag(tKey, "cptCodes"))
                        Set tIcdCodesJSON = $Get(^||ClaimAuditFlag(tKey, "icdCodes"))
                        Set tProviderNpi = $Get(^||ClaimAuditFlag(tKey, "providerNpi"))
                        
                        Set patientStr = $Get(^||ClaimAuditFlag(tKey, "patient"))
                        Set patientRef = ""
                        If patientStr '= "" {
                            Set patientRef = ##class(%DynamicObject).%FromJSON(patientStr)
                        } Else {
                            Set patientRef = { "reference": "Patient/unknown" }
                        }
                        
                        Set typeStr = $Get(^||ClaimAuditFlag(tKey, "type"))
                        Set claimType = ""
                        If typeStr '= "" {
                            Set claimType = ##class(%DynamicObject).%FromJSON(typeStr)
                        } Else {
                            Set claimType = {
                                "coding": [
                                    {"system": "http://terminology.hl7.org/CodeSystem/claim-type", "code": "professional"}
                                ]
                            }
                        }
                        
                        Set createdTime = $Translate($ZDateTime($ZTIMESTAMP, 3, 1), " ", "T") _ "Z"
                        
                        // 1. Create FHIR ClaimResponse
                        Set claimResponse = {
                            "resourceType": "ClaimResponse",
                            "status": "active",
                            "use": "claim",
                            "type": (claimType),
                            "patient": (patientRef),
                            "created": (createdTime),
                            "insurer": { "reference": "Organization/claimaudit-payer" },
                            "outcome": "queued",
                            "disposition": (summary),
                            "request": { "reference": ("Claim/" _ tClaimId) }
                        }
                        
                        Set totalStr = $Get(^||ClaimAuditFlag(tKey, "total"))
                        If totalStr '= "" {
                            Set totalAmount = ##class(%DynamicObject).%FromJSON(totalStr)
                            Set tTotalObj = {
                                "category": {"coding": [{"system": "http://terminology.hl7.org/CodeSystem/adjudication", "code": "submitted"}]},
                                "amount": (totalAmount)
                            }
                            Set tTotalArr = ##class(%DynamicArray).%New()
                            Do tTotalArr.%Push(tTotalObj)
                            Set claimResponse.total = tTotalArr
                        }
                        
                        // Embed CPT, ICD, risk score, and full explanation as extensions
                        Set tExtensions = []
                        Do tExtensions.%Push({"url": "https://claimauditai.com/fhir/extension/risk-score", "valueDecimal": (score)})
                        Do tExtensions.%Push({"url": "https://claimauditai.com/fhir/extension/explanation", "valueString": (summary)})
                        If tCptCodesJSON '= "" {
                            Do tExtensions.%Push({"url": "https://claimauditai.com/fhir/extension/cpt-codes", "valueString": (tCptCodesJSON)})
                            Set tCptArr = ##class(%DynamicArray).%FromJSON(tCptCodesJSON)
                            If tCptArr.%Size() > 0 {
                                Do tExtensions.%Push({"url": "https://claimauditai.com/fhir/extension/cpt-code", "valueString": (tCptArr.%Get(0))})
                            }
                        }
                        If tIcdCodesJSON '= "" {
                            Do tExtensions.%Push({"url": "https://claimauditai.com/fhir/extension/icd-codes", "valueString": (tIcdCodesJSON)})
                            Set tIcdArr = ##class(%DynamicArray).%FromJSON(tIcdCodesJSON)
                            If tIcdArr.%Size() > 0 {
                                Do tExtensions.%Push({"url": "https://claimauditai.com/fhir/extension/icd-code", "valueString": (tIcdArr.%Get(0))})
                            }
                        }
                        If tProviderNpi '= "" {
                            Do tExtensions.%Push({"url": "https://claimauditai.com/fhir/extension/provider-npi", "valueString": (tProviderNpi)})
                        }
                        Set tTierResultsJSON = $Get(^||ClaimAuditFlag(tKey, "tierResults"))
                        If tTierResultsJSON '= "" {
                            Do tExtensions.%Push({"url": "https://claimauditai.com/fhir/extension/tier-results", "valueString": (tTierResultsJSON)})
                        }
                        Set claimResponse.extension = tExtensions
                        
                        // Unique fullUrl in this transaction
                        Set crUuid = "https://claimauditai.com/fhir/ClaimResponse/claimresponse-bundle-" _ tKey
                        
                        Set crEntry = {
                            "fullUrl": (crUuid),
                            "resource": (claimResponse),
                            "request": {
                                "method": "POST",
                                "url": "ClaimResponse"
                            }
                        }
                        Do holdsBundle.entry.%Push(crEntry)
                        
                        // 2. Create FHIR Task
                        Set auditTask = {
                            "resourceType": "Task",
                            "status": "ready",
                            "intent": "order",
                            "priority": "urgent",
                            "code": {
                                "coding": [
                                    {
                                        "system": "http://hl7.org/fhir/CodeSystem/task-code",
                                        "code": "review",
                                        "display": "Claim Audit Review"
                                    }
                                ]
                            },
                            "focus": { "reference": ("Claim/" _ tClaimId) },
                            "owner": { "reference": "Practitioner/claimaudit-auditor" },
                            "description": ("Adjudication Score: " _ score _ ". Risk Reasons: " _ summary)
                        }
                        Set taskEntry = {
                            "resource": (auditTask),
                            "request": {
                                "method": "POST",
                                "url": "Task"
                            }
                        }
                        Do holdsBundle.entry.%Push(taskEntry)
                        
                        // 3. Create FHIR CommunicationRequest
                        Set commRequest = {
                            "resourceType": "CommunicationRequest",
                            "status": "active",
                            "category": [
                                {
                                    "coding": [
                                        {
                                           "system": "http://terminology.hl7.org/CodeSystem/communication-category",
                                            "code": "notification",
                                            "display": "Claim Hold Notification"
                                        }
                                    ]
                                }
                            ],
                            "payload": [
                                {
                                    "contentString": (summary)
                                }
                            ],
                            "about": [
                                { "reference": ("Claim/" _ tClaimId) },
                                { "reference": (crUuid) }
                            ]
                        }
                        Set commEntry = {
                            "resource": (commRequest),
                            "request": {
                                "method": "POST",
                                "url": "CommunicationRequest"
                            }
                        }
                        Do holdsBundle.entry.%Push(commEntry)
                        
                        Do tTempClaimResponse.SetAt(claimResponse, tKey)
                    }
                }
            }
            
            // Execute the hold creation transaction Bundle
            If holdsBundle.entry.%Size() > 0 {
                Set tRequestBundle = ##class(HS.FHIRServer.API.Data.Request).%New()
                Set tRequestBundle.RequestMethod = "POST"
                Set tRequestBundle.RequestPath = ""
                Set tRequestBundle.Interaction = "transaction"
                Set tRequestBundle.Json = holdsBundle
                Set tResponseBundle = ##class(HS.FHIRServer.API.Data.Response).%New()
                Do pFHIRService.DispatchRequest(tRequestBundle, .tResponseBundle)
                
                If ($Extract(tResponseBundle.Status, 1) = "2") && $IsObject(tResponseBundle.Json) && $IsObject(tResponseBundle.Json.entry) {
                    // Map created ClaimResponse IDs back and mutate entries in the output response Bundle
                    Set tHoldsRespIter = tResponseBundle.Json.entry.%GetIterator()
                    
                    // We step through the keys in order
                    Set tFlaggedKey = ""
                    For {
                        Set tFlaggedKey = tFlaggedEntries.Next(tFlaggedKey)
                        If tFlaggedKey = "" Quit
                        
                        // The ClaimResponse created status is the first of 3 resources for this claim
                        If tHoldsRespIter.%GetNext(.tHoldIndex, .tHoldRespEntry) {
                            Set tCRLocation = ""
                            If $IsObject(tHoldRespEntry) && $IsObject(tHoldRespEntry.response) {
                                Set tCRLocation = tHoldRespEntry.response.location
                            }
                            Set tCRId = $Piece(tCRLocation, "/", 2)
                            
                            Set claimRespObj = tTempClaimResponse.GetAt(tFlaggedKey)
                            If (tCRId '= "") && $IsObject(claimRespObj) {
                                Set claimRespObj.id = tCRId
                            }
                            
                            // Mutate original entry response in pFHIRResponse
                            Set tOrigRespEntry = pFHIRResponse.Json.entry.%Get(tFlaggedKey)
                            If $IsObject(tOrigRespEntry) {
                                Set tOrigRespEntry.resource = claimRespObj
                                If $IsObject(tOrigRespEntry.response) {
                                    Set tOrigRespEntry.response.status = "202 Accepted"
                                    Set tOrigRespEntry.response.location = "ClaimResponse/" _ tCRId
                                }
                            }
                        }
                        
                        // Skip Task and CommunicationRequest entries in the response
                        Do tHoldsRespIter.%GetNext(.tHoldIndex, .tHoldRespEntry)
                        Do tHoldsRespIter.%GetNext(.tHoldIndex, .tHoldRespEntry)
                    }
                    Set ^ClaimAuditStatusLog($ZTS, "BundleBatch", "status") = tResponseBundle.Status
                } Else {
                    Set ^ClaimAuditError($ZTS) = "Failed to dispatch holds transaction for batch Bundle: " _ tResponseBundle.Status
                    If $IsObject(tResponseBundle.Json) {
                        Set ^ClaimAuditError($ZTS, "error") = tResponseBundle.Json.%ToJSON()
                    }
                }
            }
            
            Kill ^||ClaimAuditFlag
        } Catch ex {
            Set ^ClaimAuditError($ZTS) = ex.DisplayString()
            Kill ^||ClaimAuditFlag
    }
}
}
}
