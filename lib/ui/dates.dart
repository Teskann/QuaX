import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:quax/ui/locale_fallback.dart';
import 'package:timeago/timeago.dart' as timeago;

final absoluteDateFormat = DateFormat.yMMMd(formattingLocale()).add_Hms();

String createRelativeDate(DateTime dateTime) {
  return timeago.format(dateTime, locale: Intl.shortLocale(formattingLocale()));
}

class Timestamp extends StatefulWidget {
  final DateTime? timestamp;
  final bool absoluteTimestamp;

  const Timestamp({super.key, required this.timestamp, this.absoluteTimestamp = false});

  @override
  State<Timestamp> createState() => _TimestampState();
}

class _TimestampState extends State<Timestamp> {
  late bool _showsAbsolute = widget.absoluteTimestamp;

  @override
  void didUpdateWidget(Timestamp oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The list may reuse this widget for another post, which starts on the default format again.
    if (oldWidget.timestamp != widget.timestamp || oldWidget.absoluteTimestamp != widget.absoluteTimestamp) {
      _showsAbsolute = widget.absoluteTimestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = widget.timestamp;
    if (timestamp == null) {
      return Container();
    }

    return GestureDetector(
      child: Text(_showsAbsolute ? absoluteDateFormat.format(timestamp.toLocal()) : createRelativeDate(timestamp)),
      onTap: () => setState(() => _showsAbsolute = !_showsAbsolute),
    );
  }
}
