import 'package:flutter/material.dart';

import 'updater.dart';

/// Offers a newer version of the app. Takes no space when there is none.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key, required this.updates, this.margin = EdgeInsets.zero});

  final UpdateController updates;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: updates,
      builder: (context, _) {
        final update = updates.available;
        if (update == null) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final foreground = scheme.onSecondaryContainer;
        final progress = updates.progress;

        final String detail;
        if (updates.downloading) {
          detail = progress == null ? 'Downloading…' : 'Downloading… ${(progress * 100).floor()}%';
        } else if (updates.installerOpened) {
          detail = 'Tap Install on the Android screen to finish. Your leave records are kept.';
        } else {
          detail = 'Update here in the app. Your leave records are kept.';
        }

        return Card(
          elevation: 0,
          margin: margin,
          color: scheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.system_update, color: foreground),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Version ${update.version} is available',
                            style: theme.textTheme.titleSmall?.copyWith(color: foreground),
                          ),
                          const SizedBox(height: 2),
                          Text(detail, style: theme.textTheme.bodySmall?.copyWith(color: foreground)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!updates.downloading)
                      FilledButton(
                        onPressed: updates.install,
                        child: Text(updates.installerOpened ? 'Open again' : 'Update'),
                      ),
                  ],
                ),
                if (updates.downloading) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: progress, minHeight: 6),
                  ),
                ],
                if (updates.message != null && !updates.downloading) ...[
                  const SizedBox(height: 8),
                  Text(updates.message!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The "App" part of the settings screen: installed version and a manual
/// check for updates.
class UpdateSection extends StatelessWidget {
  const UpdateSection({super.key, required this.updates});

  final UpdateController updates;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: updates,
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final version = updates.currentVersion;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('App', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              version == null ? 'Updates install here, inside the app.' : 'Version $version. Updates install here, inside the app.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (updates.available != null)
              UpdateBanner(updates: updates)
            else ...[
              OutlinedButton.icon(
                onPressed: updates.checking ? null : () => updates.check(manual: true),
                icon: updates.checking
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                label: Text(updates.checking ? 'Checking…' : 'Check for updates'),
              ),
              if (updates.message != null) ...[
                const SizedBox(height: 8),
                Text(updates.message!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ],
          ],
        );
      },
    );
  }
}
