// ignore_for_file: avoid_print
//
// Installs an APK built with --dart-define=QUAX_MOCK_X=http://localhost:<port> on the running emulator,
// serves the mock of X on that port, then runs each Maestro flow against it, recording one video per flow.
// Fails when a flow fails or the mock of X answered nothing.
//
//   fvm dart run tool/mock_x/emulator_qa.dart <apk> <flows folder or .yaml file> <output dir> [--port 8787]

import 'dart:io';

import 'app_preferences.dart';
import 'fixture_map.dart';
import 'mock_server.dart';
import 'video_cut.dart';

const _usage =
    'Usage: dart run tool/mock_x/emulator_qa.dart <apk> <flows folder or .yaml file> <output dir> '
    '[--port 8787]';

Future<void> main(List<String> args) async {
  final (positional, port) = _parseArgs(args);
  if (positional.length != 3 || port == null) {
    stderr.writeln(_usage);
    exit(64);
  }
  final [apk, flowsPath, outPath] = positional;
  final flows = _flows(flowsPath);
  final out = await Directory(outPath).create(recursive: true);
  final log = File('${out.path}/mock_x.log').openWrite();
  final answers = <MockAnswer>[];
  final server = await serveFixtures(
    FixtureMap.load(Directory('test/fixtures')),
    port: port,
    onAnswer: (uri, answer) {
      answers.add(answer);
      log.writeln('${answer.status} ${uri.path}');
      if (!answer.matched) log.writeln(answer.body);
    },
  );

  await _prepareDevice(apk, await _packageName(apk), port);
  // Maestro would pick the first device on its own, whichever adb serves
  final device = (await _run('adb', ['get-serialno'])).trim();
  final failedFlows = [
    for (final flow in flows)
      if (!await _runFlow(flow, device, out)) flow.path,
  ];
  await File('${out.path}/logcat.txt').writeAsString(await _run('adb', ['logcat', '-d'], quiet: true));
  await server.close(force: true);
  await log.close();
  exit(_report(failedFlows, answers) ? 0 : 1);
}

/// The positional arguments, and the port of --port, 8787 by default, or null when it is not a number.
(List<String>, int?) _parseArgs(List<String> args) {
  final portIndex = args.indexOf('--port');
  if (portIndex < 0) return (args, 8787);
  final port = portIndex + 1 < args.length ? int.tryParse(args[portIndex + 1]) : null;
  return ([...args.take(portIndex), ...args.skip(portIndex + 2)], port);
}

