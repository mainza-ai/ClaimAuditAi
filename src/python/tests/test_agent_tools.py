import sys
import os
import json

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import agent_tools

def test_tool_registry_registration():
    registry = agent_tools.ToolRegistry()

    @registry.register
    def dummy_tool(arg_str: str, arg_num: float, arg_bool: bool) -> str:
        """This is a dummy tool for testing.
        
        Args:
            arg_str: A string argument.
            arg_num: A float argument.
            arg_bool: A boolean argument.
        """
        return f"{arg_str}-{arg_num}-{arg_bool}"

    # Verify registration
    assert registry.get_tool("dummy_tool") == dummy_tool
    
    # Verify schema generation
    schemas = registry.get_all_schemas()
    assert len(schemas) == 1
    
    schema = schemas[0]
    assert schema["type"] == "function"
    assert schema["function"]["name"] == "dummy_tool"
    assert schema["function"]["description"] == "This is a dummy tool for testing."
    
    params = schema["function"]["parameters"]
    assert params["type"] == "object"
    assert "arg_str" in params["properties"]
    assert params["properties"]["arg_str"]["type"] == "string"
    assert params["properties"]["arg_num"]["type"] == "number"
    assert params["properties"]["arg_bool"]["type"] == "boolean"
    assert "arg_str" in params["required"]
    assert "arg_num" in params["required"]
    assert "arg_bool" in params["required"]

def test_tool_execution():
    registry = agent_tools.ToolRegistry()

    @registry.register
    def add_numbers(a: float, b: float) -> float:
        """Add two numbers."""
        return a + b

    # Test valid execution
    res = registry.execute("add_numbers", {"a": 5.5, "b": 4.5})
    assert res == "10.0"

    # Test execution of non-existent tool
    res_err = registry.execute("unknown_tool", {})
    assert "Error" in res_err

def test_default_tools_exist():
    # Verify standard terminology lookup tools are in the global registry
    schemas = agent_tools.registry.get_all_schemas()
    tool_names = [s["function"]["name"] for s in schemas]
    
    assert "lookup_cpt_code" in tool_names
    assert "lookup_icd_code" in tool_names
    assert "validate_clinical_edits" in tool_names
    assert "run_nlp_audit" in tool_names
    assert "run_anomaly_audit" in tool_names
    assert "run_graph_audit" in tool_names
    assert "get_patient_history" in tool_names
    assert "get_provider_history" in tool_names
