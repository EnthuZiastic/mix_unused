# Mix Unused

[![Module Version](https://img.shields.io/hexpm/v/mix_unused.svg)](https://hex.pm/packages/mix_unused)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/mix_unused/)
[![Total Download](https://img.shields.io/hexpm/dt/mix_unused.svg)](https://hex.pm/packages/mix_unused)
[![License](https://img.shields.io/hexpm/l/mix_unused.svg)](https://github.com/hauleth/mix_unused/blob/master/LICENSE.md)
[![Last Updated](https://img.shields.io/github/last-commit/hauleth/mix_unused.svg)](https://github.com/hauleth/mix_unused/commits/master)
[![CodeCov](https://codecov.io/gh/hauleth/mix_unused/branch/master/graph/badge.svg?token=936vbg6xv6)](https://codecov.io/gh/hauleth/mix_unused)

Mix compiler tracer for detecting unused public functions.

## Installation

```elixir
def deps do
  [
    {:mix_unused, "~> 0.3.0"}
  ]
end
```

The docs can be found at [https://hexdocs.pm/mix_unused](https://hexdocs.pm/mix_unused).

## Usage

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

### Warning

This isn't perfect solution and this will not find dynamic calls in form of:

```elixir
apply(mod, func, args)
```

So this mean that, for example, if you have custom `child_spec/1` definition
then `mix unused` can return such function as unused even when you are using
that indirectly in your supervisor.

**Dynamic Dispatch Detection**: The tool now automatically detects modules that use `apply/2` or `apply/3` and generates warnings during compilation to help you identify potential false positives:

```elixir
⚠️  Module MyApp.Worker uses dynamic dispatch (apply/3 calls).
    Functions called via apply may be incorrectly marked as unused.
    Consider adding them to the ignore list if false positives occur.
```

### Smart Framework Detection

The tool automatically recognizes common Elixir/Phoenix framework patterns and excludes them from unused analysis:

- **Phoenix**: Controller actions, LiveView callbacks, Channels, Views
- **OTP**: GenServer, Supervisor, Application callbacks
- **Plug**: Middleware callbacks (`init/1`, `call/2`)
- **Ecto**: Schema and changeset functions
- **Protocols**: Standard library protocol implementations
- **Test Helpers**: Factory, Fixture, and test support modules

This means you no longer need to manually annotate most framework callbacks with `@doc export: true`.

### Configuration

You can define used functions by adding `mfa` in `unused: [ignored: [⋯]]`
in your project configuration:

```elixir
def project do
  [
    # ⋯
    unused: [
      ignore: [
        {MyApp.Foo, :child_spec, 1}
      ]
    ],
    # ⋯
  ]
end
```

## HTML Report

Mix Unused can generate comprehensive, interactive HTML reports for analyzing unused functions. The report includes:

- **Interactive File Tree**: Browse your codebase hierarchy with issue counts per folder/file
- **Statistics Dashboard**: Total issues, breakdown by severity and analyzer type
- **Search & Filter**: Real-time search across files, functions, and messages with filters by severity and analyzer
- **Top Files View**: Sorted list of files with the most issues
- **Detailed Issue Listings**: Click any file to view all its unused function details

### Usage

Generate an HTML report by adding the `--html-report` flag:

```bash
mix compile --html-report
```

This will create `unused_report.html` in your project root. To customize the output path:

```bash
mix compile --html-report --html-output reports/unused.html
```

To automatically open the report in your browser after generation:

```bash
mix compile --html-report --html-open
```

You can also configure HTML report generation in your project configuration:

```elixir
def project do
  [
    # ⋯
    unused: [
      html_report: true,                    # Enable HTML report generation
      html_output: "reports/unused.html",   # Custom output path
      html_open: false                       # Auto-open in browser
    ],
    # ⋯
  ]
end
```

### Report Features

The generated HTML report is completely standalone (no external dependencies) and includes:

1. **Collapsible Folder Tree**: Navigate your project structure with expandable/collapsible folders
2. **Issue Count Badges**: See at a glance how many issues exist in each folder/file
3. **Severity Indicators**: Color-coded badges for error, warning, hint, and information levels
4. **Analyzer Grouping**: Filter and group by analyzer type (Private, Unused, RecursiveOnly)
5. **Responsive Design**: Works on desktop and mobile devices
6. **Print-Friendly**: Clean layout for printing or PDF export

## Copyright and License

Copyright © 2021 by Łukasz Niemier

This work is free. You can redistribute it and/or modify it under the
terms of the MIT License. See the [LICENSE](./LICENSE) file for more details.
