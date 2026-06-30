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

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';

import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/loading_screen.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';

// ─────────────────────────────────────────────────────────────────────────────
// My Profile Page
// ─────────────────────────────────────────────────────────────────────────────

class HubMyProfilePage extends StatefulWidget {
  const HubMyProfilePage({super.key, required this.client});
  final Client client;

  @override
  State<HubMyProfilePage> createState() => _HubMyProfilePageState();
}

class _HubMyProfilePageState extends State<HubMyProfilePage> {
  bool _uploadingAvatar = false;

  /// Opens a file picker for images, uploads the selected file as the
  /// user's avatar, and triggers a UI refresh.
  Future<void> _changeAvatar() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _uploadingAvatar = true);

    try {
      await widget.client.uploadContent(
        bytes,
        filename: file.name,
        contentType:
            file.extension != null ? 'image/${file.extension}' : 'image/png',
      );
      await widget.client.setAvatar(MatrixFile(
        bytes: bytes,
        name: file.name,
      ));

      if (!mounted) return;
      setState(() => _uploadingAvatar = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.done),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context)!.error}: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final client = widget.client;
    return FutureBuilder<Profile>(
      future: client.getProfileFromUserId(client.userID!),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingScreen();
        }
        final profile = snapshot.data;
        final theme = Theme.of(context);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar + name header
              Row(
                children: [
                  // Avatar with change overlay
                  GestureDetector(
                    onTap: _uploadingAvatar ? null : _changeAvatar,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Stack(
                        children: [
                          profile?.avatarUrl == null
                              ? CircleAvatar(
                                  radius: 40,
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                  child: Text(
                                    (profile?.displayName ??
                                            profile?.userId ??
                                            '?')
                                        .toUpperCase()
                                        .split(RegExp(' +'))
                                        .map((s) => s[0])
                                        .take(2)
                                        .join(),
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                )
                              : AvatarFromUriOrFallbackImage(
                                  client: client,
                                  avatarUri: profile!.avatarUrl,
                                  radius: 40,
                                ),
                          // Upload overlay
                          if (_uploadingAvatar)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(40),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.colorScheme.surface,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  LucideIcons.camera,
                                  size: 14,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.displayName ?? l10n.unknown,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile?.userId ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.profilePageTitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 24),

              // ── Display Name ──────────────────────────────────────
              Text(
                l10n.displayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  profile?.displayName ?? l10n.notSet,
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── User ID (read-only) ──────────────────────────────
              Text(
                l10n.userIDLabel,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  profile?.userId ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'JetBrainsMono',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
