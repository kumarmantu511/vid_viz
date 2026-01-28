import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/project_service.dart';
import 'package:vidviz/model/project.dart';
import 'package:vidviz/ui/screens/director.dart';
import 'package:vidviz/ui/screens/project_edit.dart';
import 'package:vidviz/ui/screens/settings_screen.dart';
import 'package:vidviz/ui/widgets/ads/home_banner_ad.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:vidviz/ui/widgets/export/export_video_list.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import '../widgets/svg_icon.dart';
import 'feed_back.dart';

class ProjectList extends StatefulWidget {
  const ProjectList({super.key});

  @override
  _ProjectListState createState() => _ProjectListState();
}

class _ProjectListState extends State<ProjectList> {
  final projectService = locator.get<ProjectService>();
  bool isGridView = true; // Varsayılan Grid yaptık, tasarıma daha uygun

  @override
  Widget build(BuildContext context) {
    // Ekran yönü kontrolü
    bool isLandscape = (MediaQuery.of(context).orientation == Orientation.landscape);
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Scaffold - Tema sistemine bağlı
    return Scaffold(
      backgroundColor: isDark ? app_theme.projectListBg : app_theme.background,
      body: isLandscape
        ? _buildLandscapeLayout(size, isDark)
        : _buildPortraitLayout(size, isDark),
    );
  }

