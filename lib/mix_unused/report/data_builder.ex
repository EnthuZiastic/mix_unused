defmodule MixUnused.Report.DataBuilder do
  @moduledoc """
  Builds structured data from diagnostics for HTML report generation.
  """

  alias Mix.Task.Compiler.Diagnostic

  @doc """
  Transforms a list of diagnostics into a structured data map for report generation.

  Returns a map containing:
  - `:timestamp` - ISO8601 timestamp of report generation
  - `:issues` - List of serialized diagnostic data
  - `:files` - Map of file paths to their issues and counts
  """
  @spec build([Diagnostic.t()]) :: map()
  def build(diagnostics) do
    issues = Enum.map(diagnostics, &serialize_diagnostic/1)
    files = group_by_files(diagnostics)

    %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      total_count: length(diagnostics),
      issues: issues,
      files: files,
      project_root: File.cwd!()
    }
  end

  defp serialize_diagnostic(%Diagnostic{} = diag) do
    {module, function, arity} = diag.details.mfa

    %{
      file: Path.relative_to_cwd(diag.file),
      line: diag.position,
      severity: diag.severity,
      message: diag.message,
      module: inspect(module),
      function: function,
      arity: arity,
      signature: diag.details.signature,
      analyzer: analyzer_name(diag.details.analyzer)
    }
  end

  defp analyzer_name(analyzer) do
    analyzer
    |> Module.split()
    |> List.last()
  end

  defp group_by_files(diagnostics) do
    diagnostics
    |> Enum.group_by(fn diag -> Path.relative_to_cwd(diag.file) end)
    |> Enum.map(fn {file, diags} ->
      issues = Enum.map(diags, &serialize_diagnostic/1)

      %{
        path: file,
        total_count: length(diags),
        issues: issues,
        by_severity: count_by_severity(diags),
        by_analyzer: count_by_analyzer(diags)
      }
    end)
    |> Enum.sort_by(& &1.total_count, :desc)
  end

  defp count_by_severity(diagnostics) do
    diagnostics
    |> Enum.group_by(& &1.severity)
    |> Map.new(fn {severity, diags} -> {severity, length(diags)} end)
  end

  defp count_by_analyzer(diagnostics) do
    diagnostics
    |> Enum.group_by(fn diag -> analyzer_name(diag.details.analyzer) end)
    |> Map.new(fn {analyzer, diags} -> {analyzer, length(diags)} end)
  end
end
