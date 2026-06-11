Class ClaimAudit.Data.GraphStore Extends %RegisteredObject
{

/// Add a patient node to the persistent graph
ClassMethod UpsertPatient(pPatientId As %String, pName As %String = "") As %Boolean
{
    Try {
        Set tExisting = $Get(^ClaimAuditGraph("node", pPatientId))
        If (tExisting '= "") && (pName = "") {
            Set pName = $ListGet(tExisting, 2)
        }
        Set ^ClaimAuditGraph("node", pPatientId) = $ListBuild("patient", pName)
        Return 1
    } Catch { Return 0 }
}

/// Add a provider node to the persistent graph
ClassMethod UpsertProvider(pNPI As %String, pName As %String = "", pAddress As %String = "") As %Boolean
{
    Try {
        Set tExisting = $Get(^ClaimAuditGraph("node", pNPI))
        If tExisting '= "" {
            If pName = "" Set pName = $ListGet(tExisting, 2)
            If pAddress = "" Set pAddress = $ListGet(tExisting, 3)
        }
        Set ^ClaimAuditGraph("node", pNPI) = $ListBuild("provider", pName, pAddress)
        Return 1
    } Catch { Return 0 }
}

/// Add or update a claim edge between patient and provider
ClassMethod UpsertEdge(pPatientId As %String, pProviderNPI As %String, pAmount As %Double, pDate As %String) As %Boolean
{
    Try {
        Set ^ClaimAuditGraph("edge", pPatientId, pProviderNPI) = $ListBuild(pAmount, pDate)
        Return 1
    } Catch { Return 0 }
}

/// Export persistent graph as JSON for Cytoscape.js (no SQL queries needed)
ClassMethod ExportGraphJSON() As %DynamicObject
{
    Try {
        Set tNodes = []
        Set tEdges = []
        Set tSeenNodes = ""

        // Iterate all nodes
        Set tNodeId = ""
        For {
            Set tNodeId = $Order(^ClaimAuditGraph("node", tNodeId))
            If tNodeId = "" Quit
            Set tData = ^ClaimAuditGraph("node", tNodeId)
            Set tType = $ListGet(tData, 1)
            Set tName = $ListGet(tData, 2)
            Set tAddress = $ListGet(tData, 3)

            Set tNodeObj = {
                "id": (tType _ "-" _ tNodeId),
                "label": (tName),
                "type": (tType)
            }
            If tAddress '= "" {
                Do tNodeObj.%Set("address", tAddress)
            }
            Do tNodes.%Push({"data": (tNodeObj)})
        }

        // Iterate all edges (patient -> provider)
        Set tPatientId = ""
        For {
            Set tPatientId = $Order(^ClaimAuditGraph("edge", tPatientId))
            If tPatientId = "" Quit

            Set tProviderNPI = ""
            For {
                Set tProviderNPI = $Order(^ClaimAuditGraph("edge", tPatientId, tProviderNPI))
                If tProviderNPI = "" Quit

                Set tEdgeData = ^ClaimAuditGraph("edge", tPatientId, tProviderNPI)
                Set tAmount = $ListGet(tEdgeData, 1)
                Set tDate = $ListGet(tEdgeData, 2)

                Do tEdges.%Push({"data": {
                    "id": ("edge-" _ tPatientId _ "-" _ tProviderNPI),
                    "source": ("patient-" _ tPatientId),
                    "target": ("provider-" _ tProviderNPI),
                    "label": "claim",
                    "amount": (tAmount),
                    "date": (tDate)
                }})
            }
        }

        // Compute insights from persistent graph
        Set tInsights = []

        // Address collisions
        Set tAddrMap = {}
        Set tNodeId = ""
        For {
            Set tNodeId = $Order(^ClaimAuditGraph("node", tNodeId))
            If tNodeId = "" Quit
            Set tData = ^ClaimAuditGraph("node", tNodeId)
            If $ListGet(tData, 1) = "provider" {
                Set tAddr = $ZCONVERT($ListGet(tData, 3), "L")
                If tAddr '= "" {
                    If '$Data(tAddrMap(tAddr)) Set tAddrMap(tAddr) = []
                    Do tAddrMap(tAddr).%Push(tNodeId)
                }
            }
        }
        Set tAddr = ""
        For {
            Set tAddr = $Order(tAddrMap(tAddr))
            If tAddr = "" Quit
            If tAddrMap(tAddr).%Size() > 1 {
                Set tProvIds = ""
                For tI=0:1:tAddrMap(tAddr).%Size()-1 {
                    Set tProvIds = tProvIds _ tAddrMap(tAddr).%Get(tI) _ " "
                }
                Do tInsights.%Push({
                    "type": "address_collision",
                    "severity": "critical",
                    "message": ("Address collision: " _ tAddrMap(tAddr).%Size() _ " providers at same address"),
                    "providerId": ("provider-" _ tAddrMap(tAddr).%Get(0))
                })
            }
        }

        Set tResult = {
            "nodes": (tNodes),
            "edges": (tEdges),
            "insights": (tInsights),
            "nodeCount": (tNodes.%Size()),
            "edgeCount": (tEdges.%Size()),
            "insightCount": (tInsights.%Size())
        }
        Return tResult
    } Catch ex {
        Return {"error": (ex.DisplayString())}
    }
}

/// Clear all graph data
ClassMethod ClearAll() As %Boolean
{
    Try {
        Kill ^ClaimAuditGraph
        Return 1
    } Catch { Return 0 }
}

}
