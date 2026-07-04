import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/ssh_host.dart';
import '../services/ssh_executor.dart';

/// Prompts the user for a passphrase or password. Returns null if cancelled.
/// Used by [GpuMonitorProvider] via its credential callback.
Future<String?> showCredentialDialog(
  BuildContext context,
  CredentialKind kind,
  SshHost host, {
  String? reason,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _CredentialDialog(kind: kind, host: host, reason: reason),
  );
}

class _CredentialDialog extends StatefulWidget {
  final CredentialKind kind;
  final SshHost host;
  final String? reason;
  const _CredentialDialog({
    required this.kind,
    required this.host,
    this.reason,
  });

  @override
  State<_CredentialDialog> createState() => _CredentialDialogState();
}

class _CredentialDialogState extends State<_CredentialDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPass = widget.kind == CredentialKind.passphrase;
    final l10n = AppLocalizations.of(context)!;
    final title = isPass
        ? l10n.privateKeyPassphraseTitle
        : l10n.sshPasswordTitle;
    return AlertDialog(
      icon: const Icon(Icons.lock_outline),
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.hostLabel(widget.host.alias)),
          if (widget.reason != null) ...[
            const SizedBox(height: 4),
            Text(widget.reason!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: isPass ? 'Passphrase' : l10n.passwordLabel,
              hintText: isPass ? l10n.passphraseHint : l10n.passwordHint,
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}
