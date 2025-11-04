<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.io.File" %>
<%@ page import="java.util.*" %>
<%@ page import="java.io.IOException" %>
<%@ page import="java.text.SimpleDateFormat" %>
<%@ page import="javax.servlet.ServletContext" %>
<%@ page import="java.util.Scanner" %>
<%-- Web File Browser - index.jsp --%>

<%!
    // === HELPER METHODS ===

    /** URL-encode path safely */
    private String enc(String s) {
        if (s == null) return "";
        s = s.replace("\\", "/");
        while (s.contains("//")) s = s.replace("//", "/");
        s = s.trim();
        if (s.startsWith("/")) s = s.substring(1);
        if (s.endsWith("/")) s = s.substring(0, s.length() - 1);
        return s.replace("%", "%25").replace(" ", "%20").replace("+", "%2B")
                .replace("\"", "%22").replace("#", "%23").replace("&", "%26")
                .replace("=", "%3D").replace("?", "%3F");
    }

    /** Get relative path from base to file */
    private String relativize(String basePath, String filePath) throws IOException {
        if (filePath.startsWith(basePath)) {
            String rel = filePath.substring(basePath.length());
            if (rel.startsWith(File.separator)) rel = rel.substring(1);
            return rel.replace(File.separator, "/");
        }
        return "";
    }

    /** Human-readable file size */
    private String formatSize(long bytes) {
        if (bytes < 1024) return bytes + " B";
        int exp = (int) (Math.log(bytes) / Math.log(1024));
        char pre = "KMGTPE".charAt(exp - 1);
        return String.format("%.1f %cB", bytes / Math.pow(1024, exp), pre);
    }

    /** Build navigation tree with proper expansion of all parent folders */
    private String buildTree(ServletContext ctx, File dir, String selectedPath) throws IOException {
        StringBuilder sb = new StringBuilder();
        File[] children = dir.listFiles();
        if (children == null) return "<ul></ul>";

        Arrays.sort(children, (a, b) -> {
            if (a.isDirectory() && !b.isDirectory()) return -1;
            if (!a.isDirectory() && b.isDirectory()) return 1;
            return a.getName().compareToIgnoreCase(b.getName());
        });

        String basePath = new File(ctx.getRealPath("/files")).getCanonicalPath();

        // Determine which paths need to be expanded (all ancestors of selectedPath)
        Set<String> expandPaths = new HashSet<>();
        if (selectedPath != null && !selectedPath.isEmpty()) {
            String[] parts = selectedPath.split("/");
            StringBuilder accum = new StringBuilder();
            for (String part : parts) {
                if (part.isEmpty()) continue;
                if (accum.length() > 0) accum.append("/");
                accum.append(part);
                expandPaths.add(accum.toString());
            }
        }

        sb.append("<ul>");
        for (File f : children) {
            String name = f.getName();
            String lowerName = name.toLowerCase();

            // Skip unwanted entries
            if ("lost+found".equals(name) && f.isDirectory()) continue;
            if (lowerName.endsWith(".html") || lowerName.endsWith(".htm") || lowerName.endsWith(".jsp")) continue;
            if (lowerName.equals("readme.txt")) continue;

            String rel = relativize(basePath, f.getCanonicalPath());
            boolean isDir = f.isDirectory();
            boolean shouldExpand = isDir && expandPaths.contains(rel);
            boolean isActive = rel.equals(selectedPath);

            sb.append("<li class=\"").append(isDir ? "folder" : "file").append("\"");
            if (shouldExpand) {
                sb.append(" data-open=\"true\"");
            }
            sb.append(">");

            if (isDir) {
                sb.append("<a href=\"?path=").append(enc(rel)).append("\"")
                  .append(isActive ? " class=\"active\"" : "")
                  .append(">").append(name).append("</a>");
                sb.append(buildTree(ctx, f, selectedPath));
            //} else {
                //sb.append("<span class=\"icon\">&#x1F5CE;</span>").append(name);  // Uncomment to also show files in navigation pane
            }
            sb.append("</li>");
        }
        sb.append("</ul>");
        return sb.toString();
    }
%>