/// The flow [path] names, or the flows of the folder it names, in the order Maestro would run them.
List<File> _flows(String path) {
  if (FileSystemEntity.isFileSync(path) && path.endsWith('.yaml')) return [File(path)];
  if (!FileSystemEntity.isDirectorySync(path)) _fail('$path is neither a folder nor a .yaml flow');
  final flows = Directory(path).listSync().whereType<File>().where((f) => f.path.endsWith('.yaml')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  if (flows.isEmpty) _fail('$path holds no .yaml flow');
  return flows;
}

Future<String> _packageName(String apk) async {
  String sortable(String path) => path.split('/').last.split('.').map((part) => part.padLeft(6, '0')).join('.');
  final buildTools = Directory(
    '${Platform.environment['ANDROID_HOME']}/build-tools',
  ).listSync().map((dir) => dir.path).toList()..sort((a, b) => sortable(a).compareTo(sortable(b)));
  return (await _run('${buildTools.last}/aapt2', ['dump', 'packagename', apk])).trim();
}

/// Installs the app afresh, past its onboarding, makes x.com links open it rather than the browser, keeps the
/// system dialogs an overloaded emulator shows about slow apps from covering it, and turns on the dark theme.
Future<void> _prepareDevice(String apk, String package, int port) async {
  await _run('adb', ['wait-for-device']);
  await _run('adb', ['shell', 'settings', 'put', 'global', 'hide_error_dialogs', '1']);
  await _run('adb', ['reverse', 'tcp:$port', 'tcp:$port']);
  await _run('adb', ['install', '-r', apk]);
  // Every run starts from a fresh app, whatever an earlier one left
  await _run('adb', ['shell', 'pm', 'clear', package]);
  await _writePreferences(package);
  await _run('adb', [
    'shell',
    'pm',
    'set-app-links-user-selection',
    '--user',
    '0',
    '--package',
    package,
    'true',
    'x.com',
  ]);
  await _run('adb', ['shell', 'cmd', 'uimode', 'night', 'yes']);
  await _run('adb', ['logcat', '-c']);
}

Future<void> _writePreferences(String package) async {
  final local = File('${(await Directory.systemTemp.createTemp('quax_prefs')).path}/prefs.xml');
  await local.writeAsString(sharedPreferencesXml(emulatorPreferences));
  await _run('adb', ['push', local.path, '/data/local/tmp/quax_prefs.xml']);
  await _run('adb', [
    'shell',
    "cat /data/local/tmp/quax_prefs.xml | run-as $package sh -c "
        "'mkdir -p shared_prefs && cat > shared_prefs/FlutterSharedPreferences.xml'",
  ]);
}

/// Runs [flow] while recording the screen to the output folder, one video per flow, and tells whether it passed.
Future<bool> _runFlow(File flow, String device, Directory out) async {
  final name = flow.uri.pathSegments.last.replaceAll(RegExp(r'\.yaml$'), '');
  final onDevice = '/sdcard/$name.mp4';
  // Closes an "isn't responding" dialog shown before hide_error_dialogs took effect
  await _run('adb', ['shell', 'am', 'broadcast', '-a', 'android.intent.action.CLOSE_SYSTEM_DIALOGS']);
  final recorder = await Process.start('adb', ['shell', 'screenrecord', '--bit-rate', '8000000', onDevice]);
  await Future<void>.delayed(const Duration(seconds: 1));
  final maestro = await Process.start('maestro', [
    '--device',
    device,
    'test',
    '--debug-output',
    '${out.path}/maestro/$name',
    flow.path,
  ], mode: ProcessStartMode.inheritStdio);
  final passed = await maestro.exitCode == 0;
  await Process.run('adb', ['shell', 'pkill', '-INT', 'screenrecord']);
  await recorder.exitCode;
  final video = '${out.path}/$name.mp4';
  final pulled = await Process.run('adb', ['pull', onDevice, video]);
  if (pulled.exitCode == 0) {
    await _cutStart(video);
  } else {
    print('::warning::No video of $name: ${pulled.stderr}');
  }
  return passed;
}

/// Cuts the still screen shown while Maestro starts.
Future<void> _cutStart(String video) async {
  if (!await _hasFfmpeg()) {
    print("::warning::ffmpeg is missing, the videos keep Maestro's start-up");
    return;
  }
  final freezes = await Process.run('ffmpeg', ['-i', video, '-vf', freezeFilter, '-f', 'null', '-']);
  final cut = cutPoint('${freezes.stderr}');
  if (cut == null) return;
  final trimmed = '$video.trimmed.mp4';
  await _run('ffmpeg', [
    ...['-v', 'error', '-y', '-ss', '${cut.inMicroseconds / Duration.microsecondsPerSecond}', '-i', video],
    ...['-c:v', 'libx264', '-preset', 'veryfast', '-crf', '23', '-pix_fmt', 'yuv420p', trimmed],
  ]);
  await File(trimmed).rename(video);
}

Future<bool> _hasFfmpeg() =>
    Process.run('ffmpeg', ['-version']).then((result) => result.exitCode == 0, onError: (_) => false);

/// Prints the outcome, as GitHub Actions annotations, and tells whether the run passed.
bool _report(List<String> failedFlows, List<MockAnswer> answers) {
  final served = answers.where((a) => a.status == 200).length;
  final unanswered = answers.where((a) => a.status == 501).length;
  print('The mock of X answered $served request(s) and could not answer $unanswered');
  if (unanswered > 0) print('::warning::The mock of X could not answer $unanswered request(s), see mock_x.log');
  if (served == 0) print('::error::The mock of X answered no request, the app did not reach it');
  for (final flow in failedFlows) {
    print('::error::$flow failed');
  }
  return failedFlows.isEmpty && served > 0;
}

/// Runs [executable] and returns its output, or exits when it fails.
Future<String> _run(String executable, List<String> args, {bool quiet = false}) async {
  if (!quiet) print('\$ $executable ${args.join(' ')}');
  final result = await Process.run(executable, args);
  if (result.exitCode != 0) _fail('$executable ${args.join(' ')} exited with ${result.exitCode}\n${result.stderr}');
  return '${result.stdout}';
}

Never _fail(String message) {
  print('::error::$message');
  exit(1);
}
