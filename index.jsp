<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.io.File" %>
<%@ page import="java.net.URLEncoder" %>
<%@ page import="java.util.*" %>
<%@ page import="java.io.IOException" %>
<%@ page import="java.text.SimpleDateFormat" %>
<%@ page import="javax.servlet.ServletContext" %>
<%@ page import="java.util.Scanner" %>
<%-- Web File Browser - index.jsp --%>

<%
    // ROOT DIRECTORY: /files in webapp
    String BASE_PATH = application.getRealPath("/files");
    File baseDir = new File(BASE_PATH);
    if (!baseDir.exists() || !baseDir.isDirectory()) {
        out.print("<h3 style='color:red;'>Error: /files directory not found!</h3>");
        return;
    }

    String reqPath = request.getParameter("path");
    if (reqPath == null || reqPath.trim().isEmpty()) {
        reqPath = "";
    } else {
        // Prevent directory traversal
        if (reqPath.contains("..") || reqPath.contains("\\")) {
            reqPath = "";
        }
        reqPath = reqPath.trim();
        while (reqPath.startsWith("/")) reqPath = reqPath.substring(1);
        while (reqPath.endsWith("/")) reqPath = reqPath.substring(0, reqPath.length() - 1);
    }

    File currentDir = new File(baseDir, reqPath);
    try {
        String canonicalBase = baseDir.getCanonicalPath();
        String canonicalCurrent = currentDir.getCanonicalPath();
        if (!canonicalCurrent.startsWith(canonicalBase)) {
            currentDir = baseDir;
            reqPath = "";
        }
    } catch (IOException e) {
        currentDir = baseDir;
        reqPath = "";
    }

    // Build breadcrumb parts: ["folder1", "folder1/subfolder2", ...]
    List<String> breadParts = new ArrayList<>();
    if (!reqPath.isEmpty()) {
        String[] parts = reqPath.split("/");
        StringBuilder accum = new StringBuilder();
        for (String p : parts) {
            if (p.isEmpty()) continue;
            if (accum.length() > 0) accum.append("/");
            accum.append(p);
            breadParts.add(accum.toString());
        }
    }
%>

