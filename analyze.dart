import 'dart:io';

void main() async {
  final result = await Process.run('flutter.bat', ['analyze']);
  print(result.stdout);
  print(result.stderr);
}
