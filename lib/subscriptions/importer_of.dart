import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/subscriptions/subscription_import_queue.dart';
import 'package:quax/subscriptions/subscription_importer.dart';

/// The importer wired to the models the app provides.
SubscriptionImporter subscriptionImporterOf(BuildContext context) =>
    SubscriptionImporter(context.read<SubscriptionSaver>(), context.read<SubscriptionImportQueueModel>());
