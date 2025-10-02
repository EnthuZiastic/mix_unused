defmodule MixUnused.Report.Generator do
  @moduledoc """
  Orchestrates HTML report generation from diagnostics.
  """

  alias Mix.Task.Compiler.Diagnostic
  alias MixUnused.Report.{DataBuilder, HtmlTemplate, Stats, TreeBuilder}

  @doc """
  Generates an HTML report from diagnostics and writes it to the specified file.

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @spec generate([Diagnostic.t()], String.t()) :: :ok | {:error, term()}
  def generate(diagnostics, output_path) do
    report_data = build_report_data(diagnostics)
    html = HtmlTemplate.generate(report_data)

    case File.write(output_path, html) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error, "Failed to write HTML report: #{inspect(reason)}"}
    end
  rescue
    error ->
      {:error, "Failed to generate HTML report: #{Exception.message(error)}"}
  end

  defp build_report_data(diagnostics) do
    data = DataBuilder.build(diagnostics)
    stats = Stats.calculate(diagnostics)
    tree = TreeBuilder.build(diagnostics)

    %{
      timestamp: data.timestamp,
      total_count: data.total_count,
      stats: stats,
      tree: tree,
      files: data.files,
      issues: data.issues
    }
  end

  @doc """
  Opens the generated HTML report in the default browser.
  """
  @spec open_in_browser(String.t()) :: :ok | {:error, term()}
  def open_in_browser(file_path) do
    abs_path = Path.absname(file_path)

    case :os.type() do
      {:unix, :darwin} ->
        System.cmd("open", [abs_path])
        :ok

      {:unix, _} ->
        System.cmd("xdg-open", [abs_path])
        :ok

      {:win32, _} ->
        System.cmd("cmd", ["/c", "start", abs_path])
        :ok

      _ ->
        {:error, "Unsupported operating system for auto-open"}
    end
  rescue
    error ->
      {:error, "Failed to open browser: #{Exception.message(error)}"}
  end
end
