#!/bin/bash
# Runtime initialization for IRIS — runs on first container start
# Creates FHIR server, compiles dependent classes, runs Engine.Setup

# Upgrade Python packages to match requirements.txt (catches version bumps without full rebuild)
echo "Checking Python dependencies..."
/home/irisowner/.venvs/mcp-tools/bin/pip install --upgrade -r /home/irisowner/dev/requirements.txt --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple --target /usr/irissys/mgr/python --break-system-packages 2>&1 | tail -3

iris session IRIS << 'EOF' 2>&1
zn "INTEROP"

// Compile FHIR-dependent classes FIRST so they're available for FHIR server creation
do $SYSTEM.OBJ.Load("/home/irisowner/dev/src/cls/ClaimAudit/FHIR/InteractionsStrategy.cls", "ck")
do $SYSTEM.OBJ.Load("/home/irisowner/dev/src/cls/ClaimAudit/FHIR/Interactions.cls", "ck")
do $SYSTEM.OBJ.Load("/home/irisowner/dev/src/cls/ClaimAudit/FHIR/RepoManager.cls", "ck")

// Wrap FHIR server creation/check in a try-catch to avoid dropping to debug shell on error
try {
  // Check if FHIR server already exists using bind params (avoid ObjectScript single-quote stripping)
  set tRS = ##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS cnt FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?", "HSFHIR_X0001_S", "ClaimResponse")
  do tRS.%Next()
  if tRS.%Get("cnt") = 0 {
    // Initialize FHIR metadata and create FHIR server endpoint
    do ##class(HS.FHIRServer.Installer).InstallNamespace()
    set tSC = ##class(HS.FHIRServer.Installer).InstallInstance("/fhir/r4", "ClaimAudit.FHIR.InteractionsStrategy", "hl7.fhir.r4.core@4.0.1")
    if tSC { write "FHIR server created", ! } else { write "FHIR server: ", $SYSTEM.Status.GetOneErrorText(tSC), ! }
  } else {
    write "FHIR server already exists, skipping", !
  }
} catch ex {
  write "FHIR server installation skipped or already configured: ", ex.DisplayString(), !
}

// Compile all custom classes recursively
do $SYSTEM.OBJ.LoadDir("/home/irisowner/dev/src/cls", "ckr", , 1)

// Run Engine.Setup() to create audit tables and train models (idempotent)
do ##class(ClaimAudit.AI.Engine).Setup()

// Grant permissions to UnknownUser
do ##class(ClaimAudit.Debug).GrantRolesToUnknownUser()

halt
EOF