  // Landscape Layout (Eski yapı)
  Widget _buildLandscapeLayout(Size size, bool isDark) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Column(
          children: [
            HeaderSection(
              size: size,
              isLandscape: true,
              projects: projectService.projectList,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 15, bottom: 15),
                      child: _CreateProjectLandscapeCard(),
                    ),
                    Expanded(child: ProjectListView(isGridView: isGridView)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Portrait Layout (SliverAppBar ile)
  Widget _buildPortraitLayout(Size size, bool isDark) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final loc = AppLocalizations.of(context);

    return StreamBuilder(
      stream: projectService.projectListChanged$,
      initialData: false,
      builder: (context, snapshot) {
        return Stack(
          children: [
            CustomScrollView(
              slivers: [
                // SliverAppBar - Scroll ile küçülen header
                SliverAppBar(
                  expandedHeight: size.height * 0.34,
                  pinned: false, // Scroll ile tamamen yukarı çık
                  floating: false,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: HeaderSection(
                      size: size,
                      isLandscape: false,
                      projects: projectService.projectList,
                    ),
                    collapseMode: CollapseMode.parallax,
                  ),
                ),
                // AppBar ile liste arasında sabit reklam alanı
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyHeaderDelegate(
                    minHeight: 60,
                    maxHeight: 60,
                    child: Container(
                      color: isDark ? app_theme.projectListBg : app_theme.background,
                    //  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Container(
                       // decoration: BoxDecoration(
                       //   color: isDark ? app_theme.projectListCardBg : app_theme.surface,
                       //   borderRadius: BorderRadius.circular(12),
                       //   border: Border.all(
                       //     color: isDark ? app_theme.projectListCardBorder : app_theme.border,
                       //   ),
                       // ),
                        child: const Center(child: HomeBannerAd()),
                      ),
                    ),
                  ),
                ),
                // My Projects başlığı ve toggle butonu (Sabit)
                SliverPersistentHeader(
                  pinned: true, // Scroll yukarı çekildiğinde üstte sabit kal
                  delegate: _StickyHeaderDelegate(
                    minHeight: statusBarHeight + 10,
                    maxHeight: statusBarHeight + 20,
                    child: Container(
                      color: isDark ? app_theme.projectListBg : app_theme.background,
                      padding: EdgeInsets.fromLTRB(20, 5, 20, 5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            loc.projectListTitle,
                            style: TextStyle(
                              color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: SvgIcon(
                              asset: isGridView ? 'list' : 'grid',
                              color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                              //size: isGridView ? 50 : 28,
                            ),
                            onPressed: () => setState(() => isGridView = !isGridView),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),


                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      height: 0.5,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withOpacity(0.50),
                            blurRadius: 1.0,
                            spreadRadius: 0.2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                /* // AppBar ile liste arasında sabit reklam alanı
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyHeaderDelegate(
                    minHeight: 80,
                    maxHeight: 80,
                    child: Container(
                      color: isDark ? app_theme.projectListBg : app_theme.background,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? app_theme.projectListCardBg
                              : app_theme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? app_theme.projectListCardBorder
                                : app_theme.border,
                          ),
                        ),
                        child: const Center(child: HomeBannerAd()),
                      ),
                    ),
                  ),
                ),*/

                // Empty state veya liste içeriği
                if (projectService.projectList.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Text(
                        loc.projectListEmpty,
                        style: TextStyle(
                          color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120), // Alt boşluk (buton için)
                    sliver: isGridView
                      ? SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.95,
                            crossAxisSpacing: 15,
                            mainAxisSpacing: 15,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return _StyledGridCard(projectService.projectList[index], index);
                            },
                            childCount: projectService.projectList.length,
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return _StyledListCard(projectService.projectList[index], index);
                            },
                            childCount: projectService.projectList.length,
                          ),
                        ),
                  ),
               // SliverToBoxAdapter(
               //   child: Padding(
               //     padding: const EdgeInsets.only(bottom: 50),
               //     child: Center(
               //       child: HomeBannerAd(),
               //     ),
               //   ),
               // ),
              ],
            ),

            // Floating New Project Button
            Positioned(
              bottom: 40,
              left: size.width * 0.25,
              right: size.width * 0.25,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: app_theme.neonButtonGradient,
                  borderRadius: BorderRadius.circular(app_theme.radiusM + 4),
                  boxShadow: [
                    BoxShadow(
                      color: app_theme.neonCyan.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProjectEdit(null)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: app_theme.transparent,
                    shadowColor: app_theme.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(app_theme.radiusM + 4),
                    ),
                  ),
                  child:FittedBox(
                    fit: BoxFit.scaleDown, // Sığarsa normal kalır, sığmazsa küçülür
                    alignment: Alignment.centerLeft, // Sola yaslı küçülsün
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          loc.projectListNewProject,
                          style: TextStyle(
                            color: app_theme.buttonTextColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.add, color: app_theme.buttonTextColor),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

}

// --- DÜZELTİLMİŞ & GÜÇLENDİRİLMİŞ HEADER ---
class HeaderSection extends StatefulWidget {
  final Size size;
  final bool isLandscape;
  final List<Project> projects;

  const HeaderSection({
    Key? key,
    required this.size,
    required this.isLandscape,
    required this.projects,
  }) : super(key: key);

  @override
  _HeaderSectionState createState() => _HeaderSectionState();
}

class _HeaderSectionState extends State<HeaderSection> with TickerProviderStateMixin {
  int _currentIndex = 0;
  Timer? _slideTimer;

  late AnimationController _bgAnimController;
  late AnimationController _zoomController;

  @override
  void initState() {
    super.initState();

    // 1. Arka Plan Animasyonu (Sürekli Çalışır)
    _bgAnimController = AnimationController(
      duration: app_theme.animHeaderBackground,
      vsync: this,
    )..repeat(reverse: true);

    // 2. Zoom Animasyonu
    _zoomController = AnimationController(
      duration: app_theme.animZoom,
      vsync: this,
      upperBound: 1.15,
      lowerBound: 1.0,
    );

    // İlk başlatma kontrolü
    _checkAndStartSlideShow();
  }

  // --- KRİTİK DÜZELTME: VERİ DEĞİŞİNCE TETİKLEME ---
  @override
  void didUpdateWidget(HeaderSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Eğer proje sayısı değiştiyse (Örn: Veritabanından yüklendiyse)
    if (widget.projects.length != oldWidget.projects.length) {
      _checkAndStartSlideShow();
    }
  }

  void _checkAndStartSlideShow() {
    // Mevcut timer varsa durdur, temizle
    _slideTimer?.cancel();

    if (widget.projects.isNotEmpty) {
      // Zoom'u başlat
      _zoomController.reset();
      _zoomController.forward();

      // Timer'ı başlat
      _slideTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (mounted) {
          setState(() {
            // Mod işlemi ile döngü sağla
            _currentIndex = (_currentIndex + 1) % widget.projects.length;
          });
          // Her geçişte Zoom efektini sıfırdan başlat (Tek resim olsa bile çalışır)
          _zoomController.reset();
          _zoomController.forward();
        }
      });
    } else {
      // Proje yoksa zoomu durdur
      _zoomController.stop();
    }
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _bgAnimController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool hasProjects = widget.projects.isNotEmpty;
    final loc = AppLocalizations.of(context);
    // Index hatasını önlemek için güvenli erişim
    Project? currentProject;
    if (hasProjects) {
      // Liste kısaldıysa indexi sıfırla (Güvenlik önlemi)
      if (_currentIndex >= widget.projects.length) _currentIndex = 0;
      currentProject = widget.projects[_currentIndex];
    }

    return Stack(
      children: [
        // --- 1. GÖRSEL KATMAN ---
        ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(40),
            bottomRight: Radius.circular(40),
          ),
          child: Container(
            height: widget.isLandscape ? 80 : widget.size.height * 0.45,
            width: double.infinity,
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Resim veya Neon Geçişi
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 800),
                  child: Container(
                    // Key çok önemli! Key değişmezse Flutter animasyon yapmaz.
                    key: ValueKey<String>(currentProject?.imagePath ?? "no_img_$_currentIndex"),
                    child: _buildVisualContent(currentProject, _currentIndex),
                  ),
                ),

                // Parçacıklar (Particles)
                Positioned.fill(
                  child: CustomPaint(
                    painter: ParticlePainter(_bgAnimController),
                  ),
                ),

                // Karartma (Gradient Overlay)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.1),
                        Colors.transparent,
                        Colors.black.withOpacity(0.6),
                        Colors.black.withOpacity(0.9),
                      ],
                      stops: const [0.0, 0.4, 0.7, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // --- 2. YAZI VE BUTONLAR ---
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AppBar (Butonlar)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.exit_to_app, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 10)]),
                      onPressed: () => SystemChannels.platform.invokeMethod('SystemNavigator.pop'),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const SvgIcon(asset: 'chat', color: Colors.white),
                          onPressed: () {

                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true, // Tam ekran klavye kontrolü için önemli
                              backgroundColor: Colors.transparent,
                              builder: (context) => const FeedbackSheet(),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 10)]),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen())),
                        ),

                        /// sonra kullanılacak silinmesin
                        /* Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF2979FF)]),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.6), blurRadius: 12, spreadRadius: 1)
                              ]
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.bolt, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text("PRO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),*/
                      ],
                    )
                  ],
                ),

                // Alt Başlıklar (Sadece Dikey Modda)
                if (!widget.isLandscape) ...[
                  const Spacer(),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: hasProjects && currentProject != null
                        ? Column(
                      // Key ekledik ki yazı değişince animasyon çalışsın
                      key: ValueKey("Title_${currentProject.title}"),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 4, height: 16,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(color: const Color(0xFF00E5FF), borderRadius: BorderRadius.circular(2)),
                            ),
                            Text(
                              loc.projectListContinueEditing,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          currentProject.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 5)]
                          ),
                        ),
                      ],
                    )
                        : Column(
                      key: const ValueKey("DefaultTitle"),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.projectListDefaultHeadline,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                offset: Offset(0, 2),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Slider Noktaları
                  Row(
                    children: List.generate(hasProjects ? widget.projects.length.clamp(0, 5) : 4, (index) {
                      bool isActive = hasProjects ? index == (_currentIndex % 5) : index == 0;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        width: isActive ? 24 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF00E5FF) : Colors.white38,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: isActive ? [BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.5), blurRadius: 6)] : [],
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10,),
                ]
              ],
            ),
          ),
        ),

      ],
    );
  }

  // --- GÖRSEL İÇERİK MANTIĞI ---
  Widget _buildVisualContent(Project? project, int index) {
    // 1. Durum: Proje ve Resim Var -> Zoom Efektli Resim
    if (project != null && project.imagePath != null) {
      return AnimatedBuilder(
        animation: _zoomController,
        builder: (context, child) {
          return Transform.scale(
            scale: _zoomController.value, // Zoom Değeri
            child: Image.file(
              File(project.imagePath!),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          );
        },
      );
    }

    // 2. Durum: Proje Var ama Resim Yok -> Neon Renk
    else if (project != null && project.imagePath == null) {
      List<Color> palette = app_theme.neonPalettes[index % app_theme.neonPalettes.length];
      return _buildAnimatedMeshGradient(palette[0], palette[1]);
    }

    // 3. Durum: Proje Yok -> Varsayılan Animasyon (İlk palet)
    else {
      List<Color> defaultPalette = app_theme.neonPalettes[0];
      return _buildAnimatedMeshGradient(defaultPalette[0], defaultPalette[1]);
    }
  }

  Widget _buildAnimatedMeshGradient(Color color1, Color color2) {
    return AnimatedBuilder(
      animation: _bgAnimController,
      builder: (context, child) {
        final double t = _bgAnimController.value;
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(math.sin(t * 2 * math.pi) * 0.3, math.cos(t * 2 * math.pi) * 0.3),
              radius: 1.5,
              colors: [color1, color2, Colors.black],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// ParticlePainter Class'ı aynı kalabilir, aynen ekle:
class ParticlePainter extends CustomPainter {
  final Animation<double> animation;
  final List<_Particle> _particles = [];
  final math.Random _random = math.Random();

  ParticlePainter(this.animation) : super(repaint: animation) {
    for (int i = 0; i < app_theme.particleCountHeader; i++) {
      _particles.add(_generateParticle());
    }
  }

  _Particle _generateParticle() {
    return _Particle(
      x: _random.nextDouble(),
      y: _random.nextDouble(),
      speed: _random.nextDouble() * 0.002 + 0.001,
      size: _random.nextDouble() * 3 + 1,
      opacity: _random.nextDouble() * 0.5 + 0.1,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var particle in _particles) {
      particle.y -= particle.speed;
      if (particle.y < 0) {
        particle.y = 1.0;
        particle.x = _random.nextDouble();
      }
      paint.color = Colors.white.withOpacity(particle.opacity);
      canvas.drawCircle(Offset(particle.x * size.width, particle.y * size.height), particle.size, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _Particle {
  double x, y, speed, size, opacity;
  _Particle({required this.x, required this.y, required this.speed, required this.size, required this.opacity});
}

// --- PROJE LİSTE GÖRÜNÜMÜ ---
class ProjectListView extends StatelessWidget {
  final projectService = locator.get<ProjectService>();
  final bool isGridView;

  ProjectListView({required this.isGridView});

  @override
  Widget build(BuildContext context) {
    bool isLandscape = (MediaQuery.of(context).orientation == Orientation.landscape);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    // Alt boşluk bırakıyoruz ki buton listeyi kapatmasın
    return StreamBuilder(
      stream: projectService.projectListChanged$,
      initialData: false,
      builder: (BuildContext context, AsyncSnapshot<bool> layersChanged) {
        if (projectService.projectList.isEmpty) {
          return Center(
            child: Text(
              loc.projectListEmpty,
              style: TextStyle(
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
              )
            )
          );
        }

        if (!isGridView) {
          // LİSTE GÖRÜNÜMÜ
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: projectService.projectList.length,
            itemBuilder: (context, index) {
              return _StyledListCard(projectService.projectList[index], index);
            },
          );
        } else {
          // GRID GÖRÜNÜMÜ (Tasarımına Sadık)
          return GridView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isLandscape ? 4 : 2,
              childAspectRatio: 0.95, // Biraz daha dikey, kartlar sığsın
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
            ),
            itemCount: projectService.projectList.length,
            itemBuilder: (context, index) {
              return _StyledGridCard(projectService.projectList[index], index);
            },
          );
        }
      },
    );
  }
}

// --- TASARIMA UYGUN GRID KARTI (Birebir İstediğin) ---
class _StyledGridCard extends StatefulWidget {
  final Project project;
  final int index;

  _StyledGridCard(this.project, this.index);

  @override
  _StyledGridCardState createState() => _StyledGridCardState();
}

class _StyledGridCardState extends State<_StyledGridCard> with SingleTickerProviderStateMixin {
  final projectService = locator.get<ProjectService>();
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: app_theme.animCardBackground,
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => DirectorScreen(widget.project)));
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(app_theme.radiusXL),
          color: isDark ? app_theme.projectListCardBg : app_theme.surface,
        ),
        child: Stack(
          children: [
            // 1. GÖRSEL veya ANİMASYONLU GRADIENT
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(app_theme.radiusXL),
                child: (widget.project.imagePath != null)
                    ? Image.file(File(widget.project.imagePath!), fit: BoxFit.cover)
                    : _buildAnimatedBackground(), // Animasyonlu arka plan
              ),
            ),

            // 2. GRADIENT KARARTMA (Yazıların okunması için)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(app_theme.radiusXL),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8), // Altta koyulaşma
                    ],
                  ),
                ),
              ),
            ),

            // 3. SÜRE (Sol Alt - Örnek statik veri, projenizde varsa onu kullanın)
            const Positioned(
              left: 12, bottom: 12,
              child: Text("00:00", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),

            // 4. MENU BUTONU (3 Nokta)
            Positioned(
              right: 4, bottom: 4,
              child: IconButton(
                icon: const Icon(Icons.more_horiz, color: Colors.white, size: 24),
                onPressed: () {
                  _showCustomPopup(context, widget.project, widget.index, projectService);
                },
              ),
            ),

            // 5. BAŞLIK VE TARİH
            Positioned(
              left: 12, bottom: 35,
              right: 40,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.project.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    DateFormat.yMMMd().format(widget.project.date),
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // Animasyonlu gradient arka plan (resim yoksa)
  Widget _buildAnimatedBackground() {
    List<Color> palette = app_theme.neonPalettes[widget.index % app_theme.neonPalettes.length];
    return Stack(
      children: [
        // Animasyonlu Gradient
        AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            final double t = _animController.value;
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(
                    math.sin(t * 2 * math.pi) * 0.3,
                    math.cos(t * 2 * math.pi) * 0.3,
                  ),
                  radius: 1.2,
                  colors: [palette[0], palette[1], Colors.black],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            );
          },
        ),
        // Particle efekti
        Positioned.fill(
          child: CustomPaint(
            painter: _MiniParticlePainter(_animController),
          ),
        ),
      ],
    );
  }
}

