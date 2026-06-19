import os
import sys
import threading
import numpy as np
from sentence_transformers import SentenceTransformer

# Try to import iris (only available within Embedded Python context)
try:
    import iris
    if not hasattr(iris, "cls"):
        iris = None
except ImportError:
    iris = None

# Thread-safe model loader with locking
_model_instance = None
_model_lock = threading.Lock()

def get_model():
    global _model_instance
    if _model_instance is not None:
        return _model_instance

    with _model_lock:
        if _model_instance is not None:
            return _model_instance
        cache_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "model_cache")
        os.makedirs(cache_dir, exist_ok=True)
        os.environ["SENTENCE_TRANSFORMERS_HOME"] = cache_dir
        _model_instance = SentenceTransformer('all-MiniLM-L6-v2', cache_folder=cache_dir)
        return _model_instance

def vectorize_text(text: str) -> list:
    """Vectorize input text using SentenceTransformer and return as a flat float list."""
    if not text:
        return [0.0] * 384
    model = get_model()
    embeddings = model.encode(text)
    # Ensure it's a standard Python float list
    return [float(x) for x in embeddings]

def index_clinical_note(patient_id: str, doc_id: str, note_text: str, note_date: str = None) -> str:
    """Natively index unstructured clinical progress notes in the IRIS database."""
    if not iris:
        return "Not running inside InterSystems IRIS"
        
    try:
        # Generate high-dimensional embedding
        embedding_vec = vectorize_text(note_text)
        embedding_str = ",".join(map(str, embedding_vec))
        
        # Prepare dynamic SQL to insert embedding
        stmt = iris.sql.prepare(
            "INSERT OR UPDATE INTO ClaimAudit.ClinicalNotes (PatientId, DocumentReferenceId, DocumentText, Embedding, NoteDate) "
            "VALUES (?, ?, ?, TO_VECTOR(?, DOUBLE, 384), ?)"
        )
        if not note_date:
            import time
            note_date = time.strftime("%Y-%m-%d")
        stmt.execute(patient_id, doc_id, note_text, embedding_str, note_date)
        return "OK"
    except Exception as e:
        sys.stderr.write(f"Error indexing clinical note: {str(e)}\n")
        return f"Error: {str(e)}"

def verify_clinical_validity(patient_id: str, code_descriptions, service_date: str = None) -> dict:
    """Query high-dimensional embeddings using native VECTOR_COSINE search.
    
    Returns the maximum similarity score and the supporting textual evidence.
    """
    if not iris:
        return {"similarity": 1.0, "evidence": "Not running in IRIS context (mocked success)", "flagged": False}
        
    try:
        if isinstance(code_descriptions, str):
            code_descriptions = [code_descriptions]
            
        # Determine temporal search bounds (default +/- 7 days)
        start_date, end_date = "1970-01-01", "2099-12-31"
        if service_date:
            try:
                from datetime import datetime, timedelta
                svc_dt = datetime.strptime(service_date[:10], "%Y-%m-%d")
                start_date = (svc_dt - timedelta(days=7)).strftime("%Y-%m-%d")
                end_date = (svc_dt + timedelta(days=7)).strftime("%Y-%m-%d")
            except Exception:
                pass
        
        sql_query = (
            "SELECT TOP 3 DocumentReferenceId, DocumentText, VECTOR_COSINE(Embedding, TO_VECTOR(?, DOUBLE, 384)) AS Similarity "
            "FROM ClaimAudit.ClinicalNotes "
            "WHERE PatientId = ? AND (NoteDate IS NULL OR NoteDate = '' OR NoteDate BETWEEN ? AND ?) "
            "ORDER BY Similarity DESC"
        )
        
        stmt = iris.sql.prepare(sql_query)
        
        worst_similarity = 1.0
        best_evidence = ""
        flagged = False
        findings = []
        citations = []
        
        # Check all code descriptions
        for desc in code_descriptions:
            if not desc:
                continue
            query_vec = vectorize_text(desc)
            query_str = ",".join(map(str, query_vec))
            rs = stmt.execute(query_str, patient_id, start_date, end_date)
            
            best_similarity_for_code = -1.0
            best_evidence_for_code = ""
            best_doc_id = ""
            
            for row in rs:
                doc_id = row[0]
                text = row[1]
                similarity = float(row[2])
                if similarity > best_similarity_for_code:
                    best_similarity_for_code = similarity
                    best_evidence_for_code = text
                    best_doc_id = doc_id
            
            # If no notes exist for this patient
            if best_similarity_for_code == -1.0:
                return {
                    "similarity": 0.0,
                    "evidence": "No clinical notes found for this patient in DocumentReference.",
                    "flagged": True,
                    "reason": "Missing supporting clinical documentation (phantom billing suspicion).",
                    "citations": []
                }
            
            # Track worst similarity score (lowest) among the matched codes
            if best_similarity_for_code < worst_similarity:
                worst_similarity = best_similarity_for_code
                best_evidence = best_evidence_for_code
            
            if best_doc_id:
                citations.append(f"DocumentReference/{best_doc_id}")
                
            code_flagged = best_similarity_for_code < 0.38
            if code_flagged:
                flagged = True
                findings.append(f"CPT code display '{desc}' lacks semantic alignment with progress notes. Similarity: {best_similarity_for_code:.4f}")
        
        reason = ""
        if flagged:
            reason = " | ".join(findings)
            
        return {
            "similarity": worst_similarity,
            "evidence": best_evidence,
            "flagged": flagged,
            "reason": reason,
            "citations": list(set(citations))
        }
        
    except Exception as e:
        sys.stderr.write(f"Error in verify_clinical_validity: {str(e)}\n")
        return {
            "similarity": 0.0,
            "evidence": f"Tier 1 NLP audit engine error: {str(e)}. Manual review required.",
            "flagged": True,
            "reason": f"NLP semantic audit failure: {str(e)}. Claim requires manual adjudication review."
        }
