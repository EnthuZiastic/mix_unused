defmodule MixUnused.Report.Stats do
  @moduledoc """
  Calculates statistics from diagnostic data for HTML report.
  """

  alias Mix.Task.Compiler.Diagnostic

  @doc """
  Calculates comprehensive statistics from diagnostics.

  Returns a map containing:
  - `:total_issues` - Total number of issues
  - `:total_files` - Total number of files with issues
  - `:by_severity` - Map of severity levels to counts
  - `:by_analyzer` - Map of analyzer names to counts
  - `:top_files` - List of top 10 files with most issues
  - `:avg_issues_per_file` - Average number of issues per file
  """
  @spec calculate([Diagnostic.t()]) :: map()
  def calculate([]), do: empty_stats()

  def calculate(diagnostics) do
    files = diagnostics |> Enum.group_by(fn diag -> diag.file end)
    file_count = map_size(files)

    %{
      total_issues: length(diagnostics),
      total_files: file_count,
      avg_issues_per_file: Float.round(length(diagnostics) / file_count, 2),
      by_severity: count_by_severity(diagnostics),
      by_analyzer: count_by_analyzer(diagnostics),
      top_files: top_files(files, 10)
    }
  end

  defp empty_stats do
    %{
      total_issues: 0,
      total_files: 0,
      avg_issues_per_file: 0.0,
      by_severity: %{},
      by_analyzer: %{},
      top_files: []
    }
  end

  defp count_by_severity(diagnostics) do
    diagnostics
    |> Enum.group_by(& &1.severity)
    |> Map.new(fn {severity, diags} -> {severity, length(diags)} end)
    |> ensure_all_severities()
  end

  defp ensure_all_severities(map) do
    [:error, :warning, :hint, :information]
    |> Enum.reduce(map, fn severity, acc ->
      Map.put_new(acc, severity, 0)
    end)
  end

  defp count_by_analyzer(diagnostics) do
    diagnostics
    |> Enum.group_by(fn diag -> analyzer_name(diag.details.analyzer) end)
    |> Map.new(fn {analyzer, diags} -> {analyzer, length(diags)} end)
  end

  defp analyzer_name(analyzer) do
    analyzer
    |> Module.split()
    |> List.last()
  end

  defp top_files(files_map, limit) do
    files_map
    |> Enum.map(fn {file, diags} ->
      %{
        file: Path.relative_to_cwd(file),
        count: length(diags),
        by_severity: count_by_severity(diags),
        by_analyzer: count_by_analyzer(diags)
      }
    end)
    |> Enum.sort_by(& &1.count, :desc)
    |> Enum.take(limit)
  end
end
