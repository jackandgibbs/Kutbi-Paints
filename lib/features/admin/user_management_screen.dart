import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/constants/app_colors.dart';
import '../../services/data_service.dart';
import '../../core/widgets/lottie_loading_widget.dart';
import '../../core/utils/responsive.dart';
import '../../models/user_model.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  String _filterQuery = '';
  String _sortBy = 'name'; // 'name' or 'date'

  String _capitalize(String name) {
    return name.split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');
  }

  void _clearSelection() {
    if (_selectedIds.isEmpty && !_isSelectionMode) return;
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging) {
        _clearSelection();
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);

    final pending = ds.getPaintersByStatus('inactive');
    final active = ds.getPaintersByStatus('active');
    final suspended = ds.getPaintersByStatus('suspended');
    final admins = ds.getAdmins();

    List filterUsers(List users) {
      var result = users.toList();
      if (_filterQuery.isNotEmpty) {
        final q = _filterQuery.toLowerCase();
        result = result.where((u) => u.name.toLowerCase().contains(q) || (u.businessName?.toLowerCase().contains(q) ?? false)).toList();
      }
      if (_sortBy == 'name') {
        result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      } else {
        result.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
      }
      return result;
    }

    final filteredPending = filterUsers(pending);
    final filteredActive = filterUsers(active);
    final filteredSuspended = filterUsers(suspended);
    final filteredAdmins = filterUsers(admins);

    if (!ds.isLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0EDE8),
        body: LottieLoadingWidget(message: 'Loading painters...'),
      );
    }

    // Determine current tab list for "Select All"
    List currentTabUsers = [];
    String currentStatus = 'inactive';
    switch (_tabCtrl.index) {
      case 0:
        currentTabUsers = filteredPending;
        currentStatus = 'inactive';
        break;
      case 1:
        currentTabUsers = filteredActive;
        currentStatus = 'active';
        break;
      case 2:
        currentTabUsers = filteredAdmins;
        currentStatus = 'admin';
        break;
      case 3:
        currentTabUsers = filteredSuspended;
        currentStatus = 'suspended';
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 48),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isSelectionMode
              ? AppBar(
                  key: const ValueKey('selection_appbar'),
                  backgroundColor: AppColors.primary,
                  elevation: 8,
                  leading: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: _clearSelection,
                  ),
                  title: Text(
                    '${_selectedIds.length} Selected',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        _selectedIds.length == currentTabUsers.length
                            ? Icons.deselect_rounded
                            : Icons.select_all_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          if (_selectedIds.length == currentTabUsers.length) {
                            _selectedIds.clear();
                            _isSelectionMode = false;
                          } else {
                            _selectedIds.addAll(
                                currentTabUsers.map((u) => u.id as String));
                          }
                        });
                      },
                      tooltip: 'Select All',
                    ),
                    _buildBulkActionsMenu(currentStatus),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(48),
                    child: _buildSelectionTabPlaceholder(),
                  ),
                )
              : AppBar(
                  key: const ValueKey('normal_appbar'),
                  leading: IconButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/admin');
                      }
                    },
                    icon: const Icon(Icons.arrow_back_ios_rounded),
                  ),
                  title: Text('User Management',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  actions: [
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.sort_rounded),
                      tooltip: 'Sort by',
                      onSelected: (v) => setState(() => _sortBy = v),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'name', child: Row(children: [
                          Icon(Icons.check, size: 18, color: _sortBy == 'name' ? AppColors.primary : Colors.transparent),
                          const SizedBox(width: 8),
                          const Text('Name'),
                        ])),
                        PopupMenuItem(value: 'date', child: Row(children: [
                          Icon(Icons.check, size: 18, color: _sortBy == 'date' ? AppColors.primary : Colors.transparent),
                          const SizedBox(width: 8),
                          const Text('Date'),
                        ])),
                      ],
                    ),
                    IconButton(
                      onPressed: () => _showFilterDialog(),
                      icon: Icon(_filterQuery.isEmpty ? Icons.search_rounded : Icons.search_off_rounded),
                      tooltip: 'Search',
                    ),
                    IconButton(
                      onPressed: () => context.push('/admin/add-painter'),
                      icon: const Icon(Icons.person_add_rounded),
                      tooltip: 'Add Painter',
                    ),
                    IconButton(
                      onPressed: () => _showExportDialog(ds),
                      icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.error),
                      tooltip: 'Export PDF',
                    ),
                  ],
                  bottom: TabBar(
                    isScrollable: true,
                    controller: _tabCtrl,
                    tabs: [
                      Tab(text: 'Pending (${pending.length})'),
                      Tab(text: 'Active (${active.length})'),
                      Tab(text: 'Admins (${admins.length})'),
                      Tab(text: 'Suspended (${suspended.length})'),
                    ],
                    labelStyle: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    indicatorColor: AppColors.primary,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                  ),
                ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildUserList(filteredPending, 'inactive'),
              _buildUserList(filteredActive, 'active'),
              _buildUserList(filteredAdmins, 'admin'),
              _buildUserList(filteredSuspended, 'suspended'),
            ],
          ),
        ),
      ),
      floatingActionButton: _isSelectionMode ? null : ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.25),
                  Colors.white.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              onTap: () => context.push('/admin/add-painter'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_add_rounded, color: Colors.black87, size: 20),
                  const SizedBox(width: 8),
                  Text('Add Painter',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, color: Colors.black87)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserList(List users, String status) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No ${status == 'inactive' ? 'pending' : status} users',
                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (ctx, i) {
        final user = users[i];
        final isSelected = _selectedIds.contains(user.id);

        return GestureDetector(
          onLongPress: () {
            setState(() {
              if (!_isSelectionMode) {
                _isSelectionMode = true;
                _selectedIds.add(user.id);
              } else {
                // If already in selection mode, long press toggles or does nothing?
                // Usually long press in selection mode is treated as tap.
                if (isSelected) {
                  _selectedIds.remove(user.id);
                  if (_selectedIds.isEmpty) _isSelectionMode = false;
                } else {
                  _selectedIds.add(user.id);
                }
              }
            });
          },
          onTap: () {
            if (_isSelectionMode) {
              setState(() {
                if (isSelected) {
                  _selectedIds.remove(user.id);
                  if (_selectedIds.isEmpty) _isSelectionMode = false;
                } else {
                  _selectedIds.add(user.id);
                }
              });
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : const Color(0xFFF0EDE8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: isSelected
                              ? const Center(
                                  child: Icon(Icons.check_rounded,
                                      color: Colors.white, size: 24))
                              : (user.profileImageUrl != null &&
                                      user.profileImageUrl!.isNotEmpty)
                                  ? Image.network(
                                      user.profileImageUrl!,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(
                                        child: Text(
                                          user.name.substring(0, 1).toUpperCase(),
                                          style: GoogleFonts.poppins(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        user.name.substring(0, 1).toUpperCase(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                        ),
                      ],
                    ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(_capitalize(user.name),
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ),
                            if (user.tier == 'gold')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.goldTier
                                      .withValues(alpha: 0.2),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        size: 12,
                                        color: AppColors.goldTier),
                                    const SizedBox(width: 2),
                                    Text('GOLD',
                                        style: GoogleFonts.poppins(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFD4A017),
                                        )),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        Text(user.businessName ?? '',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        Text('📞 ${user.phone} • ✉ ${user.email}',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.textLight)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!_isSelectionMode)
                Row(
                  children: [
                    if (status == 'inactive') ...[
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ref
                              .read(dataServiceProvider)
                              .approveUser(user.id, 'painter');
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '${user.name} approved as Painter!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.brush_rounded,
                            color: Colors.white, size: 16),
                        label: Text('Painter',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ref
                              .read(dataServiceProvider)
                              .approveUser(user.id, 'admin');
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '${user.name} promoted to Admin!'),
                              backgroundColor: const Color(0xFF6366F1), // Indigo/Admin color
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.admin_panel_settings_rounded,
                            color: Colors.white, size: 16),
                        label: Text('Admin',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: () {
                          ref
                              .read(dataServiceProvider)
                              .deleteUser(user.id);
                          setState(() {});
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ),
                  ],
                  if (status == 'active') ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.push('/admin/user-activity/${user.id}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side:
                              const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.analytics_rounded,
                            size: 18),
                        label: Text('Activity',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _popupMenu(user, 'active'),
                  ],
                  if (status == 'suspended') ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ref
                              .read(dataServiceProvider)
                              .updateUserStatus(user.id, 'active');
                          setState(() {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.restore_rounded,
                            color: Colors.white, size: 18),
                        label: Text('Reactivate',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        ref
                            .read(dataServiceProvider)
                            .deleteUser(user.id);
                        setState(() {});
                      },
                      icon: const Icon(Icons.delete_rounded,
                          color: AppColors.error),
                    ),
                  ],
                  if (status == 'admin') ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ref
                              .read(dataServiceProvider)
                              .approveUser(user.id, 'painter');
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '${user.name} changed to Painter!'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.person_remove_rounded,
                            color: Colors.white, size: 18),
                        label: Text('Remove Admin',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        ref
                            .read(dataServiceProvider)
                            .deleteUser(user.id);
                        setState(() {});
                      },
                      icon: const Icon(Icons.delete_rounded,
                          color: AppColors.error),
                    ),
                  ],
                ],
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _popupMenu(dynamic user, String currentStatus) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        final ds = ref.read(dataServiceProvider);
        switch (value) {
          case 'admin':
            ds.approveUser(user.id, 'admin');
            break;
          case 'suspend':
            ds.updateUserStatus(user.id, 'suspended');
            break;
          case 'gold':
            ds.updateUserTier(user.id, 'gold');
            break;
          case 'silver':
            ds.updateUserTier(user.id, 'silver');
            break;
          case 'delete':
            ds.deleteUser(user.id);
            break;
        }
        setState(() {});
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'admin',
          child: Row(
            children: [
              const Icon(Icons.admin_panel_settings_rounded,
                  color: Color(0xFF6366F1), size: 18),
              const SizedBox(width: 8),
              Text('Set as Admin', style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF6366F1), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'suspend',
          child: Row(
            children: [
              const Icon(Icons.block_rounded,
                  color: AppColors.warning, size: 18),
              const SizedBox(width: 8),
              Text('Suspend', style: GoogleFonts.poppins(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: user.tier == 'gold' ? 'silver' : 'gold',
          child: Row(
            children: [
              Icon(Icons.star_rounded,
                  color: user.tier == 'gold'
                      ? AppColors.silverTier
                      : AppColors.goldTier,
                  size: 18),
              const SizedBox(width: 8),
              Text(
                  user.tier == 'gold'
                      ? 'Set to Silver'
                      : 'Set to Gold',
                  style: GoogleFonts.poppins(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_rounded,
                  color: AppColors.error, size: 18),
              const SizedBox(width: 8),
              Text('Delete',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionTabPlaceholder() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Text(
        'Tap items to toggle · Long press to exit',
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: Colors.white70,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildBulkActionsMenu(String currentStatus) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
      onSelected: _handleBulkAction,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (ctx) {
        if (currentStatus == 'inactive') {
          return [
            _bulkItem('painter', Icons.brush_rounded, 'Approve as Painters', AppColors.success),
            _bulkItem('admin', Icons.admin_panel_settings_rounded, 'Approve as Admins', const Color(0xFF6366F1)),
          ];
        } else if (currentStatus == 'active') {
          return [
            _bulkItem('admin', Icons.admin_panel_settings_rounded, 'Set as Admins', const Color(0xFF6366F1)),
            _bulkItem('suspend', Icons.block_rounded, 'Suspend Selected', AppColors.warning),
            _bulkItem('gold', Icons.star_rounded, 'Set to Gold', AppColors.goldTier),
            _bulkItem('silver', Icons.star_border_rounded, 'Set to Silver', AppColors.silverTier),
            const PopupMenuDivider(),
            _bulkItem('delete', Icons.delete_rounded, 'Delete Selected', AppColors.error),
          ];
        } else if (currentStatus == 'suspended') {
          return [
            _bulkItem('active', Icons.restore_rounded, 'Reactivate All', AppColors.success),
            _bulkItem('delete', Icons.delete_rounded, 'Delete Permanently', AppColors.error),
          ];
        } else if (currentStatus == 'admin') {
          return [
            _bulkItem('painter', Icons.person_remove_rounded, 'Remove Admins', AppColors.warning),
            _bulkItem('delete', Icons.delete_rounded, 'Delete Selected', AppColors.error),
          ];
        }
        return [];
      },
    );
  }

  PopupMenuItem<String> _bulkItem(String value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _handleBulkAction(String action) async {
    final ds = ref.read(dataServiceProvider);
    final count = _selectedIds.length;
    
    // Confirmation for destructive actions
    if (['delete', 'suspend', 'painter'].contains(action)) {
      final confirmed = await _showConfirmDialog(action, count);
      if (!confirmed || !mounted) return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Processing $count users...'), duration: const Duration(seconds: 1)),
    );

    final ids = List<String>.from(_selectedIds);
    _clearSelection();

    try {
      for (final id in ids) {
        switch (action) {
          case 'painter':
            await ds.approveUser(id, 'painter');
            break;
          case 'admin':
            await ds.approveUser(id, 'admin');
            break;
          case 'active':
            await ds.updateUserStatus(id, 'active');
            break;
          case 'suspend':
            await ds.updateUserStatus(id, 'suspended');
            break;
          case 'gold':
            await ds.updateUserTier(id, 'gold');
            break;
          case 'silver':
            await ds.updateUserTier(id, 'silver');
            break;
          case 'delete':
            await ds.deleteUser(id);
            break;
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully processed $count users'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during bulk action: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<bool> _showConfirmDialog(String action, int count) async {
    String title = 'Confirm Action';
    String message = 'Are you sure you want to perform this action on $count users?';
    
    if (action == 'delete') {
      title = 'Delete Users';
      message = 'This will permanently delete $count users. This action cannot be undone.';
    } else if (action == 'suspend') {
      title = 'Suspend Users';
      message = 'Suspend $count users? They will lose access to the app.';
    } else if (action == 'painter' && _tabCtrl.index == 2) { // Removing admins
      title = 'Remove Admin Rights';
      message = 'Convert $count admins back to regular painters?';
    }

    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(message, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'delete' ? AppColors.error : AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(action == 'delete' ? 'Delete' : 'Confirm', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showExportDialog(DataService ds) {
    final selected = <String>{'active', 'inactive'};
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Export Users', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(title: const Text('Pending'), value: selected.contains('inactive'), onChanged: (v) => setState(() => v! ? selected.add('inactive') : selected.remove('inactive'))),
              CheckboxListTile(title: const Text('Active'), value: selected.contains('active'), onChanged: (v) => setState(() => v! ? selected.add('active') : selected.remove('active'))),
              CheckboxListTile(title: const Text('Suspended'), value: selected.contains('suspended'), onChanged: (v) => setState(() => v! ? selected.add('suspended') : selected.remove('suspended'))),
              CheckboxListTile(title: const Text('Admins'), value: selected.contains('admin'), onChanged: (v) => setState(() => v! ? selected.add('admin') : selected.remove('admin'))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selected.isEmpty ? null : () {
                Navigator.pop(ctx);
                _exportUsersPDF(ds, selected.toList());
              },
              child: const Text('Export'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportUsersPDF(DataService ds, List<String> statuses) async {
    final users = <UserModel>[];
    for (final s in statuses) {
      if (s == 'admin') {
        users.addAll(ds.getAdmins());
      } else {
        users.addAll(ds.getPaintersByStatus(s));
      }
    }
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text('Users Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Statuses: ${statuses.join(", ")}'),
          pw.Text('Generated: ${DateTime.now().toString().substring(0, 16)}'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Name', 'Phone', 'Status', 'Points'],
            data: users.map((u) => [u.name, u.phone, u.status, u.points.toString()]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  void _showFilterDialog() {
    final controller = TextEditingController(text: _filterQuery);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Filter Users', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search by name...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () => controller.clear(),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _filterQuery = '');
            },
            child: Text('Clear', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _filterQuery = controller.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Apply', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
