// lib/widgets/map_menu.dart
import 'package:flutter/material.dart';
import 'dart:ui';

class MapMenu extends StatefulWidget {
  final VoidCallback? onAddBeach;
  final VoidCallback? onFilterBeaches;
  final VoidCallback? onCenterLocation;
  final VoidCallback? onToggleLabels;
  final VoidCallback? onToggleClusters;

  const MapMenu({
    super.key,
    this.onAddBeach,
    this.onFilterBeaches,
    this.onCenterLocation,
    this.onToggleLabels,
    this.onToggleClusters,
  });

  @override
  State<MapMenu> createState() => _MapMenuState();
}

class _MapMenuState extends State<MapMenu> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).padding.top + 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Menu Items
          AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              return SizeTransition(
                sizeFactor: _expandAnimation,
                axisAlignment: -1.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (widget.onAddBeach != null)
                      _buildMenuItem(
                        icon: Icons.add_location_alt,
                        label: 'Add Beach',
                        onTap: () {
                          widget.onAddBeach?.call();
                          _toggleMenu();
                        },
                      ),
                    if (widget.onFilterBeaches != null)
                      _buildMenuItem(
                        icon: Icons.filter_list,
                        label: 'Filter Beaches',
                        onTap: () {
                          widget.onFilterBeaches?.call();
                          _toggleMenu();
                        },
                      ),
                    if (widget.onCenterLocation != null)
                      _buildMenuItem(
                        icon: Icons.my_location,
                        label: 'Center Location',
                        onTap: () {
                          widget.onCenterLocation?.call();
                          _toggleMenu();
                        },
                      ),
                    if (widget.onToggleLabels != null)
                      _buildMenuItem(
                        icon: Icons.label,
                        label: 'Toggle Labels',
                        onTap: () {
                          widget.onToggleLabels?.call();
                          _toggleMenu();
                        },
                      ),
                    if (widget.onToggleClusters != null)
                      _buildMenuItem(
                        icon: Icons.bubble_chart,
                        label: 'Toggle Clusters',
                        onTap: () {
                          widget.onToggleClusters?.call();
                          _toggleMenu();
                        },
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),

          // Main Toggle Button
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: _toggleMenu,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: AnimatedRotation(
                        duration: const Duration(milliseconds: 300),
                        turns: _isExpanded ? 0.125 : 0,
                        child: Icon(
                          _isExpanded ? Icons.close : Icons.menu,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}