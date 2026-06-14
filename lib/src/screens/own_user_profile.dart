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

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/loading_screen.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

// FIXME this entire widget is a disaster
class OwnProfilePage extends StatefulWidget {
  const OwnProfilePage({super.key, required this.client});
  final Client client;
  @override
  State<OwnProfilePage> createState() => _OwnProfilePageState();
}

class _OwnProfilePageState extends State<OwnProfilePage> {
  Profile? _profile;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final log = context.read<Logger>();
    final result = await withRetry(
      () => widget.client.getProfileFromUserId(widget.client.userID!),
      maxRetries: 1,
      timeout: kDefaultTimeout,
      log: log,
      label: 'ownProfile',
    );

    if (!mounted) return;

    switch (result) {
      case RetrySuccess(:final value):
        {
          setState(() {
            _profile = value;
            _loading = false;
          });
        }
      case RetryFailed(:final error):
        {
          setState(() {
            _error = error;
            _loading = false;
          });
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingScreen();

    if (_error != null || _profile == null) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: _buildErrorBody(context),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(context),
      body: OwnProfilePageContent(
        client: widget.client,
        userProfile: _profile!,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft),
        onPressed: () => context.pop(),
      ),
      title: Text(
        AppLocalizations.of(context)?.ownProfileDescriptor ?? 'Your Profile',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
      ),
    );
  }

  Widget _buildErrorBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final message = _error is TimeoutException
        ? 'Could not load profile: The server did not respond in time.'
        : 'Could not load profile: $_error';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.alertCircle, size: 48, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: const Text('Retry'),
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _fetchProfile();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class OwnProfilePageContent extends StatelessWidget {
  const OwnProfilePageContent({
    super.key,
    required this.client,
    required this.userProfile,
  });

  final Profile userProfile;
  final Client client;

  @override
  Widget build(BuildContext context) {
    if (userProfile.displayName == null) {
      // Schedule SnackBar after build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("You have not set a display name!"),
          ),
        );
      });
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              userProfile.avatarUrl == null
                  ? Text(
                      userProfile.displayName!
                          .toUpperCase()
                          .split(RegExp(' +'))
                          .map((s) => s[0])
                          .take(2)
                          .join(),
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                    )
                  : AvatarFromUriOrFallbackImage(
                      client: client,
                      avatarUri: userProfile.avatarUrl,
                    ),
              const SizedBox(
                width: 16,
              ),
              Text(
                userProfile.displayName ?? userProfile.userId,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const Divider(),
        Text(
          "(${userProfile.userId})",
          style: TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}
