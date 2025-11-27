#!/usr/bin/env python3
"""Hatchling build hook to compile ZigX binary before packaging.

This hook is called by Hatchling before building the wheel to ensure the Zig binary
is compiled and ready for inclusion in the distribution.
"""

import os
import platform
import subprocess
import sys
from pathlib import Path
from typing import Any, Optional

from hatchling.builders.hooks.plugin.interface import (
    BuildHookInterface,  # pylint: disable=import-error
)


class ZigBuildHook(BuildHookInterface):
    """Custom Hatchling build hook for compiling ZigX binary.

    This hook automatically compiles the Zig binary before packaging
    the wheel distribution, ensuring the native binary is included.
    """

    def pre_build(self, wheel_directory: str, config_settings: Optional[Any] = None) -> None:  # pylint: disable=unused-argument
        """Compile the ZigX binary for the current platform.

        Args:
            wheel_directory: Directory where the wheel is being built
            config_settings: Build configuration settings
        """
        # Check if build should be skipped
        if os.environ.get("ZIGX_SKIP_BUILD") == "1":
            print("⏭️  Skipping Zig compilation (ZIGX_SKIP_BUILD=1)", file=sys.stderr)
            return

        project_root = Path(__file__).parent
        zigx_dir = project_root
        build_zig = zigx_dir / "build.zig"

        if not build_zig.exists():
            print(f"⚠️  Warning: {build_zig} not found, skipping Zig compilation", file=sys.stderr)
            return

        print("🔨 Compiling zigx binary...", file=sys.stderr)

        # Check if Zig is available
        try:
            result = subprocess.run(
                ["zig", "version"],
                capture_output=True,
                text=True,
                check=False,
            )
            if result.returncode != 0:
                print("⚠️  Warning: Zig not found, using pre-built binary", file=sys.stderr)
                return

            zig_version = result.stdout.strip()
            print(f"🐺 Using Zig {zig_version}", file=sys.stderr)
        except FileNotFoundError:
            print("⚠️  Warning: Zig not found, using pre-built binary", file=sys.stderr)
            return

        # Determine build mode
        build_mode = os.environ.get("ZIGX_BUILD_MODE", "ReleaseSafe")

        # Compile the binary
        print(f"🏗️  Building with -Doptimize={build_mode}...", file=sys.stderr)
        result = subprocess.run(
            ["zig", "build", f"-Doptimize={build_mode}"],
            cwd=zigx_dir,
            capture_output=True,
            text=True,
            check=False,
        )

        if result.returncode != 0:
            print(f"❌ Error compiling zigx: {result.stderr}", file=sys.stderr)
            print("🔄 Falling back to pre-built binary if available", file=sys.stderr)
            return  # Don't fail the build, just warn

        # Verify the binary was created
        binary_name = "zigx.exe" if platform.system() == "Windows" else "zigx"
        binary_path = zigx_dir / "zig-out" / "bin" / binary_name

        if not binary_path.exists():
            print(f"⚠️  Warning: Binary not found at {binary_path}", file=sys.stderr)
            return

        # Make executable on Unix
        if platform.system() != "Windows":
            binary_path.chmod(0o755)

        print(f"✅ Successfully compiled zigx binary at {binary_path}", file=sys.stderr)
