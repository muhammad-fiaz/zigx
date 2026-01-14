# Contributing

Thank you for your interest in contributing to ZIGX!

## Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/zigx.git
   ```
3. Create a branch:
   ```bash
   git checkout -b feature/your-feature
   ```

## Development Setup

### Requirements

- Zig 0.14.0 or later (0.15.x recommended)
- Git

### Building

```bash
# Build the library
zig build

# Run tests
zig build test

# Run the example
zig build run-example
```

### Project Structure

```
zigx/
├── src/
│   ├── zigx.zig          # Public API
│   ├── bundler.zig       # Archive creation
│   ├── extractor.zig     # Archive extraction
│   ├── compression.zig   # Compression engine
│   ├── format.zig        # Format definitions
│   ├── parser.zig        # Archive parsing
│   ├── validator.zig     # Validation
│   ├── security.zig      # Security features
│   ├── hash.zig          # Hashing utilities
│   └── config.zig        # Configuration
├── examples/
│   └── self_bundle.zig   # CLI example
├── docs/                 # Documentation
├── build.zig
└── build.zig.zon
```

## Making Changes

### Code Style

- Follow Zig's style guide
- Use descriptive variable names
- Add comments for complex logic
- Keep functions focused and small

### Testing

Add tests for new functionality:

```zig
test "my_feature" {
    // Test code
}
```

Run tests before submitting:

```bash
zig build test
```

### Documentation

Update documentation for API changes:

- Add/update doc comments in code
- Update relevant markdown files in `docs/`

## Submitting Changes

1. Ensure tests pass
2. Update documentation
3. Commit with clear messages:
   ```
   feat: add exclude pattern support
   
   - Add matchesExcludePattern function
   - Support glob-style patterns
   - Update CompressOptions struct
   ```
4. Push to your fork
5. Open a Pull Request

### PR Guidelines

- Describe what the PR does
- Reference any related issues
- Include test coverage
- Keep PRs focused on one feature/fix

## Reporting Issues

### Bug Reports

Include:
- Zig version (`zig version`)
- OS and architecture
- Steps to reproduce
- Expected vs actual behavior
- Minimal code example

### Feature Requests

Include:
- Use case description
- Proposed API (if applicable)
- Alternatives considered

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.

## Questions?

Open an issue for questions or discussions!
