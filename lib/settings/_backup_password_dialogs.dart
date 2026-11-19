import 'package:material_ui/material_ui.dart';
import 'package:quax/client/accounts.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/settings/encrypted_accounts.dart';

/// The accounts of a new backup, encrypted with a password the user picks, or null when the user cancels the export.
/// Without any account, no password is asked and the backup holds none.
Future<({Map<String, dynamic>? encrypted})?> encryptAccountsToExport(BuildContext context) async {
  final accounts = await getAccounts();
  if (accounts.isEmpty || !context.mounted) {
    return (encrypted: null);
  }
  final password = await askNewBackupPassword(context);
  if (password == null) {
    return null;
  }
  return (encrypted: (await encryptAccounts(accounts, password)).toJson());
}

/// The password the accounts of a new backup are encrypted with, or null when the user cancels the export.
Future<String?> askNewBackupPassword(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const _NewBackupPasswordDialog());

/// The decrypted accounts of a backup, or null when the user skips them.
Future<List<Account>?> askPasswordAndDecryptAccounts(BuildContext context, Map<String, dynamic> encryptedAccounts) =>
    showDialog<List<Account>>(
        context: context, barrierDismissible: false, builder: (_) => _DecryptAccountsDialog(encryptedAccounts));

// A second tap while the dialog closes would also close the page under it
void _closeOnce<T>(BuildContext context, [T? result]) {
  if (ModalRoute.of(context)?.isCurrent ?? false) {
    Navigator.pop(context, result);
  }
}

class _NewBackupPasswordDialog extends StatefulWidget {
  const _NewBackupPasswordDialog();

  @override
  State<_NewBackupPasswordDialog> createState() => _NewBackupPasswordDialogState();
}

class _NewBackupPasswordDialogState extends State<_NewBackupPasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      _closeOnce(context, _password.text);
    }
  }

  String? _validatePassword(String? password) => (password ?? '').length < minimumPasswordLength
      ? L10n.of(context).backup_password_too_short(minimumPasswordLength)
      : null;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AlertDialog(
      title: Text(l10n.backup_password_export_title),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(l10n.backup_password_export_details),
              TextFormField(
                  controller: _password,
                  obscureText: true,
                  autofocus: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(labelText: l10n.backup_password),
                  validator: _validatePassword),
              TextFormField(
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(labelText: l10n.backup_password_confirmation),
                  validator: (value) => value != _password.text ? l10n.backup_password_mismatch : null,
                  onFieldSubmitted: (_) => _submit()),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => _closeOnce(context), child: Text(l10n.cancel)),
        TextButton(onPressed: _submit, child: Text(l10n.export)),
      ],
    );
  }
}

class _DecryptAccountsDialog extends StatefulWidget {
  final Map<String, dynamic> encryptedAccounts;

  const _DecryptAccountsDialog(this.encryptedAccounts);

  @override
  State<_DecryptAccountsDialog> createState() => _DecryptAccountsDialogState();
}

class _DecryptAccountsDialogState extends State<_DecryptAccountsDialog> {
  final _password = TextEditingController();
  bool _decrypting = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = L10n.of(context);
    setState(() => _decrypting = true);
    try {
      final accounts = await decryptAccounts(EncryptedAccounts.fromJson(widget.encryptedAccounts), _password.text);
      if (mounted) {
        _closeOnce(context, accounts);
      }
    } on WrongPasswordException {
      _showError(l10n.backup_password_wrong);
    } on UnreadableAccountsException {
      _showError(l10n.backup_accounts_unreadable);
    }
  }

  void _showError(String error) {
    if (mounted) {
      setState(() {
        _decrypting = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return PopScope(
      canPop: !_decrypting,
      child: AlertDialog(
        title: Text(l10n.backup_password_import_title),
        content: SingleChildScrollView(
          child: AutofillGroup(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(l10n.backup_password_import_details),
              TextField(
                  controller: _password,
                  obscureText: true,
                  autofocus: true,
                  enabled: !_decrypting,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(labelText: l10n.backup_password, errorText: _error),
                  onSubmitted: (_) => _submit()),
              if (_decrypting) const LinearProgressIndicator(),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: _decrypting ? null : () => _closeOnce(context),
              child: Text(l10n.backup_password_skip_accounts)),
          TextButton(onPressed: _decrypting ? null : _submit, child: Text(l10n.import)),
        ],
      ),
    );
  }
}
