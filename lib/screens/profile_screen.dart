// lib/screens/profile_screen.dart  — 3-D UI rebuild
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t    = RiverColors.of(context);
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          Td3AppBar(
            title: 'Profile',
            subtitle: user?.email ?? 'Guest',
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: t.textPrimary, size: 18),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Avatar tile
                Td3Card(
                  elevation: Td3.elevHigh,
                  accentColor: t.accent,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                t.accent.withValues(alpha: 0.30),
                                t.accent.withValues(alpha: 0.10)
                              ],
                            ),
                            border: Td3.depthBorder(
                              topColor: t.accent.withValues(alpha: 0.4),
                            ),
                            boxShadow: Td3.cardShadow(t.accent,
                                elev: Td3.elevMid),
                          ),
                          child: Center(
                            child: Text(
                              (user?.email?.substring(0, 1) ?? 'G')
                                  .toUpperCase(),
                              style: TextStyle(
                                  color: t.accent,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? 'Guest User',
                                style: TextStyle(
                                    color: t.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? 'Not signed in',
                                style: TextStyle(
                                    color: t.textSecondary,
                                    fontSize: 11),
                              ),
                              const SizedBox(height: 8),
                              Td3Chip(
                                  label: 'VERIFIED USER',
                                  color: t.safe,
                                  icon: Icons.verified_rounded,
                                  fontSize: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Stats
                Row(
                  children: [
                    Expanded(
                      child: Td3StatTile(
                        value: '24',
                        label: 'REPORTS FILED',
                        valueColor: t.accent,
                        icon: Icons.description_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Td3StatTile(
                        value: '7',
                        label: 'ALERTS TRIGGERED',
                        valueColor: t.warning,
                        icon: Icons.notifications_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Sign out
                Td3Button(
                  label: 'Sign Out',
                  icon: Icons.logout_rounded,
                  color: t.danger,
                  onTap: () => auth.signOut(),
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
