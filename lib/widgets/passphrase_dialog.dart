import 'package:flutter/material.dart';

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
  const _CredentialDialog(
      {required this.kind, required this.host, this.reason});

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
    final title = isPass ? '私钥 Passphrase' : 'SSH 密码';
    return AlertDialog(
      icon: const Icon(Icons.lock_outline),
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('主机：${widget.host.alias}'),
          if (widget.reason != null) ...[
            const SizedBox(height: 4),
            Text(widget.reason!,
                style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: isPass ? 'Passphrase' : '密码',
              hintText: isPass ? '输入私钥的 passphrase' : '输入登录密码',
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
