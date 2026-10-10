import 'package:flutter_triple/flutter_triple.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/subscriptions/subscription_import_queue.dart';
import 'package:quax/ui/errors.dart';

/// Tells how many subscriptions are still waiting to be imported, and nothing once the queue is empty.
class ImportQueueCard extends StatelessWidget {
  const ImportQueueCard({super.key});

  @override
  Widget build(BuildContext context) {
    return TripleBuilder<SubscriptionImportQueueModel, int>(
      store: context.read<SubscriptionImportQueueModel>(),
      builder: (context, triple) {
        if (triple.state <= 0) return const SizedBox.shrink();
        final l10n = L10n.of(context);
        return StatusCard(
          icon: Icons.hourglass_top,
          title: l10n.importing_more_subscriptions(triple.state, smartImportBatch),
          details: l10n.importing_more_subscriptions_details,
          actions: const [],
        );
      },
    );
  }
}
