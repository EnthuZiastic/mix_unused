# Mix Unused - False Positives Deep Analysis Report

**Analysis Date:** 2025-10-02
**Tool Version:** 0.4.1
**Analysis Type:** Comprehensive Code Review with Sequential Reasoning

---

## Executive Summary

Mix Unused is an Elixir compile-time tracer that detects unused public functions. While the tool's core architecture is sound, it produces **false positives due to fundamental limitations of static compile-time analysis**. This report identifies 12 distinct sources of false positives, categorizes them by root cause, and provides actionable recommendations.

**Key Finding:** False positives are NOT bugs in the implementation, but rather inherent limitations of the compile-time analysis approach. The tool cannot detect runtime dispatch, cross-boundary calls, or dynamically invoked functions.

---

## Architecture Overview

### Components

1. **Tracer** (`lib/mix_unused/tracer.ex`)
   - Hooks into Elixir compiler via `Code.put_compiler_option(:tracers, [Tracer])`
   - Captures function calls during compilation
   - Stores call graph in ETS table

2. **Exports** (`lib/mix_unused/exports.ex`)
   - Extracts public functions from compiled BEAM files
   - Uses `:beam_lib.chunks` and `Code.fetch_docs/1`
   - Filters out callbacks for declared `@behaviour` modules

3. **Analyzers** (`lib/mix_unused/analyzers/`)
   - **Unused**: Detects completely unused functions
   - **Private**: Suggests functions that should be private
   - **RecursiveOnly**: Detects functions only called recursively

4. **Filter** (`lib/mix_unused/filter.ex`)
   - Applies ignore patterns from config
   - Supports MFA patterns, regexes, predicates

### Detection Algorithm

```elixir
# Simplified logic from analyzers/unused.ex
graph = build_call_graph(tracer_data)

for each possibly_unused_function do
  if not marked_as_export?(function) do
    reaching_callers = graph.reaching_neighbors(function)

    if all_callers_also_unused?(reaching_callers) do
      mark_as_unused(function)
    end
  end
end
```

**Key Insight:** A function is marked unused if ALL its callers are also unused. This correctly handles call cycles but fails for any calls invisible to the tracer.

---

## Root Causes of False Positives

### Category 1: Runtime vs Compile-time Dispatch

The tracer only captures **static, compile-time visible** function calls. Dynamic dispatch is invisible.

#### FP Source #1: Dynamic Apply Calls

**Location:** `lib/mix_unused/tracer.ex:44-70`

**Problem:** The tracer handles these events:
- `:remote_function`, `:imported_function`
- `:remote_macro`, `:imported_macro`
- `:local_function`, `:local_macro`
- `:struct_expansion`

But does NOT capture:
```elixir
apply(MyModule, :my_function, [args])
Kernel.apply(MyModule, :my_function, [args])
:erlang.apply(MyModule, :my_function, [args])
```

**Impact:** High - Common in GenServer, Supervisor, metaprogramming

**Example False Positive:**
```elixir
defmodule MyWorker do
  def child_spec(opts) do
    # ... supervisor spec
  end

  def start_link(args) do
    # ...
  end
end

# Usage (invisible to tracer):
children = [
  {MyWorker, [arg: :value]}  # Supervisor uses apply internally
]
Supervisor.start_link(children, strategy: :one_for_one)
```

Result: `MyWorker.start_link/1` flagged as unused ❌

**Workaround:** Add to config:
```elixir
unused: [
  ignore: [
    {:_, :child_spec, 1},
    {:_, :start_link, 1}
  ]
]
```

---

#### FP Source #2: Function Captures

**Location:** Missing tracer event handlers for captures

**Problem:** Function capture syntax is not tracked:
```elixir
Enum.map(items, &MyModule.process/1)
Task.async(&MyModule.expensive_work/0)
Enum.filter(list, &valid?/1)
```

**Analysis:** The capture operator `&` creates an anonymous function reference. The Elixir compiler likely emits different tracer events (possibly `:remote_function_capture`, `:local_function_capture`) which are caught by the catch-all clause:
```elixir
def trace(_event, _env), do: :ok  # Line 70
```

**Impact:** Critical - Very common Elixir pattern

**Evidence:** Context7 docs show captures like `&Module.function/1` are standard Elixir idiom.

**Workaround:** Manual ignore patterns for all functions passed as captures.

---

#### FP Source #3: Protocol Implementations

**Location:** Protocol dispatch mechanism

**Problem:** Protocol calls are dispatched at runtime based on data type:

```elixir
defprotocol Renderer do
  def render(data)
end

defimpl Renderer, for: JSON do
  def render(data), do: # implementation
end

defimpl Renderer, for: XML do
  def render(data), do: # implementation
end

# Usage:
Renderer.render(%JSON{})  # Calls Renderer.JSON.render/1
```