// --- YENİ TASARIM: LIST KART ---
class _StyledListCard extends StatefulWidget {
  final Project project;
  final int index;

  _StyledListCard(this.project, this.index);

  @override
  _StyledListCardState createState() => _StyledListCardState();
}

class _StyledListCardState extends State<_StyledListCard> with SingleTickerProviderStateMixin {
  final projectService = locator.get<ProjectService>();
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: app_theme.animCardBackground,
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.only(bottom: app_theme.spaceS),
      padding: EdgeInsets.symmetric(horizontal: app_theme.spaceXXS ,vertical: app_theme.spaceXXS),
      decoration: BoxDecoration(
        color: isDark ? app_theme.projectListCardBg : app_theme.surface,
        borderRadius: BorderRadius.circular(app_theme.radiusL),
        border: Border.all(color: isDark ? app_theme.projectListCardBorder : app_theme.border),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DirectorScreen(widget.project),
            ),
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(app_theme.radiusM),
              child: Container(
                width: 80,
                height: 80,
                color: Colors.grey[900],
                child: widget.project.imagePath != null ? Image.file(
                  File(widget.project.imagePath!),
                  fit: BoxFit.cover,
                ) : _buildAnimatedThumbnail(),
              ),
            ),

            const SizedBox(width: 12),

            // Title + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.project.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? app_theme.darkTextPrimary
                          : app_theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat.yMMMd().format(widget.project.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? app_theme.darkTextSecondary
                          : app_theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                _showCustomPopup(
                  context,
                  widget.project,
                  widget.index,
                  projectService,
                );
              },
            ),
          ],
        ),
      )

    );
  }

  Widget _buildAnimatedThumbnail() {
    List<Color> palette = app_theme.neonPalettes[widget.index % app_theme.neonPalettes.length];
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            final double t = _animController.value;
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(
                    math.sin(t * 2 * math.pi) * 0.3,
                    math.cos(t * 2 * math.pi) * 0.3,
                  ),
                  radius: 1.2,
                  colors: [palette[0], palette[1], Colors.black],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            );
          },
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _MiniParticlePainter(_animController),
          ),
        ),
      ],
    );
  }
}

