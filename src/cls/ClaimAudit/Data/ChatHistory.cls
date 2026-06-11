Class ClaimAudit.Data.ChatHistory Extends (%Persistent, %XML.Adaptor, %JSON.Adaptor)
{

Property ClaimId As %String [ Required ];

Property Role As %String [ Required ];

Property Content As %String(MAXLEN = 16000) [ Required ];

Property Timestamp As %String [ Required ];

Index ClaimIndex On ClaimId;

ClassMethod SaveMessage(pClaimId As %String, pRole As %String, pContent As %String, pTimestamp As %String) As %Status
{
    Set tMsg = ..%New()
    Set tMsg.ClaimId = pClaimId
    Set tMsg.Role = pRole
    Set tMsg.Content = pContent
    Set tMsg.Timestamp = pTimestamp
    Quit tMsg.%Save()
}

ClassMethod GetHistory(pClaimId As %String) As %DynamicArray
{
    Set tArr = []
    Try {
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSC = tStatement.%Prepare("SELECT ""Role"", Content, ""Timestamp"" FROM ClaimAudit_Data.ChatHistory WHERE ClaimId = ? ORDER BY ""Timestamp"" ASC")
        If $$$ISOK(tSC) {
            Set tRS = tStatement.%Execute(pClaimId)
            While tRS.%Next() {
                Do tArr.%Push({
                    "role": (tRS.%Get("Role")),
                    "content": (tRS.%Get("Content")),
                    "timestamp": (tRS.%Get("Timestamp"))
                })
            }
        }
    } Catch {}
    Quit tArr
}

}
