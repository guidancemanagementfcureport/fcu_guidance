import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_sidebar.dart';
import 'package:go_router/go_router.dart';

class PlaceholderPage extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const PlaceholderPage({
    super.key,
    required this.title,
    this.description = 'This page will be implemented soon.',
    this.icon = Icons.construction_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;

    return ResponsiveSidebar(
      currentRoute: currentRoute,
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            child: Container(decoration: AppTheme.appBarGradientDecoration),
          ),
          shape: AppTheme.appBarShape,
          title: Text(title),
          leading:
              MediaQuery.of(context).size.width < 768
                  ? IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => ResponsiveSidebar.openDrawer(context),
                  )
                  : null,
        ),
        body: Container(
          decoration: AppTheme.softBlueGradientDecoration,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 80, color: AppTheme.mediumGray),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkGray,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppTheme.mediumGray,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
