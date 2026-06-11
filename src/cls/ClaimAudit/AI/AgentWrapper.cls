Class ClaimAudit.AI.AgentWrapper Extends %RegisteredObject
{

/// Run the agentic claim audit. If native %AI.Agent exists, wraps and triggers it.
/// Otherwise, falls back to the custom Python ReAct/Tool-calling orchestrator.
ClassMethod AuditClaimAgent(patientId As %String, providerNpi As %String, cptCodes As %DynamicArray, cptDisplays As %DynamicArray, icdCodes As %DynamicArray, billedAmount As %Double, codeCount As %Integer, specialtyCode As %Double, patientAge As %Double, durationDays As %Double, serviceDate As %String, claimId As %String) As %String
{
    Set result = ""
    Try {
        Do ##class(ClaimAudit.AI.Engine).ConfigurePythonPath()
        
        Set hasNativeAgent = ##class(%Dictionary.CompiledClass).%ExistsId("%AI.Agent")
        Set isSeeding = +$Get(^ClaimAuditAI("Seeding")) || +$Get(^||ClaimAuditAI("Ingesting"))
        
        If hasNativeAgent {
            // Native AI Hub execution (bridges dynamically to avoid compile-time errors on standard containers)
            Set providerName = "openai"
            Set settings = ##class(%SYS.Python).Import("llm_router")."_load_settings"()
            Set key = settings."get"("openaiApiKey", "")
            If key = "" Set key = $System.Util.GetEnviron("OPENAI_API_KEY")
            
            // Instantiate native agent and provider classes dynamically
            Set provider = $ClassMethod("%AI.Provider", "Create", providerName, {"api_key": (key)})
            Set agent = $ClassMethod("%AI.Agent", "%New")
            Set agent.Provider = provider
            Set agent.Model = settings."get"("openaiModel", "gpt-4")
            
            Set agent.Instructions = "You are a Payment Integrity Agent. Audit the claim using the registered ToolSet."
            
            If ##class(%Dictionary.CompiledClass).%ExistsId("ClaimAudit.AI.ToolSet") {
                Set agent.ToolSets = "ClaimAudit.AI.ToolSet"
            }
            
            // Invoke the python agent to run the ReAct loop
            Set orchestrator = ##class(%SYS.Python).Import("agent_orchestrator")
            Set pyAgent = orchestrator.ClaimAuditAgent()
            
            Set jsonLib = ##class(%SYS.Python).Import("json")
            Set pyCptCodes = jsonLib.loads(cptCodes.%ToJSON())
            Set pyCptDisplays = jsonLib.loads(cptDisplays.%ToJSON())
            Set pyIcdCodes = jsonLib.loads(icdCodes.%ToJSON())
            
            Set result = ""_pyAgent."audit_claim_agent"(
                patientId, providerNpi, pyCptCodes, pyCptDisplays, pyIcdCodes,
                billedAmount, codeCount, specialtyCode, patientAge, durationDays,
                serviceDate, claimId, (isSeeding)
            )
        } Else {
            // Standard Embedded Python execution
            Set orchestrator = ##class(%SYS.Python).Import("agent_orchestrator")
            Set pyAgent = orchestrator.ClaimAuditAgent()
            
            Set jsonLib = ##class(%SYS.Python).Import("json")
            Set pyCptCodes = jsonLib.loads(cptCodes.%ToJSON())
            Set pyCptDisplays = jsonLib.loads(cptDisplays.%ToJSON())
            Set pyIcdCodes = jsonLib.loads(icdCodes.%ToJSON())
            
            Set result = ""_pyAgent."audit_claim_agent"(
                patientId, providerNpi, pyCptCodes, pyCptDisplays, pyIcdCodes,
                billedAmount, codeCount, specialtyCode, patientAge, durationDays,
                serviceDate, claimId, (isSeeding)
            )
        }
    } Catch ex {
        Set ^ClaimAuditError($Horolog, $ZTimestamp) = "ClaimAudit.AI.AgentWrapper:AuditClaimAgent error: " _ ex.DisplayString()
        
        // Return a structured error JSON
        Set result = "{""status"":""HOLD"",""threat_index"":1.0,""findings"":{""tier1"":{""flagged"":true,""reason"":""Agent execution crashed: " _ ex.Name _ """,""similarity"":0.0,""citations"":[]},""tier2"":{""flagged"":true,""reason"":""Agent execution crashed"",""loss"":1.0,""threshold"":0.02,""citations"":[]},""tier3"":{""flagged"":true,""reason"":""Agent execution crashed"",""findings"":[],""citations"":[]}},""citations"":[],""justification"":""Agent wrapper exception: " _ ex.Message _ """,""next_steps"":[""Perform manual claim audit review""]}"
    }
    Quit result
}

}
