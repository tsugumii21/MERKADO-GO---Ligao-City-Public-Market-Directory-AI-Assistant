import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../map/domain/navigation_models.dart';
import '../../map/providers/entrance_provider.dart';
import 'widgets/admin_edit_entrance_sheet.dart';

/// Administrative screen for inspecting and updating photos and details for all market entrances.
class AdminManageEntrancesScreen extends ConsumerStatefulWidget {
  const AdminManageEntrancesScreen({super.key});

  @override
  ConsumerState<AdminManageEntrancesScreen> createState() =>
      _AdminManageEntrancesScreenState();
}

class _AdminManageEntrancesScreenState
    extends ConsumerState<AdminManageEntrancesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entrances = ref.watch(marketEntrancesProvider);

    final filteredEntrances = entrances.where((entry) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final idMatch = 'gate ${entry.entranceId}'.contains(query) ||
          entry.entranceId.toString() == query;
      final descMatch = entry.effectiveDescription.toLowerCase().contains(query);
      final landmarkMatch = entry.effectiveLandmark.toLowerCase().contains(query);
      final titleMatch = entry.displayName.toLowerCase().contains(query);
      final nodeMatch = entry.nodeId.toLowerCase().contains(query);
      return idMatch || descMatch || landmarkMatch || titleMatch || nodeMatch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Manage Entrances',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFFE2E8F0),
            height: 1.0,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by gate number, church, LCC, street...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                size: 18, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '${filteredEntrances.length} ENTRANCES',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Tap card to edit photo or details',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Gate Cards List
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF1B5E20),
              backgroundColor: Colors.white,
              onRefresh: () async {
                await HapticFeedback.lightImpact();
                ref.invalidate(firestoreEntrancesStreamProvider);
                ref.invalidate(marketEntrancesProvider);
                await Future.delayed(const Duration(milliseconds: 400));
              },
              child: filteredEntrances.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.55,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: Color(0xFFCBD5E1),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No entrances found',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try searching with a different keyword',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      itemCount: filteredEntrances.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final entrance = filteredEntrances[index];
                        return _buildEntranceCard(context, entrance);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _openEditSheet(BuildContext context, MarketEntryPoint entrance) {
    HapticFeedback.selectionClick();
    AdminEditEntranceSheet.show(
      context,
      entrance,
      onSaved: () {
        ref.invalidate(firestoreEntrancesStreamProvider);
        ref.invalidate(marketEntrancesProvider);
      },
    );
  }

  Widget _buildEntranceCard(BuildContext context, MarketEntryPoint entrance) {
    final hasCustomImage = entrance.imageUrl != null &&
        entrance.imageUrl!.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openEditSheet(context, entrance),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Thumbnail Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 68,
                    height: 68,
                    color: const Color(0xFFF1F5F9),
                    child: hasCustomImage
                        ? CachedNetworkImage(
                            imageUrl: entrance.imageUrl!.trim(),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF2E7D32)),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) =>
                                _buildCardPlaceholder(entrance),
                          )
                        : _buildCardPlaceholder(entrance),
                  ),
                ),

                const SizedBox(width: 14),

                // Details Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (context) {
                          final hasCustomTitle = entrance.title != null &&
                              entrance.title!.trim().isNotEmpty &&
                              entrance.title!.trim().toLowerCase() !=
                                  'gate ${entrance.entranceId}';

                          final hasDistinctDescription = entrance
                                  .effectiveDescription.isNotEmpty &&
                              entrance.effectiveDescription
                                      .toLowerCase()
                                      .trim() !=
                                  entrance.effectiveLandmark
                                      .toLowerCase()
                                      .trim() &&
                              entrance.effectiveDescription
                                      .toLowerCase()
                                      .trim() !=
                                  entrance.displayName.toLowerCase().trim();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasCustomTitle) ...[
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(
                                            color: const Color(0xFF86EFAC),
                                            width: 0.8),
                                      ),
                                      child: Text(
                                        'Gate ${entrance.entranceId}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF166534),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        entrance.displayName,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Text(
                                  entrance.displayName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],

                              if (hasDistinctDescription) ...[
                                const SizedBox(height: 3),
                                Text(
                                  entrance.effectiveDescription,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF475569),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],

                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    size: 13,
                                    color: Color(0xFF166534),
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      entrance.effectiveLandmark,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Edit Button
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  tooltip: 'Edit Gate',
                  onPressed: () => _openEditSheet(context, entrance),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardPlaceholder(MarketEntryPoint entrance) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.location_on_rounded,
            size: 22,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 2),
          Text(
            'G${entrance.entranceId}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
