import 'package:flutter/material.dart';

class MenuItem {
  final String title;
  final IconData icon;
  final String route;
  final String? section; // Optional section grouping

  const MenuItem({
    required this.title,
    required this.icon,
    required this.route,
    this.section,
  });
}
