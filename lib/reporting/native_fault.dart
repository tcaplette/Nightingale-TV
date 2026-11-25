import 'dart:ffi';
import 'dart:io';

/// The crash-visibility live checks' faults (D7), through libc: a real
/// native crash, and the process killed as Android's low-memory killer
/// does it. Only ever called when adb (or the environment) set the hook.
abstract final class NativeFault {
  static const _sigkill = 9;
  static const _sigsegv = 11;

  static DynamicLibrary get _libc => Platform.isAndroid ? DynamicLibrary.open('libc.so') : DynamicLibrary.process();

  /// `raise(SIGSEGV)`: caught by sentry-native's handler on Android 8+.
  static void segfault() {
    final raise = _libc.lookupFunction<Int32 Function(Int32), int Function(int)>('raise');
    raise(_sigsegv);
  }

  /// `kill(getpid(), SIGKILL)`: no handler runs.
  static void killSelf() {
    final libc = _libc;
    final getpid = libc.lookupFunction<Int32 Function(), int Function()>('getpid');
    final kill = libc.lookupFunction<Int32 Function(Int32, Int32), int Function(int, int)>('kill');
    kill(getpid(), _sigkill);
  }
}
