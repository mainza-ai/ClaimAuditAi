Class ClaimAudit.AI.Engine Extends %RegisteredObject
{

/// Set up the database tables and native HNSW vector index
ClassMethod Setup() As %Status
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
                   "PRIMARY KEY (PatientId, DocumentReferenceId))"
        Set tSC = tStatement.%Prepare(tSQL)
        If $$$ISOK(tSC) {
            Do tStatement.%Execute()
            Write "Created table ClaimAudit.ClinicalNotes.", !
        } Else {
            Write "Table ClaimAudit.ClinicalNotes already exists or skipped: ", $System.Status.GetErrorText(tSC), !
        }

        // 2. Create the HNSW index on the vector field
        Set tIndexSQL = "CREATE INDEX HNSWIndex ON ClaimAudit.ClinicalNotes (Embedding) "_
                        "AS %SQL.Index.HNSW(Distance='Cosine', M=16, efConstruct=200)"
        Set tSC = tStatement.%Prepare(tIndexSQL)
        If $$$ISOK(tSC) {
            Do tStatement.%Execute()
            Write "Created HNSW Vector Index on ClaimAudit.ClinicalNotes.", !
        } Else {
            Write "HNSW Vector Index already exists or skipped: ", $System.Status.GetErrorText(tSC), !
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
                   "PatientKey VARCHAR(50), "_
                   "ProviderNPI VARCHAR(50), "_
                   "BilledAmount DOUBLE, "_
                   "ItemCount INTEGER, "_
                   "SpecialtyCode INTEGER, "_
                   "PatientAge INTEGER, "_
                   "DurationDays INTEGER, "_
                   "ServiceDate VARCHAR(10))"
        Set tSC = tStatement.%Prepare(tSQL)
        If $$$ISOK(tSC) { Do tStatement.%Execute() }

        // Trigger PyTorch autoencoder training with default synthetic values initially
        Set trainResult = ##class(ClaimAudit.AI.Engine).TrainAutoencoder()
        Write "Autoencoder Model: ", trainResult, !

        // Pre-load NLP sentence transformer model (~80MB download on first use)
        Try {
            Do ..ConfigurePythonPath()
            Set tNLP = ##class(%SYS.Python).Import("nlp_auditor")
            Set tDummy = tNLP."vectorize_text"("warmup")
            Write "NLP model pre-loaded.", !
        } Catch ex {
            Write "NLP pre-load skipped: ", ex.DisplayString(), !
        }

    } Catch ex {
        Set sc = ex.AsStatus()
        Write "Setup Error: ", ex.DisplayString(), !
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
ClassMethod IndexNote(pPatientId As %String, pDocId As %String, pNoteText As %String) As %Status
{
    Set sc = $$$OK
    Try {
        Do ..ConfigurePythonPath()
        Set nlp = ##class(%SYS.Python).Import("nlp_auditor")
        Set res = nlp."index_clinical_note"(pPatientId, pDocId, pNoteText)
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
        "reasons": []
    }
    Try {
        Do ..ConfigurePythonPath()
        
        // Extract basic features from Claim dynamic object
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
        
        Set codeCount = 0
        Set firstCodeDesc = ""
        If $IsObject(pClaimJson.item) {
            Set iter = pClaimJson.item.%GetIterator()
            While iter.%GetNext(.key, .item) {
                Set codeCount = codeCount + 1
                If (firstCodeDesc = "") && $IsObject(item.productOrService) {
                    Set codingIter = item.productOrService.coding.%GetIterator()
                    If codingIter.%GetNext(.cKey, .coding) {
                        Set firstCodeDesc = coding.display
                        If firstCodeDesc = "" Set firstCodeDesc = coding.code
                    }
                }
            }
        }
        
        // Extract service date from claim, default to today
        Set serviceDate = $ZDate($Horolog, 3)
        If pClaimJson.created '= "" {
            Set serviceDate = $EXTRACT(pClaimJson.created, 1, 10)
        }
        
        // Enrich autoencoder features from ClaimProjections table when available.
        // Falls back to sensible defaults for claims without projection data.
        Set specialtyCode = 1
        Set patientAge = 45
        Set durationDays = 1
        If patientId '= "" {
            Try {
                Set tCPRS = ##class(%SQL.Statement).%ExecDirect(,
                "SELECT SpecialtyCode, PatientAge, DurationDays "_
                "FROM ClaimAudit.ClaimProjections WHERE PatientKey = ?", patientId)
                If tCPRS.%Next() {
                    Set specialtyCode = +tCPRS.%Get("SpecialtyCode")
                    Set patientAge = +tCPRS.%Get("PatientAge")
                    Set durationDays = +tCPRS.%Get("DurationDays")
                }
            } Catch {}
        }
        
        // Run all three AI tiers in parallel with timeouts and circuit breaker
        Set orchestrator = ##class(%SYS.Python).Import("tier_orchestrator")
        Set tAllResults = orchestrator."run_all_tiers"(
            patientId, providerNpi, firstCodeDesc,
            billedAmount, codeCount,
            specialtyCode, patientAge, durationDays,
            serviceDate
        )

        // Tier 1: NLP results
        Set tDict1 = tAllResults."get"("tier1")
        Set t1Flagged = 0
        Set t1Reason = ""
        Set t1Sim = 0.0
        If $IsObject(tDict1) {
            Set t1Flagged = +tDict1."get"("flagged", 0)
            Set t1Reason = tDict1."get"("reason", "")
            Set t1Sim = +tDict1."get"("similarity", 0.0)
        }

        // Tier 2: Autoencoder results
        Set tDict2 = tAllResults."get"("tier2")
        Set t2Flagged = 0
        Set t2Reason = ""
        Set t2Loss = 0.0
        If $IsObject(tDict2) {
            Set t2Flagged = +tDict2."get"("flagged", 0)
            Set t2Reason = tDict2."get"("reason", "")
            Set t2Loss = +tDict2."get"("loss", 0.0)
        }

        // Tier 3: Graph results
        Set tDict3 = tAllResults."get"("tier3")
        Set t3Flagged = 0
        Set t3Reason = ""
        If $IsObject(tDict3) {
            Set t3Flagged = +tDict3."get"("flagged", 0)
            Set t3Reason = tDict3."get"("reason", "")
        }

        // Synthesis & Risk Scoring
        Set score = 0.0
        Set flaggedCount = 0
        
        If t1Flagged {
            Set score = score + 0.35
            Set flaggedCount = flaggedCount + 1
            Do pResult.reasons.%Push("Tier 1 (NLP): " _ t1Reason)
        }
        If t2Flagged {
            Set score = score + 0.35
            Set flaggedCount = flaggedCount + 1
            Do pResult.reasons.%Push("Tier 2 (ML): " _ t2Reason)
        }
        If t3Flagged {
            Set score = score + 0.30
            Set flaggedCount = flaggedCount + 1
            Do pResult.reasons.%Push("Tier 3 (Graph): " _ t3Reason)
        }
        
        // Cap score at 1.0
        If score > 1.0 Set score = 1.0
        Set pResult.score = score
        
        // If threat score exceeds threshold, flag for hold
        If score >= 0.35 {
            Set pResult.flagged = 1
        }
        
        Set pResult.patientId = patientId
        Set pResult.providerNpi = providerNpi
        Set pResult.billedAmount = billedAmount
        Set pResult.codeCount = codeCount
        Set pResult.serviceDate = serviceDate
        Set pResult.firstCodeDesc = firstCodeDesc

        // Incrementally persist graph nodes and edges for real-time collusion network
        // (no full SQL rebuild needed — graph is updated on each claim audit)
        If patientId '= "" {
            Do ##class(ClaimAudit.Data.GraphStore).UpsertPatient(patientId)
        }
        If providerNpi '= "" {
            Do ##class(ClaimAudit.Data.GraphStore).UpsertProvider(providerNpi, "", "")
        }
        If (patientId '= "") && (providerNpi '= "") {
            Do ##class(ClaimAudit.Data.GraphStore).UpsertEdge(patientId, providerNpi, billedAmount, serviceDate)
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
    }
    Quit sc
}

}
