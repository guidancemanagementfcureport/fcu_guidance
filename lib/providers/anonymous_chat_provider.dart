import 'package:flutter/material.dart';

class AnonymousChatProvider with ChangeNotifier {
  String? _caseCode;
  String? _reportId;
  bool _isOpen = false;

  String? get caseCode => _caseCode;
  String? get reportId => _reportId;
  bool get isOpen => _isOpen;

  void toggleChat({bool? open}) {
    _isOpen = open ?? !_isOpen;
    notifyListeners();
  }

  void setChat(String caseCode, String reportId) {
    _caseCode = caseCode;
    _reportId = reportId;
    _isOpen = true;
    notifyListeners();
  }

  void clearChat() {
    _caseCode = null;
    _reportId = null;
    notifyListeners();
  }
}
