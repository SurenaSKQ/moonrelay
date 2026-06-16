// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.

// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/helpers/log_service.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:provider/provider.dart';

/// A settings page that lets the user view the most recent log file
/// inline, pick older log files, or open the logs folder in the system
/// file manager.
class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  List<File> _logFiles = [];
  File? _selectedFile;
  String _logContent = '';
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLogFiles();
  }

  Future<void> _loadLogFiles() async {
    final logService = context.read<LogService>();
    final dir = Directory(logService.logDir);
    if (!await dir.exists()) return;

    final entities = await dir.list().toList();
    final files = <File>[];
    for (final e in entities) {
      if (e is File && await e.length() > 0) {
        files.add(e);
      }
    }
    // Sort — most recently modified first.
    files.sort((a, b) {
      final aStat = a.statSync();
      final bStat = b.statSync();
      return bStat.modified.compareTo(aStat.modified);
    });

    if (!mounted) return;
    setState(() {
      _logFiles = files;
      if (files.isNotEmpty && _selectedFile != files.first) {
        _selectedFile = files.first;
        _loadContent(files.first);
      } else if (files.isEmpty) {
        _logContent = '(no log files)';
      }
    });
  }

  Future<void> _loadContent(File file) async {
    setState(() => _loading = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      // Read only the last ~50 KB to avoid freezing on huge files.
      final length = await file.length();
      final offset = length > 51200 ? length - 51200 : 0;
      final raf = await file.open(mode: FileMode.read);
      await raf.setPosition(offset);
      final bytes = await raf.read(length - offset);
      await raf.close();
      final content = utf8.decode(bytes);

      if (!mounted) return;
      setState(() {
        _logContent =
            offset > 0 ? '${l10n.showingLastKb}\n\n$content' : content;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _logContent = '${l10n.error}: $e';
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    if (_selectedFile != null) {
      await _loadContent(_selectedFile!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logService = context.watch<LogService>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.logs,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.logsDescription,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedFile != null)
                IconButton(
                  icon: const Icon(LucideIcons.refreshCw, size: 20),
                  tooltip: l10n.refresh,
                  onPressed: _loading ? null : _refresh,
                ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Open logs folder button ────────────────────────────────
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: ListTile(
              leading: const Icon(LucideIcons.folderOpen, size: 24),
              title: Text(
                l10n.openLogsFolder,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                logService.logDir,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(LucideIcons.chevronRight, size: 20),
              onTap: () => _openLogsFolder(logService.logDir),
            ),
          ),
          const SizedBox(height: 16),

          // ── Clear logs button ────────────────────────────────────────
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: ListTile(
              leading: Icon(LucideIcons.trash2, size: 24, color: scheme.error),
              title: Text(
                l10n.clearLog,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: scheme.error,
                ),
              ),
              subtitle: Text(
                l10n.clearLogDescription,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Icon(LucideIcons.chevronRight, size: 20),
              onTap: () => _confirmClearLogs(context, logService),
            ),
          ),
          const SizedBox(height: 20),

          // ── File picker row ────────────────────────────────────────
          if (_logFiles.length > 1) ...[
            Row(
              children: [
                Icon(LucideIcons.fileText,
                    size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  l10n.logFile,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<File>(
              initialValue: _selectedFile,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              items: _logFiles.map((f) {
                final name = f.uri.pathSegments.last;
                return DropdownMenuItem<File>(value: f, child: Text(name));
              }).toList(),
              onChanged: (file) {
                if (file == null) return;
                setState(() => _selectedFile = file);
                _loadContent(file);
              },
            ),
            const SizedBox(height: 16),
          ],

          // ── Log content viewer ─────────────────────────────────────
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 600),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    _logContent,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.4,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openLogsFolder(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) return;

      if (defaultTargetPlatform == TargetPlatform.windows) {
        await Process.run('explorer', [dir.absolute.path], runInShell: true);
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        await Process.run('open', [dir.absolute.path], runInShell: true);
      } else if (defaultTargetPlatform == TargetPlatform.linux) {
        await Process.run('xdg-open', [dir.absolute.path], runInShell: true);
      }
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _confirmClearLogs(
      BuildContext context, LogService logService) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearLogsTitle),
        content: Text(
          l10n.clearLogsConfirmation,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await logService.wipeLogs();
    if (!mounted) return;
    setState(() {
      _selectedFile = null;
      _logContent = l10n.logFilesCleared;
      _logFiles = [];
    });
    _loadLogFiles();
  }
}
