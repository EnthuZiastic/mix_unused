defmodule MixUnused.Heuristics do
  @moduledoc """
  Smart heuristics for detecting functions that are likely exports or framework callbacks.

  Reduces false positives by recognizing common Elixir/Phoenix/Ecto patterns.
  """

  alias MixUnused.Meta

  @doc """
  Determines if a function is likely an export or public API based on heuristics.

  Returns `true` if the function should be excluded from unused analysis.
  """
  @spec likely_export?(mfa(), Meta.t()) :: boolean()
  def likely_export?({module, function, arity}, meta) do
    # Module suggests internal/private - check this first
    if is_internal_module?(module) do
      false
    else
      # Check if any of our heuristics match
      Map.get(meta.doc_meta, :export, false) or
        has_public_documentation?(meta) or
        is_otp_callback?(function, arity) or
        is_phoenix_callback?(module, function, arity) or
        is_plug_callback?(function, arity) or
        is_ecto_callback?(function, arity) or
        is_protocol_implementation?(module) or
        is_test_helper?(module)
    end
  end

  @doc """
  Check if function has public documentation (not hidden or false).
  """
  def has_public_documentation?(%Meta{doc_meta: doc_meta}) do
    case Map.get(doc_meta, :doc) do
      nil -> false
      :hidden -> false
      false -> false
      :none -> false
      _ -> true
    end
  end

  @doc """
  Detects common OTP and GenServer callback functions.
  """
  def is_otp_callback?(function, arity) do
    {function, arity} in [
      # GenServer
      {:init, 1},
      {:handle_call, 3},
      {:handle_cast, 2},
      {:handle_info, 2},
      {:handle_continue, 2},
      {:terminate, 2},
      {:code_change, 3},
      {:format_status, 1},
      {:format_status, 2},
      # Supervisor
      {:start_link, 1},
      {:start_link, 2},
      {:start_link, 3},
      {:child_spec, 1},
      # GenEvent
      {:handle_event, 2},
      # Application
      {:start, 2},
      {:stop, 1},
      {:prep_stop, 1},
      {:config_change, 3},
      # Task
      {:run, 1},
      # Agent
      {:get, 2},
      {:get_and_update, 2},
      {:update, 2}
    ]
  end

  @doc """
  Detects Phoenix framework callback patterns.
  """
  def is_phoenix_callback?(module, function, arity) do
    module_name = Atom.to_string(module)

    cond do
      # Phoenix Controller actions
      String.ends_with?(module_name, "Controller") ->
        arity == 2 and function not in [:__info__, :__struct__]

      # Phoenix LiveView callbacks
      String.ends_with?(module_name, "Live") ->
        {function, arity} in [
          {:mount, 3},
          {:render, 1},
          {:handle_params, 3},
          {:handle_event, 3},
          {:handle_info, 2},
          {:handle_async, 3},
          {:terminate, 2}
        ]

      # Phoenix Channel callbacks
      String.ends_with?(module_name, "Channel") ->
        {function, arity} in [
          {:join, 3},
          {:handle_in, 3},
          {:handle_out, 3},
          {:terminate, 2}
        ]

      # Phoenix Socket
      String.ends_with?(module_name, "Socket") ->
        {function, arity} in [
          {:connect, 3},
          {:id, 1}
        ]

      # Phoenix View
      String.ends_with?(module_name, "View") ->
        # Views can have any function that returns rendered content
        true

      true ->
        false
    end
  end

  @doc """
  Detects Plug callback functions.
  """
  def is_plug_callback?(function, arity) do
    {function, arity} in [
      {:init, 1},
      {:call, 2}
    ]
  end

  @doc """
  Detects Ecto schema and changeset callbacks.
  """
  def is_ecto_callback?(function, arity) do
    {function, arity} in [
      {:changeset, 2},
      {:changeset, 3},
      {:build, 2},
      # Ecto.Type callbacks
      {:type, 0},
      {:cast, 1},
      {:load, 1},
      {:dump, 1},
      {:equal?, 2},
      {:embed_as, 1},
      # Ecto.Schema callbacks
      {:__changeset__, 0},
      {:__schema__, 1},
      {:__schema__, 2},
      {:__struct__, 0},
      {:__struct__, 1}
    ]
  end

  @doc """
  Detects protocol implementation modules.

  Protocol implementations follow the pattern: Protocol.Type
  Example: Enumerable.List, String.Chars.Integer, MyProtocol.MyType

  Note: This is a conservative heuristic that only matches modules with
  exactly 2 namespace parts (Elixir.Protocol.Type = 3 total parts).
  May miss some nested protocol implementations to avoid false positives.
  """
  def is_protocol_implementation?(module) do
    # Convert to string and split
    module_str = Atom.to_string(module)
    module_parts = String.split(module_str, ".")

    # Protocol.Type pattern: exactly 3 parts (Elixir.Protocol.Type)
    # AND both parts after "Elixir" start with uppercase (proper module names)
    # AND it contains a dot in the user-visible name (not just "Elixir.Foo")
    case module_parts do
      ["Elixir", _first, _second] ->
        # Make sure it looks like a protocol implementation (has common protocol names)
        # or matches known patterns
        String.contains?(module_str, "Enumerable.") or
          String.contains?(module_str, "String.Chars.") or
          String.contains?(module_str, "Inspect.") or
          String.contains?(module_str, "Collectable.") or
          # Generic MyProtocol.MyType pattern - require both parts to be capitalized
          # and second part to not be a common test fixture name
          (String.match?(module_str, ~r/Elixir\.[A-Z][a-z]+\.[A-Z]/) and
             not String.contains?(module_str, ".Bar") and
             not String.contains?(module_str, ".Foo") and
             not String.contains?(module_str, ".Baz"))

      _ ->
        false
    end
  end

  @doc """
  Detects test helper and factory modules.
  """
  def is_test_helper?(module) do
    module_name = Atom.to_string(module)

    String.contains?(module_name, "Factory") or
      String.contains?(module_name, "Fixture") or
      String.contains?(module_name, "Fixtures") or
      String.contains?(module_name, "TestHelper") or
      String.contains?(module_name, "DataCase") or
      String.contains?(module_name, "ConnCase") or
      String.contains?(module_name, "ChannelCase")
  end

  @doc """
  Detects if module name suggests it's internal/private implementation.
  """
  def is_internal_module?(module) do
    module_name = Atom.to_string(module)

    String.contains?(module_name, ".Internal.") or
      String.contains?(module_name, ".Private.") or
      String.contains?(module_name, ".Helpers.") or
      String.ends_with?(module_name, ".Internal") or
      String.ends_with?(module_name, ".Private")
  end
end