<%
    // === MAIN LOGIC ===
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
        // Basic sanitization
        if (reqPath.contains("..") || reqPath.contains("\\") || reqPath.contains("\0")) {
            reqPath = "";
        } else {
            reqPath = reqPath.replace("\\", "/").trim();
            while (reqPath.startsWith("/")) reqPath = reqPath.substring(1);
            while (reqPath.endsWith("/")) reqPath = reqPath.substring(0, reqPath.length() - 1);
        }
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

    // Build breadcrumb parts
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
        body { background:#1F1F1F; font-family:Ubuntu,Verdana,sans-serif; margin:20px; color:#EEE; }
        a { text-decoration:none; color:inherit; }
        a:hover { text-decoration:underline; }
        .container { display:flex; justify-content:center; align-items:flex-start; }
        .header-table { width:70%; margin-bottom:20px; border-collapse:separate; border-spacing:0; }
        .header-table td, .header-table th { background:transparent; border:0; padding:0; text-align:center; vertical-align:middle; }
        .header-table h1 { margin:0; padding-left:20px; text-align:left; color:#EEE; }
        h1 { color:#EEE; text-align:left; padding-left:20px; font-size:24px; }
        .button { background:#598D36; color:white; padding:15px 32px; font-size:16px; margin:4px 2px; cursor:pointer; height:20px; border-radius:4px; display:inline-block; line-height:20px; }
        .button:hover { background:#6aa540; color:#1F1F1F; }
        .main-content { display:flex; width:70%; gap:20px; margin-top:20px; }
        .nav-pane, .file-pane { background:#22252D; border:1px solid #424655; border-radius:4px; overflow:hidden; max-height:75vh; }
        .nav-pane { width:300px; }
        .file-pane { flex:1; }
        .th-header { background:#2C303D; color:#EEE; font-weight:600; padding:10px; font-size:14px; border-bottom:1px solid #424655; }
        .breadcrumb .th-header { font-size:14px; }
        .tree-content, .file-content { padding:15px; overflow-y:auto; max-height:calc(75vh - 50px); font-size:12px; }
        .tree-content *, .file-content * { font-size:14px !important; }

        /* === Collapsible Tree === */
        .tree ul { margin:0; padding-left:20px; list-style:none; display:none; }
        .tree > ul { display:block; padding-left:0;}
        .tree li { margin:6px 0; line-height:1.4; }
        .tree .folder > a {
            font-weight:600; cursor:pointer; position:relative; padding-left:10px; display:block;
            white-space:nowrap; overflow:hidden; text-overflow:ellipsis;
        }
        .tree a { color:#EEE; text-decoration: none !important; font-weight: normal !important;}
        .tree a:hover { color: #156082 !important; font-weight:bold !important;}
        .tree a.active { color:#0F9ED5; font-weight:bold !important; }
        .tree .folder > a::before { content:"📁"; position:relative; left:-5px; width:12px; font-size:14px; line-height:1.4; }
        .tree .folder.open > a::before { content:"📂"; }
        .tree .folder.open > ul { display:block; }
        .icon { font-size:14px !important; margin-right:6px; vertical-align:middle; color:#0F9ED5 !important;}
        .iconlg { font-size:20px !important; margin-right:6px; vertical-align:middle; color:#0F9ED5 !important;}

        table.file-table { width:100%; border-collapse:separate; border-spacing:0; border-radius:4px; overflow:hidden; margin-top:8px;}
        table.file-table th, table.file-table td { background:#22252D; border:1px solid #424655; padding:6px 8px; text-align:left;}
        table.file-table th { background:#2C303D; color:#EEE; font-weight:600; }
        table.file-table tr:nth-child(even) td { background:#1e2027; }
        .size { text-align:right; font-family:monospace; }
        .up a { color:#0F9ED5; font-weight:600; }
        .readme-box {
            background:#2C303D;
            border:1px solid #424655;
            border-radius:4px;
            padding:10px; margin:5px 0; max-height:150px; overflow-y:auto;
            font-family:monospace; white-space:pre-wrap;
            font-size:14px !important;
        }
        .breadcrumb a { color:#0F9ED5 }
        .breadcrumb a:hover { text-decoration:underline; }
    </style>
    <script>
        document.addEventListener('DOMContentLoaded', () => {
            // Expand all folders marked with data-open="true"
            document.querySelectorAll('.tree li[data-open="true"]').forEach(li => {
                li.classList.add('open');
            });

            // Toggle folder on click
            document.querySelectorAll('.tree .folder > a').forEach(a => {
                a.addEventListener('click', e => {
                    e.preventDefault();
                    const li = a.parentElement;
                    li.classList.toggle('open');
                    setTimeout(() => location.href = a.href, 120);
                });
            });
        });
    </script>
</head>
<body>

<!-- ====================== HEADER ====================== -->
<div class="container">
    <table class="header-table">
        <tr>
            <td width="80px"><img src="../img/folder.png" width="64" height="64" alt="Logo"/></td>
            <td><h1>Web File Browser</h1></td>
            <td width="150px"><a href="../index.html" class="button">Home</a></td>
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
                    <%= buildTree(application, baseDir, reqPath) %>
                </div>
            </div>
        </div>

        <!-- ================== RIGHT FILE PANE ================== -->
        <div class="file-pane">
            <div class="th-header breadcrumb">
                <a href="?path=">Home</a>
                <% for (String lp : breadParts) {
                    String partName = lp.substring(lp.lastIndexOf('/') + 1);
                %> / <a href="?path=<%=enc(lp)%>"><%=partName%></a><% } %>
            </div>

            <div class="file-content">
                <% 
                String parentPath = "";
                if (!currentDir.equals(baseDir)) {
                    try {
                        File parent = currentDir.getParentFile();
                        String cb = baseDir.getCanonicalPath();
                        String cp = parent.getCanonicalPath();
                        if (cp.startsWith(cb)) {
                            parentPath = cp.substring(cb.length());
                            if (parentPath.startsWith(File.separator)) parentPath = parentPath.substring(1);
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
                        if (f.isFile() && "readme.txt".equalsIgnoreCase(f.getName())) {
                            readmeFile = f; break;
                        }
                    }
                }
                if (readmeFile != null) {
                    StringBuilder content = new StringBuilder();
                    try (Scanner sc = new Scanner(readmeFile, "UTF-8")) {
                        while (sc.hasNextLine()) content.append(sc.nextLine()).append("\n");
                    } catch (Exception e) {
                        content.append("[Error reading README]");
                    }
                %>
                    <div class="readme-box">&#x26A0; README: <%=content.toString().trim()%></div>
                <% } %>

                <!-- === DIRECTORY CONTENTS DISPLAY === -->
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

                            if ("lost+found".equals(name) && f.isDirectory()) continue;
                            if (lowerName.endsWith(".html") || lowerName.endsWith(".htm") || lowerName.endsWith(".jsp")) continue;
                            if (lowerName.equals("readme.txt")) continue;

                            String fullPath = reqPath.isEmpty() ? name : reqPath + "/" + name;
                            boolean isDir = f.isDirectory();
                    %>
                        <tr>
                            <td>
                                <% if (isDir) { %>
                                    <strong><span class="icon">&#x1F4C1;</span>
                                    <a href="?path=<%=enc(fullPath)%>"><%=name%></a></strong>
                                <% } else { %>
                                    <span class="iconlg">&#x1F5CE;</span>
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

</body>
</html>
