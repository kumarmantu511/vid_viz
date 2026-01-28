import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vidviz/service_locator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'package:vidviz/model/layer.dart' as layer_model;
import 'package:vidviz/l10n/generated/app_localizations.dart';


// --- MAIN WIDGET ---

class MediaPickerSheet extends StatefulWidget {
  final List<AssetEntity> selectedAssets;
  final int initialTabIndex;

  const MediaPickerSheet({
    super.key,
    required this.selectedAssets,
    this.initialTabIndex = 0,
  });

  @override
  State<MediaPickerSheet> createState() => _MediaPickerSheetState();
}

class _MediaPickerSheetState extends State<MediaPickerSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Seçili dosyaları ana widget'ta tutuyoruz ki sekmeler arası senkron olsun
  late List<AssetEntity> _selectedAssets;
  String _searchQuery = '';
  bool _hasPermission = true;

  @override
  void initState() {
    super.initState();
    _selectedAssets = List.from(widget.selectedAssets);
    // 4 sekme: Tümü, Resim, Video, Ses
    int initialIndex = widget.initialTabIndex.clamp(0, 3);
    _tabController = TabController(length: 4, vsync: this, initialIndex: initialIndex);
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (mounted) {
      setState(() {
        _hasPermission = ps.isAuth || ps.hasAccess;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleSelection(AssetEntity asset) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedAssets.any((a) => a.id == asset.id)) {
        _selectedAssets.removeWhere((a) => a.id == asset.id);
      } else {
        _selectedAssets.add(asset);
      }
    });
  }

  // --- External Actions ---
  Future<void> _handleGenericPick(FileType type, layer_model.AssetType assetType, {List<String>? extensions}) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: type, allowedExtensions: extensions, allowMultiple: true);
      if (result != null && result.files.isNotEmpty) {
        final paths = result.files.map((f) => f.path).whereType<String>().toList();
        if (paths.isNotEmpty) {
          await locator.get<DirectorService>().mediaAdd(assetType, paths);
          if (mounted) Navigator.pop(context);
        }
      }
    } catch (e) { debugPrint("Picker Error: $e"); }
  }

  Future<void> _handlePickAll() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'avi', 'mkv', 'webm', 'jpg', 'jpeg', 'png', 'webp', 'bmp', 'heic', 'mp3', 'wav', 'aac', 'm4a', 'flac', 'ogg',],
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;

      final director = locator.get<DirectorService>();
      final validFiles = result.files.where((f) => f.path != null).toList();

      for(var f in validFiles) {
        final ext = f.path!.split('.').last.toLowerCase();
        layer_model.AssetType type = layer_model.AssetType.image;
        if (['mp4','mov','avi','mkv','webm'].contains(ext)) type = layer_model.AssetType.video;
        else if (['mp3','wav','aac','m4a','flac','ogg'].contains(ext)) type = layer_model.AssetType.audio;

        await director.mediaAdd(type, [f.path!]);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) { debugPrint("PickAll Error: $e"); }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    // Theme Colors
    final Color bg = isDark ? const Color(0xFF121212) : const Color(0xFFF2F2F7);
    final Color surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textPrimary = isDark ? Colors.white : Colors.black87;

    if (!_hasPermission) return _PermissionDeniedView(isDark: isDark);

    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? app_theme.darkTextSecondary : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(loc.mediaPickerTitle, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: textPrimary,overflow: TextOverflow.ellipsis,))),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black12,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded, size: 20, color: textPrimary),
                      ),
                    )
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withAlpha(40)),
                  ),
                  child: Center(
                    child: TextField(
                      style: TextStyle(color: textPrimary, fontSize: 14),
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: loc.mediaPickerSearchHint,
                        hintStyle: TextStyle(color: Colors.grey.withAlpha(140)),
                        prefixIcon: Icon(Icons.search, color: Colors.grey.withAlpha(160)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
              ),

              // Quick Actions
              SizedBox(
                height: 54,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    _QuickPill(icon: Icons.image_rounded, label: loc.mediaPickerTypeImage, color: Colors.teal, onTap: () => _handleGenericPick(FileType.custom, layer_model.AssetType.image, extensions: ['jpg','jpeg','png','webp','bmp','heic'])),
                    const SizedBox(width: 8),
                    _QuickPill(icon: Icons.videocam_rounded, label: loc.mediaPickerTypeVideo, color: Colors.blue, onTap: () => _handleGenericPick(FileType.custom, layer_model.AssetType.video, extensions: ['mp4','mov','avi','mkv','webm'])),
                    const SizedBox(width: 8),
                    _QuickPill(icon: Icons.audiotrack_rounded, label: loc.mediaPickerTypeAudio, color: Colors.orange, onTap: () => _handleGenericPick(FileType.custom, layer_model.AssetType.audio, extensions: ['mp3','wav','aac','m4a','flac','ogg'])),
                    const SizedBox(width: 8),
                    _QuickPill(icon: Icons.folder_open_rounded, label: loc.mediaPickerFiles, color: Colors.purple, onTap: _handlePickAll),
                  ],
                ),
              ),

              // Tabs
              SizedBox(
                height: 36,
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorColor: app_theme.accent,
                  indicatorWeight: 3,
                  labelColor: app_theme.accent,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  dividerColor: Colors.transparent,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  tabs: [
                    Tab(text: loc.mediaPickerTabAll(0).split('(').first),
                    Tab(text: loc.mediaPickerTypeImage),
                    Tab(text: loc.mediaPickerTypeVideo),
                    Tab(text: loc.mediaPickerTypeAudio),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),

              // Swipeable Content Body
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(), // Swipe kolaylığı
                  children: [
                    // Tab 0: All
                    _MediaGridPage(
                      requestType: RequestType.common,
                      searchQuery: _searchQuery,
                      selectedAssets: _selectedAssets,
                      onToggle: _toggleSelection,
                    ),
                    // Tab 1: Image
                    _MediaGridPage(
                      requestType: RequestType.image,
                      searchQuery: _searchQuery,
                      selectedAssets: _selectedAssets,
                      onToggle: _toggleSelection,
                    ),
                    // Tab 2: Video
                    _MediaGridPage(
                      requestType: RequestType.video,
                      searchQuery: _searchQuery,
                      selectedAssets: _selectedAssets,
                      onToggle: _toggleSelection,
                    ),
                    // Tab 3: Audio
                    _MediaGridPage(
                      requestType: RequestType.audio,
                      searchQuery: _searchQuery,
                      selectedAssets: _selectedAssets,
                      onToggle: _toggleSelection,
                      isAudioMode: true,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 7. Floating Action Bar (Modern & Chic Design)
          if (_selectedAssets.isNotEmpty)
            Positioned(
              left: 64,
              right: 64,
              bottom: 46, // Alt boşluk biraz artırıldı
              child: Material(
                color: Colors.transparent,
                shadowColor: app_theme.accent.withOpacity(0.5), // Glow Rengi
                elevation: 10, // Havada durma efekti
                borderRadius: BorderRadius.circular(30), // Tam yuvarlak (Pill shape)
                child: InkWell(
                  onTap: () => Navigator.pop(context, _selectedAssets),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    decoration: BoxDecoration(
                      color: app_theme.accent, // Ana tema rengi (Solid)
                      borderRadius: BorderRadius.circular(30),
                      // İsteğe bağlı: Hafif gradient eklenebilir
                      gradient: app_theme.neonButtonGradient,
                    ),
                    child: Row(
                      children: [
                        // Sol Taraf: Sayaç (Badge Stili)
                        Container(
                          height: 40,
                          constraints: const BoxConstraints(minWidth: 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "${_selectedAssets.length}",
                            style: TextStyle(
                              color: app_theme.accent,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),

                        // Orta Taraf: Metin
                        Expanded(
                          child: Center(
                            child: Text(
                              // Regex ile parantezli sayıyı temizleyip sade metni alıyoruz
                              loc.mediaPickerAddToProject(0).replaceAll(RegExp(r'\([0-9]+\)'), '').trim(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),

                        // Sağ Taraf: İkon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2), // Hafif transparan daire
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 20,
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
    );
  }
}

// --- SUB-WIDGET: MEDIA PAGE (Handles Pagination & State per Tab) ---

class _MediaGridPage extends StatefulWidget {
  final RequestType requestType;
  final String searchQuery;
  final List<AssetEntity> selectedAssets;
  final Function(AssetEntity) onToggle;
  final bool isAudioMode;

  const _MediaGridPage({
    required this.requestType,
    required this.searchQuery,
    required this.selectedAssets,
    required this.onToggle,
    this.isAudioMode = false,
  });

  @override
  State<_MediaGridPage> createState() => _MediaGridPageState();
}

class _MediaGridPageState extends State<_MediaGridPage> with AutomaticKeepAliveClientMixin {
  // KeepAlive sayesinde sekmeler arası gezerken scroll pozisyonu kaybolmaz
  @override
  bool get wantKeepAlive => true;

  final ScrollController _scrollController = ScrollController();
  List<AssetEntity> _assets = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 60; // Düşürüldü, daha sık yükleme daha akıcı hissettirir
  AssetPathEntity? _currentPath;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void didUpdateWidget(_MediaGridPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) setState(() {});
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _assets.clear();
      _currentPage = 0;
      _hasMore = true;
      _currentPath = null;
    });

    try {
      // "onlyAll: true" yerine hepsini çekip ilkini alıyoruz (Cihaz uyumluluğu için kritik)
      final albums = await PhotoManager.getAssetPathList(
        type: widget.requestType,
        hasAll: true,
        filterOption: FilterOptionGroup(
          orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
          containsPathModified: true, // Bazı cihazlarda modifikasyon tarihine göre path değişimi
        ),
      );

      if (albums.isNotEmpty) {
        // Genellikle ilk albüm "Recent" veya "All"dır.
        _currentPath = albums.first;
        await _loadMore();
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Load Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_currentPath == null || _isLoadingMore || !_hasMore) return;

    if (mounted) setState(() => _isLoadingMore = true);

    try {
      final newItems = await _currentPath!.getAssetListPaged(page: _currentPage, size: _pageSize);

      if (mounted) {
        setState(() {
          _assets.addAll(newItems);

          _hasMore = newItems.length == _pageSize;
          _currentPage++;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _isLoadingMore = false; });
    }
  }

  bool _isSelected(AssetEntity asset) {
    return widget.selectedAssets.any((a) => a.id == asset.id);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // KeepAlive için gerekli
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final query = widget.searchQuery.trim().toLowerCase();
    final visibleAssets = query.isEmpty
        ? _assets
        : _assets.where((a) => a.title?.toLowerCase().contains(query) ?? false).toList();

    if (_isLoading) {
      return _ShimmerLoadingGrid(isAudioMode: widget.isAudioMode);
    }

    if (visibleAssets.isEmpty) {
      return _EmptyState(isDark: isDark, loc: loc);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        // Listenin sonuna yaklaşıldı mı? (Pre-load)
        if (!_isLoadingMore && _hasMore && scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 500) {
          _loadMore();
        }
        return false;
      },
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.isAudioMode ? 2 : 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: widget.isAudioMode ? 2.5 : 1.0,
        ),
        itemCount: visibleAssets.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == visibleAssets.length) {
            // Sonsuz scroll spinner
            return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
          }
          final asset = visibleAssets[index];
          return _ProGridItem(
            key: ValueKey(asset.id),
            asset: asset,
            isSelected: _isSelected(asset),
            onTap: () => widget.onToggle(asset),
            accentColor: app_theme.accent,
            isAudioMode: widget.isAudioMode,
          );
        },
      ),
    );
  }
}

// --- OPTIMIZED GRID ITEM ---

class _ProGridItem extends StatelessWidget {
  final AssetEntity asset;
  final bool isSelected;
  final VoidCallback onTap;
  final Color accentColor;
  final bool isAudioMode;

  const _ProGridItem({
    super.key,
    required this.asset,
    required this.isSelected,
    required this.onTap,
    required this.accentColor,
    this.isAudioMode = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isAudioMode) {
      final loc = AppLocalizations.of(context);
      // AUDIO CARD
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: isSelected ? accentColor.withOpacity(0.15) : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? accentColor : Colors.transparent, width: 2),
              boxShadow: [
                if (!isSelected) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0,2))
              ]
          ),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.music_note, color: Colors.orange, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asset.title ?? loc.mediaPickerAudioFallbackTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(_formatDuration(asset.duration), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              if (isSelected) Icon(Icons.check_circle, color: accentColor, size: 18),
            ],
          ),
        ),
      );
    }

    // IMAGE/VIDEO CARD
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: isSelected ? const EdgeInsets.all(4) : EdgeInsets.zero,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: accentColor, width: 2) : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isSelected ? 8 : 12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              _AssetThumbnail(asset: asset),

              // Video Overlay
              if (asset.type == AssetType.video)
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Container(
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                      ),
                    ),
                    padding: const EdgeInsets.only(right: 6, bottom: 4),
                    alignment: Alignment.bottomRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow, color: Colors.white, size: 12),
                        const SizedBox(width: 2),
                        Text(_formatDuration(asset.duration), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),

              // Selection Check
              if (isSelected)
                Container(
                  color: Colors.black12,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.all(6),
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(Icons.check_circle, color: accentColor, size: 20),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return "0:00";
    final duration = Duration(seconds: seconds);
    final min = duration.inMinutes;
    final sec = duration.inSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }
}

