import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'package:quax/constants.dart';
import 'package:quax/subscriptions/importer_of.dart';
import 'package:quax/subscriptions/subscription_importer.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/generated/l10n.dart';

class SubscriptionImportScreen extends StatefulWidget {
  final String? screenName;

  const SubscriptionImportScreen({super.key, this.screenName});

  @override
  State<SubscriptionImportScreen> createState() => _SubscriptionImportScreenState();
}

class _SubscriptionImportScreenState extends State<SubscriptionImportScreen> {
  String? _screenName;
  StreamController<ImportProgress>? _streamController;

  @override
  void initState() {
    super.initState();
    _screenName = widget.screenName;
  }

  Future importSubscriptions() async {
    setState(() {
      _streamController = StreamController();
    });

    try {
      var screenName = _screenName;
      if (screenName == null || screenName.isEmpty) {
        return;
      }

      var importer = subscriptionImporterOf(context);

      var maxCount = await _chooseHowMany(await importer.size(screenName));
      if (maxCount == null) {
        if (mounted) setState(() => _streamController = null);
        return;
      }

      _streamController?.add(const ImportProgress(collected: 0));
      await _streamController?.addStream(importer.import(screenName, maxCount));
      _streamController?.close();
    } catch (e, stackTrace) {
      _streamController?.addError(e, stackTrace);
    }
  }

  /// How many subscriptions to import: all of them, unless there are more than X lets the feeds load and the user
  /// chooses fewer. Null when the user cancels.
  Future<int?> _chooseHowMany(SubscriptionImportSize size) async {
    var count = size.count;
    var limit = size.limit;
    if (count == null || !size.exceedsLimit || !mounted) {
      return count ?? 1 << 31; // unknown count: import everything
    }
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L10n.of(context).import_subscriptions),
        content: Text(L10n.of(context).import_too_many_subscriptions_warning(count.toString(), limit.toString())),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, count),
              child: Text(L10n.of(context).import_count_subscriptions(count))),
          FilledButton(
              onPressed: () => Navigator.pop(context, limit),
              child: Text(L10n.of(context).import_count_subscriptions(limit))),
        ],
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final theme = Theme.of(context);
    return Text(L10n.of(context).import_subscriptions_intro,
        style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant));
  }

  Widget _field(BuildContext context, bool running) => ImportUsernameField(
      initialValue: widget.screenName, enabled: !running, onChanged: (value) => setState(() => _screenName = value));

  Widget _status(BuildContext context, AsyncSnapshot<ImportProgress> snapshot) {
    final l10n = L10n.of(context);
    if (snapshot.error != null) {
      return ErrorCard(error: snapshot.error, stackTrace: snapshot.stackTrace, prefix: (l10n) => l10n.unable_to_import);
    }
    return switch (snapshot.connectionState) {
      ConnectionState.none || ConnectionState.waiting => const SizedBox.shrink(),
      ConnectionState.active => Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 8, children: [
          // ignore: deprecated_member_use
          const LinearProgressIndicator(year2023: false),
          Text(l10n.imported_snapshot_data_users_so_far((snapshot.data?.collected ?? 0).toString())),
        ]),
      ConnectionState.done => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.check_circle, size: 36, color: Theme.of(context).colorScheme.primary),
          title: Text(l10n.subscriptions_imported(snapshot.data?.imported ?? 0)),
          subtitle: (snapshot.data?.queued ?? 0) > 0
              ? Text(l10n.importing_more_subscriptions(snapshot.data!.queued, smartImportBatch))
              : null,
        ),
    };
  }

  Widget _importButton(BuildContext context, bool running) {
    final canImport = !running && (_screenName?.isNotEmpty ?? false);
    return FilledButton.icon(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
      onPressed: canImport ? importSubscriptions : null,
      icon: const Icon(Icons.download),
      label: Text(L10n.of(context).import),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).import_subscriptions)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: StreamBuilder<ImportProgress>(
              stream: _streamController?.stream,
              builder: (context, snapshot) {
                final running = snapshot.connectionState == ConnectionState.active && snapshot.error == null;
                return Column(children: [
                  Expanded(
                    child: ListView(padding: const EdgeInsets.all(16), children: [
                      _intro(context),
                      const SizedBox(height: 24),
                      _field(context, running),
                      const SizedBox(height: 16),
                      _status(context, snapshot),
                    ]),
                  ),
                  Padding(padding: const EdgeInsets.all(16), child: _importButton(context, running)),
                ]);
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The username of the X account to import the subscriptions of
class ImportUsernameField extends StatelessWidget {
  final String? initialValue;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  const ImportUsernameField(
      {super.key, this.initialValue, this.enabled = true, required this.onChanged, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Shaped like the Material 3 search bar, as the user looks an account up
    return TextFormField(
      initialValue: initialValue,
      enabled: enabled,
      decoration: InputDecoration(
        filled: true,
        fillColor: colors.surfaceContainerHigh,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        prefixIcon: const Padding(padding: EdgeInsetsDirectional.only(start: 12), child: Icon(Icons.alternate_email)),
        hintText: L10n.of(context).username,
        counterText: '',
      ),
      maxLength: 15,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z0-9_]+'))],
      textInputAction: TextInputAction.go,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
    );
  }
}