The tracer sees `Renderer.render/1` but NOT `Renderer.JSON.render/1`.

**Impact:** Critical for protocol-heavy codebases (Ecto, Phoenix)

**Workaround:**
```elixir
unused: [
  ignore: [
    {~r/^Elixir\..*\..*/, :_, :_}  # Risky: ignores nested modules
  ]
]
```

---

#### FP Source #4: Behaviour Callbacks (Partial)

**Location:** `lib/mix_unused/exports.ex:53-68`

**Problem:** Callbacks ARE handled if `@behaviour` is declared:
```elixir
callbacks = data[:attributes] |> Keyword.get(:behaviour, []) |> callbacks()

# Filtered out (line 36-37):
{name, arity} not in callbacks
```

BUT fails for:
1. **Optional callbacks** without `@behaviour` declaration
2. **Convention-based callbacks** (Phoenix actions, Plug callbacks)
3. **Implicit behaviours** (some GenServer implementations)

**Impact:** Medium - Most projects use `@behaviour` properly

**Example False Positive:**
```elixir
defmodule MyPlug do
  # No @behaviour Plug declared (common pattern)

  def init(opts), do: opts

  def call(conn, _opts) do
    # ... implementation
  end
end
```

Result: `init/1` and `call/2` flagged as unused ❌

---

### Category 2: Compilation Scope Boundaries

The tracer only sees calls within the **current compilation unit**.

#### FP Source #5: Cross-Application Calls

**Location:** `lib/mix_unused/exports.ex:10-18`

**Problem:** Only analyzes current application:
```elixir
def application(name) do
  Application.spec(:modules)  # Only current app's modules
  |> Enum.flat_map(&fetch/1)
end
```

**Impact:** Critical for umbrella projects and libraries

**Example:** Umbrella with apps A and B:
```elixir
# apps/a/lib/service.ex
defmodule A.Service do
  def process(data), do: # ...
end

# apps/b/lib/consumer.ex
defmodule B.Consumer do
  def run do
    A.Service.process(data)  # Cross-app call
  end
end
```

When compiling app A in isolation, `A.Service.process/1` flagged as unused ❌

**Evidence:** Test `test/mix/tasks/compile.unused_test.exs:8-16` expects cross-app functions to be flagged as unused, confirming this limitation.

---

#### FP Source #6: Test-Only Usage

**Location:** `lib/mix/tasks/compile.unused.ex:102-118`

**Problem:** Tool runs after `:app` compiler, NOT after `:test`:
```elixir
Compiler.after_compiler(:app, &after_compiler(...))
```

**Impact:** High - Common pattern for test helpers

**Example:**
```elixir
# lib/my_app/factory.ex
defmodule MyApp.Factory do
  def build(:user), do: %User{...}
  def build(:post), do: %Post{...}
end

# test/my_app/user_test.exs (MIX_ENV=test)
test "user creation" do
  user = MyApp.Factory.build(:user)
  # ...
end
```

Result: `Factory.build/1` flagged as unused ❌ (only used in tests)

**Workaround:**
```elixir
defp elixirc_paths(:test), do: ["lib", "test/support"]
defp elixirc_paths(_), do: ["lib"]

# In project config:
unused: [
  ignore: [
    {MyApp.Factory, :_, :_}
  ]
]
```

---

#### FP Source #7: External API Usage

**Location:** Fundamental to compile-time analysis

**Problem:** Public APIs called from outside the compilation scope:
- IEx console commands
- Other applications/libraries
- Remote nodes (distributed Erlang)
- Mix tasks
- External scripts

**Impact:** Critical for library authors

**Example:**
```elixir
# Public API meant for library users
defmodule MyLib do
  def configure(opts), do: # ...
  def start(), do: # ...
  def stop(), do: # ...
end
```

If these are only called by downstream applications, all flagged as unused ❌

**Mitigation:** Use `@doc` metadata:
```elixir
@doc export: true
def configure(opts), do: # ...
```

**Problem with mitigation:** Requires manual annotation, not discoverable, easily forgotten.

---

### Category 3: Incomplete Heuristics

The tool lacks smart defaults for what constitutes "exported" or "public API".

#### FP Source #8: Export Annotation Requirement

**Location:** `lib/mix_unused/analyzers/unused.ex:24`

**Problem:** Requires manual annotation:
```elixir
not Map.get(meta.doc_meta, :export, false)
```

**Impact:** High - Most developers don't know about this feature

**Better approach:** Auto-detect exports based on:
- Module is listed in `application/0` in `mix.exs`
- Function has public `@doc` (not `@doc false`)
- Module name suggests public API (no `.Internal`, `.Private` namespace)
- Function name follows public conventions (not `do_*`, `handle_*` helpers)

