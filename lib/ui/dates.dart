import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

final absoluteDateFormat = DateFormat.yMMMd().add_Hms();

String createRelativeDate(DateTime dateTime) {
  return timeago.format(dateTime, locale: Intl.shortLocale(Intl.getCurrentLocale()));
}

class Timestamp extends StatefulWidget {
  final DateTime? timestamp;
  final bool absoluteTimestamp;

  const Timestamp({super.key, required this.timestamp, this.absoluteTimestamp = false});

  @override
  State<Timestamp> createState() => _TimestampState(useRelativeTimestamp: !absoluteTimestamp);
}

class _TimestampState extends State<Timestamp> {
  bool _useRelativeTimestamp;

  _TimestampState({useRelativeTimestamp = true}) : _useRelativeTimestamp = useRelativeTimestamp;

  String formattedTime = '';

  @override
  void initState() {
    super.initState();

    var timestamp = widget.timestamp;
    if (timestamp != null) {
      if (_useRelativeTimestamp) {
        formattedTime = createRelativeDate(timestamp);
      } else {
        formattedTime = absoluteDateFormat.format(timestamp.toLocal());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var timestamp = widget.timestamp;
    if (timestamp == null) {
      return Container();
    }

    return GestureDetector(
      child: Text(formattedTime),
      onTap: () {
        setState(() {
          if (_useRelativeTimestamp) {
            formattedTime = createRelativeDate(timestamp);
          } else {
            formattedTime = absoluteDateFormat.format(timestamp.toLocal());
          }

          _useRelativeTimestamp = !_useRelativeTimestamp;
        });
      },
    );
  }
}
