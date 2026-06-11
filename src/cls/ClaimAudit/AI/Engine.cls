Class ClaimAudit.AI.Engine Extends %RegisteredObject
{

/// Set up the database tables and native HNSW vector index
ClassMethod Setup(pQuiet As %Boolean = 0) As %Status
{
    Set sc = $$$OK
    Try {
        // Set Python environment paths
        Do ##class(ClaimAudit.AI.Engine).ConfigurePythonPath()

        // 1. Create the ClinicalNotes vector table
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSQL = "CREATE TABLE ClaimAudit.ClinicalNotes ("_
                   "PatientId VARCHAR(50) NOT NULL, "_
                   "DocumentReferenceId VARCHAR(50) NOT NULL, "_
                   "DocumentText VARCHAR(32000), "_
                   "Embedding VECTOR(DOUBLE, 384), "_
                   "NoteDate VARCHAR(10), "_
                   "PRIMARY KEY (PatientId, DocumentReferenceId))"
        Set tSC = tStatement.%Prepare(tSQL)
        If $$$ISOK(tSC) {
            Do tStatement.%Execute()
            If 'pQuiet Write "Created table ClaimAudit.ClinicalNotes.", !
        } Else {
            // Table already exists, make sure NoteDate column exists
            Try {
                Set tAlterStatement = ##class(%SQL.Statement).%New()
                Set tAlterSQL = "ALTER TABLE ClaimAudit.ClinicalNotes ADD COLUMN NoteDate VARCHAR(10)"
                Set tSCAlter = tAlterStatement.%Prepare(tAlterSQL)
                If $$$ISOK(tSCAlter) {
                    Do tAlterStatement.%Execute()
                    If 'pQuiet Write "Added NoteDate column to existing table ClaimAudit.ClinicalNotes.", !
                }
            } Catch {}
        }

        // 2. Create the HNSW index on the vector field
        Set tIndexSQL = "CREATE INDEX HNSWIndex ON ClaimAudit.ClinicalNotes (Embedding) "_
                        "AS %SQL.Index.HNSW(Distance='Cosine', M=16, efConstruct=200)"
        Set tSC = tStatement.%Prepare(tIndexSQL)
        If $$$ISOK(tSC) {
            Do tStatement.%Execute()
            If 'pQuiet Write "Created HNSW Vector Index on ClaimAudit.ClinicalNotes.", !
        } Else {
            If 'pQuiet Write "HNSW Vector Index already exists or skipped: ", $System.Status.GetErrorText(tSC), !
        }

        // 3. Create PatientProjections table for relational graphs
        Set tSQL = "CREATE TABLE ClaimAudit.PatientProjections ("_
                   "Key VARCHAR(50) PRIMARY KEY, "_
                   "Name VARCHAR(100))"
        Set tSC = tStatement.%Prepare(tSQL)
        If $$$ISOK(tSC) { Do tStatement.%Execute() }

        // 4. Create ProviderProjections table
        Set tSQL = "CREATE TABLE ClaimAudit.ProviderProjections ("_
                   "NPI VARCHAR(50) PRIMARY KEY, "_
                   "Name VARCHAR(100), "_
                   "AddressLine VARCHAR(200))"
        Set tSC = tStatement.%Prepare(tSQL)
        If $$$ISOK(tSC) { Do tStatement.%Execute() }

        // 5. Create ClaimProjections table
        Set tSQL = "CREATE TABLE ClaimAudit.ClaimProjections ("_
                   "ClaimId VARCHAR(50), "_
                   "PatientKey VARCHAR(50), "_
                   "ProviderNPI VARCHAR(50), "_
                   "BilledAmount DOUBLE, "_
                   "ItemCount INTEGER, "_
                   "SpecialtyCode INTEGER, "_
                   "PatientAge INTEGER, "_
                   "DurationDays INTEGER, "_
                   "ServiceDate VARCHAR(10))"
        Set tSC = tStatement.%Prepare(tSQL)
        If $$$ISOK(tSC) {
            Do tStatement.%Execute()
        } Else {
            // Table already exists, make sure ClaimId column exists
            Try {
                Set tAlterStatement = ##class(%SQL.Statement).%New()
                Set tAlterSQL = "ALTER TABLE ClaimAudit.ClaimProjections ADD COLUMN ClaimId VARCHAR(50)"
                Set tSCAlter = tAlterStatement.%Prepare(tAlterSQL)
                If $$$ISOK(tSCAlter) { Do tAlterStatement.%Execute() }
            } Catch {}
        }

        // Trigger PyTorch autoencoder training with default synthetic values initially
        Set trainResult = ##class(ClaimAudit.AI.Engine).TrainAutoencoder()
        If 'pQuiet Write "Autoencoder Model: ", trainResult, !

        // Pre-load NLP sentence transformer model (~80MB download on first use)
        Try {
            Do ..ConfigurePythonPath()
            Set tNLP = ##class(%SYS.Python).Import("nlp_auditor")
            Set tDummy = tNLP."vectorize_text"("warmup")
            If 'pQuiet Write "NLP model pre-loaded.", !
        } Catch ex {
            If 'pQuiet Write "NLP pre-load skipped: ", ex.DisplayString(), !
        }

    } Catch ex {
        Set sc = ex.AsStatus()
        If 'pQuiet Write "Setup Error: ", ex.DisplayString(), !
    }
    Quit sc
}

/// Helper method to append custom Python path to sys.path
ClassMethod ConfigurePythonPath()
{
    Try {
        Set sys = ##class(%SYS.Python).Import("sys")
        Set devPath = "/home/irisowner/dev/src/python"
        Set pipPath = "/usr/irissys/mgr/python"
        If '(sys.path."__contains__"(devPath)) {
            Do sys.path.insert(0, devPath)
        }
        If '(sys.path."__contains__"(pipPath)) {
            Do sys.path.insert(0, pipPath)
        }
    } Catch {}
}