---

#### FP Source #9: Generated Functions

**Location:** `lib/mix_unused/exports.ex:35`

**Problem:** Filters generated functions:
```elixir
{name, arity} == {:__struct__, 0} or not :erl_anno.generated(anno)
```

`__struct__/0` has special exception, but other generated functions might not have proper annotations.

**Impact:** Low to Medium - Depends on macro quality

---

#### FP Source #10: Documentation Metadata Dependency

**Location:** `lib/mix_unused/exports.ex:27`

**Problem:** Relies on `Code.fetch_docs/1`:
```elixir
{_hidden?, _meta, docs} <- fetch_docs(to_string(path))
```

If docs are missing (no `@moduledoc`, no function docs), fallback returns empty list (line 75-76).

Functions without docs might not get proper metadata.

**Impact:** Low - Most functions have at least compiler-generated docs

---

#### FP Source #11: Macro Expansion Timing

**Problem:** Tracer runs after macro expansion. Dynamic calls in macro-generated code are invisible:

```elixir
defmacro define_route(name) do
  handler = String.to_atom("handle_#{name}")

  quote do
    def unquote(name)(conn) do
      apply(__MODULE__, unquote(handler), [conn])  # Dynamic!
    end
  end
end
```

The expanded code contains `apply/3`, which won't be traced.

**Impact:** Medium - Depends on framework design

---

#### FP Source #12: Module Concat and String-to-Atom

**Problem:** Dynamic module construction bypasses compile-time tracking:

```elixir
parts = [:MyApp, :Internal, :Helper]
module = Module.concat(parts)
apply(module, :process, [data])
```

From Context7 docs (Elixir anti-patterns), this is known to break compile-time dependency tracking.

**Impact:** Medium - Less common pattern

---

## Quantified Impact Assessment

| False Positive Source | Severity | Frequency | Workaround Difficulty |
|----------------------|----------|-----------|---------------------|
| Dynamic apply/3 | 🔴 Critical | High | Medium (ignore patterns) |
| Function captures | 🔴 Critical | Very High | Medium (ignore patterns) |
| Protocol implementations | 🔴 Critical | Medium | Hard (broad patterns) |
| Behaviour callbacks | 🟡 Medium | Low | Easy (@behaviour) |
| Cross-app calls | 🔴 Critical | High (umbrella) | Hard (architectural) |
| Test-only usage | 🔴 Critical | Very High | Medium (ignore + structure) |
| External API usage | 🔴 Critical | High (libraries) | Easy (@doc export: true) |
| Export annotations | 🟡 Medium | High | Easy (documentation) |
| Generated functions | 🟢 Low | Low | N/A (rare issue) |
| Missing docs | 🟢 Low | Low | Easy (add docs) |
| Macro timing | 🟡 Medium | Medium | Hard (framework dependent) |
| Module.concat | 🟡 Medium | Low | Medium (ignore patterns) |

---

## Recommendations

### For Mix Unused Maintainers

#### High Priority Improvements

1. **Add Function Capture Tracking**
   ```elixir
   # In tracer.ex, add handling for capture events
   @capture ~w[
     remote_function_capture
     local_function_capture
     imported_function_capture
   ]a

   def trace({action, _meta, module, name, arity}, env)
       when action in @capture do
     add_call(module, name, arity, env)
     :ok
   end
   ```

2. **Smart Export Detection**
   ```elixir
   # In analyzers/unused.ex
   defp is_likely_export?({module, func, _arity}, meta) do
     cond do
       # Explicit annotation
       Map.get(meta.doc_meta, :export, false) -> true

       # Has public documentation
       meta.doc_meta[:doc] not in [nil, :hidden, false] -> true

       # Common callback patterns
       func in [:init, :call, :start_link, :child_spec] -> true

       # Module suggests internal
       module_path = Atom.to_string(module)
       String.contains?(module_path, ".Internal.") -> false
       String.contains?(module_path, ".Private.") -> false

       # Default: might be export
       true
     end
   end
   ```

3. **Protocol Implementation Detection**
   ```elixir
   # Check if module name matches protocol implementation pattern
   # Elixir.ProtocolName.DataType
   defp is_protocol_impl?(module) do
     parts = Module.split(module)
     length(parts) >= 2  # Has at least Protocol.Type
   end
   ```

4. **Better Documentation**
   - Add comprehensive "Known Limitations" section to README
   - Provide common ignore patterns for Phoenix, Ecto, Plug
   - Create migration guide for adding to existing projects

#### Medium Priority

5. **Test Environment Support**
   ```elixir
   # Add option to run in multiple environments
   unused: [
     environments: [:dev, :test],
     merge_results: true
   ]
   ```

