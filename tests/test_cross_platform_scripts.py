from __future__ import annotations

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class CrossPlatformScriptTests(unittest.TestCase):
    def test_comsol_bash_scripts_exist_and_detect_os(self):
        for script in [
            "comsol-multiphysics/scripts/probe_comsol.sh",
            "comsol-multiphysics/scripts/validate_comsol_skill.sh",
        ]:
            content = read(script)
            self.assertTrue(content.startswith("#!/usr/bin/env bash"))
            self.assertIn("detect_os", content)
            self.assertIn("MINGW", content)
            self.assertRegex(content, r"Linux|linux")

    def test_lumerical_bash_script_exists_and_detects_os(self):
        content = read("lumerical-fdtd/scripts/probe_lumerical.sh")
        self.assertTrue(content.startswith("#!/usr/bin/env bash"))
        self.assertIn("detect_os", content)
        self.assertIn("MINGW", content)
        self.assertRegex(content, r"Linux|linux")

    def test_skill_docs_prefer_os_detection_before_probe_commands(self):
        comsol = read("comsol-multiphysics/SKILL.md")
        lumerical = read("lumerical-fdtd/SKILL.md")
        self.assertIn("Detect the operating system first", comsol)
        self.assertIn("probe_comsol.sh", comsol)
        self.assertIn("validate_comsol_skill.sh", comsol)
        self.assertIn("Detect the operating system first", lumerical)
        self.assertIn("probe_lumerical.sh", lumerical)


if __name__ == "__main__":
    unittest.main()