// --- MİNİ PARTİCLE PAİNTER (Kartlar için optimize) ---
class _MiniParticlePainter extends CustomPainter {
  final Animation<double> animation;
  final List<_MiniParticle> _particles = [];
  final math.Random _random = math.Random();

  _MiniParticlePainter(this.animation) : super(repaint: animation) {
    // Daha az particle - performans için
    for (int i = 0; i < app_theme.particleCountCard; i++) {
      _particles.add(_generateParticle());
    }
  }

  _MiniParticle _generateParticle() {
    return _MiniParticle(
      x: _random.nextDouble(),
      y: _random.nextDouble(),
      speed: _random.nextDouble() * 0.001 + 0.0005,
      size: _random.nextDouble() * 2 + 0.5,
      opacity: _random.nextDouble() * 0.4 + 0.1,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var particle in _particles) {
      particle.y -= particle.speed;
      if (particle.y < 0) {
        particle.y = 1.0;
        particle.x = _random.nextDouble();
      }
      paint.color = Colors.white.withOpacity(particle.opacity);
      canvas.drawCircle(
        Offset(particle.x * size.width, particle.y * size.height),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MiniParticle {
  double x, y, speed, size, opacity;
  _MiniParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
  });
}

// --- LANDSCAPE İÇİN "CREATE PROJECT" KARTI ---
class _CreateProjectLandscapeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ProjectEdit(null)));
      },
      child: Container(
        width: 160, // Grid kartlarla aynı genişlikte
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(app_theme.radiusXL),
            gradient: app_theme.neonButtonGradient,
            boxShadow: [
              BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
            ]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline, color: Colors.white, size: 40),
            const SizedBox(height: 10),
            Text(
              loc.projectListNewProject,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- STICKY HEADER DELEGATE ---
class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _StickyHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}

