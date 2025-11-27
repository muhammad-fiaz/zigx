<div align="center">

# ZigX

[![PyPI version](https://badge.fury.io/py/zigx.svg)](https://badge.fury.io/py/zigx)
[![PyPI downloads](https://img.shields.io/pypi/dm/zigx.svg)](https://pypi.org/project/zigx/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Python](https://img.shields.io/pypi/pyversions/zigx.svg)](https://pypi.org/project/zigx/)
[![Documentation](https://img.shields.io/badge/docs-mkdocs-blue)](https://muhammad-fiaz.github.io/zigx)
[![CI](https://github.com/muhammad-fiaz/zigx/actions/workflows/deploy.yml/badge.svg)](https://github.com/muhammad-fiaz/zigx/actions)
[![GitHub issues](https://img.shields.io/github/issues/muhammad-fiaz/zigx)](https://github.com/muhammad-fiaz/zigx/issues)
[![GitHub pull requests](https://img.shields.io/github/issues-pr/muhammad-fiaz/zigx)](https://github.com/muhammad-fiaz/zigx/pulls)
[![GitHub last commit](https://img.shields.io/github/last-commit/muhammad-fiaz/zigx)](https://github.com/muhammad-fiaz/zigx/commits/main)

*A maturin-like Python binding system implemented in pure Zig.*

</div>

ZigX makes it easy to create Python extensions using Zig, providing automatic ctypes-based bindings, type stub generation, GIL support, and cross-platform wheel building.

> Note: This Project is in Early Active Development, so there may be Breaking changes!

## Features

- 🚀 **Pure Zig Implementation** - No Python build dependencies beyond standard library
- 📦 **Bootstrapped Wheels** - Pre-compiled binaries bundled for all platforms
- 🔧 **Development Mode** - Hot-reload friendly `develop` command
- 📝 **Type Stubs** - Automatic `.pyi` file generation for IDE support
- 🔒 **GIL-Safe** - Automatic GIL release for ctypes calls (just like maturin/pyo3)
- 🌐 **Cross-Platform** - Supports Linux (x86_64, aarch64), Windows (x86_64), and macOS (x86_64, arm64)
- 🎯 **Automatic Export Detection** - No configuration needed, exports are detected from Zig source
- ⚡ **uv Integration** - Works seamlessly with modern Python tooling
- 💪 **No Zig Required** - Install and use without needing Zig compiler (binaries pre-built)

## Installation

### From PyPI (Recommended)

```bash
pip install zigx
```

Or with uv (recommended):

```bash
uv pip install zigx
```

**No Zig installation required!** ZigX wheels include pre-compiled binaries for your platform.

### From Source (Requires Zig 0.14.0+)

```bash
git clone https://github.com/muhammad-fiaz/zigx.git
cd zigx
uv pip install -e .
```

## Documentation

📚 **Full documentation is available at [muhammad-fiaz.github.io/zigx](https://muhammad-fiaz.github.io/zigx)**

The documentation includes:
- Getting started guide
- API reference
- Examples and tutorials
- Troubleshooting guide

### Create a New Project

```bash
zigx new myproject
cd myproject
```

This creates a minimal project structure:
```
myproject/
├── pyproject.toml       # Project configuration with zigx build backend
├── src/
│   └── lib.zig          # Your Zig code with exported functions
└── myproject/
    └── __init__.py      # Python package (bindings generated on build)
```

### Write Zig Code

```zig
// src/lib.zig
const std = @import("std");

/// Add two integers
pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

/// Multiply two floats
pub export fn multiply(a: f64, b: f64) f64 {
    return a * b;
}

/// Calculate fibonacci number
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

### Development Build

```bash
# Build and install in development mode
zigx develop
```

### Use in Python

```python
import myproject

# Call your Zig functions - GIL is automatically released!
result = myproject.add(1, 2)
print(f"1 + 2 = {result}")

# With type hints in your IDE!
product = myproject.multiply(3.14, 2.0)
fib_10 = myproject.fibonacci(10)
```

### Release Build

```bash
# Build a release wheel
zigx build --release
```

This creates a wheel in `dist/`:
```
dist/myproject-0.1.0-cp314-cp314-win_amd64.whl
```

### Publish to PyPI

```bash
# Build and upload
zigx publish
```

## GIL Support

ZigX provides automatic GIL (Global Interpreter Lock) release just like maturin/pyo3. When you call a native function through ctypes, Python automatically releases the GIL for the duration of the call.

This means your Zig code can run in parallel with other Python threads without any extra configuration:

```python
import threading
import myproject

def compute():
    # GIL is released during this call - other threads can run
    result = myproject.heavy_computation(data)
    return result

# Run computations in parallel
threads = [threading.Thread(target=compute) for _ in range(4)]
for t in threads:
    t.start()
for t in threads:
    t.join()
```

For explicit GIL control in Zig, you can use the zigx helpers:

```zig
const zigx = @import("zigx");

pub export fn heavy_computation(data: [*]f64, len: usize) f64 {
    // GIL is already released by ctypes
    // Do heavy work without blocking Python
    var sum: f64 = 0;
    for (0..len) |i| {
        sum += @sin(data[i]) * @cos(data[i]);
    }
    return sum;
}
```

## Type Mappings

| Zig Type | Python Type | ctypes Type |
|----------|-------------|-------------|
| `i8`     | `int`       | `c_int8`    |
| `i16`    | `int`       | `c_int16`   |
| `i32`    | `int`       | `c_int32`   |
| `i64`    | `int`       | `c_int64`   |
| `u8`     | `int`       | `c_uint8`   |
| `u16`    | `int`       | `c_uint16`  |
| `u32`    | `int`       | `c_uint32`  |
| `u64`    | `int`       | `c_uint64`  |
| `f32`    | `float`     | `c_float`   |
| `f64`    | `float`     | `c_double`  |
| `bool`   | `bool`      | `c_bool`    |
| `void`   | `None`      | `None`      |
| `[*]u8`  | `bytes`     | `c_char_p`  |
| `usize`  | `int`       | `c_size_t`  |

## Commands

| Command | Description |
|---------|-------------|
| `zigx new <name>` | Create a new ZigX project |
| `zigx develop` | Build and install in development mode |
| `zigx build --release` | Build a release wheel |
| `zigx publish` | Build and publish to PyPI |
| `zigx --help` | Show help information |

## Requirements

### System Requirements

- **Operating System**: Linux, macOS, or Windows
- **Architecture**: x86_64, ARM64

### Software Requirements

- **Zig Compiler**: 0.14.0 or later (0.15.0+ recommended)
  - Download from: https://ziglang.org/download/
- **Python**: 3.8 or later
- **Build Tool**: uv (recommended) or pip or hatchling or poetry

### Optional Dependencies

For development:
- pytest (testing)
- ruff (linting)
- mypy (type checking)
- mkdocs (documentation)
- hatchling (build backend)

For documentation building:
- mkdocs-material
- mkdocstrings[python]

## Documentation

Full documentation is available at [muhammad-fiaz.github.io/zigx](https://muhammad-fiaz.github.io/zigx)

## License

Apache License 2.0 - see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Links

- 📚 [Documentation](https://muhammad-fiaz.github.io/zigx)
- 🐛 [Issue Tracker](https://github.com/muhammad-fiaz/zigx/issues)
- 📦 [PyPI Package](https://pypi.org/project/zigx/)
- 💻 [Source Code](https://github.com/muhammad-fiaz/zigx)
