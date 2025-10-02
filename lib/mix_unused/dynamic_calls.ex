defmodule MixUnused.DynamicCalls do
  @moduledoc """
  Detects dynamic function calls (apply/2, apply/3, Kernel.apply) that may
  cause false positives in unused function detection.

  Dynamic calls cannot be statically analyzed, so functions called via apply
  may be incorrectly marked as unused.
  """

  @doc """
  Analyzes tracer data to find modules that use dynamic dispatch.

  Returns a map of modules to the functions that use apply/2 or apply/3.
  """
  @spec find_dynamic_dispatchers(map()) :: %{module() => [{atom(), arity()}]}
  def find_dynamic_dispatchers(tracer_data) do
    for {module, calls} <- tracer_data,
        {{called_mod, called_func, called_arity}, _meta} <- calls,
        is_apply_call?(called_mod, called_func, called_arity),
        reduce: %{} do
      acc ->
        Map.update(acc, module, [{called_func, called_arity}], fn existing ->
          [{called_func, called_arity} | existing]
        end)
    end
  end

  @doc """
  Checks if a call is to apply/2, apply/3, or Kernel.apply.
  """
  @spec is_apply_call?(module(), atom(), arity()) :: boolean()
  def is_apply_call?(module, function, arity) do
    (module == Kernel and function == :apply and arity in [2, 3]) or
      (module == :erlang and function == :apply and arity in [2, 3]) or
      (function == :apply and arity in [2, 3])
  end

  @doc """
  Generates warning messages for modules using dynamic dispatch.
  """
  @spec generate_warnings(%{module() => [{atom(), arity()}]}) :: [String.t()]
  def generate_warnings(dynamic_dispatchers) do
    for {module, apply_calls} <- dynamic_dispatchers do
      apply_count = length(apply_calls)

      """
      ⚠️  Module #{inspect(module)} uses dynamic dispatch (apply/#{apply_count} calls).
          Functions called via apply may be incorrectly marked as unused.
          Consider adding them to the ignore list if false positives occur.
      """
    end
  end

  @doc """
  Creates suggested ignore patterns for a module using dynamic dispatch.

  This helps users quickly configure ignore patterns for modules that
  frequently use apply/2 or apply/3.
  """
  @spec suggest_ignore_pattern(module()) :: String.t()
  def suggest_ignore_pattern(module) do
    """
    # Add to mix.exs project config:
    unused: [
      ignore: [
        {#{inspect(module)}, :_, :_}  # Module uses dynamic dispatch
      ]
    ]
    """
  end
end
