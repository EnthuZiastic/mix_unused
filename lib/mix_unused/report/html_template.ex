defmodule MixUnused.Report.HtmlTemplate do
  @moduledoc """
  HTML template for generating standalone interactive reports.
  """

  alias Jason

  @doc """
  Generates a complete HTML document with embedded data, CSS, and JavaScript.
  """
  def generate(report_data) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>MixUnused Report - #{report_data.timestamp}</title>
      <style>
        #{css()}
      </style>
    </head>
    <body>
      <div class="container">
        <header>
          <h1>🔍 MixUnused Analysis Report</h1>
          <p class="timestamp">Generated: #{report_data.timestamp}</p>
        </header>

        <div class="stats-grid">
          #{render_stats(report_data.stats)}
        </div>

        <div class="controls">
          <div class="search-box">
            <input type="text" id="searchInput" placeholder="🔎 Search files, functions, messages..." />
          </div>
          <div class="filters">
            <label>Severity:</label>
            <select id="severityFilter">
              <option value="">All Severities</option>
              <option value="error">Error</option>
              <option value="warning">Warning</option>
              <option value="hint">Hint</option>
              <option value="information">Information</option>
            </select>
            <label>Analyzer:</label>
            <select id="analyzerFilter">
              <option value="">All Analyzers</option>
              #{render_analyzer_options(report_data.stats)}
            </select>
          </div>
        </div>

        <div class="content-layout">
          <div class="tree-panel">
            <h2>📁 File Tree</h2>
            <div id="fileTree">
              #{render_tree(report_data.tree)}
            </div>
          </div>

          <div class="details-panel">
            <div id="topFiles">
              <h2>📊 Top Files by Issue Count</h2>
              #{render_top_files(report_data.stats.top_files)}
            </div>
            <div id="issueDetails">
              <h2>📝 Issue Details</h2>
              <p class="placeholder">Click on a file in the tree to view its issues</p>
            </div>
          </div>
        </div>
      </div>

      <script>
        const reportData = #{Jason.encode!(report_data)};
      </script>
      <script>
        #{javascript()}
      </script>
    </body>
    </html>
    """
  end

  defp render_stats(stats) do
    """
    <div class="stat-card">
      <div class="stat-value">#{stats.total_issues}</div>
      <div class="stat-label">Total Issues</div>
    </div>
    <div class="stat-card">
      <div class="stat-value">#{stats.total_files}</div>
      <div class="stat-label">Files</div>
    </div>
    <div class="stat-card">
      <div class="stat-value">#{stats.avg_issues_per_file}</div>
      <div class="stat-label">Avg/File</div>
    </div>
    <div class="stat-card severity-error">
      <div class="stat-value">#{Map.get(stats.by_severity, :error, 0)}</div>
      <div class="stat-label">Errors</div>
    </div>
    <div class="stat-card severity-warning">
      <div class="stat-value">#{Map.get(stats.by_severity, :warning, 0)}</div>
      <div class="stat-label">Warnings</div>
    </div>
    <div class="stat-card severity-hint">
      <div class="stat-value">#{Map.get(stats.by_severity, :hint, 0)}</div>
      <div class="stat-label">Hints</div>
    </div>
    """
  end

  defp render_analyzer_options(stats) do
    Enum.map_join(stats.by_analyzer, "\n", fn {analyzer, _count} ->
      ~s(<option value="#{analyzer}">#{analyzer}</option>)
    end)
  end

  defp render_top_files(top_files) do
    if Enum.empty?(top_files) do
      "<p class='placeholder'>No issues found</p>"
    else
      top_files
      |> Enum.with_index()
      |> Enum.map_join("\n", fn {file, index} ->
        """
        <div class="top-file-item" data-file="#{escape_html(file.file)}">
          <span class="rank">#{index + 1}</span>
          <span class="file-name">#{escape_html(file.file)}</span>
          <span class="issue-count">#{file.count}</span>
        </div>
        """
      end)
    end
  end

  defp render_tree(tree) do
    render_tree_node(tree, 0)
  end

  defp render_tree_node(%{type: :root, children: children} = node, _level) do
    """
    <div class="tree-node root-node">
      <div class="tree-node-header" data-expanded="true">
        <span class="tree-icon">▼</span>
        <span class="tree-name">#{escape_html(node.name)}</span>
        <span class="tree-count">#{node.count}</span>
      </div>
      <div class="tree-children">
        #{children |> Map.values() |> Enum.map_join("\n", &render_tree_node(&1, 1))}
      </div>
    </div>
    """
  end

  defp render_tree_node(%{type: :folder, children: children} = node, level) do
    """
    <div class="tree-node folder-node" style="margin-left: #{level * 20}px">
      <div class="tree-node-header" data-expanded="false">
        <span class="tree-icon">▶</span>
        <span class="tree-name">📁 #{escape_html(node.name)}</span>
        <span class="tree-count">#{node.count}</span>
      </div>
      <div class="tree-children" style="display: none;">
        #{children |> Map.values() |> Enum.map_join("\n", &render_tree_node(&1, level + 1))}
      </div>
    </div>
    """
  end

  defp render_tree_node(%{type: :file} = node, level) do
    """
    <div class="tree-node file-node" style="margin-left: #{level * 20}px" data-file="#{escape_html(node.path)}">
      <div class="tree-node-header" data-file="#{escape_html(node.path)}">
        <span class="tree-icon">📄</span>
        <span class="tree-name">#{escape_html(node.name)}</span>
        <span class="tree-count">#{node.count}</span>
      </div>
    </div>
    """
  end

  defp escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  defp css do
    """
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif; background: #f5f7fa; color: #2c3e50; }
    .container { max-width: 1400px; margin: 0 auto; padding: 20px; }
    header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px; margin-bottom: 20px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
    header h1 { font-size: 2em; margin-bottom: 10px; }
    .timestamp { opacity: 0.9; font-size: 0.9em; }
    .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 15px; margin-bottom: 20px; }
    .stat-card { background: white; padding: 20px; border-radius: 8px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1); transition: transform 0.2s; }
    .stat-card:hover { transform: translateY(-2px); box-shadow: 0 4px 8px rgba(0,0,0,0.15); }
    .stat-value { font-size: 2em; font-weight: bold; color: #667eea; }
    .stat-label { font-size: 0.9em; color: #7f8c8d; margin-top: 5px; }
    .severity-error .stat-value { color: #e74c3c; }
    .severity-warning .stat-value { color: #f39c12; }
    .severity-hint .stat-value { color: #3498db; }
    .controls { background: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .search-box { margin-bottom: 15px; }
    .search-box input { width: 100%; padding: 12px; border: 2px solid #e0e6ed; border-radius: 6px; font-size: 1em; }
    .search-box input:focus { outline: none; border-color: #667eea; }
    .filters { display: flex; gap: 15px; align-items: center; flex-wrap: wrap; }
    .filters label { font-weight: 600; color: #2c3e50; }
    .filters select { padding: 8px 12px; border: 2px solid #e0e6ed; border-radius: 6px; font-size: 0.9em; cursor: pointer; }
    .filters select:focus { outline: none; border-color: #667eea; }
    .content-layout { display: grid; grid-template-columns: 1fr 2fr; gap: 20px; }
    .tree-panel, .details-panel { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .tree-panel h2, .details-panel h2 { margin-bottom: 15px; color: #2c3e50; font-size: 1.3em; }
    #fileTree { max-height: 600px; overflow-y: auto; }
    .tree-node { margin: 2px 0; }
    .tree-node-header { padding: 8px 10px; cursor: pointer; border-radius: 4px; display: flex; align-items: center; gap: 8px; transition: background 0.2s; }
    .tree-node-header:hover { background: #f5f7fa; }
    .tree-node-header.selected { background: #667eea; color: white; }
    .tree-icon { font-size: 0.8em; width: 15px; display: inline-block; }
    .tree-name { flex: 1; }
    .tree-count { background: #667eea; color: white; padding: 2px 8px; border-radius: 12px; font-size: 0.85em; font-weight: 600; }
    .tree-node-header.selected .tree-count { background: white; color: #667eea; }
    .tree-children { margin-left: 0; }
    .top-file-item { padding: 12px; border-left: 4px solid #667eea; margin: 10px 0; background: #f8f9fa; border-radius: 4px; cursor: pointer; display: flex; align-items: center; gap: 10px; transition: all 0.2s; }
    .top-file-item:hover { background: #e8eaf6; transform: translateX(5px); }
    .top-file-item .rank { background: #667eea; color: white; width: 30px; height: 30px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: bold; font-size: 0.9em; }
    .top-file-item .file-name { flex: 1; font-family: 'Courier New', monospace; font-size: 0.9em; }
    .top-file-item .issue-count { background: #e74c3c; color: white; padding: 4px 10px; border-radius: 12px; font-weight: 600; font-size: 0.85em; }
    .issue-item { border-left: 4px solid #3498db; padding: 15px; margin: 10px 0; background: #f8f9fa; border-radius: 4px; }
    .issue-item.severity-error { border-left-color: #e74c3c; }
    .issue-item.severity-warning { border-left-color: #f39c12; }
    .issue-item.severity-hint { border-left-color: #3498db; }
    .issue-header { display: flex; justify-content: space-between; margin-bottom: 8px; }
    .issue-signature { font-family: 'Courier New', monospace; font-weight: 600; color: #2c3e50; }
    .issue-meta { display: flex; gap: 10px; font-size: 0.85em; }
    .badge { padding: 3px 8px; border-radius: 12px; color: white; font-weight: 600; }
    .badge-error { background: #e74c3c; }
    .badge-warning { background: #f39c12; }
    .badge-hint { background: #3498db; }
    .badge-information { background: #95a5a6; }
    .badge-analyzer { background: #9b59b6; }
    .issue-message { color: #555; margin-top: 8px; }
    .issue-location { font-family: 'Courier New', monospace; font-size: 0.85em; color: #7f8c8d; margin-top: 5px; }
    .placeholder { color: #95a5a6; text-align: center; padding: 40px; font-style: italic; }
    @media (max-width: 768px) { .content-layout { grid-template-columns: 1fr; } .stats-grid { grid-template-columns: repeat(2, 1fr); } }
    @media print { .controls, .tree-panel { display: none; } .content-layout { grid-template-columns: 1fr; } }
    """
  end

  defp javascript do
    """
    // Initialize app
    document.addEventListener('DOMContentLoaded', function() {
      setupTreeNavigation();
      setupFilters();
      setupTopFileClicks();
    });

    // Tree navigation
    function setupTreeNavigation() {
      const headers = document.querySelectorAll('.tree-node-header');
      headers.forEach(header => {
        header.addEventListener('click', function(e) {
          e.stopPropagation();
          const node = this.closest('.tree-node');
          const filePath = this.getAttribute('data-file');

          if (filePath) {
            // File clicked - show issues
            showFileIssues(filePath);
            highlightSelectedNode(this);
          } else {
            // Folder clicked - toggle expand
            toggleFolder(node, this);
          }
        });
      });
    }

    function toggleFolder(node, header) {
      const children = node.querySelector('.tree-children');
      const icon = header.querySelector('.tree-icon');
      const isExpanded = header.getAttribute('data-expanded') === 'true';

      if (children) {
        if (isExpanded) {
          children.style.display = 'none';
          icon.textContent = '▶';
          header.setAttribute('data-expanded', 'false');
        } else {
          children.style.display = 'block';
          icon.textContent = '▼';
          header.setAttribute('data-expanded', 'true');
        }
      }
    }

    function highlightSelectedNode(header) {
      document.querySelectorAll('.tree-node-header.selected').forEach(el => {
        el.classList.remove('selected');
      });
      header.classList.add('selected');
    }

    function showFileIssues(filePath) {
      const fileData = reportData.files.find(f => f.path === filePath);
      if (!fileData) return;

      const detailsPanel = document.getElementById('issueDetails');
      let html = `<h2>📝 ${escapeHtml(filePath)} (${fileData.total_count} issues)</h2>`;

      fileData.issues.forEach(issue => {
        html += `
          <div class="issue-item severity-${issue.severity}">
            <div class="issue-header">
              <div class="issue-signature">${escapeHtml(issue.signature)}</div>
              <div class="issue-meta">
                <span class="badge badge-${issue.severity}">${issue.severity}</span>
                <span class="badge badge-analyzer">${escapeHtml(issue.analyzer)}</span>
              </div>
            </div>
            <div class="issue-message">${escapeHtml(issue.message)}</div>
            <div class="issue-location">Line ${issue.line}</div>
          </div>
        `;
      });

      detailsPanel.innerHTML = html;
    }

    // Filters
    function setupFilters() {
      const searchInput = document.getElementById('searchInput');
      const severityFilter = document.getElementById('severityFilter');
      const analyzerFilter = document.getElementById('analyzerFilter');

      searchInput.addEventListener('input', applyFilters);
      severityFilter.addEventListener('change', applyFilters);
      analyzerFilter.addEventListener('change', applyFilters);
    }

    function applyFilters() {
      const searchTerm = document.getElementById('searchInput').value.toLowerCase();
      const severity = document.getElementById('severityFilter').value;
      const analyzer = document.getElementById('analyzerFilter').value;

      const fileNodes = document.querySelectorAll('.file-node');
      fileNodes.forEach(node => {
        const filePath = node.getAttribute('data-file');
        const fileData = reportData.files.find(f => f.path === filePath);

        if (!fileData) {
          node.style.display = 'none';
          return;
        }

        let matches = true;

        // Search filter
        if (searchTerm) {
          const searchableText = `${filePath} ${JSON.stringify(fileData.issues)}`.toLowerCase();
          matches = matches && searchableText.includes(searchTerm);
        }

        // Severity filter
        if (severity) {
          matches = matches && fileData.issues.some(issue => issue.severity === severity);
        }

        // Analyzer filter
        if (analyzer) {
          matches = matches && fileData.issues.some(issue => issue.analyzer === analyzer);
        }

        node.style.display = matches ? 'block' : 'none';
      });
    }

    // Top files click
    function setupTopFileClicks() {
      const topFileItems = document.querySelectorAll('.top-file-item');
      topFileItems.forEach(item => {
        item.addEventListener('click', function() {
          const filePath = this.getAttribute('data-file');
          showFileIssues(filePath);

          // Find and highlight in tree
          const treeNode = document.querySelector(`.tree-node-header[data-file="${filePath}"]`);
          if (treeNode) {
            highlightSelectedNode(treeNode);
            treeNode.scrollIntoView({ behavior: 'smooth', block: 'center' });
          }
        });
      });
    }

    function escapeHtml(text) {
      const div = document.createElement('div');
      div.textContent = text;
      return div.innerHTML;
    }
    """
  end
end
