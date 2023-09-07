import 'package:flutter_dotenv/flutter_dotenv.dart';

class Constants {
  static String githubURL = "https://github.com/arfento";

  static String? recognize = dotenv.env['URL_RECOGNIZE'];
}
