#!/usr/bin/env python
"""CLI adapter for the bundled COMSOL MCP runtime.

The adapter reuses the MCP server's original registration functions through a
small FastMCP-compatible registry. It does not reimplement COMSOL operations.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Tuple
from urllib.parse import unquote


DEFAULT_RUNTIME_DIR = Path(__file__).resolve().parent / "comsol_mcp_runtime"


class RegistryMCP:
    """Minimal registry that accepts the FastMCP decorators used by runtime code."""

    def __init__(self) -> None:
        self.tools: Dict[str, Callable[..., Any]] = {}
        self.resources: Dict[str, Callable[..., Any]] = {}

    def tool(self, *args: Any, **kwargs: Any) -> Callable[[Callable[..., Any]], Callable[..., Any]]:
        name_override = kwargs.get("name")

        def decorator(func: Callable[..., Any]) -> Callable[..., Any]:
            self.tools[str(name_override or func.__name__)] = func
            return func

        if len(args) == 1 and callable(args[0]) and not kwargs:
            return decorator(args[0])
        return decorator

    def resource(self, uri_template: str, *args: Any, **kwargs: Any) -> Callable[[Callable[..., Any]], Callable[..., Any]]:
        def decorator(func: Callable[..., Any]) -> Callable[..., Any]:
            self.resources[uri_template] = func
            return func

        return decorator

    def tool_names(self) -> List[str]:
        return sorted(self.tools)

    def resource_names(self) -> List[str]:
        return sorted(self.resources)


def _ensure_runtime_on_path(runtime_dir: Path) -> None:
    runtime = str(runtime_dir.resolve())
    if runtime not in sys.path:
        sys.path.insert(0, runtime)


def load_registry(runtime_dir: Optional[Path] = None) -> RegistryMCP:
    """Load all original MCP tools and resources into a local registry."""
    runtime = runtime_dir or DEFAULT_RUNTIME_DIR
    _ensure_runtime_on_path(runtime)

    from src.knowledge.embedded import register_knowledge_tools
    from src.resources.model_resources import register_model_resources
    from src.tools.geometry import register_geometry_tools
    from src.tools.mesh import register_mesh_tools
    from src.tools.model import register_model_tools
    from src.tools.parameters import register_parameter_tools
    from src.tools.physics import register_physics_tools
    from src.tools.results import register_results_tools
    from src.tools.session import register_session_tools
    from src.tools.study import register_study_tools

    registry = RegistryMCP()
    register_session_tools(registry)
    register_model_tools(registry)
    register_parameter_tools(registry)
    register_geometry_tools(registry)
    register_physics_tools(registry)
    register_mesh_tools(registry)
    register_study_tools(registry)
    register_results_tools(registry)
    register_knowledge_tools(registry)
    register_model_resources(registry)
    return registry


def _resource_regex(uri_template: str) -> re.Pattern[str]:
    parts: List[str] = []
    index = 0
    for match in re.finditer(r"\{([A-Za-z_][A-Za-z0-9_]*)\}", uri_template):
        parts.append(re.escape(uri_template[index:match.start()]))
        parts.append(f"(?P<{match.group(1)}>[^/]+)")
        index = match.end()
    parts.append(re.escape(uri_template[index:]))
    return re.compile("^" + "".join(parts) + "$")


def _match_resource(uri_template: str, uri: str) -> Optional[Dict[str, str]]:
    match = _resource_regex(uri_template).match(uri)
    if not match:
        return None
    return {key: unquote(value) for key, value in match.groupdict().items()}


def invoke_tool(registry: RegistryMCP, name: str, payload: Dict[str, Any]) -> Any:
    if name not in registry.tools:
        raise KeyError(f"Unknown tool: {name}")
    return registry.tools[name](**payload)


def invoke_resource(registry: RegistryMCP, uri: str) -> Any:
    for uri_template, func in registry.resources.items():
        matched = _match_resource(uri_template, uri)
        if matched is not None:
            return func(**matched)
    raise KeyError(f"Unknown resource URI: {uri}")


def invoke_steps(registry: RegistryMCP, steps: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Run multiple tool/resource operations in one process.

    This preserves the original MCP runtime's process-local session state.
    """
    results: List[Dict[str, Any]] = []
    for index, step in enumerate(steps):
        if "tool" in step:
            name = str(step["tool"])
            payload = step.get("args", {})
            if not isinstance(payload, dict):
                raise ValueError(f"Step {index} args must be a JSON object")
            result = invoke_tool(registry, name, payload)
            results.append({"index": index, "kind": "tool", "name": name, "result": result})
        elif "resource" in step:
            uri = str(step["resource"])
            result = invoke_resource(registry, uri)
            results.append({"index": index, "kind": "resource", "uri": uri, "result": result})
        else:
            raise ValueError(f"Step {index} must contain either 'tool' or 'resource'")
    return results


def _parse_json_object(text: str) -> Dict[str, Any]:
    try:
        value = json.loads(text)
    except json.JSONDecodeError as exc:
        raise ValueError(f"--json must be valid JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError("--json must decode to a JSON object")
    return value


def _parse_json_list(text: str) -> List[Dict[str, Any]]:
    try:
        value = json.loads(text)
    except json.JSONDecodeError as exc:
        raise ValueError(f"--json must be valid JSON: {exc}") from exc
    if not isinstance(value, list) or not all(isinstance(item, dict) for item in value):
        raise ValueError("--json must decode to a JSON array of objects")
    return value


def _json_default(value: Any) -> str:
    return str(value)


def _print_result(value: Any) -> None:
    if isinstance(value, str):
        print(value)
    else:
        print(json.dumps(value, indent=2, ensure_ascii=False, default=_json_default))


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Call tools from the bundled COMSOL MCP runtime.")
    parser.add_argument(
        "--runtime-dir",
        default=str(DEFAULT_RUNTIME_DIR),
        help="Path to the bundled comsol_mcp_runtime directory.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("list-tools", help="List registered tools and resources.")

    tool_parser = subparsers.add_parser("tool", help="Invoke a registered tool.")
    tool_parser.add_argument("name", help="Tool name, for example model_load.")
    tool_parser.add_argument("--json", default="{}", help="JSON object passed as keyword arguments.")

    resource_parser = subparsers.add_parser("resource", help="Read a registered resource URI.")
    resource_parser.add_argument("uri", help="Resource URI, for example comsol://session/info.")

    batch_parser = subparsers.add_parser("batch", help="Run tool/resource steps in one process.")
    batch_parser.add_argument(
        "--json",
        required=True,
        help="JSON array of steps, each with {'tool': name, 'args': {...}} or {'resource': uri}.",
    )
    return parser


def main(argv: Optional[List[str]] = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)
    runtime_dir = Path(args.runtime_dir)

    try:
        registry = load_registry(runtime_dir)
        if args.command == "list-tools":
            _print_result(
                {
                    "runtime_dir": str(runtime_dir.resolve()),
                    "tool_count": len(registry.tools),
                    "resource_count": len(registry.resources),
                    "tools": registry.tool_names(),
                    "resources": registry.resource_names(),
                }
            )
        elif args.command == "tool":
            _print_result(invoke_tool(registry, args.name, _parse_json_object(args.json)))
        elif args.command == "resource":
            _print_result(invoke_resource(registry, args.uri))
        elif args.command == "batch":
            _print_result(invoke_steps(registry, _parse_json_list(args.json)))
        else:
            parser.error(f"Unsupported command: {args.command}")
    except Exception as exc:
        _print_result({"success": False, "error": str(exc), "error_type": type(exc).__name__})
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