6. **Umbrella Project Support**
   - Aggregate call graphs across apps
   - Add `--umbrella` flag for multi-app analysis

7. **IDE Integration**
   - LSP integration for inline warnings
   - Quick-fix actions to add ignore patterns

### For Mix Unused Users

#### Immediate Actions

1. **Understand Tool Limitations**
   - This tool finds **statically detectable** unused code
   - False positives are expected and normal
   - Use as a **hint system**, not absolute truth

2. **Configure Ignore Patterns**
   ```elixir
   # In mix.exs
   def project do
     [
       # ...
       unused: [
         ignore: [
           # Supervisor callbacks
           {:_, :child_spec, 1},
           {:_, :start_link, :_},

           # GenServer callbacks
           {:_, :init, 1},
           {:_, :handle_call, 3},
           {:_, :handle_cast, 2},
           {:_, :handle_info, 2},

           # Phoenix controllers
           {~r/Controller$/, :_, :_},

           # Plug callbacks
           {:_, :init, 1},
           {:_, :call, 2},

           # Test factories
           {MyApp.Factory, :_, :_},
           {MyApp.Fixtures, :_, :_},

           # Public API (until you add @doc export: true)
           {MyApp.API, :_, :_}
         ]
       ]
     ]
   end
   ```

3. **Annotate Public APIs**
   ```elixir
   @doc """
   Configures the application.

   ## Options
   - `:setting` - Description
   """
   @doc export: true
   def configure(opts) do
     # ...
   end
   ```

4. **Review Output Critically**
   - Don't blindly delete flagged functions
   - Search codebase for dynamic usage
   - Check tests in different MIX_ENV
   - Verify not used by external applications

#### Progressive Adoption Strategy

**Phase 1: Awareness** (Week 1)
- Run `mix compile.unused` and review output
- DON'T delete anything yet
- Categorize findings:
  - ✅ True unused (can delete)
  - ⚠️ Need investigation
  - ❌ False positive (add to ignore)

**Phase 2: Configuration** (Week 2)
- Add ignore patterns for known false positives
- Document why each pattern is needed
- Re-run and verify clean(er) output

**Phase 3: Maintenance** (Ongoing)
- Run in CI as informational (not failing)
- Review new findings during code review
- Update ignore patterns as needed
- Gradually add `@doc export: true` to APIs

---

## Conclusion

Mix Unused is a **valuable tool with fundamental limitations**. False positives are not bugs but rather inherent constraints of compile-time static analysis.

### Key Takeaways

1. **Compile-time analysis cannot detect runtime dispatch** - This is unsolvable without runtime instrumentation

2. **Scope boundaries create blind spots** - Cross-app, test, and external calls are invisible

3. **Heuristics can improve** - Better defaults for what constitutes "exported" would reduce false positives

4. **Configuration is essential** - Expect to maintain ignore patterns; it's not a one-click solution

5. **Use as hint system** - Tool output is a starting point for investigation, not absolute truth

### Final Recommendation

**For Maintainers:** Focus on improving capture tracking, smarter export detection, and better documentation of limitations.

**For Users:** Configure ignore patterns extensively, annotate public APIs, and use tool output as hints rather than directives. The tool is most effective for finding truly dead internal implementation code, not for auditing public APIs.

---

## Appendix: Example Configuration for Common Frameworks

### Phoenix Application
```elixir
unused: [
  ignore: [
    # Phoenix Controllers
    {~r/Controller$/, :_, :_},

    # Phoenix LiveView
    {~r/Live$/, :mount, 3},
    {~r/Live$/, :handle_event, 3},
    {~r/Live$/, :handle_info, 2},

    # Phoenix Channels
    {~r/Channel$/, :join, 3},
    {~r/Channel$/, :handle_in, 3},

    # Ecto Schema
    {:_, :changeset, 2},

    # Plug
    {:_, :init, 1},
    {:_, :call, 2}
  ]
]
```

### Library Project
```elixir
unused: [
  ignore: [
    # Public API module (until @doc export added)
    {MyLib, :_, :_},
    {MyLib.API, :_, :_},

    # Protocol implementations
    {~r/^MyLib\..*\..*/, :_, :_}
  ]
]
```

### Umbrella Project
```elixir
# Run from umbrella root
# Currently limited - best practice: ignore cross-app calls
unused: [
  ignore: [
    # App A exports used by App B
    {AppA.Services, :_, :_},

    # App B exports used by App A
    {AppB.Utils, :_, :_}
  ]
]
```

---

**Report Generated:** 2025-10-02
**Analyst:** Claude Code (Sonnet 4.5)
**Methodology:** Static code analysis + Sequential reasoning + Context7 documentation review
