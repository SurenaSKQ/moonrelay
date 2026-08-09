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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:provider/provider.dart';

/// A widget for searching the user directory and starting direct chats.
///
/// Supports:
/// - Text-based user search via [Client.searchUserDirectory]
/// - Starting a direct chat with any user from the results
/// - Reusing an existing direct chat if one already exists
///
/// When [embedded] is `true`, the widget renders without its own
/// [Scaffold] / [AppBar] so it can be used as a tab inside another page.
class UserSearchWidget extends StatefulWidget {
  /// When `true`, the widget renders without its own [Scaffold] / [AppBar]
  /// so it can be embedded inside another page (e.g. as a tab in
  /// [AddRoomPage]) without duplicating the chrome.
  final bool embedded;

  const UserSearchWidget({super.key, this.embedded = false});

  @override
  State<UserSearchWidget> createState() => _UserSearchWidgetState();
}

class _UserSearchWidgetState extends State<UserSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // Search state
  String _searchQuery = '';
  List<Profile> _results = [];
  bool _isLoading = false;
  Object? _error;
  String? _startingDmUserId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Debounced search  waits 300ms after the user stops typing.
  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query == _searchQuery) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchQuery = query;
      _searchUsers();
    });
  }

  /// Searches the user directory on the homeserver.
  Future<void> _searchUsers() async {
    if (_searchQuery.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = context.read<Client>();
      final response = await client.searchUserDirectory(
        _searchQuery,
        limit: 20,
      );

      if (!mounted) return;

      setState(() {
        _results = response.results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  /// Starts (or reuses) a direct chat with the selected user.
  Future<void> _startDirectChat(Profile user) async {
    final log = context.read<Logger>();
    final l10n = AppLocalizations.of(context)!;

    setState(() => _startingDmUserId = user.userId);

    final result = await withRetry(
      () => context.read<Client>().startDirectChat(user.userId),
      maxRetries: 1,
      timeout: kDefaultTimeout,
      log: log,
      label: 'startDirectChat',
    );

    if (!mounted) return;

    setState(() => _startingDmUserId = null);

    switch (result) {
      case RetrySuccess(:final value):
        context.go('/main/rooms/$value');
      case RetryFailed(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is TimeoutException
                  ? l10n.couldNotStartChatTimeout
                  : l10n.couldNotStartChat('$error'),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MoonrelayThemeExtension.of(context).tokens;

    final Widget body = Column(
      children: [
        // Search bar
        Padding(
          padding: EdgeInsets.fromLTRB(
              t.spaceLg, t.spaceSm, t.spaceLg, t.spaceXs),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.searchUsers,
              prefixIcon: Icon(LucideIcons.search, size: t.iconSizeMedium),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: t.opacitySubtle),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.radiusMd),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              _debounce?.cancel();
              _searchQuery = _searchController.text.trim();
              _searchUsers();
            },
          ),
        ),

        SizedBox(height: t.spaceXs),

        // Results area
        Expanded(child: _buildContent()),
      ],
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.searchUsers,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: body,
    );
  }

  Widget _buildContent() {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;

    // Loading state
    if (_isLoading && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: scheme.primary),
            SizedBox(height: t.spaceLg),
            Text(l10n.searching,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    // Error state
    if (_error != null && _results.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(t.spaceXxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.alertCircle, size: 48, color: scheme.error),
              SizedBox(height: t.spaceLg),
              Text(
                l10n.couldNotLoadMessages,
                style: TextStyle(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: t.spaceLg),
              FilledButton.tonalIcon(
                onPressed: _searchUsers,
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    // Empty results (searched but nothing found)
    if (_results.isEmpty && !_isLoading && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.searchX,
              size: 48,
              color: scheme.onSurfaceVariant.withValues(alpha: t.opacityDisabled),
            ),
            SizedBox(height: t.spaceMd),
            Text(
              l10n.noUsersFound,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    // Empty state (no search yet)
    if (_results.isEmpty && !_isLoading && _searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.messageCircle,
              size: 48,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            SizedBox(height: t.spaceMd),
            Text(
              l10n.searchUsersHint,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    // Results list
    final client = context.read<Client>();
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: t.spaceMd),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final user = _results[index];
        final isStarting = _startingDmUserId == user.userId;
        final displayName = user.displayName ?? user.userId;

        return Card(
          elevation: t.elevationNone,
          margin: EdgeInsets.symmetric(vertical: t.spaceXs),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusMd),
            side:
                BorderSide(color: scheme.outlineVariant.withValues(alpha: t.opacitySubtle)),
          ),
          child: Padding(
            padding: EdgeInsets.all(t.spaceMd),
            child: Row(
              children: [
                // User avatar
                AvatarFromUriOrFallbackImage(
                  client: client,
                  avatarUri: user.avatarUrl,
                  radius: 24,
                ),
                SizedBox(width: t.spaceMd),

                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: t.spaceXxs),
                        child: Text(
                          user.userId,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                            fontFamily: 'JetBrainsMono',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Start DM button
                SizedBox(width: t.spaceSm),
                if (isStarting)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: () => _startDirectChat(user),
                    icon: const Icon(LucideIcons.messageSquare, size: 14),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    label: Text(
                      l10n.actionStartDirectChat,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
