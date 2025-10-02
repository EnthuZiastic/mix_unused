# Mix Unused

[![Module Version](https://img.shields.io/hexpm/v/mix_unused.svg)](https://hex.pm/packages/mix_unused)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/mix_unused/)
[![Total Download](https://img.shields.io/hexpm/dt/mix_unused.svg)](https://hex.pm/packages/mix_unused)
[![License](https://img.shields.io/hexpm/l/mix_unused.svg)](https://github.com/hauleth/mix_unused/blob/master/LICENSE.md)
[![Last Updated](https://img.shields.io/github/last-commit/hauleth/mix_unused.svg)](https://github.com/hauleth/mix_unused/commits/master)
[![CodeCov](https://codecov.io/gh/hauleth/mix_unused/branch/master/graph/badge.svg?token=936vbg6xv6)](https://codecov.io/gh/hauleth/mix_unused)

**Mix compiler tracer for detecting unused public functions in Elixir projects.**

Mix Unused is a compile-time analysis tool that identifies unused public functions, private functions that could be made private, and functions only called recursively. It integrates seamlessly into your Mix compilation workflow and provides actionable insights to improve code maintainability.

## Installation

```elixir
def deps do
  [
    {:mix_unused, "~> 0.3.0"}
  ]
end
```

The docs can be found at [https://hexdocs.pm/mix_unused](https://hexdocs.pm/mix_unused).

---

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
  - [Basic Setup](#basic-setup)
  - [Analyzers](#analyzers)
- [Smart Framework Detection](#smart-framework-detection)
- [Dynamic Dispatch Detection](#dynamic-dispatch-detection)
- [Configuration](#configuration)
  - [Ignore Patterns](#ignore-patterns)
  - [Severity Levels](#severity-levels)
  - [Advanced Filtering](#advanced-filtering)
- [HTML Report](#html-report)
- [How It Works](#how-it-works)
- [Limitations](#limitations)
- [License](#license)

---

## Features

- **Three Built-in Analyzers**:
  - **Unused**: Detects public functions that are never called
  - **Private**: Identifies public functions that could be made private (only called within the same module)
  - **RecursiveOnly**: Finds functions only called recursively (potential dead code)

- **Smart Framework Detection**: Automatically recognizes and excludes common Elixir/Phoenix framework patterns:
  - Phoenix controllers, LiveView, channels, views
  - OTP GenServer, Supervisor, Application callbacks
  - Plug middleware, Ecto schemas, Protocol implementations

- **Dynamic Dispatch Detection**: Warns about modules using `apply/2` or `apply/3` to help identify potential false positives

- **Interactive HTML Reports**: Generate comprehensive, filterable reports with file tree navigation, statistics, and search capabilities

- **Flexible Configuration**: Pattern-based ignore lists with regex support, metadata-based filtering, and custom predicates

- **Compile-time Integration**: Runs seamlessly as part of your Mix compilation workflow

---

## Usage

### Basic Setup

After installation you need to add `:unused` as a compiler to the list of Mix
compilers:

```elixir
defmodule MySystem.MixProject do
  use Mix.Project

  def project do
    [
      compilers: [:unused] ++ Mix.compilers(),
      # In case of Phoenix projects you need to add it to the list
      # compilers: [:unused, :phoenix, :gettext] ++ Mix.compilers()
      # ...
      #
      # If you want to only run it in the dev environment you could do
      # it by using `compilers: compilers(Mix.env()) ++ Mix.compilers()`
      # instead and then returning the right compilers per environment.
    ]
  end

  # ...
end
```

Then you just need to run `mix compile` or `mix compile --force` as usual
and unused hints will be added to the end of the output.

### Analyzers

Mix Unused includes three powerful analyzers that run automatically:

#### 1. Unused Analyzer
Detects public functions that are never called anywhere in your codebase.

```elixir
# Example output:
hint: MixUnused.Analyzers.Unused - function Foo.bar/1 is unused
  lib/foo.ex:10
```

#### 2. Private Analyzer
Identifies public functions that could be made private because they're only called within the same module.

```elixir
# Example output:
hint: MixUnused.Analyzers.Private - function Foo.internal_helper/2 could be private
  lib/foo.ex:25
```

#### 3. RecursiveOnly Analyzer
Finds functions that are only called recursively, indicating potential dead code.

```elixir
# Example output:
hint: MixUnused.Analyzers.RecursiveOnly - function Foo.loop/1 is only called recursively
  lib/foo.ex:40
```

---

## Smart Framework Detection

The tool automatically recognizes common Elixir/Phoenix framework patterns and excludes them from unused analysis:

- **Phoenix**: Controller actions, LiveView callbacks, Channels, Views
- **OTP**: GenServer, Supervisor, Application callbacks
- **Plug**: Middleware callbacks (`init/1`, `call/2`)
- **Ecto**: Schema and changeset functions
- **Protocols**: Standard library protocol implementations
- **Test Helpers**: Factory, Fixture, and test support modules

This means you no longer need to manually annotate most framework callbacks with `@doc export: true`.

---

## Dynamic Dispatch Detection

The tool automatically detects modules that use `apply/2` or `apply/3` and generates warnings during compilation to help you identify potential false positives:

```elixir
⚠️  Module MyApp.Worker uses dynamic dispatch (apply/3 calls).
    Functions called via apply may be incorrectly marked as unused.
    Consider adding them to the ignore list if false positives occur.
```

### Known Limitations

This tool cannot detect dynamic calls in the form of:

```elixir
apply(mod, func, args)
```

This means that, for example, if you have a custom `child_spec/1` definition used indirectly in your supervisor, `mix unused` may return it as unused. See the [Configuration](#configuration) section for how to handle these cases.

---

## Configuration

### Ignore Patterns

You can define functions to ignore using pattern matching in your project configuration:

```elixir
def project do
  [
    # ⋯
    unused: [
      ignore: [
        # Exact function match
        {MyApp.Foo, :child_spec, 1},

        # Wildcard matches
        {:_, :child_spec, 1},              # Any module's child_spec/1
        {MyApp.Test, :foo, :_},            # Any arity of MyApp.Test.foo

        # Regular expression matches
        {~r/^MyAppWeb\..*Controller/, :_, 2},  # All controller actions with arity 2
        {:_, ~r/^__.+__\??$/, :_},            # All special functions like __struct__

        # Arity ranges
        {MyApp.Utils, :helper, 1..3},      # helper/1, helper/2, helper/3

        # Module shortcuts
        MyApp.EntireModule,                # Ignore entire module
        ~r/^MyApp\.Test\./,                # Ignore all test modules

        # Ignore unused structs
        {StructModule, :__struct__, 0}
      ]
    ],
    # ⋯
  ]
end
```

### Severity Levels

Control the severity of reported issues:

```bash
# Set severity level (hint, information, warning, error)
mix compile --severity warning

# Treat warnings as errors (fail compilation)
mix compile --severity warning --warnings-as-errors
```

Or configure in `mix.exs`:

```elixir
def project do
  [
    unused: [
      severity: :warning,
      warnings_as_errors: true
    ]
  ]
end
```

### Advanced Filtering

Use predicate functions for complex filtering logic:

```elixir
def project do
  [
    unused: [
      ignore: [
        # Unary predicate - receives {module, function, arity}
        fn {mod, _fun, _arity} ->
          String.starts_with?(to_string(mod), "Elixir.MyApp.Generated")
        end,

        # Binary predicate - receives {m, f, a} and metadata
        fn {_mod, fun, _arity}, meta ->
          meta.file =~ ~r/test/ or fun in [:setup, :teardown]
        end
      ]
    ]
  ]
end
```

### Documentation Metadata

Mark functions as exports to exclude them from unused analysis:

```elixir
@doc export: true
def public_api_function do
  # This function won't be marked as unused
end
```

## HTML Report

Mix Unused can generate comprehensive, interactive HTML reports for analyzing unused functions.

### Quick Start

Generate an HTML report:

```bash
# Basic report
mix compile --html-report

# Custom output path
mix compile --html-report --html-output reports/unused.html

# Auto-open in browser
mix compile --html-report --html-open
```

Or configure in `mix.exs`:

```elixir
def project do
  [
    unused: [
      html_report: true,                    # Enable HTML report generation
      html_output: "reports/unused.html",   # Custom output path
      html_open: false                       # Auto-open in browser
    ]
  ]
end
```

### Report Features

The generated HTML report is completely standalone (no external dependencies) and includes:

- **Interactive File Tree**: Browse your codebase hierarchy with issue counts per folder/file
- **Statistics Dashboard**: Total issues, breakdown by severity and analyzer type
- **Search & Filter**: Real-time search across files, functions, and messages
- **Severity Indicators**: Color-coded badges (error, warning, hint, information)
- **Analyzer Grouping**: Filter by analyzer type (Private, Unused, RecursiveOnly)
- **Top Files View**: Sorted list of files with the most issues
- **Responsive Design**: Works on desktop and mobile devices
- **Print-Friendly**: Clean layout for printing or PDF export
- **Click to Open**: Click file paths to open them in your editor (with proper URL handling)

---

## How It Works

Mix Unused integrates into the Elixir compiler pipeline as a tracer:

1. **Compilation Tracing**: Hooks into Mix compilation to track all function calls and definitions
2. **Graph Analysis**: Builds a call graph using `libgraph` to understand function relationships
3. **Pattern Detection**: Applies three analyzers to identify unused, private-worthy, and recursive-only functions
4. **Smart Filtering**: Automatically excludes framework patterns and respects ignore configurations
5. **Report Generation**: Produces compiler diagnostics and optional HTML reports

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Mix.Tasks.Compile.Unused (Compiler Entry Point)            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  MixUnused.Tracer (Compile-time Tracing)                    │
│  - Tracks function definitions                               │
│  - Tracks function calls                                     │
│  - Detects dynamic dispatch (apply/2, apply/3)              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  MixUnused.Analyze (Call Graph Analysis)                    │
│  - Builds call graph using libgraph                         │
│  - Identifies transitive dependencies                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Analyzers (Pattern Detection)                              │
│  ├─ Unused: Never called functions                          │
│  ├─ Private: Could-be-private functions                     │
│  └─ RecursiveOnly: Only recursively called functions        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Filtering & Output                                          │
│  ├─ MixUnused.Heuristics (Framework detection)             │
│  ├─ MixUnused.Filter (Ignore patterns)                     │
│  └─ MixUnused.Report.Generator (HTML reports)              │
└─────────────────────────────────────────────────────────────┘
```

---

## Limitations

While Mix Unused is powerful, it has some known limitations:

### Dynamic Dispatch
Cannot detect function calls made via `apply/2` or `apply/3`:

```elixir
# This function may be marked as unused even if called
apply(MyModule, :dynamic_function, [arg1, arg2])
```

**Workaround**: Add dynamic functions to ignore list or use `@doc export: true`

### Metaprogramming
May not detect functions generated or called via macros at compile time.

**Workaround**: Use ignore patterns for macro-generated functions

### Runtime-only Calls
Functions only called at runtime (e.g., via configuration) may be marked as unused.

**Workaround**: Use `@doc export: true` or add to ignore list

### External Callers
Cannot detect calls from outside your application (e.g., when building a library).

**Workaround**: Mark public API functions with `@doc export: true`

---

## License

Copyright © 2021 by Łukasz Niemier

This work is free. You can redistribute it and/or modify it under the
terms of the MIT License. See the [LICENSE](./LICENSE) file for more details.
