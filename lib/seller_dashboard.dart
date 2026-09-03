import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:proto_app/screens/seller_home_page.dart';
import 'package:proto_app/screens/seller_upload_product_page.dart';
import 'package:proto_app/screens/seller_analytics_page.dart';
import 'package:proto_app/screens/seller_insights.dart';

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({
    super.key,
  });

  @override
  State<SellerDashboard> createState() =>
      _SellerDashboardState();
}

class _SellerDashboardState
    extends State<SellerDashboard> {

  // =========================================================
  // THEME
  // =========================================================

  static const Color orange =
      Color(0xFFE4862D);

  static const Color deepOrange =
      Color(0xFFD66A16);

  static const Color navy =
      Color(0xFF172033);

  // =========================================================
  // CURRENT TAB
  // =========================================================

  int _currentIndex = 0;

  // =========================================================
  // PAGES
  // =========================================================

  final List<Widget> _pages = const [
    SellerHomePage(),
    SellerUploadProductPage(),
    SellerAnalyticsPage(),
    SellerInsights(),
  ];

  final List<String> _titles = const [
    'Home',
    'Upload Product',
    'Analytics',
    'AI Growth',
  ];

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/splash',
      (route) => false,
    );
  }

  // =========================================================
  // CHANGE TAB
  // =========================================================

  void _changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // =========================================================
  // DRAWER ITEM
  // =========================================================

  Widget _buildDrawerItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String title,
    required String subtitle,
  }) {
    final bool selected =
        _currentIndex == index;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 3,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(17),
          onTap: () {
            Navigator.of(context).pop();

            setState(() {
              _currentIndex = index;
            });
          },
          child: AnimatedContainer(
            duration:
                const Duration(
              milliseconds: 180,
            ),
            padding:
                const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 12,
            ),
            decoration:
                BoxDecoration(
              color: selected
                  ? const Color(
                      0xFFFFF1E3,
                    )
                  : Colors.transparent,
              borderRadius:
                  BorderRadius.circular(
                17,
              ),
            ),
            child: Row(
              children: [

                // =================================================
                // ICON
                // =================================================

                Container(
                  width: 43,
                  height: 43,
                  decoration:
                      BoxDecoration(
                    color: selected
                        ? orange.withOpacity(
                            0.14,
                          )
                        : const Color(
                            0xFFF6F3EF,
                          ),
                    borderRadius:
                        BorderRadius.circular(
                      13,
                    ),
                  ),
                  child: Icon(
                    selected
                        ? selectedIcon
                        : icon,
                    color: selected
                        ? deepOrange
                        : const Color(
                            0xFF707070,
                          ),
                    size: 22,
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                // =================================================
                // TEXT
                // =================================================

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [

                      Text(
                        title,
                        style:
                            TextStyle(
                          fontSize: 14,
                          fontWeight:
                              selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                          color: selected
                              ? navy
                              : const Color(
                                  0xFF454545,
                                ),
                        ),
                      ),

                      const SizedBox(
                        height: 2,
                      ),

                      Text(
                        subtitle,
                        style:
                            const TextStyle(
                          fontSize: 10,
                          color:
                              Color(
                            0xFF999999,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (selected)
                  const Icon(
                    Icons
                        .arrow_forward_ios_rounded,
                    size: 13,
                    color:
                        deepOrange,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // DRAWER
  // =========================================================

  Widget _buildDrawer() {
    return Drawer(
      width: 310,
      backgroundColor:
          const Color(0xFFFFFCF8),
      child: SafeArea(
        child: Column(
          children: [

            // =====================================================
            // DRAWER HEADER
            // =====================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                18,
                18,
                18,
              ),
              child: Row(
                children: [

                  Container(
                    width: 50,
                    height: 50,
                    decoration:
                        BoxDecoration(
                      gradient:
                          const LinearGradient(
                        begin:
                            Alignment.topLeft,
                        end:
                            Alignment.bottomRight,
                        colors: [
                          Color(
                            0xFFFFE4BF,
                          ),
                          Color(
                            0xFFFFD19B,
                          ),
                        ],
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),
                    child:
                        const Icon(
                      Icons
                          .storefront_rounded,
                      color:
                          deepOrange,
                      size: 26,
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [

                        Text(
                          "Karigari",
                          style:
                              TextStyle(
                            fontSize: 19,
                            fontWeight:
                                FontWeight
                                    .w800,
                            color:
                                navy,
                          ),
                        ),

                        SizedBox(
                          height: 2,
                        ),

                        Text(
                          "Seller workspace",
                          style:
                              TextStyle(
                            fontSize: 11,
                            color:
                                Color(
                              0xFF858585,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pop();
                    },
                    icon:
                        const Icon(
                      Icons
                          .close_rounded,
                      size: 21,
                      color:
                          Color(0xFF555555),
                    ),
                  ),
                ],
              ),
            ),

            // =====================================================
            // DIVIDER
            // =====================================================

            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              child: Divider(
                height: 1,
                color:
                    const Color(
                  0xFFECE5DD,
                ),
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // =====================================================
            // NAVIGATION LABEL
            // =====================================================

            const Padding(
              padding:
                  EdgeInsets.symmetric(
                horizontal: 25,
              ),
              child: Align(
                alignment:
                    Alignment.centerLeft,
                child: Text(
                  "WORKSPACE",
                  style:
                      TextStyle(
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing:
                        1.1,
                    color:
                        Color(0xFFA19A92),
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            // =====================================================
            // HOME
            // =====================================================

            _buildDrawerItem(
              index: 0,
              icon:
                  Icons.dashboard_outlined,
              selectedIcon:
                  Icons.dashboard_rounded,
              title: "Home",
              subtitle:
                  "Shop overview",
            ),

            // =====================================================
            // UPLOAD
            // =====================================================

            _buildDrawerItem(
              index: 1,
              icon:
                  Icons.add_box_outlined,
              selectedIcon:
                  Icons.add_box_rounded,
              title: "Upload",
              subtitle:
                  "Add a new product",
            ),

            // =====================================================
            // ANALYTICS
            // =====================================================

            _buildDrawerItem(
              index: 2,
              icon:
                  Icons.analytics_outlined,
              selectedIcon:
                  Icons.analytics_rounded,
              title: "Analytics",
              subtitle:
                  "Sales performance",
            ),

            // =====================================================
            // AI GROWTH
            // =====================================================

            _buildDrawerItem(
              index: 3,
              icon:
                  Icons.auto_awesome_outlined,
              selectedIcon:
                  Icons.auto_awesome_rounded,
              title: "AI Growth",
              subtitle:
                  "Insights & actions",
            ),

            const Spacer(),

            // =====================================================
            // LOGOUT
            // =====================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                10,
                20,
                20,
              ),
              child: Material(
                color:
                    const Color(
                  0xFFFFF3EA,
                ),
                borderRadius:
                    BorderRadius.circular(
                  17,
                ),
                child: InkWell(
                  borderRadius:
                      BorderRadius.circular(
                    17,
                  ),
                  onTap: _logout,
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      13,
                    ),
                    child: Row(
                      children: [

                        Container(
                          width: 40,
                          height: 40,
                          decoration:
                              BoxDecoration(
                            color:
                                const Color(
                              0xFFFFE2D0,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                          ),
                          child:
                              const Icon(
                            Icons
                                .logout_rounded,
                            size: 20,
                            color:
                                deepOrange,
                          ),
                        ),

                        const SizedBox(
                          width: 11,
                        ),

                        const Expanded(
                          child: Text(
                            "Log out",
                            style:
                                TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  FontWeight
                                      .w700,
                              color:
                                  navy,
                            ),
                          ),
                        ),

                        const Icon(
                          Icons
                              .arrow_forward_ios_rounded,
                          size: 13,
                          color:
                              Color(
                            0xFF999999,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return AnnotatedRegion<
        SystemUiOverlayStyle>(
      value:
          const SystemUiOverlayStyle(
        statusBarColor:
            orange,
        statusBarIconBrightness:
            Brightness.light,
        systemNavigationBarColor:
            Color(0xFFF8F5F0),
        systemNavigationBarIconBrightness:
            Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor:
            const Color(0xFFF8F5F0),

        // =====================================================
        // LEFT DRAWER
        // =====================================================

        drawer:
            _buildDrawer(),

        // =====================================================
        // APP BAR
        // =====================================================

        appBar: AppBar(
          toolbarHeight: 72,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor:
              orange,
          foregroundColor:
              Colors.white,

          // ===================================================
          // HAMBURGER
          // ===================================================

          leading: Builder(
            builder: (context) {
              return IconButton(
                tooltip:
                    "Open navigation",
                icon:
                    const Icon(
                  Icons
                      .menu_rounded,
                  size: 29,
                ),
                onPressed: () {
                  Scaffold.of(
                    context,
                  ).openDrawer();
                },
              );
            },
          ),

          // ===================================================
          // TITLE
          // ===================================================

          title: Text(
            _titles[
                _currentIndex],
            style:
                const TextStyle(
              color:
                  Colors.white,
              fontSize: 21,
              fontWeight:
                  FontWeight.w800,
              letterSpacing:
                  -0.3,
            ),
          ),

          // ===================================================
          // LOGOUT
          // ===================================================

          actions: [
            IconButton(
              tooltip:
                  "Log out",
              icon:
                  const Icon(
                Icons
                    .logout_rounded,
                color:
                    Colors.white,
                size: 25,
              ),
              onPressed:
                  _logout,
            ),

            const SizedBox(
              width: 5,
            ),
          ],
        ),

        // =====================================================
        // PAGES
        // =====================================================

        body: IndexedStack(
          index:
              _currentIndex,
          children:
              _pages,
        ),

        // =====================================================
        // BOTTOM NAVIGATION
        // =====================================================

        bottomNavigationBar:
            NavigationBar(
          height: 76,
          backgroundColor:
              const Color(
            0xFFFFFDFC,
          ),
          surfaceTintColor:
              Colors.transparent,
          indicatorColor:
              const Color(
            0xFFFFE8CF,
          ),
          selectedIndex:
              _currentIndex,

          onDestinationSelected:
              _changeTab,

          labelBehavior:
              NavigationDestinationLabelBehavior
                  .alwaysShow,

          destinations: const [

            NavigationDestination(
              icon: Icon(
                Icons
                    .dashboard_outlined,
              ),
              selectedIcon:
                  Icon(
                Icons
                    .dashboard_rounded,
              ),
              label: "Home",
            ),

            NavigationDestination(
              icon: Icon(
                Icons
                    .add_box_outlined,
              ),
              selectedIcon:
                  Icon(
                Icons
                    .add_box_rounded,
              ),
              label: "Upload",
            ),

            NavigationDestination(
              icon: Icon(
                Icons
                    .analytics_outlined,
              ),
              selectedIcon:
                  Icon(
                Icons
                    .analytics_rounded,
              ),
              label: "Analytics",
            ),

            NavigationDestination(
              icon: Icon(
                Icons
                    .auto_awesome_outlined,
              ),
              selectedIcon:
                  Icon(
                Icons
                    .auto_awesome_rounded,
              ),
              label: "AI Growth",
            ),
          ],
        ),
      ),
    );
  }
}