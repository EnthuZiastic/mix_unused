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

## Copyright and License

Copyright © 2021 by Łukasz Niemier

This work is free. You can redistribute it and/or modify it under the
terms of the MIT License. See the [LICENSE](./LICENSE) file for more details.