// --- MODERN POPUP MENÜ FONKSİYONU ---
void _showCustomPopup(BuildContext context, Project project, int index, ProjectService service,) {
  if (!context.mounted) return;

  final loc = AppLocalizations.of(context);

  showDialog(
    context: context,
    barrierColor: Colors.black.withAlpha(100),
    builder: (dialogContext) { // 🔥 ÖNEMLİ: AYRI CONTEXT
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(dialogContext).pop(), // ✅
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        height: 30,
                        width: 30,
                        decoration: BoxDecoration(
                          color: app_theme.layerDeleted,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Center(
                          child: Icon(Icons.close, size: 18),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                _buildPopupItem(
                  Icons.movie_filter_outlined,
                  loc.projectMenuDesign,
                  Colors.white,
                  Colors.black,
                      () {
                    Navigator.of(dialogContext).pop(); // ✅
                    Future.microtask(() {
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DirectorScreen(project),
                          ),
                        );
                      }
                    });
                  },
                ),

                const SizedBox(height: 10),

                _buildPopupItem(
                  Icons.edit_outlined,
                  loc.projectMenuEditInfo,
                  Colors.white,
                  Colors.black,
                      () {
                    Navigator.of(dialogContext).pop();
                    Future.microtask(() {
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProjectEdit(project),
                          ),
                        );
                      }
                    });
                  },
                ),

                const SizedBox(height: 10),

                _buildPopupItem(
                  Icons.video_library_outlined,
                  loc.projectMenuVideos,
                  Colors.white,
                  Colors.black,
                      () {
                    Navigator.of(dialogContext).pop();
                    Future.microtask(() {
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExportVideoList(project),
                          ),
                        );
                      }
                    });
                  },
                ),

                const SizedBox(height: 10),

                _buildPopupItem(
                  Icons.delete_outline,
                  loc.projectMenuDelete,
                  const Color(0xFFFF3B30),
                  Colors.white,
                      () {
                    Navigator.of(dialogContext).pop();
                    Future.microtask(() {
                      if (context.mounted) {
                        _showDeleteConfirmation(
                          context,
                          loc,
                          service,
                          index,
                        );
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void _showDeleteConfirmation(BuildContext context, AppLocalizations loc, ProjectService service, int index,) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                loc.projectDeleteDialogTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                loc.projectDeleteDialogMessage,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              /// 👇 BUTTON ROW
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.of(dialogContext).pop(false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        child: Text(loc.commonCancel),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.of(dialogContext).pop(true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        child: Text(
                          loc.commonDelete,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  /// 👇 DELETE LOGIC DIŞARIDA (EN KRİTİK KURAL)
  if (result == true) {
    service.delete(index);
  }
}

// Popup İçin Yardımcı Widget
Widget _buildPopupItem(IconData icon, String text, Color bgColor, Color textColor, VoidCallback onTap) {
  return Container(
    height: 50,

    margin: EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(icon, color: textColor, size: 22),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}