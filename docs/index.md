# ZigX

<p align="center">
  <strong>A maturin-like Python binding system implemented in pure Zig</strong>
</p>

<p align="center">
  <a href="https://pypi.org/project/zigx/"><img src="https://badge.fury.io/py/zigx.svg" alt="PyPI version"></a>
  <a href="https://opensource.org/licenses/Apache-2.0"><img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" alt="License"></a>
  <a href="https://pypi.org/project/zigx/"><img src="https://img.shields.io/pypi/pyversions/zigx.svg" alt="Python versions"></a>
</p>

---

ZigX makes it easy to create Python extensions using Zig, providing automatic ctypes-based bindings, type stub generation, GIL support, and cross-platform wheel building.

## Features

- 🚀 **Pure Zig Implementation** - No Python build dependencies beyond standard library
- 📦 **Wheel Building** - Create platform-specific wheels with proper metadata
- 🔧 **Development Mode** - Hot-reload friendly `develop` command
- 📝 **Type Stubs** - Automatic `.pyi` file generation for IDE support
- 🔒 **GIL-Safe** - Automatic GIL release for ctypes calls (just like maturin/pyo3)
- 🌐 **Cross-Platform** - Supports Linux, Windows, and macOS
- 🎯 **Automatic Export Detection** - No configuration needed, exports are detected from Zig source
- ⚡ **uv Integration** - Works seamlessly as a PEP 517 build backend

## Quick Start

```bash
# Install zigx
pip install zigx

# Create a new project
zigx new myproject
cd myproject

# Build in development mode
zigx develop

# Use in Python
python -c "import myproject; print(myproject.add(1, 2))"
```

## Example

Write your Zig code:

```zig
// src/lib.zig
pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

pub export fn fibonacci(n: u32) u64 {
    if (n <= 1) return n;
    var a: u64 = 0;
    var b: u64 = 1;
    var i: u32 = 2;
    while (i <= n) : (i += 1) {
        const c = a + b;
        a = b;
        b = c;
    }
    return b;
}
```

Use in Python with automatic bindings:

```python
import myproject

result = myproject.add(1, 2)  # Returns 3
fib_10 = myproject.fibonacci(10)  # Returns 55
```

## Requirements

- **Zig** 0.14.0 or later (0.15.0+ recommended)
- **Python** 3.8 or later
- **uv** (recommended) or pip

## Navigation

<div class="grid cards" markdown>

-   🚀 **Getting Started**

    ---

    Install ZigX and create your first project

    [→ Installation](getting-started/installation.md)

-   📖 **User Guide**

    ---

    Learn how to write Zig code and build Python extensions

    [→ User Guide](guide/writing-zig.md)

-   💻 **Examples**

    ---

    Explore example projects and use cases

    [→ Examples](examples/basic.md)

-   🔧 **Reference**

    ---

    CLI commands, configuration, and API reference

    [→ Reference](reference/cli.md)

</div>
