"""
ZigX - A maturin-like Python binding system implemented in pure Zig.

ZigX makes it easy to create Python extensions using Zig, providing:
- Automatic ctypes-based bindings generation
- Type stub (.pyi) generation for IDE support
- Cross-platform wheel building
- GIL-safe operation helpers

Usage:
    zigx new <project_name>    Create a new ZigX project
    zigx develop               Build and install in development mode
    zigx build --release       Build release wheel
    zigx publish               Build and upload to PyPI

For more information, run: zigx --help
"""

__version__ = "0.0.1"
__all__ = ["main", "run"]

import platform
import subprocess
import sys
from pathlib import Path
from typing import Optional


def find_zigx_binary() -> Optional[Path]:
    """Find the zigx binary in common locations."""
    # Check if running from source
    pkg_dir = Path(__file__).parent

    # Look in installed bin directory (from wheel)
    bin_dir = pkg_dir / "bin" / get_binary_name()
    if bin_dir.exists():
        return bin_dir

    # Look for zig-out directory (built binary, development mode)
    zig_out = pkg_dir / "zig-out" / "bin" / get_binary_name()
    if zig_out.exists():
        return zig_out

    # Look in parent's zig-out (development mode)
    parent_zig_out = pkg_dir.parent / "zigx" / "zig-out" / "bin" / get_binary_name()
    if parent_zig_out.exists():
        return parent_zig_out

    # Look in system bin directory
    sys_bin_dir = Path(sys.prefix) / "bin"
    installed = sys_bin_dir / get_binary_name()
    if installed.exists():
        return installed

    # Check if zig is available and try to build
    return None


def get_binary_name() -> str:
    """Get the platform-specific binary name."""
    if platform.system() == "Windows":
        return "zigx.exe"
    return "zigx"


def ensure_binary() -> Path:
    """Ensure the zigx binary exists, building if necessary."""
    binary = find_zigx_binary()
    if binary:
        return binary

    # Try to build from source
    pkg_dir = Path(__file__).parent
    zig_src = pkg_dir / "src"

    # Check for Zig source
    if not (zig_src / "main.zig").exists():
        # Maybe in development structure
        zig_src = pkg_dir.parent / "zigx" / "src"

    if (zig_src / "main.zig").exists():
        build_dir = zig_src.parent
        print("Building zigx from source...", file=sys.stderr)
        try:
            result = subprocess.run(
                ["zig", "build", "-Doptimize=ReleaseSafe"],
                cwd=build_dir,
                capture_output=True,
                text=True,
                check=False,  # We handle errors manually for better messages
            )
            if result.returncode == 0:
                binary = build_dir / "zig-out" / "bin" / get_binary_name()
                if binary.exists():
                    return binary
            else:
                print(f"Build failed: {result.stderr}", file=sys.stderr)
        except FileNotFoundError:
            pass

    raise RuntimeError(
        "zigx binary not found. Please ensure Zig is installed and run:\n"
        "  cd zigx && zig build\n"
        "Or install the pre-built wheel."
    )


def run(*args: str) -> int:
    """Run the zigx command with the given arguments."""
    try:
        binary = ensure_binary()
    except RuntimeError as e:
        print(str(e), file=sys.stderr)
        return 1

    result = subprocess.run([str(binary)] + list(args), check=False)
    return result.returncode


def main() -> int:
    """Main entry point for the zigx command."""
    return run(*sys.argv[1:])


if __name__ == "__main__":
    sys.exit(main())
