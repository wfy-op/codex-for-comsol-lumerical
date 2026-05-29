"""Tests for the COMSOL MCP runtime CLI adapter."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest


ADAPTER_PATH = Path(__file__).resolve().parents[2] / "comsol_mph_tool.py"


def load_adapter():
    spec = importlib.util.spec_from_file_location("comsol_mph_tool", ADAPTER_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class RegistryMCPTests(unittest.TestCase):
    def test_tools_register_and_invoke_with_json_arguments(self):
        adapter = load_adapter()
        registry = adapter.RegistryMCP()

        @registry.tool()
        def sample_tool(value: int, scale: int = 2) -> dict:
            return {"answer": value * scale}

        self.assertEqual(registry.tool_names(), ["sample_tool"])
        self.assertEqual(
            adapter.invoke_tool(registry, "sample_tool", {"value": 4, "scale": 3}),
            {"answer": 12},
        )

    def test_resource_templates_match_uri_arguments(self):
        adapter = load_adapter()
        registry = adapter.RegistryMCP()

        @registry.resource("comsol://model/{name}/tree")
        def model_tree(name: str) -> str:
            return f"tree:{name}"

        self.assertEqual(
            adapter.invoke_resource(registry, "comsol://model/demo/tree"),
            "tree:demo",
        )

    def test_unknown_tool_raises_clear_error(self):
        adapter = load_adapter()
        registry = adapter.RegistryMCP()

        with self.assertRaisesRegex(KeyError, "Unknown tool"):
            adapter.invoke_tool(registry, "missing_tool", {})

    def test_batch_steps_keep_one_registry_instance(self):
        adapter = load_adapter()
        registry = adapter.RegistryMCP()
        state = []

        @registry.tool()
        def add_value(value: str) -> dict:
            state.append(value)
            return {"count": len(state)}

        @registry.resource("state://values")
        def values() -> str:
            return ",".join(state)

        results = adapter.invoke_steps(
            registry,
            [
                {"tool": "add_value", "args": {"value": "a"}},
                {"tool": "add_value", "args": {"value": "b"}},
                {"resource": "state://values"},
            ],
        )

        self.assertEqual(results[-1]["result"], "a,b")


if __name__ == "__main__":
    unittest.main()