<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Web File Browser</title>
    <style>
        /* === Global === */
        body {
            background-color: #1F1F1F;
            font-family: Ubuntu, Verdana, sans-serif;
            margin: 20px;
            color: #EEEEEE;
        }
        a { text-decoration: none; color: inherit; }
        a:hover { text-decoration: underline; }

        /* === Layout === */
        .container {
            display: flex;
            justify-content: center;
            align-items: flex-start;
        }

        /* === Header === */
        .header-table {
            border-collapse: separate;
            border-spacing: 0;
            width: 70%;
            margin-bottom: 20px;
        }
        .header-table td, .header-table th {
            background: transparent;
            border: 0;
            padding: 0;
            text-align: center;
            vertical-align: middle;
        }
        .header-table h1 {
            color: #EEEEEE;
            margin: 0;
            padding-left: 20px;
            text-align: left;
        }
        h1 {
            color: #EEEEEE;
            text-align: left;
            padding-left: 20px;
            font-size: 24px;
        }

        /* === Button === */
        .button {
            background-color: #598D36;
            border: none;
            color: white;
            padding: 15px 32px;
            text-align: center;
            text-decoration: none;
            display: inline-block;
            font-size: 16px;
            margin: 4px 2px;
            cursor: pointer;
            height: 20px;
            border-radius: 4px;
            overflow: hidden;
        }
        .button:hover { background-color: #6aa540; text-decoration: none; color: #1F1F1F; }

        /* === Main Content === */
        .main-content {
            display: flex;
            width: 70%;
            gap: 20px;
            margin-top: 20px;
        }
        .nav-pane, .file-pane {
            background-color: #22252D;
            border: 1px solid #424655;
            border-radius: 4px;
            padding: 0;
            overflow: hidden;
            max-height: 75vh;
        }
        .nav-pane { width: 300px; }
        .file-pane { flex: 1; }

        /* === TH-Style Header === */
        .th-header {
            background: #2C303D;
            color: #EEEEEE;
            font-weight: 600;
            padding: 10px;
            font-size: 14px;
            border-bottom: 1px solid #424655;
        }
        .breadcrumb .th-header {
            font-size: 13px;
        }

        /* === 10px Font for Nav & Table === */
        .tree-content, .file-content {
            padding: 15px;
            overflow-y: auto;
            max-height: calc(75vh - 50px);
            font-size: 10px;
        }
        .tree-content *, .file-content * {
            font-size: 10px !important;
        }

        /* === Tree === */
        .tree ul { 
            margin: 0; 
            padding-left: 16px; 
            list-style: none; 
        }
        .tree li { 
            margin: 8px 0; 
            list-style: none; 
            padding-left: 2px; 
        }
        .tree .folder > a { font-weight: 600; }
        .tree a { color: #EEEEEE; }
        .tree a.active { color: #598D36; font-weight: bold; }
        .icon { font-size: 12px; margin-right: 6px; vertical-align: middle; }

        /* === File Table === */
        table.file-table {
            width: 100%;
            border-collapse: separate;
            border-spacing: 0;
            border-radius: 4px;
            overflow: hidden;
            margin-top: 8px;
        }
        table.file-table th,
        table.file-table td {
            background-color: #22252D;
            border: 1px solid #424655;
            padding: 6px 8px;
            text-align: left;
            vertical-align: top;
        }
        table.file-table th {
            background-color: #2C303D;
            font-weight: 600;
            color: #EEEEEE;
        }
        table.file-table tr:nth-child(even) td { background-color: #1e2027; }
        .size { text-align: right; font-family: monospace; }
        .up a { color: #598D36; font-weight: 600; }

        /* === README Display === */
        .readme-box {
            background: #2C303D;
            border: 1px solid #424655;
            border-radius: 4px;
            padding: 10px;
            margin: 5px 0;
            max-height: 150px;
            overflow-y: auto;
            font-family: monospace;
            white-space: pre-wrap;
        }

        /* === Breadcrumb Links === */
        .breadcrumb a { color: #598D36; }
        .breadcrumb a:hover { text-decoration: underline; }
    </style>
</head>
<body>

<!-- ====================== HEADER ====================== -->
<div class="container">
    <table class="header-table">
        <tr>
            <td width="80px">
                <img src="../img/folder.png" width="64" height="64" alt="Logo"/>
            </td>
            <td><h1>Web File Browser</h1></td>
            <td width="150px">
                <a href="../index.html" class="button">Home</a>
            </td>
        </tr>
    </table>
</div>

<!-- ====================== MAIN CONTENT ====================== -->
<div class="container">
    <div class="main-content">

        <!-- ================== LEFT NAVIGATION PANE ================== -->
        <div class="nav-pane">
            <div class="th-header">Navigation</div>
            <div class="tree-content">
                <div class="tree">
                    <%=buildTree(application, baseDir, "", reqPath)%>
                </div>
            </div>
        </div>

        <!-- ================== RIGHT FILE PANE ================== -->
        <div class="file-pane">
            <div class="th-header breadcrumb">
                <a href="?path=">Home</a>
                <%
                for (int i = 0; i < breadParts.size(); i++) {
                    String lp = breadParts.get(i);
                    String partName = lp.substring(lp.lastIndexOf('/') + 1);
                    %> / <a href="?path=<%=enc(lp)%>"><%=partName%></a><%
                }
                %>
            </div>

            <div class="file-content">
                <%
                // Parent directory link
                String parentPath = "";
                if (!currentDir.equals(baseDir)) {
                    try {
                        File parent = currentDir.getParentFile();
                        String canonicalBase = baseDir.getCanonicalPath();
                        String canonicalParent = parent.getCanonicalPath();
                        if (canonicalParent.startsWith(canonicalBase)) {
                            parentPath = canonicalParent.substring(canonicalBase.length());
                            if (parentPath.startsWith(File.separator)) {
                                parentPath = parentPath.substring(1);
                            }
                            parentPath = parentPath.replace(File.separator, "/");
                        }
                    } catch (Exception ignored) {}
                }
                if (!parentPath.isEmpty()) {
                %>
                    <p class="up"><a href="?path=<%=enc(parentPath)%>">.. (parent directory)</a></p>
                <% } %>

                <!-- === README.TXT DISPLAY === -->
                <%
                File[] allFiles = currentDir.listFiles();
                File readmeFile = null;
                if (allFiles != null) {
                    for (File f : allFiles) {
                        if (f.isFile() && f.getName().toLowerCase().equals("readme.txt")) {
                            readmeFile = f;
                            break;
                        }
                    }
                }

                if (readmeFile != null) {
                    StringBuilder readmeContent = new StringBuilder();
                    try (Scanner scanner = new Scanner(readmeFile, "UTF-8")) {
                        while (scanner.hasNextLine()) {
                            readmeContent.append(scanner.nextLine()).append("\n");
                        }
                    } catch (Exception e) {
                        readmeContent.append("[Error reading readme.txt]");
                    }
                %>
                    <div class="readme-box">&#x26A0; README: <%=readmeContent.toString().trim()%></div>
                <% } %>

                <table class="file-table">
                    <thead>
                        <tr>
                            <th>Name</th>
                            <th class="size">Size</th>
                            <th>Last Modified</th>
                        </tr>
                    </thead>
                    <tbody>
                    <%
                    if (allFiles != null) {
                        Arrays.sort(allFiles, (a, b) -> {
                            if (a.isDirectory() && !b.isDirectory()) return -1;
                            if (!a.isDirectory() && b.isDirectory()) return 1;
                            return a.getName().compareToIgnoreCase(b.getName());
                        });

                        for (File f : allFiles) {
                            String name = f.getName();
                            String lowerName = name.toLowerCase();

                            // === IGNORE: lost+found, .html, .htm, .jsp, readme.txt ===
                            if ("lost+found".equals(name) && f.isDirectory()) continue;
                            if (lowerName.endsWith(".html") || lowerName.endsWith(".htm") || lowerName.endsWith(".jsp")) continue;
                            if (lowerName.equals("readme.txt")) continue;

                            String fullPath = reqPath.isEmpty() ? name : reqPath + "/" + name;
                            boolean isDir = f.isDirectory();
                    %>
                        <tr>
                            <td>
                                <% if (isDir) { %>
                                    <strong>
                                        <span class="icon">&#x1F4C1;</span>
                                        <a href="?path=<%=enc(fullPath)%>"><%=name%></a>
                                    </strong>
                                <% } else { %>
                                    <span class="icon">&#x1F5CE;</span>
                                    <a href="/files/<%=enc(fullPath)%>"><%=name%></a>
                                <% } %>
                            </td>
                            <td class="size"><%=isDir ? "—" : formatSize(f.length())%></td>
                            <td><%=new SimpleDateFormat("yyyy-MM-dd HH:mm").format(new Date(f.lastModified()))%></td>
                        </tr>
                    <% } } %>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<%!
    private String buildTree(ServletContext ctx, File dir, String indent, String selectedPath) throws IOException {
        StringBuilder sb = new StringBuilder();
        File[] children = dir.listFiles();
        if (children == null) return "";

        Arrays.sort(children, (a, b) -> {
            if (a.isDirectory() && !b.isDirectory()) return -1;
            if (!a.isDirectory() && b.isDirectory()) return 1;
            return a.getName().compareToIgnoreCase(b.getName());
        });

        String basePath = new File(ctx.getRealPath("/files")).getCanonicalPath();
        for (File f : children) {
            String name = f.getName();
            String lowerName = name.toLowerCase();

            // === IGNORE: lost+found, .html, .htm, .jsp, readme.txt ===
            if ("lost+found".equals(name) && f.isDirectory()) continue;
            if (lowerName.endsWith(".html") || lowerName.endsWith(".htm") || lowerName.endsWith(".jsp")) continue;
            if (lowerName.equals("readme.txt")) continue;

            String rel = relativize(basePath, f.getCanonicalPath());
            boolean active = rel.equals(selectedPath);

            sb.append("<li class=\"").append(f.isDirectory() ? "folder" : "file").append("\">");
            if (f.isDirectory()) {
                sb.append("<a href=\"?path=").append(enc(rel)).append("\"")
                  .append(active ? " class=\"active\"" : "").append(">")
                  .append("<span class=\"icon\">&#x1F4C1;</span>")
                  .append(name).append("</a>");
                sb.append("<ul>");
                sb.append(buildTree(ctx, f, indent + "  ", selectedPath));
                sb.append("</ul>");
            } else {
                sb.append("<span class=\"icon\">&#x1F5CE;</span>").append(name);
            }
            sb.append("</li>");
        }
        return sb.toString();
    }

    private String relativize(String basePath, String filePath) throws IOException {
        if (filePath.startsWith(basePath)) {
            String rel = filePath.substring(basePath.length());
            if (rel.startsWith(File.separator)) rel = rel.substring(1);
            return rel.replace(File.separator, "/");
        }
        return "";
    }

    private String enc(String s) {
        try { return URLEncoder.encode(s, "UTF-8"); }
        catch (Exception e) { return s; }
    }

    private String formatSize(long bytes) {
        if (bytes < 1024) return bytes + " B";
        int exp = (int) (Math.log(bytes) / Math.log(1024));
        char pre = "KMGTPE".charAt(exp - 1);
        return String.format("%.1f %cB", bytes / Math.pow(1024, exp), pre);
    }
%>
</body>
</html>