/// Index a clinical progress note in the native vector table
ClassMethod IndexNote(pPatientId As %String, pDocId As %String, pNoteText As %String, pNoteDate As %String = "") As %Status
{
    Set sc = $$$OK
    Try {
        Do ..ConfigurePythonPath()
        Set nlp = ##class(%SYS.Python).Import("nlp_auditor")
        Set res = nlp."index_clinical_note"(pPatientId, pDocId, pNoteText, pNoteDate)
        If $Extract(res, 1, 5) = "Error" {
            Set sc = $$$ERROR($$$GeneralError, res)
        }
    } Catch ex {
        Set sc = ex.AsStatus()
    }
    Quit sc
}

/// Trigger PyTorch autoencoder training
ClassMethod TrainAutoencoder() As %String
{
    Set res = ""
    Try {
        Do ..ConfigurePythonPath()
        Set ae = ##class(%SYS.Python).Import("autoencoder_train")
        Set res = ae."train_autoencoder"()
    } Catch ex {
        Set res = "Error: "_ex.DisplayString()
    }
    Quit res
}

/// Execute three-tiered payment integrity audit on intercepted Claims
ClassMethod AuditClaim(pClaimJson As %DynamicObject, Output pResult As %DynamicObject) As %Status
{
    Set sc = $$$OK
    Set pResult = {
        "flagged": 0,
        "score": 0.0,
        "reasons": [],
        "tierResults": []
    }
    Try {
        Do ..ConfigurePythonPath()
        
        // Extract basic features from Claim dynamic object
        Set claimId = pClaimJson.id
        If claimId = "" Set claimId = "unknown"
        Set patientId = ""
        If $IsObject(pClaimJson.patient) {
            Set patRef = pClaimJson.patient.reference
            Set patientId = $Piece(patRef, "/", *)
        }
        
        Set providerNpi = ""
        If $IsObject(pClaimJson.provider) {
            Set provRef = pClaimJson.provider.reference
            Set providerNpi = $Piece(provRef, "/", *)
        }
        
        Set billedAmount = 0.0
        If $IsObject(pClaimJson.total) {
            Set billedAmount = +pClaimJson.total.value
        }
        
        Set tCptCodes = ##class(%DynamicArray).%New()
        Set tCptDisplays = ##class(%DynamicArray).%New()
        Set codeCount = 0
        If $IsObject(pClaimJson.item) {
            Set iter = pClaimJson.item.%GetIterator()
            While iter.%GetNext(.key, .item) {
                Set codeCount = codeCount + 1
                If $IsObject(item.productOrService) && $IsObject(item.productOrService.coding) {
                    Set codingIter = item.productOrService.coding.%GetIterator()
                    While codingIter.%GetNext(.cKey, .coding) {
                        Set cptVal = coding.code
                        Set displayVal = coding.display
                        If displayVal = "" Set displayVal = cptVal
                        If cptVal '= "" {
                            Do tCptCodes.%Push(cptVal)
                            Do tCptDisplays.%Push(displayVal)
                        }
                    }
                }
            }
        }

        Set firstCodeDesc = ""
        If tCptDisplays.%Size() > 0 Set firstCodeDesc = tCptDisplays.%Get(0)

        Set tIcdCodes = ##class(%DynamicArray).%New()
        If $IsObject(pClaimJson.diagnosis) {
            Set diagIter = pClaimJson.diagnosis.%GetIterator()
            While diagIter.%GetNext(.dKey, .diag) {
                If $IsObject(diag.diagnosisCodeableConcept) && $IsObject(diag.diagnosisCodeableConcept.coding) {
                    Set dCodingIter = diag.diagnosisCodeableConcept.coding.%GetIterator()
                    While dCodingIter.%GetNext(.dcKey, .dCoding) {
                        Set icdVal = dCoding.code
                        If icdVal '= "" {
                            Do tIcdCodes.%Push(icdVal)
                        }
                    }
                }
            }
        }
        
        // Extract service date from claim, default to today
        Set serviceDate = $ZDate($Horolog, 3)
        If pClaimJson.created '= "" {
            Set serviceDate = $EXTRACT(pClaimJson.created, 1, 10)
        }
        
        // Enrich autoencoder features dynamically, falling back to projections or defaults
        Set specialtyCode = 1
        Set patientAge = 45
        Set durationDays = 1
        
        // 1. Calculate patient age dynamically from Patient.birthDate
        If patientId '= "" {
            Try {
                Set tReqPat = ##class(HS.FHIRServer.API.Data.Request).%New()
                Set tReqPat.RequestMethod = "GET"
                Set tReqPat.RequestPath = "/Patient/" _ patientId
                Set tReqPat.Interaction = "read"
                Set tRespPat = ##class(HS.FHIRServer.API.Data.Response).%New()
                Set tFHIRService = ##class(HS.FHIRServer.Service).EnsureInstance("/fhir/r4")
                Do tFHIRService.DispatchRequest(tReqPat, .tRespPat)
                If $IsObject(tRespPat.Json) {
                    Set tBirthDate = tRespPat.Json.birthDate
                    If tBirthDate '= "" {
                        Set birthYear = +$Piece(tBirthDate, "-", 1)
                        Set claimYear = +$Piece(serviceDate, "-", 1)
                        If (claimYear > 0) && (birthYear > 0) {
                            Set patientAge = claimYear - birthYear
                        }
                    }
                }
            } Catch {}
        }
        
        // 2. Calculate durationDays dynamically from billablePeriod
        If $IsObject(pClaimJson.billablePeriod) {
            Try {
                Set tStart = pClaimJson.billablePeriod.start
                Set tEnd = pClaimJson.billablePeriod.end
                If (tStart '= "") && (tEnd '= "") {
                    Set dStart = $ZDateH($Extract(tStart, 1, 10), 3)
                    Set dEnd = $ZDateH($Extract(tEnd, 1, 10), 3)
                    Set durationDays = dEnd - dStart
                    If durationDays < 1 Set durationDays = 1
                }
            } Catch {}
        }
        
        // 3. Fallback to ClaimProjections table
        If patientId '= "" {
            Try {
                Set tCPRS = ##class(%SQL.Statement).%ExecDirect(,
                "SELECT SpecialtyCode, PatientAge, DurationDays "_
                "FROM ClaimAudit.ClaimProjections WHERE PatientKey = ?", patientId)
                If tCPRS.%Next() {
                    If specialtyCode = 1 Set specialtyCode = +tCPRS.%Get("SpecialtyCode")
                    If patientAge = 45 Set patientAge = +tCPRS.%Get("PatientAge")
                    If durationDays = 1 Set durationDays = +tCPRS.%Get("DurationDays")
                }
            } Catch {}
        }
        
        // Run agentic audit using AgentWrapper
        Set agentJsonStr = ##class(ClaimAudit.AI.AgentWrapper).AuditClaimAgent(
            patientId, providerNpi, tCptCodes, tCptDisplays, tIcdCodes,
            billedAmount, codeCount, specialtyCode, patientAge, durationDays,
            serviceDate, claimId
        )
        
        Set agentRes = ##class(%DynamicObject).%FromJSON(agentJsonStr)
        Set status = agentRes.status
        Set score = +agentRes.threatIndex
        
        Set pResult.score = score
        If status = "HOLD" {
            Set pResult.flagged = 1
        } Else {
            Set pResult.flagged = 0
        }
        
        Set tTierArr = ##class(%DynamicArray).%New()
        Set findings = agentRes.findings
        
        If $IsObject(findings) {
            // Tier 1
            Set t1 = findings.tier1
            If $IsObject(t1) {
                Set tObj1 = {
                    "tier": 1,
                    "label": "Semantic Clinical Audit",
                    "score": (+t1.similarity),
                    "flags": []
                }
                If t1.citations '= "" Set tObj1.citations = t1.citations
                If t1.reason '= "" {
                    Do tObj1.flags.%Push(t1.reason)
                    Set tObj1.summary = t1.reason
                    If t1.flagged Do pResult.reasons.%Push("Tier 1 (NLP): " _ t1.reason)
                } Else {
                    Set tObj1.summary = "Clinical SOAP notes match the procedural description."
                }
                Do tTierArr.%Push(tObj1)
            }
            
            // Tier 2
            Set t2 = findings.tier2
            If $IsObject(t2) {
                Set tObj2 = {
                    "tier": 2,
                    "label": "Statistical Outlier Profiler",
                    "score": (+t2.loss),
                    "threshold": (+t2.threshold),
                    "flags": []
                }
                If t2.citations '= "" Set tObj2.citations = t2.citations
                If t2.reason '= "" {
                    Do tObj2.flags.%Push(t2.reason)
                    Set tObj2.summary = t2.reason
                    If t2.flagged Do pResult.reasons.%Push("Tier 2 (ML): " _ t2.reason)
                } Else {
                    Set tObj2.summary = "Claim billing features are within normal statistical bounds."
                }
                Do tTierArr.%Push(tObj2)
            }
            
            // Tier 3
            Set t3 = findings.tier3
            If $IsObject(t3) {
                Set tObj3 = {
                    "tier": 3,
                    "label": "Collusion Network Analysis",
                    "score": 0.0,
                    "flags": []
                }
                If t3.citations '= "" Set tObj3.citations = t3.citations
                If $IsObject(t3.findings) {
                    Set tFindIter = t3.findings.%GetIterator()
                    While tFindIter.%GetNext(.tFK, .tFV) {
                        Do tObj3.flags.%Push(tFV)
                    }
                }
                If t3.reason '= "" {
                    If tObj3.flags.%Size() = 0 Do tObj3.flags.%Push(t3.reason)
                    Set tObj3.summary = t3.reason
                    If t3.flagged Do pResult.reasons.%Push("Tier 3 (Graph): " _ t3.reason)
                } Else {
                    Set tObj3.summary = "Referral loop scan complete. Patient-provider relational topology is clean, geodetic limits matched."
                }
                Do tTierArr.%Push(tObj3)
            }
        }
        
        Set pResult.tierResults = tTierArr
        
        // Add extra agent fields to pResult
        If agentRes.justification '= "" Set pResult.justification = agentRes.justification
        If agentRes.nextSteps '= "" Set pResult.nextSteps = agentRes.nextSteps
        If agentRes.citations '= "" Set pResult.citations = agentRes.citations
        
        Set pResult.patientId = patientId
        Set pResult.providerNpi = providerNpi
        Set pResult.billedAmount = billedAmount
        Set pResult.codeCount = codeCount
        Set pResult.serviceDate = serviceDate
        Set pResult.firstCodeDesc = firstCodeDesc

        // Incrementally persist graph nodes and edges for real-time collusion network
        // (no full SQL rebuild needed — graph is updated on each claim audit)
        If patientId '= "" {
            Set tPatientName = ""
            Try {
                Set tPatRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM ClaimAudit.PatientProjections WHERE Key = ?", patientId)
                If tPatRS.%Next() Set tPatientName = tPatRS.%Get("Name")
            } Catch {}
            Do ##class(ClaimAudit.Data.GraphStore).UpsertPatient(patientId, tPatientName)
        }
        If providerNpi '= "" {
            Set tProvName = ""
            Set tProvAddr = ""
            Try {
                Set tProvRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name, AddressLine FROM ClaimAudit.ProviderProjections WHERE NPI = ?", providerNpi)
                If tProvRS.%Next() {
                    Set tProvName = tProvRS.%Get("Name")
                    Set tProvAddr = tProvRS.%Get("AddressLine")
                }
            } Catch {}
            Do ##class(ClaimAudit.Data.GraphStore).UpsertProvider(providerNpi, tProvName, tProvAddr)
        }
        If (patientId '= "") && (providerNpi '= "") {
            Do ##class(ClaimAudit.Data.GraphStore).UpsertEdge(patientId, providerNpi, billedAmount, serviceDate)
            
            // Also persist claim to ClaimProjections table
            Try {
                Set tStatement = ##class(%SQL.Statement).%New()
                Do tStatement.%Prepare("INSERT INTO ClaimAudit.ClaimProjections (ClaimId, PatientKey, ProviderNPI, BilledAmount, ItemCount, SpecialtyCode, PatientAge, DurationDays, ServiceDate) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)")
                Do tStatement.%Execute(claimId, patientId, providerNpi, billedAmount, codeCount, specialtyCode, patientAge, durationDays, serviceDate)
            } Catch {}
        }
        // Invalidate graph cache so the next claim audit sees this claim's edges.
        // Without this, claims 2-8 hit the 30s TTL cache and see an empty/stale graph.
        Try {
            Set pyGA = ##class(%SYS.Python).Import("graph_analyzer")
            Do pyGA."invalidate_graph_cache"()
        } Catch {}
        
    } Catch ex {
        Set sc = ex.AsStatus()
        Do pResult.reasons.%Push("Adjudication engine failure: " _ ex.DisplayString() _ ". Claim requires manual review.")
        Set pResult.score = 0.35
        Set pResult.flagged = 1
        // Populate fallback tierResults so the FHIR extension is always stored
        Set pResult.tierResults = ##class(%DynamicArray).%New()
        Do pResult.tierResults.%Push({
            "tier": 1, "label": "Semantic Clinical Audit", "score": 0.0, "flags": (##class(%DynamicArray).%New()), "summary": ("NLP audit pipeline failed: " _ ex.DisplayString() _ ". Verify NVIDIA_API_KEY and Python orchestration logs."), "citations": (##class(%DynamicArray).%New())
        })
        Do pResult.tierResults.%Push({
            "tier": 2, "label": "Statistical Outlier Profiler", "score": 0.0, "threshold": 0, "flags": (##class(%DynamicArray).%New()), "summary": ("Autoencoder anomaly detection failed: " _ ex.DisplayString()), "citations": (##class(%DynamicArray).%New())
        })
        Do pResult.tierResults.%Push({
            "tier": 3, "label": "Collusion Network Analysis", "score": 0.0, "flags": (##class(%DynamicArray).%New()), "summary": ("Graph collusion analysis failed: " _ ex.DisplayString()), "citations": (##class(%DynamicArray).%New())
        })
    }
    Quit sc
}

}
