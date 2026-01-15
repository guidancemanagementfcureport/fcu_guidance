import 'dart:math';

class PasswordGenerator {
  static String generateSixDigitPassword() {
    final random = Random();
    final password = StringBuffer();

    for (int i = 0; i < 6; i++) {
      password.write(random.nextInt(10));
    }

    return password.toString();
  }
}
