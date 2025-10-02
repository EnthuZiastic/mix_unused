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
          <div class="header-row-1">
            <div class="header-left">
              <h1>🔍 MixUnused</h1>
              <p class="timestamp">#{report_data.timestamp}</p>
            </div>
            <div class="header-stats">
              #{render_inline_stats(report_data.stats)}
            </div>
            <select id="editorSelect" class="filter-select" style="width: auto; margin-right: 8px;" title="Choose editor for opening files">
              <option value="windsurf">Windsurf</option>
              <option value="vscode">VS Code</option>
              <option value="cursor">Cursor</option>
              <option value="idea">IntelliJ IDEA</option>
              <option value="sublime">Sublime Text</option>
              <option value="vim">Vim / Neovim</option>
              <option value="file">System Default</option>
            </select>
            <button class="export-button" id="exportJson" title="Export data as JSON">
              📊 Export JSON
            </button>
          </div>
          <div class="header-row-2">
            <input type="text" id="searchInput" class="search-input" placeholder="🔎 Search files, functions, messages..." />
            <div class="filters-inline">
              <select id="severityFilter" class="filter-select">
                <option value="">All Severities</option>
                <option value="error">Error</option>
                <option value="warning">Warning</option>
                <option value="hint">Hint</option>
                <option value="information">Information</option>
              </select>
              <select id="analyzerFilter" class="filter-select">
                <option value="">All Analyzers</option>
                #{render_analyzer_options(report_data.stats)}
              </select>
            </div>
          </div>
        </header>

        <div class="tabs">
          <button class="tab-button active" data-tab="tree">File Tree</button>
          <button class="tab-button" data-tab="top-files">Top Files</button>
        </div>

        <div class="content-layout">
          <div class="tree-panel">
            <div class="tab-content active" id="tab-tree">
              <div id="fileTree">
                #{render_tree(report_data.tree)}
              </div>
            </div>
            <div class="tab-content" id="tab-top-files">
              <div id="topFiles">
                #{render_top_files(report_data.stats.top_files)}
              </div>
            </div>
          </div>

          <div class="details-panel">
            <div id="issueDetails">
              <h2>📝 Issue Details</h2>
              <p class="placeholder">Click on a file to view its issues</p>
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

  defp render_inline_stats(stats) do
    """
    <span class="stat-inline">
      <span class="stat-value">#{stats.total_issues}</span>
      <span class="stat-label">issues</span>
    </span>
    <span class="stat-divider">•</span>
    <span class="stat-inline">
      <span class="stat-value">#{stats.total_files}</span>
      <span class="stat-label">files</span>
    </span>
    <span class="stat-divider">•</span>
    <span class="stat-inline severity-error">
      <span class="stat-value">#{Map.get(stats.by_severity, :error, 0)}</span>
      <span class="stat-label">errors</span>
    </span>
    <span class="stat-inline severity-warning">
      <span class="stat-value">#{Map.get(stats.by_severity, :warning, 0)}</span>
      <span class="stat-label">warn</span>
    </span>
    <span class="stat-inline severity-hint">
      <span class="stat-value">#{Map.get(stats.by_severity, :hint, 0)}</span>
      <span class="stat-label">hints</span>
    </span>
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
    <div class="tree-node folder-node" style="margin-left: #{level * 16}px">
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
    <div class="tree-node file-node" style="margin-left: #{level * 16}px" data-file="#{escape_html(node.path)}">
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
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif; background: #f5f7fa; color: #2c3e50; font-size: 14px; }
    .container { max-width: 1400px; margin: 0 auto; padding: 15px; }
    header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 12px 20px; border-radius: 6px; margin-bottom: 15px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .header-row-1 { display: flex; align-items: center; justify-content: space-between; margin-bottom: 10px; }
    .header-row-2 { display: flex; gap: 12px; align-items: center; }
    .header-left { display: flex; align-items: center; gap: 15px; }
    header h1 { font-size: 1.3em; margin: 0; }
    .timestamp { opacity: 0.9; font-size: 0.85em; }
    .header-stats { display: flex; align-items: center; gap: 12px; font-size: 0.9em; }
    .stat-inline { display: inline-flex; align-items: baseline; gap: 4px; }
    .stat-inline .stat-value { font-weight: bold; font-size: 1.1em; }
    .stat-inline .stat-label { opacity: 0.85; font-size: 0.85em; }
    .stat-inline.severity-error .stat-value { color: #ffcccc; }
    .stat-inline.severity-warning .stat-value { color: #ffe0b3; }
    .stat-inline.severity-hint .stat-value { color: #cce5ff; }
    .stat-divider { opacity: 0.5; margin: 0 4px; }
    .export-button { background: rgba(255,255,255,0.2); color: white; border: 1px solid rgba(255,255,255,0.3); padding: 6px 12px; border-radius: 4px; font-size: 0.85em; cursor: pointer; transition: all 0.2s; font-weight: 600; }
    .export-button:hover { background: rgba(255,255,255,0.3); transform: translateY(-1px); }
    .search-input { width: 400px; padding: 8px 12px; border: 1px solid rgba(255,255,255,0.3); background: rgba(255,255,255,0.15); color: white; border-radius: 4px; font-size: 0.9em; }
    .search-input::placeholder { color: rgba(255,255,255,0.7); }
    .search-input:focus { outline: none; background: rgba(255,255,255,0.25); border-color: rgba(255,255,255,0.5); }
    .filters-inline { display: flex; gap: 8px; flex: 1; }
    .filter-select { padding: 7px 10px; border: 1px solid rgba(255,255,255,0.3); background: rgba(255,255,255,0.15); color: white; border-radius: 4px; font-size: 0.85em; cursor: pointer; }
    .filter-select:focus { outline: none; background: rgba(255,255,255,0.25); border-color: rgba(255,255,255,0.5); }
    .filter-select option { color: #2c3e50; background: white; }
    .tabs { display: flex; gap: 5px; margin-bottom: 15px; background: white; padding: 8px; border-radius: 6px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .tab-button { padding: 8px 16px; border: none; background: transparent; color: #7f8c8d; font-size: 0.9em; font-weight: 600; cursor: pointer; border-radius: 4px; transition: all 0.2s; }
    .tab-button:hover { background: #f5f7fa; }
    .tab-button.active { background: #667eea; color: white; }
    .tab-content { display: none; }
    .tab-content.active { display: block; }
    .content-layout { display: grid; grid-template-columns: 1fr 2fr; gap: 15px; }
    .tree-panel, .details-panel { background: white; padding: 15px; border-radius: 6px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .tree-panel h2, .details-panel h2 { margin-bottom: 12px; color: #2c3e50; font-size: 1.1em; }
    #fileTree { max-height: 600px; overflow-y: auto; }
    .tree-node { margin: 1px 0; }
    .tree-node-header { padding: 6px 8px; cursor: pointer; border-radius: 4px; display: flex; align-items: center; gap: 6px; transition: background 0.2s; }
    .tree-node-header:hover { background: #f5f7fa; }
    .tree-node-header.selected { background: #667eea; color: white; }
    .tree-icon { font-size: 0.8em; width: 15px; display: inline-block; }
    .tree-name { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .tree-count { background: #667eea; color: white; padding: 2px 8px; border-radius: 12px; font-size: 0.85em; font-weight: 600; }
    .tree-node-header.selected .tree-count { background: white; color: #667eea; }
    .tree-children { margin-left: 0; }
    .top-file-item { padding: 10px; border-left: 3px solid #667eea; margin: 8px 0; background: #f8f9fa; border-radius: 4px; cursor: pointer; display: flex; align-items: center; gap: 8px; transition: all 0.2s; }
    .top-file-item:hover { background: #e8eaf6; transform: translateX(3px); }
    .top-file-item .rank { background: #667eea; color: white; width: 26px; height: 26px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: bold; font-size: 0.85em; }
    .top-file-item .file-name { flex: 1; font-family: 'Courier New', monospace; font-size: 0.85em; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .top-file-item .issue-count { background: #e74c3c; color: white; padding: 3px 8px; border-radius: 12px; font-weight: 600; font-size: 0.8em; }
    .issue-item { border-left: 3px solid #3498db; padding: 12px; margin: 8px 0; background: #f8f9fa; border-radius: 4px; cursor: pointer; transition: all 0.2s; }
    .issue-item:hover { background: #e8eaf6; transform: translateX(2px); }
    .issue-item:hover .issue-signature { color: #2563eb; text-decoration: underline; }
    .issue-item.severity-error { border-left-color: #e74c3c; }
    .issue-item.severity-warning { border-left-color: #f39c12; }
    .issue-item.severity-hint { border-left-color: #3498db; }
    .issue-header { display: flex; justify-content: space-between; margin-bottom: 6px; align-items: flex-start; }
    .issue-signature { font-family: 'Courier New', monospace; font-weight: 600; color: #3b82f6; font-size: 0.9em; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; flex: 1; text-decoration: underline; cursor: pointer; }
    .issue-meta { display: flex; gap: 6px; font-size: 0.8em; flex-shrink: 0; }
    .badge { padding: 3px 7px; border-radius: 10px; color: white; font-weight: 600; white-space: nowrap; }
    .badge-error { background: #dc3545; }
    .badge-warning { background: #ffc107; color: #212529; }
    .badge-hint { background: #17a2b8; }
    .badge-information { background: #6c757d; }
    .badge-analyzer { background: #34495e; }
    .badge-analyzer.Private { background: #9b59b6; }
    .badge-analyzer.RecursiveOnly { background: #16a085; }
    .badge-analyzer.Unused { background: #e67e22; }
    .issue-message { color: #2c3e50; margin-top: 6px; font-size: 0.9em; font-weight: 500; }
    .issue-message .keyword { color: #e74c3c; font-weight: 600; }
    .placeholder { color: #95a5a6; text-align: center; padding: 30px; font-style: italic; }
    @media (max-width: 768px) { .content-layout { grid-template-columns: 1fr; } .stats-grid { grid-template-columns: repeat(2, 1fr); } }
    @media print { .controls, .tree-panel { display: none; } .content-layout { grid-template-columns: 1fr; } }
    """
  end

  defp javascript do
    """
    // Initialize app
    document.addEventListener('DOMContentLoaded', function() {
      setupTabs();
      setupTreeNavigation();
      setupFilters();
      setupTopFileClicks();
      setupExport();
      setupEditorSelector();
    });

    // Export functionality
    function setupExport() {
      const exportButton = document.getElementById('exportJson');
      exportButton.addEventListener('click', function() {
        const dataStr = JSON.stringify(reportData, null, 2);
        const dataBlob = new Blob([dataStr], { type: 'application/json' });
        const url = URL.createObjectURL(dataBlob);
        const link = document.createElement('a');
        link.href = url;
        link.download = 'mixunused-report-' + reportData.timestamp.replace(/[:\\s]/g, '-') + '.json';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);
      });
    }

    // Editor selector functionality
    function setupEditorSelector() {
      const editorSelect = document.getElementById('editorSelect');

      // Load saved preference
      const saved = localStorage.getItem('editorProtocol');
      if (saved) {
        editorSelect.value = saved;
      }

      // Save preference on change
      editorSelect.addEventListener('change', function() {
        localStorage.setItem('editorProtocol', this.value);
      });
    }

    // Tab navigation
    function setupTabs() {
      const tabButtons = document.querySelectorAll('.tab-button');
      tabButtons.forEach(button => {
        button.addEventListener('click', function() {
          const tabName = this.getAttribute('data-tab');

          // Update button states
          tabButtons.forEach(btn => btn.classList.remove('active'));
          this.classList.add('active');

          // Update content visibility
          document.querySelectorAll('.tab-content').forEach(content => {
            content.classList.remove('active');
          });
          document.getElementById('tab-' + tabName).classList.add('active');
        });
      });
    }

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

    function highlightKeywords(text) {
      const keywords = ['unused', 'is not used', 'should be private', 'not used outside', 'is called only recursively'];
      let result = text;
      keywords.forEach(keyword => {
        const regex = new RegExp(`(${keyword})`, 'gi');
        result = result.replace(regex, '<span class="keyword">$1</span>');
      });
      return result;
    }

    function extractAnalyzerMessage(fullMessage) {
      // Remove the MFA (Module.Function/Arity) pattern from the beginning
      // Pattern: ModuleName.function_name/arity followed by space
      // Example: "Enthuziastic.Countries.get_country_alpha/1 should be private"
      const mfaPattern = /^[A-Z][A-Za-z0-9._]*[?.!]?\\/\\d+\\s+/;
      return fullMessage.replace(mfaPattern, '');
    }

    function createEditorLink(filePath, line) {
      // Construct absolute path from project root
      const absolutePath = reportData.project_root + '/' + filePath;

      // Detect editor from user agent or allow configuration
      // Default to file:// protocol for system default, but users can customize
      const editorProtocol = getEditorProtocol();

      if (editorProtocol === 'vscode' || editorProtocol === 'cursor' || editorProtocol === 'windsurf') {
        return `${editorProtocol}://file${absolutePath}:${line}`;
      } else if (editorProtocol === 'idea') {
        return `idea://open?file=${absolutePath}&line=${line}`;
      } else if (editorProtocol === 'sublime') {
        return `subl://open?url=file://${absolutePath}&line=${line}`;
      } else if (editorProtocol === 'vim') {
        // Neovim protocol (requires neovim-remote or similar handler)
        return `nvim://open?file=${absolutePath}&line=${line}`;
      } else {
        // Default: open file in system default application
        return `file://${absolutePath}`;
      }
    }

    function getEditorProtocol() {
      // Check localStorage for user preference
      const stored = localStorage.getItem('editorProtocol');
      if (stored) return stored;

      // Default to windsurf
      return 'windsurf';
    }

    function showFileIssues(filePath) {
      const fileData = reportData.files.find(f => f.path === filePath);
      if (!fileData) return;

      const detailsPanel = document.getElementById('issueDetails');

      // Get current filter values
      const searchTerm = document.getElementById('searchInput').value.toLowerCase();
      const severity = document.getElementById('severityFilter').value;
      const analyzer = document.getElementById('analyzerFilter').value;

      // Filter issues based on current filters
      let filteredIssues = fileData.issues.filter(issue => {
        let matches = true;

        // Search filter
        if (searchTerm) {
          const searchableText = `${issue.signature} ${issue.message} ${issue.analyzer}`.toLowerCase();
          matches = matches && searchableText.includes(searchTerm);
        }

        // Severity filter
        if (severity) {
          matches = matches && issue.severity === severity;
        }

        // Analyzer filter
        if (analyzer) {
          matches = matches && issue.analyzer === analyzer;
        }

        return matches;
      });

      let html = `<h2>📝 ${escapeHtml(filePath)} (${filteredIssues.length} issues)</h2>`;

      filteredIssues.forEach(issue => {
        const analyzerMessage = extractAnalyzerMessage(issue.message);
        const highlightedMessage = highlightKeywords(escapeHtml(analyzerMessage));
        const editorLink = createEditorLink(issue.file, issue.line);
        html += `
          <div class="issue-item severity-${issue.severity}" onclick="window.location.href='${editorLink}'">
            <div class="issue-header">
              <div class="issue-signature">${escapeHtml(issue.signature)}</div>
              <div class="issue-meta">
                <span class="badge badge-${issue.severity}">${issue.severity}</span>
                <span class="badge badge-analyzer ${escapeHtml(issue.analyzer)}">${escapeHtml(issue.analyzer)}</span>
              </div>
            </div>
            <div class="issue-message">${highlightedMessage}</div>
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

      // First pass: filter files
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

      // Second pass: hide folders with no visible descendants (bottom-up)
      function hasVisibleDescendants(folderNode) {
        const childrenContainer = folderNode.querySelector('.tree-children');
        if (!childrenContainer) return false;

        // Check for visible files
        const visibleFiles = Array.from(childrenContainer.querySelectorAll(':scope > .file-node')).some(
          file => file.style.display !== 'none'
        );
        if (visibleFiles) return true;

        // Check nested folders recursively
        const childFolders = Array.from(childrenContainer.querySelectorAll(':scope > .folder-node'));
        return childFolders.some(childFolder => {
          const hasVisible = hasVisibleDescendants(childFolder);
          childFolder.style.display = hasVisible ? 'block' : 'none';
          return hasVisible;
        });
      }

      const folderNodes = document.querySelectorAll('.folder-node');
      // Process from deepest to shallowest
      const sortedFolders = Array.from(folderNodes).sort((a, b) => {
        return b.querySelectorAll('.folder-node').length - a.querySelectorAll('.folder-node').length;
      });

      sortedFolders.forEach(folder => {
        folder.style.display = hasVisibleDescendants(folder) ? 'block' : 'none';
      });

      // Refresh currently displayed issues if a file is selected
      const selectedNode = document.querySelector('.tree-node-header.selected');
      if (selectedNode) {
        const filePath = selectedNode.getAttribute('data-file');
        if (filePath) {
          showFileIssues(filePath);
        }
      }
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
