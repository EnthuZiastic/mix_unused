defmodule MixUnused.Report.TreeBuilder do
  @moduledoc """
  Builds a hierarchical tree structure from file paths for HTML report navigation.
  """

  alias Mix.Task.Compiler.Diagnostic

  @doc """
  Builds a tree structure from diagnostics grouped by file paths.

  Returns a nested map representing the folder hierarchy, where each node contains:
  - `:type` - `:folder` or `:file`
  - `:name` - The folder or file name
  - `:path` - Full path to the item
  - `:count` - Number of issues in this node and all children
  - `:by_severity` - Issue counts by severity
  - `:children` - Map of child nodes (for folders)
  - `:issues` - List of issue indices (for files)
  """
  @spec build([Diagnostic.t()]) :: map()
  def build(diagnostics) do
    diagnostics
    |> Enum.group_by(fn diag -> Path.relative_to_cwd(diag.file) end)
    |> Enum.reduce(%{}, fn {file, diags}, tree ->
      add_file_to_tree(tree, file, diags)
    end)
    |> wrap_root()
  end

  defp add_file_to_tree(tree, file_path, diagnostics) do
    parts = Path.split(file_path)
    issue_count = length(diagnostics)
    by_severity = count_by_severity(diagnostics)

    do_add_path(tree, parts, file_path, issue_count, by_severity, diagnostics)
  end

  defp do_add_path(tree, [filename], full_path, count, by_severity, diagnostics) do
    # Leaf node (file)
    Map.put(tree, filename, %{
      type: :file,
      name: filename,
      path: full_path,
      count: count,
      by_severity: by_severity,
      issues:
        Enum.map(diagnostics, fn diag ->
          {module, function, arity} = diag.details.mfa

          %{
            line: diag.position,
            severity: diag.severity,
            message: diag.message,
            module: inspect(module),
            function: function,
            arity: arity,
            signature: diag.details.signature,
            analyzer: analyzer_name(diag.details.analyzer)
          }
        end)
    })
  end

  defp do_add_path(
         tree,
         [folder | rest],
         full_path,
         count,
         by_severity,
         diagnostics
       ) do
    # Intermediate node (folder)
    existing =
      Map.get(tree, folder, %{
        type: :folder,
        name: folder,
        count: 0,
        by_severity: %{},
        children: %{}
      })

    updated_children =
      do_add_path(
        existing.children,
        rest,
        full_path,
        count,
        by_severity,
        diagnostics
      )

    updated_count = existing.count + count
    updated_severity = merge_severity_counts(existing.by_severity, by_severity)

    Map.put(tree, folder, %{
      existing
      | count: updated_count,
        by_severity: updated_severity,
        children: updated_children
    })
  end

  defp count_by_severity(diagnostics) do
    diagnostics
    |> Enum.group_by(& &1.severity)
    |> Map.new(fn {severity, diags} -> {severity, length(diags)} end)
  end

  defp merge_severity_counts(counts1, counts2) do
    Map.merge(counts1, counts2, fn _k, v1, v2 -> v1 + v2 end)
  end

  defp analyzer_name(analyzer) do
    analyzer
    |> Module.split()
    |> List.last()
  end

  defp wrap_root(tree) do
    total_count = tree |> Map.values() |> Enum.map(& &1.count) |> Enum.sum()

    total_severity =
      tree
      |> Map.values()
      |> Enum.reduce(%{}, fn node, acc ->
        merge_severity_counts(acc, node.by_severity)
      end)

    %{
      type: :root,
      name: "Project Root",
      count: total_count,
      by_severity: total_severity,
      children: tree
    }
  end
end
