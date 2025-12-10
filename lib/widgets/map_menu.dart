// lib/widgets/map_menu.dart
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:mybeachbook/services/notification_service.dart';

class MapMenu extends StatefulWidget {
  final VoidCallback? onAddBeach;
  final VoidCallback? onCenterLocation;
  final VoidCallback? onToggleMarkers;
  final VoidCallback? onHeatmapLayer;
  final VoidCallback? onClearHeatmap;
  final VoidCallback? onMapStyle;
  final VoidCallback? onSettings;
  final VoidCallback? onModeration;
  final bool showMarkers;
  final bool hasActiveHeatmap;

  const MapMenu({
    super.key,
    this.onAddBeach,
    this.onCenterLocation,
    this.onToggleMarkers,
    this.onHeatmapLayer,
    this.onClearHeatmap,
    this.onMapStyle,
    this.onSettings,
    this.onModeration,
    this.showMarkers = true,
    this.hasActiveHeatmap = false,
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
      top: MediaQuery.of(context).padding.top + 80,
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
                    if (widget.onCenterLocation != null)
                      _buildMenuItem(
                        icon: Icons.my_location,
                        label: 'My Location',
                        onTap: () {
                          widget.onCenterLocation?.call();
                          _toggleMenu();
                        },
                      ),
                    if (widget.onToggleMarkers != null)
                      _buildMenuItem(
                        icon: Icons.location_pin,
                        label: widget.showMarkers ? 'Hide Markers' : 'Show Markers',
                        iconColor: widget.showMarkers ? Colors.green : Colors.white,
                        onTap: () {
                          widget.onToggleMarkers?.call();
                          _toggleMenu();
                        },
                      ),
                    if (widget.onHeatmapLayer != null)
                      _buildMenuItem(
                        icon: Icons.layers,
                        label: 'Heatmap Layer',
                        iconColor: widget.hasActiveHeatmap ? Colors.green : Colors.white,
                        onTap: () {
                          widget.onHeatmapLayer?.call();
                          _toggleMenu();
                        },
                      ),
                    if (widget.onClearHeatmap != null && widget.hasActiveHeatmap)
                      _buildMenuItem(
                        icon: Icons.layers_clear,
                        label: 'Clear Heatmap',
                        onTap: () {
                          widget.onClearHeatmap?.call();
                          _toggleMenu();
                        },
                      ),
                    if (widget.onMapStyle != null)
                      _buildMenuItem(
                        icon: Icons.map,
                        label: 'Map Style',
                        onTap: () {
                          widget.onMapStyle?.call();
                          _toggleMenu();
                        },
                      ),
                    if (widget.onModeration != null)
                      _buildMenuItemWithBadge(
                        icon: Icons.notifications,
                        label: 'Moderation',
                        onTap: () {
                          widget.onModeration?.call();
                          _toggleMenu();
                        },
                      ),
                    if (widget.onSettings != null)
                      _buildMenuItem(
                        icon: Icons.more_vert,
                        label: 'Menu',
                        onTap: () {
                          widget.onSettings?.call();
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
                      child: Icon(
                        _isExpanded ? Icons.keyboard_arrow_up : Icons.menu,
                        color: Colors.white,
                        size: 24,
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
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
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
                        color: iconColor ?? Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 16,
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

  Widget _buildMenuItemWithBadge({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Consumer<NotificationService>(
      builder: (context, notificationService, child) {
        final count = notificationService.totalPendingCount;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
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
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                icon,
                                color: Colors.white,
                                size: 24,
                              ),
                              if (count > 0)
                                Positioned(
                                  right: -8,
                                  top: -8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 18,
                                      minHeight: 18,
                                    ),
                                    child: Text(
                                      count > 99 ? '99+' : count.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Text(
                            label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontSize: 16,
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
      },
    );
  }
}