// --- THUMBNAIL WIDGET ---
class _AssetThumbnail extends StatefulWidget {
  final AssetEntity asset;
  const _AssetThumbnail({required this.asset});

  @override
  State<_AssetThumbnail> createState() => _AssetThumbnailState();
}

class _AssetThumbnailState extends State<_AssetThumbnail> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    widget.asset.thumbnailDataWithSize(const ThumbnailSize.square(200)).then((val) {
      if (mounted) setState(() => _bytes = val);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) {
      return Container(color: Colors.grey.withOpacity(0.1)); // Basit gri placeholder
    }
    return Image.memory(_bytes!, fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: 200);
  }
}

// --- SHIMMER LOADING (CUSTOM) ---
class _ShimmerLoadingGrid extends StatefulWidget {
  final bool isAudioMode;
  const _ShimmerLoadingGrid({this.isAudioMode = false});

  @override
  State<_ShimmerLoadingGrid> createState() => _ShimmerLoadingGridState();
}

class _ShimmerLoadingGridState extends State<_ShimmerLoadingGrid> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);
    final highlightColor = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.02);

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.isAudioMode ? 2 : 3,
        crossAxisSpacing: 8, mainAxisSpacing: 8,
        childAspectRatio: widget.isAudioMode ? 2.5 : 1.0,
      ),
      itemCount: 15, // Ekrani dolduracak kadar
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [baseColor, highlightColor, baseColor],
                  stops: [
                    0.0,
                    (0.3 + 0.4 * _controller.value).clamp(0.0, 1.0),
                    1.0
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// --- HELPERS ---

class _QuickPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickPill({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? color : color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  final bool isDark;
  const _PermissionDeniedView({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_clock, size: 80, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 20),
          Text(loc.mediaPermissionDeniedTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(loc.mediaPermissionDeniedMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: PhotoManager.openSetting,
            style: ElevatedButton.styleFrom(
              backgroundColor: app_theme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: Text(loc.mediaPermissionManageButton),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.mediaPermissionNotNow)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final AppLocalizations loc;
  const _EmptyState({required this.isDark, required this.loc});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.perm_media_outlined, size: 64, color: isDark ? Colors.white10 : Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(loc.mediaPickerEmpty, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}