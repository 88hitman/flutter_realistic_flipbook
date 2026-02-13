import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

typedef FlipbookPageCallback = void Function(int page);
typedef FlipbookZoomCallback = void Function(double zoom);

enum FlipbookForwardDirection { right, left }

enum FlipbookWheelMode { scroll, zoom }

enum _FlipDirection { left, right }

class FlipbookPage {
  const FlipbookPage({
    this.image,
    this.widgetBuilder,
    this.sizeHint,
    this.hiResImage,
    this.headerText,
    this.footerText,
    this.headerAlignment = Alignment.topCenter,
  }) : assert(
          image != null || widgetBuilder != null,
          'Provide either image or widgetBuilder.',
        );

  final ImageProvider? image;
  final WidgetBuilder? widgetBuilder;
  final Size? sizeHint;
  final ImageProvider? hiResImage;
  final String? headerText;
  final String? footerText;
  final Alignment headerAlignment;
}

class FlipbookController {
  _RealisticFlipbookState? _state;

  bool get canFlipLeft => _state?._canFlipLeft ?? false;
  bool get canFlipRight => _state?._canFlipRight ?? false;
  bool get canZoomIn => _state?._canZoomIn ?? false;
  bool get canZoomOut => _state?._canZoomOut ?? false;
  int get page => _state?._publicPage ?? 1;
  int get numPages => _state?._numPages ?? 0;

  void flipLeft() => _state?._flipLeft(auto: true);
  void flipRight() => _state?._flipRight(auto: true);
  void zoomIn([Offset? zoomAt]) => _state?._zoomIn(zoomAt);
  void zoomOut([Offset? zoomAt]) => _state?._zoomOut(zoomAt);
  void goToPage(int page) => _state?._goToPage(page);

  void _attach(_RealisticFlipbookState state) {
    _state = state;
  }

  void _detach(_RealisticFlipbookState state) {
    if (_state == state) {
      _state = null;
    }
  }
}

class RealisticFlipbook extends StatefulWidget {
  const RealisticFlipbook({
    super.key,
    required this.pages,
    this.controller,
    this.flipDuration = const Duration(milliseconds: 1000),
    this.zoomDuration = const Duration(milliseconds: 500),
    this.zooms = const <double>[1, 2, 4],
    this.perspective = 2400,
    this.nPolygons = 10,
    this.ambient = 0.4,
    this.gloss = 0.6,
    this.swipeMin = 3,
    this.singlePage = false,
    this.forwardDirection = FlipbookForwardDirection.right,
    this.centering = true,
    this.startPage,
    this.flipThreshold = 0.25,
    this.allowPageWidgetGestures = false,
    this.tapToFlip = true,
    this.clickToZoom = true,
    this.dragToFlip = true,
    this.dragToScroll = true,
    this.wheel = FlipbookWheelMode.scroll,
    this.clipToViewport = true,
    this.singlePageSpreadNavigation = true,
    this.singlePageSlideDuration = const Duration(milliseconds: 320),
    this.paperColor = Colors.white,
    this.bookChrome = false,
    this.bookTopInsetRatio = 0.075,
    this.bookBottomInsetRatio = 0.085,
    this.bookSideInsetRatio = 0.045,
    this.bookHeaderStyle,
    this.bookFooterStyle,
    this.bookHeaderFooterColor = const Color(0xFF6D4C1E),
    this.bookBorderColor = const Color(0xFFC8A86F),
    this.bookInnerBorderColor = const Color(0xFFEAD3A5),
    this.bookShadowStrength = 0.22,
    this.blankPageColor = const Color(0xFFDDDDDD),
    this.loadingBuilder,
    this.onFlipLeftStart,
    this.onFlipLeftEnd,
    this.onFlipRightStart,
    this.onFlipRightEnd,
    this.onZoomStart,
    this.onZoomEnd,
  })  : assert(zooms.length > 0),
        assert(nPolygons > 0),
        assert(ambient >= 0 && ambient <= 1),
        assert(gloss >= 0 && gloss <= 1),
        assert(
          singlePageSlideDuration > Duration.zero,
          'singlePageSlideDuration must be > 0.',
        ),
        assert(bookTopInsetRatio >= 0 && bookTopInsetRatio <= 0.3),
        assert(bookBottomInsetRatio >= 0 && bookBottomInsetRatio <= 0.3),
        assert(bookSideInsetRatio >= 0 && bookSideInsetRatio <= 0.2),
        assert(bookShadowStrength >= 0 && bookShadowStrength <= 1);

  final List<FlipbookPage?> pages;
  final FlipbookController? controller;

  final Duration flipDuration;
  final Duration zoomDuration;
  final List<double> zooms;

  final double perspective;
  final int nPolygons;
  final double ambient;
  final double gloss;
  final double swipeMin;

  final bool singlePage;
  final FlipbookForwardDirection forwardDirection;
  final bool centering;
  final int? startPage;
  final double flipThreshold;

  final bool allowPageWidgetGestures;
  final bool tapToFlip;
  final bool clickToZoom;
  final bool dragToFlip;
  final bool dragToScroll;
  final FlipbookWheelMode wheel;
  final bool clipToViewport;
  final bool singlePageSpreadNavigation;
  final Duration singlePageSlideDuration;

  final Color paperColor;
  final bool bookChrome;
  final double bookTopInsetRatio;
  final double bookBottomInsetRatio;
  final double bookSideInsetRatio;
  final TextStyle? bookHeaderStyle;
  final TextStyle? bookFooterStyle;
  final Color bookHeaderFooterColor;
  final Color bookBorderColor;
  final Color bookInnerBorderColor;
  final double bookShadowStrength;
  final Color blankPageColor;
  final WidgetBuilder? loadingBuilder;

  final FlipbookPageCallback? onFlipLeftStart;
  final FlipbookPageCallback? onFlipLeftEnd;
  final FlipbookPageCallback? onFlipRightStart;
  final FlipbookPageCallback? onFlipRightEnd;
  final FlipbookZoomCallback? onZoomStart;
  final FlipbookZoomCallback? onZoomEnd;

  @override
  State<RealisticFlipbook> createState() => _RealisticFlipbookState();
}

class _RealisticFlipbookState extends State<RealisticFlipbook>
    with TickerProviderStateMixin {
  static const String _buildTag = 'flipbook_local_2026_02_13_r48';
  static const Duration _widgetSnapshotRefreshInterval = Duration(
    milliseconds: 1200,
  );
  Size _viewSize = Size.zero;
  double? _imageWidth;
  double? _imageHeight;

  int _displayedPages = 1;
  int _currentPage = 0;
  int _firstPage = 0;
  int _secondPage = 1;

  int _zoomIndex = 0;
  double _zoom = 1;
  bool _zooming = false;

  Offset? _touchStart;
  Offset? _lastTouch;
  double _dragDx = 0;
  double _dragDy = 0;
  double _maxMove = 0;
  MouseCursor? _activeCursor;

  double _startScrollLeft = 0;
  double _startScrollTop = 0;
  double _scrollLeft = 0;
  double _scrollTop = 0;

  double _lastBoundingLeft = 0;
  double _lastBoundingRight = 0;
  double _lastPageHeight = 0;
  double _lastYMargin = 0;
  double _currentCenterOffset = 0;
  bool _centerOffsetInitialized = false;

  bool _didApplyStartPage = false;

  final _flip = _FlipState();
  final _slide = _SlideState();

  late final AnimationController _flipProgressController;
  late final AnimationController _zoomController;

  double _zoomAnimStart = 1;
  double _zoomAnimEnd = 1;
  double _zoomScrollStartX = 0;
  double _zoomScrollStartY = 0;
  double _zoomScrollEndX = 0;
  double _zoomScrollEndY = 0;

  ImageStream? _metricStream;
  ImageStreamListener? _metricListener;
  final Map<int, GlobalKey> _widgetCaptureKeys = <int, GlobalKey>{};
  final Map<int, ui.Image> _widgetSnapshotProviders = <int, ui.Image>{};
  final Set<int> _widgetSnapshotQueued = <int>{};
  final Set<int> _widgetSnapshotInFlight = <int>{};
  final Map<int, DateTime> _widgetSnapshotUpdatedAt = <int, DateTime>{};
  double _lastWidgetCaptureWidth = 0;
  double _lastWidgetCaptureHeight = 0;
  int? _rawActivePointer;
  Offset? _rawLastLocal;
  VelocityTracker? _rawVelocityTracker;
  final Set<int> _preFlipCapturePages = <int>{};
  bool _flipPreparationInProgress = false;
  int _flipPreparationToken = 0;
  _FlipDirection? _pendingFlipDirection;
  bool _pendingFlipAuto = false;
  int? _pendingFlipFrontPage;
  int? _pendingFlipBackPage;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint('RealisticFlipbook buildTag=$_buildTag');
    }
    _flipProgressController = AnimationController(
      vsync: this,
      lowerBound: 0,
      upperBound: 1,
      value: 0,
    )..addListener(_onFlipProgressTick);
    _zoomController = AnimationController(vsync: this)
      ..addListener(_onZoomTick)
      ..addStatusListener(_onZoomStatus);
    _zoom = _zooms.first;
    widget.controller?._attach(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveFirstImageSize();
    _preloadImages();
  }

  @override
  void didUpdateWidget(covariant RealisticFlipbook oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }

    if (!listEquals(oldWidget.pages, widget.pages)) {
      _imageWidth = null;
      _imageHeight = null;
      _didApplyStartPage = false;
      _widgetSnapshotProviders.clear();
      _widgetCaptureKeys.clear();
      _widgetSnapshotQueued.clear();
      _widgetSnapshotInFlight.clear();
      _widgetSnapshotUpdatedAt.clear();
      _lastWidgetCaptureWidth = 0;
      _lastWidgetCaptureHeight = 0;
      _resolveFirstImageSize();
      _fixFirstPage();
      _syncCurrentPages();
      _preloadImages();
    }

    if (!listEquals(oldWidget.zooms, widget.zooms)) {
      _zoomIndex = _zoomIndex.clamp(0, _zooms.length - 1);
      _zoom = _zooms[_zoomIndex];
    }

    if (oldWidget.startPage != widget.startPage) {
      _didApplyStartPage = false;
      _goToPage(widget.startPage);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _detachMetricListener();
    for (final image in _widgetSnapshotProviders.values) {
      try {
        image.dispose();
      } catch (_) {}
    }
    _widgetSnapshotProviders.clear();
    _widgetCaptureKeys.clear();
    _widgetSnapshotQueued.clear();
    _widgetSnapshotInFlight.clear();
    _widgetSnapshotUpdatedAt.clear();
    _lastWidgetCaptureWidth = 0;
    _lastWidgetCaptureHeight = 0;
    _clearFlipPreparationState(invalidateToken: false);
    _flipProgressController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  List<double> get _zooms =>
      widget.zooms.isEmpty ? const <double>[1] : widget.zooms;

  double get _viewWidth => _viewSize.width;
  double get _viewHeight => _viewSize.height;

  bool get _canZoomIn => !_zooming && _zoomIndex < _zooms.length - 1;
  bool get _canZoomOut => !_zooming && _zoomIndex > 0;

  int get _numPages => widget.pages.isNotEmpty && widget.pages.first == null
      ? widget.pages.length - 1
      : widget.pages.length;

  int get _publicPage {
    if (widget.pages.isNotEmpty && widget.pages.first != null) {
      return _currentPage + 1;
    }
    return math.max(1, _currentPage);
  }

  bool get _navigationInProgress =>
      _flip.direction != null || _slide.direction != null;

  bool get _canGoForward =>
      !_navigationInProgress &&
      _currentPage < widget.pages.length - _displayedPages;

  bool get _canGoBack =>
      !_navigationInProgress &&
      _currentPage >= _displayedPages &&
      !(_displayedPages == 1 && !_hasRenderablePage(_firstPage - 1));

  bool get _canFlipLeft =>
      widget.forwardDirection == FlipbookForwardDirection.left
          ? _canGoForward
          : _canGoBack;

  bool get _canFlipRight =>
      widget.forwardDirection == FlipbookForwardDirection.right
          ? _canGoForward
          : _canGoBack;

  int get _leftPage =>
      widget.forwardDirection == FlipbookForwardDirection.right ||
              _displayedPages == 1
          ? _firstPage
          : _secondPage;

  int get _rightPage => widget.forwardDirection == FlipbookForwardDirection.left
      ? _firstPage
      : _secondPage;

  bool get _showLeftPage => _hasRenderablePage(_leftPage);
  bool get _showRightPage =>
      _hasRenderablePage(_rightPage) && _displayedPages == 2;

  bool _pageHasContent(int pageIndex) {
    final page = _pageData(pageIndex);
    if (page == null) {
      return false;
    }
    return page.image != null || page.widgetBuilder != null;
  }

  MouseCursor get _cursor {
    if (_activeCursor != null) {
      return _activeCursor!;
    }
    if (widget.clickToZoom && _canZoomIn) {
      return SystemMouseCursors.zoomIn;
    }
    if (widget.clickToZoom && _canZoomOut) {
      return SystemMouseCursors.zoomOut;
    }
    if (widget.dragToFlip) {
      return SystemMouseCursors.grab;
    }
    return SystemMouseCursors.basic;
  }

  _FlipDirection get _forwardDirection =>
      widget.forwardDirection == FlipbookForwardDirection.right
          ? _FlipDirection.right
          : _FlipDirection.left;

  bool get _singleSpreadNavigationEnabled =>
      widget.singlePageSpreadNavigation && _displayedPages == 1;

  bool _isRightSidePage(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= widget.pages.length) {
      return false;
    }
    if (!_pageHasContent(pageIndex)) {
      return false;
    }
    final pageNumber = widget.pages.isNotEmpty && widget.pages.first == null
        ? pageIndex
        : pageIndex + 1;
    return pageNumber.isOdd;
  }

  bool _isForwardStartSidePage(int pageIndex) {
    final isRight = _isRightSidePage(pageIndex);
    if (widget.forwardDirection == FlipbookForwardDirection.left) {
      return isRight;
    }
    return !isRight;
  }

  bool _shouldUseSinglePageSlide(_FlipDirection direction) {
    if (!_singleSpreadNavigationEnabled) {
      return false;
    }
    final isForward = direction == _forwardDirection;
    final isStartSide = _isForwardStartSidePage(_currentPage);
    return isForward ? isStartSide : !isStartSide;
  }

  double _singleSideFactorForPage(int pageIndex) {
    return _isRightSidePage(pageIndex) ? 1.0 : 0.0;
  }

  int _singleSpreadAnchorPage() {
    if (_slide.direction != null && _slide.fromPage != null) {
      return _slide.fromPage!;
    }
    if (_flip.direction != null) {
      final back = _flip.backPage;
      if (back != null && back >= 0 && back < widget.pages.length) {
        return back;
      }
      final front = _flip.frontPage;
      if (front != null && front >= 0 && front < widget.pages.length) {
        return front;
      }
    }
    return _currentPage;
  }

  int _singleSpreadLeftPage(int anchorPage) {
    return _isRightSidePage(anchorPage) ? anchorPage + 1 : anchorPage;
  }

  int _singleSpreadRightPage(int anchorPage) {
    return _isRightSidePage(anchorPage) ? anchorPage : anchorPage - 1;
  }

  int _oppositeSidePage(int pageIndex) {
    return _isRightSidePage(pageIndex) ? pageIndex + 1 : pageIndex - 1;
  }

  bool _hasRenderablePage(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= widget.pages.length) {
      return false;
    }
    return _pageHasContent(pageIndex);
  }

  double _singleSpreadCameraFactor() {
    if (!_singleSpreadNavigationEnabled) {
      return 0;
    }
    if (_slide.direction != null &&
        _slide.fromPage != null &&
        _slide.toPage != null) {
      final from = _singleSideFactorForPage(_slide.fromPage!);
      final to = _singleSideFactorForPage(_slide.toPage!);
      final t = Curves.easeInOut.transform(
        _slide.progress.clamp(0.0, 1.0).toDouble(),
      );
      return from + (to - from) * t;
    }
    if (_flip.direction != null) {
      final fromPage = _flip.frontPage ?? _currentPage;
      final toPage = _flip.backPage ?? fromPage;
      final from = _singleSideFactorForPage(fromPage);
      final to = _singleSideFactorForPage(toPage);
      final t = Curves.easeInOut.transform(
        _flip.progress.clamp(0.0, 1.0).toDouble(),
      );
      return from + (to - from) * t;
    }
    return _singleSideFactorForPage(_currentPage);
  }

  double get _pageScale {
    final imageWidth = _imageWidth;
    final imageHeight = _imageHeight;
    if (imageWidth == null ||
        imageHeight == null ||
        _viewWidth <= 0 ||
        _viewHeight <= 0) {
      return 1;
    }
    final vw = _viewWidth / _displayedPages;
    final xScale = vw / imageWidth;
    final yScale = _viewHeight / imageHeight;
    final scale = xScale < yScale ? xScale : yScale;
    return scale < 1 ? scale : 1;
  }

  double get _pageWidth => (_imageWidth ?? 1) * _pageScale;
  double get _pageHeight => (_imageHeight ?? 1) * _pageScale;
  double get _xMargin => (_viewWidth - _pageWidth * _displayedPages) / 2;
  double get _yMargin => (_viewHeight - _pageHeight) / 2;

  double get _polygonWidthRaw {
    final base = _pageWidth / widget.nPolygons;
    return (base + 1 / _zoom).ceilToDouble();
  }

  double get _scrollLeftMin {
    if (_viewWidth <= 0) {
      return 0;
    }
    final width = math.max(0, _lastBoundingRight - _lastBoundingLeft) * _zoom;
    if (width < _viewWidth) {
      return (_lastBoundingLeft + _currentCenterOffset) * _zoom -
          (_viewWidth - width) / 2;
    }
    return (_lastBoundingLeft + _currentCenterOffset) * _zoom;
  }

  double get _scrollLeftMax {
    if (_viewWidth <= 0) {
      return 0;
    }
    final width = math.max(0, _lastBoundingRight - _lastBoundingLeft) * _zoom;
    if (width < _viewWidth) {
      return (_lastBoundingLeft + _currentCenterOffset) * _zoom -
          (_viewWidth - width) / 2;
    }
    return (_lastBoundingRight + _currentCenterOffset) * _zoom - _viewWidth;
  }

  double get _scrollTopMin {
    if (_viewHeight <= 0) {
      return 0;
    }
    final height = _lastPageHeight * _zoom;
    if (height < _viewHeight) {
      return _lastYMargin * _zoom - (_viewHeight - height) / 2;
    }
    return _lastYMargin * _zoom;
  }

  double get _scrollTopMax {
    if (_viewHeight <= 0) {
      return 0;
    }
    final height = _lastPageHeight * _zoom;
    if (height < _viewHeight) {
      return _lastYMargin * _zoom - (_viewHeight - height) / 2;
    }
    return (_lastYMargin + _lastPageHeight) * _zoom - _viewHeight;
  }

  double get _scrollLeftLimited {
    final minValue = _scrollLeftMin;
    final maxValue = _scrollLeftMax;
    final low = math.min(minValue, maxValue);
    final high = math.max(minValue, maxValue);
    return _scrollLeft.clamp(low, high).toDouble();
  }

  double get _scrollTopLimited {
    final minValue = _scrollTopMin;
    final maxValue = _scrollTopMax;
    final low = math.min(minValue, maxValue);
    final high = math.max(minValue, maxValue);
    return _scrollTop.clamp(low, high).toDouble();
  }

  void _clampScroll() {
    _scrollLeft = _scrollLeftLimited;
    _scrollTop = _scrollTopLimited;
  }

  void _resetNavigationIfStuck() {
    if (_flipProgressController.isAnimating) {
      return;
    }
    final flipStuck = _flip.direction != null && _flip.progress <= 0.0001;
    final slideStuck = _slide.direction != null && _slide.progress <= 0.0001;
    if (!flipStuck && !slideStuck) {
      return;
    }
    _flip.direction = null;
    _flip.progress = 0;
    _flip.frontPage = null;
    _flip.backPage = null;

    _flip.frontProvider = null;

    _flip.backProvider = null;
    _flip.auto = false;
    _slide.direction = null;
    _slide.progress = 0;
    _slide.fromPage = null;
    _slide.toPage = null;
    _slide.auto = false;
    _flipProgressController.value = 0;
    _clearFlipPreparationState(invalidateToken: false);
  }

  void _updateLayoutForSize(Size size) {
    _resetNavigationIfStuck();
    if (size == _viewSize) {
      return;
    }
    _viewSize = size;
    final displayedPages =
        size.width > size.height && !widget.singlePage ? 2 : 1;
    if (displayedPages != _displayedPages) {
      _flipProgressController.stop();
      _flip.direction = null;
      _flip.progress = 0;
      _flip.frontPage = null;
      _flip.backPage = null;

      _flip.frontProvider = null;

      _flip.backProvider = null;
      _flip.auto = false;
      _slide.direction = null;
      _slide.progress = 0;
      _slide.fromPage = null;
      _slide.toPage = null;
      _slide.auto = false;
      _flipProgressController.value = 0;
      _clearFlipPreparationState(invalidateToken: false);
      _displayedPages = displayedPages;
      if (_displayedPages == 2) {
        _currentPage &= ~1;
      }
      _fixFirstPage();
      _syncCurrentPages();
    }
    if (!_didApplyStartPage) {
      _goToPage(widget.startPage, notify: false);
      _didApplyStartPage = true;
    }
    _clampScroll();
  }

  void _syncCurrentPages() {
    _firstPage = _currentPage;
    _secondPage = _currentPage + 1;
  }

  void _fixFirstPage() {
    if (_displayedPages == 1 &&
        _currentPage == 0 &&
        widget.pages.isNotEmpty &&
        !_hasRenderablePage(0)) {
      _currentPage++;
    }
  }

  FlipbookPage? _pageData(int page) {
    if (page < 0 || page >= widget.pages.length) {
      return null;
    }
    return widget.pages[page];
  }

  bool _pageIsWidget(int page) => _pageData(page)?.widgetBuilder != null;

  bool _pageRequiresWidgetSnapshot(int page) {
    final pageData = _pageData(page);
    if (pageData == null || pageData.widgetBuilder == null) {
      return false;
    }
    return true;
  }

  ImageProvider? _pageStaticProvider(FlipbookPage pageData,
      {bool hiRes = false}) {
    if (hiRes && _zoom > 1 && !_zooming && pageData.hiResImage != null) {
      return pageData.hiResImage;
    }
    return pageData.image;
  }

  ImageProvider? _pageProvider(int page, {bool hiRes = false}) {
    final pageData = _pageData(page);
    if (pageData == null) {
      return null;
    }
    return _pageStaticProvider(pageData, hiRes: hiRes);
  }

  ui.Image? _pageRawImage(int page) {
    if (!_pageIsWidget(page)) {
      return null;
    }
    return _widgetSnapshotProviders[page];
  }

  void _goToPage(int? page, {bool notify = true}) {
    if (page == null || page == _publicPage) {
      return;
    }

    void apply() {
      if (widget.pages.isNotEmpty && widget.pages.first == null) {
        if (_displayedPages == 2 && page == 1) {
          _currentPage = 0;
        } else {
          _currentPage = page;
        }
      } else {
        _currentPage = page - 1;
      }
      _flip.direction = null;
      _flip.progress = 0;
      _flip.frontPage = null;
      _flip.backPage = null;

      _flip.frontProvider = null;

      _flip.backProvider = null;
      _flip.auto = false;
      _slide.direction = null;
      _slide.progress = 0;
      _slide.fromPage = null;
      _slide.toPage = null;
      _slide.auto = false;
      _flipProgressController.value = 0;
      _clearFlipPreparationState(invalidateToken: false);
      _syncCurrentPages();
      _preloadImages();
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _resolveFirstImageSize() {
    if (_imageWidth != null && _imageHeight != null) {
      return;
    }
    final provider = _firstImageProvider();
    if (provider == null) {
      final sizeHint = _firstSizeHint();
      final fallback = sizeHint ?? const Size(1000, 1414);
      setState(() {
        _imageWidth = fallback.width;
        _imageHeight = fallback.height;
      });
      return;
    }

    final stream = provider.resolve(createLocalImageConfiguration(context));
    _detachMetricListener();
    _metricStream = stream;
    _metricListener = ImageStreamListener((info, _) {
      if (!mounted) {
        return;
      }
      setState(() {
        _imageWidth = info.image.width.toDouble();
        _imageHeight = info.image.height.toDouble();
      });
      _preloadImages();
      _detachMetricListener();
    });
    stream.addListener(_metricListener!);
  }

  void _detachMetricListener() {
    final stream = _metricStream;
    final listener = _metricListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _metricStream = null;
    _metricListener = null;
  }

  ImageProvider? _firstImageProvider() {
    for (final page in widget.pages) {
      final provider = page?.image;
      if (provider != null) {
        return provider;
      }
    }
    return null;
  }

  Size? _firstSizeHint() {
    for (final page in widget.pages) {
      final hint = page?.sizeHint;
      if (hint != null && hint.width > 0 && hint.height > 0) {
        return hint;
      }
    }
    return null;
  }

  void _preloadImages([bool hiRes = false]) {
    if (!mounted) {
      return;
    }
    _pruneWidgetSnapshotCache();
    for (int i = _currentPage - 3; i <= _currentPage + 3; i++) {
      final provider = _pageProvider(i);
      if (provider != null) {
        unawaited(_precache(provider));
      }
    }
    if (hiRes) {
      for (int i = _currentPage; i < _currentPage + _displayedPages; i++) {
        final provider = _pageProvider(i, hiRes: true);
        if (provider != null) {
          unawaited(_precache(provider));
        }
      }
    }
    _requestWidgetSnapshots(_widgetCaptureCandidates());
  }

  Future<void> _precache(ImageProvider provider) async {
    try {
      await precacheImage(provider, context);
    } catch (_) {
      // Ignore preload errors to keep page rendering non-blocking.
    }
  }

  GlobalKey _captureKeyForPage(int page) {
    return _widgetCaptureKeys.putIfAbsent(
      page,
      () => GlobalKey(debugLabel: 'flipbook_capture_$page'),
    );
  }

  Set<int> _widgetCaptureCandidates() {
    final candidates = <int>{};
    void add(int? page) {
      if (page == null || page < 0 || page >= widget.pages.length) {
        return;
      }
      if (_pageIsWidget(page)) {
        candidates.add(page);
      }
    }

    for (int i = _currentPage - 1; i <= _currentPage + 1; i++) {
      add(i);
    }
    add(_leftPage);
    add(_rightPage);
    add(_flip.frontPage);
    add(_flip.backPage);
    add(_slide.fromPage);
    add(_slide.toPage);
    for (final page in _preFlipCapturePages) {
      add(page);
    }
    return candidates;
  }

  Set<int> _widgetRefreshTargets() {
    final targets = <int>{};

    void add(int? page) {
      if (page == null || page < 0 || page >= widget.pages.length) {
        return;
      }
      if (_pageIsWidget(page)) {
        targets.add(page);
      }
    }

    add(_leftPage);
    add(_rightPage);
    add(_flip.frontPage);
    add(_flip.backPage);
    add(_slide.fromPage);
    add(_slide.toPage);
    return targets;
  }

  void _requestWidgetSnapshots(
    Iterable<int> pages, {
    bool forceRefresh = false,
    bool refreshStaticFallbackWidgets = false,
    bool ignoreThrottle = false,
  }) {
    if (!mounted) {
      return;
    }
    for (final page in pages) {
      if (!_pageIsWidget(page)) {
        continue;
      }
      if (forceRefresh &&
          !_pageRequiresWidgetSnapshot(page) &&
          !refreshStaticFallbackWidgets) {
        continue;
      }
      if (_widgetSnapshotInFlight.contains(page) ||
          _widgetSnapshotQueued.contains(page)) {
        continue;
      }
      if (!forceRefresh && _widgetSnapshotProviders.containsKey(page)) {
        continue;
      }
      if (!ignoreThrottle &&
          forceRefresh &&
          _widgetSnapshotProviders.containsKey(page)) {
        final updatedAt = _widgetSnapshotUpdatedAt[page];
        if (updatedAt != null &&
            DateTime.now().difference(updatedAt) <
                _widgetSnapshotRefreshInterval) {
          continue;
        }
      }
      _widgetSnapshotQueued.add(page);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _widgetSnapshotQueued.remove(page);
        unawaited(_captureWidgetSnapshot(page));
      });
    }
  }

  Future<void> _refreshWidgetSnapshotAfterPrecache(int page) async {
    if (!mounted || !_pageIsWidget(page)) {
      return;
    }

    final pageData = _pageData(page);
    if (pageData == null) {
      return;
    }

    final staticProvider = _pageStaticProvider(pageData);
    if (staticProvider != null) {
      await _precache(staticProvider);
    }

    if (!mounted) {
      return;
    }

    _requestWidgetSnapshots(
      <int>[page],
      forceRefresh: true,
      refreshStaticFallbackWidgets: true,
      ignoreThrottle: true,
    );
  }

  void _refreshVisibleWidgetSnapshotsAfterNavigation() {
    final targets =
        _widgetCaptureCandidates().where(_pageIsWidget).toList(growable: false);
    if (targets.isEmpty) {
      return;
    }

    for (final page in targets) {
      unawaited(_refreshWidgetSnapshotAfterPrecache(page));
    }
  }

  Future<void> _captureWidgetSnapshot(int page) async {
    if (!mounted ||
        _widgetSnapshotInFlight.contains(page) ||
        !_pageIsWidget(page)) {
      return;
    }
    final key = _widgetCaptureKeys[page];
    final captureContext = key?.currentContext;
    if (captureContext == null) {
      if (_pageRequiresWidgetSnapshot(page)) {
        _requestWidgetSnapshots(<int>[page]);
      }
      return;
    }
    final renderObject = captureContext.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      _requestWidgetSnapshots(<int>[page]);
      return;
    }
    if (renderObject.debugNeedsPaint) {
      _requestWidgetSnapshots(<int>[page]);
      return;
    }

    _widgetSnapshotInFlight.add(page);
    try {
      final devicePixelRatio = View.of(captureContext).devicePixelRatio;
      final pixelRatio = (devicePixelRatio * (_zoom > 1 ? 1.2 : 1.0)).clamp(
        1.0,
        3.0,
      );
      final image = await renderObject.toImage(pixelRatio: pixelRatio);
      if (!mounted) {
        image.dispose();
        return;
      }

      setState(() {
        final old = _widgetSnapshotProviders[page];
        if (old != null) {
          try {
            old.dispose();
          } catch (_) {}
        }
        _widgetSnapshotProviders[page] = image;
        _widgetSnapshotUpdatedAt[page] = DateTime.now();
      });
    } catch (_) {
      // Keep rendering resilient if snapshot capture fails.
    } finally {
      _widgetSnapshotInFlight.remove(page);
    }
  }

  void _pruneWidgetSnapshotCache() {
    final keep = _widgetCaptureCandidates();
    final toRemove = _widgetSnapshotProviders.keys
        .where((k) => !keep.contains(k))
        .toList();

    for (final page in toRemove) {
      final image = _widgetSnapshotProviders[page];
      if (image != null) {
        try {
          image.dispose();
        } catch (_) {}
      }
    }

    _widgetSnapshotProviders.removeWhere((key, _) => !keep.contains(key));
    _widgetCaptureKeys.removeWhere((key, _) => !keep.contains(key));
    _widgetSnapshotQueued.removeWhere((key) => !keep.contains(key));
    _widgetSnapshotInFlight.removeWhere((key) => !keep.contains(key));
    _widgetSnapshotUpdatedAt.removeWhere((key, _) => !keep.contains(key));
  }

  void _queueFlipStartSnapshotRefresh(int? page) {
    if (page == null || !_pageIsWidget(page)) {
      return;
    }
    if (_widgetSnapshotProviders.containsKey(page) ||
        _widgetSnapshotInFlight.contains(page) ||
        _widgetSnapshotQueued.contains(page)) {
      return;
    }
    unawaited(_refreshWidgetSnapshotAfterPrecache(page));
  }

  ({int? frontPage, int? backPage}) _flipPagesForDirection(
    _FlipDirection direction,
  ) {
    int? frontPage;
    int? backPage;

    if (direction != _forwardDirection) {
      if (_displayedPages == 1) {
        frontPage = _currentPage;
        backPage = _currentPage - 1;
      } else {
        frontPage = _firstPage;
        backPage = _currentPage - _displayedPages + 1;
      }
    } else {
      if (_displayedPages == 1) {
        frontPage = _currentPage;
        backPage = _currentPage + 1;
      } else {
        frontPage = _secondPage;
        backPage = _currentPage + _displayedPages;
      }
    }

    return (frontPage: frontPage, backPage: backPage);
  }

  bool _pageNeedsWidgetTexture(int? page) {
    if (page == null || !_pageIsWidget(page)) {
      return false;
    }
    return true;
  }

  bool _pageTextureReadyForFlip(int page) {
    final pageData = _pageData(page);
    if (pageData == null) {
      return false;
    }
    if (pageData.widgetBuilder == null) {
      return true;
    }
    return _widgetSnapshotProviders.containsKey(page);
  }

  Set<int> _criticalPagesNeedingTexture(int? frontPage, int? backPage) {
    final pages = <int>{};
    if (_pageNeedsWidgetTexture(frontPage) && frontPage != null) {
      pages.add(frontPage);
    }
    if (_pageNeedsWidgetTexture(backPage) && backPage != null) {
      pages.add(backPage);
    }
    return pages;
  }

  void _setPreFlipCapturePages(Set<int> pages) {
    final unchanged = pages.length == _preFlipCapturePages.length &&
        _preFlipCapturePages.containsAll(pages);
    if (unchanged) {
      return;
    }
    if (!mounted) {
      _preFlipCapturePages
        ..clear()
        ..addAll(pages);
      return;
    }
    setState(() {
      _preFlipCapturePages
        ..clear()
        ..addAll(pages);
    });
  }

  void _clearFlipPreparationState({
    bool notify = false,
    bool invalidateToken = true,
  }) {
    final hadChanges = _preFlipCapturePages.isNotEmpty ||
        _flipPreparationInProgress ||
        _pendingFlipDirection != null ||
        _pendingFlipFrontPage != null ||
        _pendingFlipBackPage != null;
    if (!hadChanges && !invalidateToken) {
      return;
    }

    void clear() {
      _preFlipCapturePages.clear();
      _flipPreparationInProgress = false;
      _pendingFlipDirection = null;
      _pendingFlipAuto = false;
      _pendingFlipFrontPage = null;
      _pendingFlipBackPage = null;
      if (invalidateToken) {
        _flipPreparationToken += 1;
      }
    }

    if (notify && mounted) {
      setState(clear);
    } else {
      clear();
    }
  }

  Future<bool> _waitForCriticalTextures(Set<int> pages) async {
    if (pages.isEmpty) {
      return true;
    }
    final deadline = DateTime.now().add(const Duration(milliseconds: 280));
    while (mounted) {
      final ready = pages.every(_pageTextureReadyForFlip);
      if (ready) {
        return true;
      }
      if (DateTime.now().isAfter(deadline)) {
        return false;
      }
      _requestWidgetSnapshots(
        pages,
        forceRefresh: true,
        refreshStaticFallbackWidgets: true,
        ignoreThrottle: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    return false;
  }

  Future<void> _beginFlipWithPreparedTextures(
    _FlipDirection direction,
    bool auto,
    int? frontPage,
    int? backPage,
  ) async {
    final capturePages = <int>{
      if (frontPage != null && _pageIsWidget(frontPage)) frontPage,
      if (backPage != null && _pageIsWidget(backPage)) backPage,
    };
    final criticalPages = _criticalPagesNeedingTexture(frontPage, backPage);

    if (_flipPreparationInProgress &&
        _pendingFlipDirection == direction &&
        _pendingFlipAuto == auto &&
        _pendingFlipFrontPage == frontPage &&
        _pendingFlipBackPage == backPage) {
      return;
    }

    _clearFlipPreparationState(invalidateToken: true);
    _flipPreparationInProgress = true;
    _pendingFlipDirection = direction;
    _pendingFlipAuto = auto;
    _pendingFlipFrontPage = frontPage;
    _pendingFlipBackPage = backPage;
    _flipPreparationToken += 1;
    final token = _flipPreparationToken;

    _setPreFlipCapturePages(capturePages);
    if (capturePages.isNotEmpty) {
      _requestWidgetSnapshots(
        capturePages,
        forceRefresh: true,
        refreshStaticFallbackWidgets: true,
        ignoreThrottle: true,
      );
    }

    final ready = await _waitForCriticalTextures(criticalPages);

    if (!mounted || token != _flipPreparationToken) {
      return;
    }
    if (!auto && _touchStart == null) {
      _clearFlipPreparationState(notify: true, invalidateToken: false);
      return;
    }
    if (_flip.direction != null || _slide.direction != null) {
      _clearFlipPreparationState(notify: true, invalidateToken: false);
      return;
    }

    if (frontPage == null || backPage == null) {
      _clearFlipPreparationState(notify: true, invalidateToken: false);
      return;
    }

    _startFlipAnimation(
      direction: direction,
      auto: auto,
      frontPage: frontPage,
      backPage: backPage,
    );
    _continuePreparedDragIfNeeded(direction, auto);

    if (!ready && kDebugMode) {
      debugPrint(
        '_flipStart: textures not fully ready, using live strip fallback where needed',
      );
    }
  }

  void _continuePreparedDragIfNeeded(_FlipDirection direction, bool auto) {
    if (auto || _touchStart == null || _flip.direction != direction) {
      return;
    }
    final progress = direction == _FlipDirection.left
        ? (_dragDx / _pageWidth)
        : (-_dragDx / _pageWidth);
    _flipProgressController.value = progress.clamp(0.0, 1.0).toDouble();
  }

  void _flipLeft({required bool auto}) {
    if (!_canFlipLeft) {
      return;
    }
    _flipStart(_FlipDirection.left, auto);
  }

  void _flipRight({required bool auto}) {
    if (!_canFlipRight) {
      return;
    }
    _flipStart(_FlipDirection.right, auto);
  }

  void _flipStart(_FlipDirection direction, bool auto) {
    if (_slide.direction != null) {
      return;
    }
    if (_shouldUseSinglePageSlide(direction)) {
      _slideStart(direction, auto);
      return;
    }

    final pages = _flipPagesForDirection(direction);
    final frontPage = pages.frontPage;
    final backPage = pages.backPage;
    if (frontPage == null ||
        backPage == null ||
        !_hasRenderablePage(frontPage) ||
        !_hasRenderablePage(backPage)) {
      return;
    }

    final criticalPages = _criticalPagesNeedingTexture(frontPage, backPage);
    if (criticalPages.isNotEmpty) {
      unawaited(
        _beginFlipWithPreparedTextures(direction, auto, frontPage, backPage),
      );
      return;
    }

    _startFlipAnimation(
      direction: direction,
      auto: auto,
      frontPage: frontPage,
      backPage: backPage,
    );
  }

  void _startFlipAnimation({
    required _FlipDirection direction,
    required bool auto,
    required int frontPage,
    required int backPage,
  }) {
    _queueFlipStartSnapshotRefresh(frontPage);
    _queueFlipStartSnapshotRefresh(backPage);

    final frontProvider = _pageProvider(frontPage);
    final backProvider = _pageProvider(backPage);

    _flipProgressController.stop();
    _flipProgressController.value = 0;
    setState(() {
      _clearFlipPreparationState(invalidateToken: false);
      _flip.direction = direction;
      _flip.progress = 0;
      _flip.frontPage = frontPage;
      _flip.backPage = backPage;
      _flip.frontProvider = frontProvider;
      _flip.backProvider = backProvider;
      _flip.auto = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _flip.direction != direction) {
        return;
      }
      setState(() {
        if (_flip.direction != _forwardDirection) {
          if (_displayedPages == 2) {
            _firstPage = _currentPage - _displayedPages;
          } else {
            _firstPage = _currentPage - 1;
          }
        } else {
          if (_displayedPages == 1) {
            _firstPage = _currentPage + _displayedPages;
          } else {
            _secondPage = _currentPage + 1 + _displayedPages;
          }
        }
      });
      if (auto) {
        unawaited(_flipAuto(ease: true));
      }
    });
  }

  void _slideStart(_FlipDirection direction, bool auto) {
    if (!_singleSpreadNavigationEnabled || _flip.direction != null) {
      return;
    }

    final delta = direction == _forwardDirection ? 1 : -1;
    final toPage = _currentPage + delta;
    if (toPage < 0 || toPage >= widget.pages.length) {
      return;
    }
    if (!_hasRenderablePage(toPage)) {
      return;
    }

    _flipProgressController.stop();
    _flipProgressController.value = 0;
    setState(() {
      _slide.direction = direction;
      _slide.progress = 0;
      _slide.fromPage = _currentPage;
      _slide.toPage = toPage;
      _slide.auto = false;
    });

    final targetHiRes = _pageProvider(toPage, hiRes: true);
    if (targetHiRes != null) {
      unawaited(_precache(targetHiRes));
    }

    if (auto) {
      unawaited(_slideAuto(ease: true));
    }
  }

  Future<void> _flipAuto({required bool ease}) async {
    final direction = _flip.direction;
    if (direction == null) {
      return;
    }
    final ratioLeft = (1 - _flip.progress).clamp(0.0, 1.0);
    final durationMs = (widget.flipDuration.inMilliseconds * ratioLeft).round();
    if (durationMs <= 0) {
      _completeFlip(direction);
      return;
    }

    setState(() {
      _flip.auto = true;
    });

    _emitFlipStart(direction);

    try {
      await _flipProgressController.animateTo(
        1,
        duration: Duration(milliseconds: durationMs),
        curve: ease ? Curves.easeInOut : Curves.linear,
      );
    } on TickerCanceled {
      return;
    }

    if (!mounted || _flip.direction != direction) {
      return;
    }
    _completeFlip(direction);
  }

  Future<void> _slideAuto({required bool ease}) async {
    final direction = _slide.direction;
    if (direction == null) {
      return;
    }
    final ratioLeft = (1 - _slide.progress).clamp(0.0, 1.0);
    final durationMs =
        (widget.singlePageSlideDuration.inMilliseconds * ratioLeft).round();
    if (durationMs <= 0) {
      _completeSlide(direction);
      return;
    }

    setState(() {
      _slide.auto = true;
    });

    _emitFlipStart(direction);

    try {
      await _flipProgressController.animateTo(
        1,
        duration: Duration(milliseconds: durationMs),
        curve: ease ? Curves.easeInOut : Curves.linear,
      );
    } on TickerCanceled {
      return;
    }

    if (!mounted || _slide.direction != direction) {
      return;
    }
    _completeSlide(direction);
  }

  Future<void> _flipRevert() async {
    final direction = _flip.direction;
    if (direction == null) {
      return;
    }
    final durationMs =
        (widget.flipDuration.inMilliseconds * _flip.progress).round();
    if (durationMs <= 0) {
      _cancelFlip();
      return;
    }
    setState(() {
      _flip.auto = true;
    });
    try {
      await _flipProgressController.animateBack(
        0,
        duration: Duration(milliseconds: durationMs),
        curve: Curves.linear,
      );
    } on TickerCanceled {
      return;
    }
    if (!mounted || _flip.direction != direction) {
      return;
    }
    _cancelFlip();
  }

  Future<void> _slideRevert() async {
    final direction = _slide.direction;
    if (direction == null) {
      return;
    }
    final durationMs =
        (widget.singlePageSlideDuration.inMilliseconds * _slide.progress)
            .round();
    if (durationMs <= 0) {
      _cancelSlide();
      return;
    }
    setState(() {
      _slide.auto = true;
    });
    try {
      await _flipProgressController.animateBack(
        0,
        duration: Duration(milliseconds: durationMs),
        curve: Curves.linear,
      );
    } on TickerCanceled {
      return;
    }
    if (!mounted || _slide.direction != direction) {
      return;
    }
    _cancelSlide();
  }

  void _completeFlip(_FlipDirection direction) {
    _clearFlipPreparationState(invalidateToken: false);
    setState(() {
      if (direction != _forwardDirection) {
        _currentPage -= _displayedPages;
      } else {
        _currentPage += _displayedPages;
      }
      _syncCurrentPages();
      _flip.direction = null;
      _flip.progress = 0;
      _flip.frontPage = null;
      _flip.backPage = null;

      _flip.frontProvider = null;

      _flip.backProvider = null;
      _flip.opacity = 1;
      _flip.auto = false;
      _slide.direction = null;
      _slide.progress = 0;
      _slide.fromPage = null;
      _slide.toPage = null;
      _slide.auto = false;
      _flipProgressController.value = 0;
    });
    _emitFlipEnd(direction);
    _preloadImages();
    _refreshVisibleWidgetSnapshotsAfterNavigation();
  }

  void _completeSlide(_FlipDirection direction) {
    _clearFlipPreparationState(invalidateToken: false);
    final toPage = _slide.toPage;
    if (toPage == null) {
      _cancelSlide();
      return;
    }
    setState(() {
      _currentPage = toPage;
      _syncCurrentPages();
      _flip.direction = null;
      _flip.progress = 0;
      _flip.frontPage = null;
      _flip.backPage = null;

      _flip.frontProvider = null;

      _flip.backProvider = null;
      _flip.auto = false;
      _slide.direction = null;
      _slide.progress = 0;
      _slide.fromPage = null;
      _slide.toPage = null;
      _slide.auto = false;
      _flipProgressController.value = 0;
    });
    _emitFlipEnd(direction);
    _preloadImages();
    _refreshVisibleWidgetSnapshotsAfterNavigation();
  }

  void _cancelFlip() {
    _clearFlipPreparationState(invalidateToken: false);
    setState(() {
      _firstPage = _currentPage;
      _secondPage = _currentPage + 1;
      _flip.direction = null;
      _flip.progress = 0;
      _flip.frontPage = null;
      _flip.backPage = null;

      _flip.frontProvider = null;

      _flip.backProvider = null;
      _flip.opacity = 1;
      _flip.auto = false;
      _slide.direction = null;
      _slide.progress = 0;
      _slide.fromPage = null;
      _slide.toPage = null;
      _slide.auto = false;
      _flipProgressController.value = 0;
    });
  }

  void _cancelSlide() {
    _clearFlipPreparationState(invalidateToken: false);
    setState(() {
      _slide.direction = null;
      _slide.progress = 0;
      _slide.fromPage = null;
      _slide.toPage = null;
      _slide.auto = false;
      _flipProgressController.value = 0;
    });
  }

  void _emitFlipStart(_FlipDirection direction) {
    if (direction == _FlipDirection.left) {
      widget.onFlipLeftStart?.call(_publicPage);
    } else {
      widget.onFlipRightStart?.call(_publicPage);
    }
  }

  void _emitFlipEnd(_FlipDirection direction) {
    if (direction == _FlipDirection.left) {
      widget.onFlipLeftEnd?.call(_publicPage);
    } else {
      widget.onFlipRightEnd?.call(_publicPage);
    }
  }

  void _onFlipProgressTick() {
    if (!mounted) {
      return;
    }
    final value = _flipProgressController.value.clamp(0.0, 1.0);
    if (_flip.direction != null) {
      if ((value - _flip.progress).abs() < 1e-6) {
        return;
      }
      setState(() {
        _flip.progress = value;
      });
      return;
    }
    if (_slide.direction != null) {
      if ((value - _slide.progress).abs() < 1e-6) {
        return;
      }
      setState(() {
        _slide.progress = value;
      });
    }
  }

  void _zoomIn([Offset? zoomAt]) {
    if (!_canZoomIn) {
      return;
    }
    setState(() {
      _zoomIndex += 1;
    });
    _zoomTo(_zooms[_zoomIndex], zoomAt);
  }

  void _zoomOut([Offset? zoomAt]) {
    if (!_canZoomOut) {
      return;
    }
    setState(() {
      _zoomIndex -= 1;
    });
    _zoomTo(_zooms[_zoomIndex], zoomAt);
  }

  void _zoomAt(Offset zoomAt) {
    if (_zooms.length <= 1) {
      return;
    }
    setState(() {
      _zoomIndex = (_zoomIndex + 1) % _zooms.length;
    });
    _zoomTo(_zooms[_zoomIndex], zoomAt);
  }

  void _zoomTo(double zoom, [Offset? zoomAt]) {
    if (_viewWidth <= 0 || _viewHeight <= 0) {
      return;
    }
    final fixedX = zoomAt?.dx ?? _viewWidth / 2;
    final fixedY = zoomAt?.dy ?? _viewHeight / 2;
    final start = _zoom;
    final end = zoom;
    final startX = _scrollLeftLimited;
    final startY = _scrollTopLimited;
    final containerFixedX = fixedX + startX;
    final containerFixedY = fixedY + startY;
    final endX = containerFixedX / start * end - fixedX;
    final endY = containerFixedY / start * end - fixedY;

    _zoomAnimStart = start;
    _zoomAnimEnd = end;
    _zoomScrollStartX = startX;
    _zoomScrollStartY = startY;
    _zoomScrollEndX = endX;
    _zoomScrollEndY = endY;

    _zoomController.stop();
    _zoomController.duration = widget.zoomDuration;
    setState(() {
      _zooming = true;
    });
    widget.onZoomStart?.call(end);
    _zoomController.forward(from: 0);

    if (end > 1) {
      _preloadImages(true);
    }
  }

  void _onZoomTick() {
    if (!mounted || !_zooming) {
      return;
    }
    final ratio = Curves.easeInOut.transform(_zoomController.value);
    setState(() {
      _zoom = _zoomAnimStart + (_zoomAnimEnd - _zoomAnimStart) * ratio;
      _scrollLeft =
          _zoomScrollStartX + (_zoomScrollEndX - _zoomScrollStartX) * ratio;
      _scrollTop =
          _zoomScrollStartY + (_zoomScrollEndY - _zoomScrollStartY) * ratio;
      _clampScroll();
    });
  }

  void _onZoomStatus(AnimationStatus status) {
    if (!mounted || !_zooming) {
      return;
    }
    if (status != AnimationStatus.completed) {
      return;
    }
    setState(() {
      _zooming = false;
      _zoom = _zoomAnimEnd;
      _scrollLeft = _zoomScrollEndX;
      _scrollTop = _zoomScrollEndY;
      _clampScroll();
    });
    widget.onZoomEnd?.call(_zoomAnimEnd);
  }

  void _onTapUp(TapUpDetails details) {
    if (!widget.tapToFlip && !widget.clickToZoom) {
      return;
    }
    if (_zoom > 1) {
      if (widget.clickToZoom) {
        final local = Offset(
          details.localPosition.dx + _lastBoundingLeft,
          details.localPosition.dy + _lastYMargin,
        );
        _zoomAt(local);
      }
      return;
    }

    final xInViewport = details.localPosition.dx + _lastBoundingLeft;
    bool didFlip = false;
    if (widget.tapToFlip) {
      if (xInViewport < _viewWidth / 2) {
        if (_canFlipLeft) {
          _flipLeft(auto: true);
          didFlip = true;
        }
      } else {
        if (_canFlipRight) {
          _flipRight(auto: true);
          didFlip = true;
        }
      }
    }

    if (!didFlip && widget.clickToZoom) {
      final local = Offset(
        details.localPosition.dx + _lastBoundingLeft,
        details.localPosition.dy + _lastYMargin,
      );
      _zoomAt(local);
    }
  }

  Offset _toBookLocal(Offset localPosition) {
    return Offset(
      localPosition.dx + _lastBoundingLeft,
      localPosition.dy + _lastYMargin,
    );
  }

  Offset _viewportToContentLocal(Offset viewportLocal) {
    return Offset(
      (viewportLocal.dx + _scrollLeft) / _zoom,
      (viewportLocal.dy + _scrollTop) / _zoom,
    );
  }

  Offset? _tryGetOverlayLocalFromViewport(Offset viewportLocal) {
    final contentLocal = _viewportToContentLocal(viewportLocal);
    if (contentLocal.dx < _lastBoundingLeft ||
        contentLocal.dx > _lastBoundingRight ||
        contentLocal.dy < _lastYMargin ||
        contentLocal.dy > _lastYMargin + _lastPageHeight) {
      return null;
    }
    return Offset(
      contentLocal.dx - _lastBoundingLeft,
      contentLocal.dy - _lastYMargin,
    );
  }

  void _startSwipe(Offset local) {
    _resetNavigationIfStuck();
    _touchStart = local;
    _lastTouch = local;
    _dragDx = 0;
    _dragDy = 0;
    _maxMove = 0;
    if (_zoom <= 1) {
      if (widget.dragToFlip) {
        setState(() {
          _activeCursor = SystemMouseCursors.grab;
        });
      }
    } else {
      _startScrollLeft = _scrollLeftLimited;
      _startScrollTop = _scrollTopLimited;
      setState(() {
        _activeCursor = SystemMouseCursors.allScroll;
      });
    }
  }

  void _updateSwipe(Offset delta) {
    final start = _touchStart;
    if (start == null) {
      return;
    }
    _dragDx += delta.dx;
    _dragDy += delta.dy;

    final local = Offset(start.dx + _dragDx, start.dy + _dragDy);
    _lastTouch = local;
    final x = _dragDx;
    final y = _dragDy;
    _maxMove = math.max(_maxMove, x.abs());
    _maxMove = math.max(_maxMove, y.abs());

    if (_zoom > 1) {
      if (widget.dragToScroll) {
        setState(() {
          _scrollLeft = _startScrollLeft - x;
          _scrollTop = _startScrollTop - y;
          _clampScroll();
        });
      }
      return;
    }

    if (!widget.dragToFlip) {
      return;
    }
    if (_flip.direction == null &&
        _slide.direction == null &&
        y.abs() > x.abs()) {
      return;
    }

    setState(() {
      _activeCursor = SystemMouseCursors.grabbing;
    });

    if (x > 0) {
      if (_flip.direction == null && _canFlipLeft && x >= widget.swipeMin) {
        _flipStart(_FlipDirection.left, false);
      }
      if (_flip.direction == _FlipDirection.left) {
        final progress = (x / _pageWidth).clamp(0.0, 1.0).toDouble();
        _flipProgressController.value = progress;
      } else if (_slide.direction == _FlipDirection.left) {
        final progress = (x / _pageWidth).clamp(0.0, 1.0).toDouble();
        _flipProgressController.value = progress;
      }
    } else {
      if (_flip.direction == null && _canFlipRight && x <= -widget.swipeMin) {
        _flipStart(_FlipDirection.right, false);
      }
      if (_flip.direction == _FlipDirection.right) {
        final progress = (-x / _pageWidth).clamp(0.0, 1.0).toDouble();
        _flipProgressController.value = progress;
      } else if (_slide.direction == _FlipDirection.right) {
        final progress = (-x / _pageWidth).clamp(0.0, 1.0).toDouble();
        _flipProgressController.value = progress;
      }
    }
  }

  void _onPanStart(DragStartDetails details) {
    _startSwipe(_toBookLocal(details.localPosition));
    _requestWidgetSnapshots(
      _widgetCaptureCandidates(),
      forceRefresh: true,
      refreshStaticFallbackWidgets: true,
      ignoreThrottle: true,
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _updateSwipe(details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    _endSwipeGesture(details.velocity.pixelsPerSecond.dx);
  }

  void _onPanCancel() {
    _endSwipeGesture(0);
  }

  void _onRawPointerDown(PointerDownEvent event) {
    if (!widget.dragToFlip && !(_zoom > 1 && widget.dragToScroll)) {
      return;
    }
    if (_rawActivePointer != null) {
      return;
    }
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons != kPrimaryMouseButton) {
      return;
    }
    final overlayLocal = _tryGetOverlayLocalFromViewport(event.localPosition);
    if (overlayLocal == null) {
      return;
    }
    _rawActivePointer = event.pointer;
    _rawLastLocal = _toBookLocal(overlayLocal);
    _rawVelocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
    _startSwipe(_rawLastLocal!);
    _requestWidgetSnapshots(
      _widgetCaptureCandidates(),
      forceRefresh: true,
      refreshStaticFallbackWidgets: true,
      ignoreThrottle: true,
    );
  }

  void _onRawPointerMove(PointerMoveEvent event) {
    if (event.pointer != _rawActivePointer) {
      return;
    }
    final previousLocal = _rawLastLocal;
    if (previousLocal == null) {
      return;
    }
    final overlayLocal = _tryGetOverlayLocalFromViewport(event.localPosition);
    if (overlayLocal == null) {
      return;
    }
    final local = _toBookLocal(overlayLocal);
    _rawLastLocal = local;
    _rawVelocityTracker?.addPosition(event.timeStamp, event.position);
    _updateSwipe(local - previousLocal);
  }

  void _onRawPointerUp(PointerUpEvent event) {
    if (event.pointer != _rawActivePointer) {
      return;
    }
    _rawVelocityTracker?.addPosition(event.timeStamp, event.position);
    final velocityX =
        _rawVelocityTracker?.getVelocity().pixelsPerSecond.dx ?? 0;
    _clearRawPointerState();
    _endSwipeGesture(velocityX);
  }

  void _onRawPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _rawActivePointer) {
      return;
    }
    _clearRawPointerState();
    _endSwipeGesture(0);
  }

  void _clearRawPointerState() {
    _rawActivePointer = null;
    _rawLastLocal = null;
    _rawVelocityTracker = null;
  }

  void _endSwipeGesture(double velocityX) {
    if (_touchStart == null) {
      return;
    }

    if (!widget.allowPageWidgetGestures &&
        widget.clickToZoom &&
        _maxMove < widget.swipeMin &&
        _lastTouch != null) {
      _zoomAt(_lastTouch!);
    }

    if (_flipPreparationInProgress &&
        _flip.direction == null &&
        _slide.direction == null) {
      _clearFlipPreparationState(invalidateToken: true);
    }

    if (_slide.direction != null && !_slide.auto) {
      const velocityThreshold = 700.0;
      final forwardFling = _slide.direction == _FlipDirection.left
          ? velocityX > velocityThreshold
          : velocityX < -velocityThreshold;
      if (_slide.progress >= widget.flipThreshold || forwardFling) {
        unawaited(_slideAuto(ease: false));
      } else {
        unawaited(_slideRevert());
      }
    } else if (_flip.direction != null && !_flip.auto) {
      const velocityThreshold = 700.0;
      final forwardFling = _flip.direction == _FlipDirection.left
          ? velocityX > velocityThreshold
          : velocityX < -velocityThreshold;
      if (_flip.progress >= widget.flipThreshold || forwardFling) {
        unawaited(_flipAuto(ease: false));
      } else {
        unawaited(_flipRevert());
      }
    }

    setState(() {
      _touchStart = null;
      _lastTouch = null;
      _activeCursor = null;
    });
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }
    if (widget.wheel == FlipbookWheelMode.scroll &&
        _zoom > 1 &&
        widget.dragToScroll) {
      setState(() {
        _scrollLeft += event.scrollDelta.dx;
        _scrollTop += event.scrollDelta.dy;
        _clampScroll();
      });
      return;
    }

    if (widget.wheel == FlipbookWheelMode.zoom) {
      if (event.scrollDelta.dy >= 100) {
        _zoomOut(event.localPosition);
      } else if (event.scrollDelta.dy <= -100) {
        _zoomIn(event.localPosition);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _updateLayoutForSize(size);
        if (_imageWidth == null || _imageHeight == null) {
          _resolveFirstImageSize();
          return _buildLoading();
        }

        final pageWidth = _pageWidth;
        final pageHeight = _pageHeight;
        final xMargin = _xMargin;
        final yMargin = _yMargin;
        final polygonWidth = _polygonWidthRaw;
        if ((pageWidth - _lastWidgetCaptureWidth).abs() > 0.5 ||
            (pageHeight - _lastWidgetCaptureHeight).abs() > 0.5) {
          _lastWidgetCaptureWidth = pageWidth;
          _lastWidgetCaptureHeight = pageHeight;
          _widgetSnapshotProviders.clear();
          _widgetSnapshotQueued.clear();
          _widgetSnapshotInFlight.clear();
          _widgetSnapshotUpdatedAt.clear();
        }

        final polygonFrame = _buildPolygonFrame(
          pageWidth: pageWidth,
          pageHeight: pageHeight,
          xMargin: xMargin,
          yMargin: yMargin,
          polygonWidth: polygonWidth,
        );

        final useSingleSpreadLayout = _singleSpreadNavigationEnabled;
        final singleCameraFactor =
            useSingleSpreadLayout ? _singleSpreadCameraFactor() : 0.0;
        final singleLeftPos = xMargin - singleCameraFactor * pageWidth;
        final singleRightPos = xMargin + (1 - singleCameraFactor) * pageWidth;
        final singleAnchorPage =
            useSingleSpreadLayout ? _singleSpreadAnchorPage() : _currentPage;
        var singleLeftPage = _singleSpreadLeftPage(singleAnchorPage);
        var singleRightPage = _singleSpreadRightPage(singleAnchorPage);

        // In single-page spread mode, keep background slots consistent with a
        // real book while a page is turning:
        // - destination side keeps the old opposite page
        // - source side reveals the new opposite page.
        if (useSingleSpreadLayout) {
          final front = _flip.frontPage;
          final back = _flip.backPage;
          if (_flip.direction != null && front != null && back != null) {
            final oldOpposite = _oppositeSidePage(front);
            final newOpposite = _oppositeSidePage(back);
            final frontIsRight = _isRightSidePage(front);
            if (frontIsRight) {
              singleLeftPage = oldOpposite;
              singleRightPage = newOpposite;
            } else {
              singleLeftPage = newOpposite;
              singleRightPage = oldOpposite;
            }
          }
        }

        final showSingleLeft = !useSingleSpreadLayout
            ? _showLeftPage
            : _hasRenderablePage(singleLeftPage);
        final showSingleRight = !useSingleSpreadLayout
            ? _showRightPage
            : _hasRenderablePage(singleRightPage);
        final widgetCapturePages = _widgetCaptureCandidates().toList()..sort();
        final needsWidgetSnapshotRequest = widgetCapturePages.any(
          (page) =>
              !_widgetSnapshotProviders.containsKey(page) &&
              !_widgetSnapshotInFlight.contains(page) &&
              !_widgetSnapshotQueued.contains(page),
        );
        if (needsWidgetSnapshotRequest) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            _requestWidgetSnapshots(widgetCapturePages);
          });
        }

        final widgetRefreshPages =
            _widgetRefreshTargets().where(_pageRequiresWidgetSnapshot).toSet();
        final allowWidgetRefresh = widgetRefreshPages.isNotEmpty &&
            !_navigationInProgress &&
            !_zooming &&
            _touchStart == null &&
            _rawActivePointer == null;
        if (allowWidgetRefresh) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            _requestWidgetSnapshots(widgetRefreshPages, forceRefresh: true);
          });
        }

        final visibleFixedPages = <int>{
          if (useSingleSpreadLayout && showSingleLeft) singleLeftPage,
          if (useSingleSpreadLayout && showSingleRight) singleRightPage,
          if (!useSingleSpreadLayout && _showLeftPage) _leftPage,
          if (!useSingleSpreadLayout && _showRightPage) _rightPage,
        };

        final widgetOverlayPages = <int>{
          for (final page in widgetCapturePages)
            if (!visibleFixedPages.contains(page)) page,
        }.toList()
          ..sort();

        final rawBoundingLeft =
            _computeBoundingLeft(polygonFrame.minX, xMargin);
        final rawBoundingRight =
            _computeBoundingRight(polygonFrame.maxX, xMargin);
        final boundingLeft = useSingleSpreadLayout ? 0.0 : rawBoundingLeft;
        final boundingRight =
            useSingleSpreadLayout ? _viewWidth : rawBoundingRight;
        final centerTarget = useSingleSpreadLayout
            ? 0.0
            : widget.centering
                ? (size.width / 2 - (boundingLeft + boundingRight) / 2)
                    .roundToDouble()
                : 0.0;

        if (!_centerOffsetInitialized) {
          _currentCenterOffset = centerTarget;
          _centerOffsetInitialized = true;
        } else {
          final diff = centerTarget - _currentCenterOffset;
          if (diff.abs() < 0.5) {
            _currentCenterOffset = centerTarget;
          } else {
            _currentCenterOffset += diff * 0.1;
          }
        }

        _lastBoundingLeft = boundingLeft;
        _lastBoundingRight = boundingRight;
        _lastPageHeight = pageHeight;
        _lastYMargin = yMargin;
        _clampScroll();

        final contentChildren = <Widget>[
          if (widgetOverlayPages.isNotEmpty)
            _buildWidgetCaptureOverlay(
              pages: widgetOverlayPages,
              pageWidth: pageWidth,
              pageHeight: pageHeight,
              left: xMargin,
              top: yMargin,
            ),
          if (useSingleSpreadLayout && showSingleLeft)
            _buildFixedPage(
              pageIndex: singleLeftPage,
              left: singleLeftPos,
              top: yMargin,
              width: pageWidth,
              height: pageHeight,
            )
          else if (!useSingleSpreadLayout && _showLeftPage)
            _buildFixedPage(
              pageIndex: _leftPage,
              left: xMargin,
              top: yMargin,
              width: pageWidth,
              height: pageHeight,
            ),
          if (useSingleSpreadLayout && showSingleRight)
            _buildFixedPage(
              pageIndex: singleRightPage,
              left: singleRightPos,
              top: yMargin,
              width: pageWidth,
              height: pageHeight,
            )
          else if (!useSingleSpreadLayout && _showRightPage)
            _buildFixedPage(
              pageIndex: _rightPage,
              left: _viewWidth / 2,
              top: yMargin,
              width: pageWidth,
              height: pageHeight,
            ),
          if (_flip.direction != null && polygonFrame.strips.isEmpty)
            _buildFallbackFlipLayer(
              pageWidth: pageWidth,
              pageHeight: pageHeight,
              xMargin: xMargin,
              yMargin: yMargin,
            ),
          if (polygonFrame.strips.isNotEmpty)
            Opacity(
              opacity: polygonFrame.opacity,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  for (final strip in polygonFrame.strips)
                    _buildStrip(
                      strip,
                      pageWidth: pageWidth,
                      pageHeight: pageHeight,
                    ),
                ],
              ),
            ),
          if (!widget.allowPageWidgetGestures)
            Positioned(
              left: boundingLeft,
              top: yMargin,
              width: math.max(0, boundingRight - boundingLeft),
              height: pageHeight,
              child: MouseRegion(
                cursor: _cursor,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (widget.tapToFlip || widget.clickToZoom)
                      ? _onTapUp
                      : null,
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  onPanCancel: _onPanCancel,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
        ];

        final content = Transform.translate(
          offset: Offset(_currentCenterOffset, 0),
          child: SizedBox(
            width: _viewWidth,
            height: _viewHeight,
            child: Stack(clipBehavior: Clip.none, children: contentChildren),
          ),
        );

        return Listener(
          onPointerSignal: _onPointerSignal,
          onPointerDown:
              widget.allowPageWidgetGestures ? _onRawPointerDown : null,
          onPointerMove:
              widget.allowPageWidgetGestures ? _onRawPointerMove : null,
          onPointerUp: widget.allowPageWidgetGestures ? _onRawPointerUp : null,
          onPointerCancel:
              widget.allowPageWidgetGestures ? _onRawPointerCancel : null,
          child: widget.clipToViewport
              ? ClipRect(
                  child: Transform.translate(
                    offset: Offset(-_scrollLeft, -_scrollTop),
                    child: Transform.scale(
                      alignment: Alignment.topLeft,
                      scale: _zoom,
                      child: SizedBox(
                        width: _viewWidth,
                        height: _viewHeight,
                        child: content,
                      ),
                    ),
                  ),
                )
              : Transform.translate(
                  offset: Offset(-_scrollLeft, -_scrollTop),
                  child: Transform.scale(
                    alignment: Alignment.topLeft,
                    scale: _zoom,
                    child: SizedBox(
                      width: _viewWidth,
                      height: _viewHeight,
                      child: content,
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildLoading() {
    final builder = widget.loadingBuilder;
    if (builder != null) {
      return builder(context);
    }
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildWidgetCaptureOverlay({
    required List<int> pages,
    required double pageWidth,
    required double pageHeight,
    required double left,
    required double top,
  }) {
    if (pages.isEmpty || pageWidth <= 0 || pageHeight <= 0) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: left,
      top: top,
      width: pageWidth,
      height: pageHeight,
      child: IgnorePointer(
        child: Opacity(
          // Keep alpha above 0 after quantization (RenderOpacity uses int alpha).
          // Use the smallest visible alpha possible to avoid user-perceived flash.
          opacity: 0.004,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              for (final page in pages)
                _buildImage(
                  provider: null,
                  pageData: _pageData(page),
                  filterQuality: FilterQuality.none,
                  allowLiveWidget: true,
                  widgetCaptureKey: _captureKeyForPage(page),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFixedPage({
    required int pageIndex,
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    final pageData = _pageData(pageIndex);
    final captureKey =
        pageData?.widgetBuilder != null ? _captureKeyForPage(pageIndex) : null;
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: _buildImage(
        provider: _pageProvider(pageIndex, hiRes: true),
        pageData: pageData,
        filterQuality: FilterQuality.high,
        allowLiveWidget: true,
        rawImage: _pageRawImage(pageIndex),
        widgetCaptureKey: captureKey,
      ),
    );
  }

  Widget _buildImage({
    required ImageProvider? provider,
    required FlipbookPage? pageData,
    required FilterQuality filterQuality,
    required bool allowLiveWidget,
    ui.Image? rawImage,
    Key? widgetCaptureKey,
  }) {
    final widgetBuilder = pageData?.widgetBuilder;
    final imageLayer = allowLiveWidget && widgetBuilder != null
        ? RepaintBoundary(
            key: widgetCaptureKey,
            child: SizedBox.expand(child: Builder(builder: widgetBuilder)),
          )
        : rawImage != null
            ? RawImage(
                image: rawImage,
                fit: BoxFit.fill,
                filterQuality: filterQuality,
              )
            : provider == null
                ? ColoredBox(color: widget.blankPageColor)
                : Image(
                    image: provider,
                    fit: BoxFit.fill,
                    filterQuality: filterQuality,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) {
                      return ColoredBox(color: widget.blankPageColor);
                    },
                  );

    if (!widget.bookChrome) {
      return RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: widget.paperColor),
            imageLayer,
          ],
        ),
      );
    }

    final headerText = pageData?.headerText?.trim();
    final footerText = pageData?.footerText?.trim();
    final headerAlignment = pageData?.headerAlignment ?? Alignment.topCenter;
    final headerTextAlign = headerAlignment.x < -0.33
        ? TextAlign.left
        : headerAlignment.x > 0.33
            ? TextAlign.right
            : TextAlign.center;

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          final sideInset = (width * widget.bookSideInsetRatio).clamp(
            8.0,
            40.0,
          );
          final topInset = (height * widget.bookTopInsetRatio).clamp(
            12.0,
            64.0,
          );
          final bottomInset = (height * widget.bookBottomInsetRatio).clamp(
            12.0,
            72.0,
          );
          final outerRadius = (width * 0.018).clamp(6.0, 16.0);
          final innerRadius = (width * 0.008).clamp(2.0, 8.0);

          final headerStyle = widget.bookHeaderStyle ??
              TextStyle(
                color: widget.bookHeaderFooterColor,
                fontSize: (width * 0.028).clamp(10.0, 18.0),
                fontWeight: FontWeight.w600,
                height: 1.1,
              );
          final footerStyle = widget.bookFooterStyle ??
              TextStyle(
                color: widget.bookHeaderFooterColor,
                fontSize: (width * 0.03).clamp(10.0, 18.0),
                fontWeight: FontWeight.w700,
              );

          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(outerRadius),
              border: Border.all(color: widget.bookBorderColor, width: 1.2),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  widget.paperColor,
                  const Color(0xFFF7EBCF),
                  const Color(0xFFECDCB9),
                ],
                stops: const <double>[0, 0.55, 1],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: widget.bookShadowStrength * 0.55,
                  ),
                  blurRadius: 9,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: widget.bookShadowStrength * 0.25,
                  ),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(outerRadius - 2),
                        border: Border.all(
                          color: widget.bookInnerBorderColor.withValues(
                            alpha: 0.9,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      sideInset,
                      topInset,
                      sideInset,
                      bottomInset,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(innerRadius),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(innerRadius),
                        child: imageLayer,
                      ),
                    ),
                  ),
                ),
                if (headerText != null && headerText.isNotEmpty)
                  Positioned(
                    top: topInset * 0.26,
                    left: sideInset,
                    right: sideInset,
                    child: Align(
                      alignment: Alignment(headerAlignment.x, 0),
                      child: Text(
                        headerText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: headerTextAlign,
                        style: headerStyle,
                      ),
                    ),
                  ),
                if (footerText != null && footerText.isNotEmpty)
                  Positioned(
                    bottom: bottomInset * 0.22,
                    left: sideInset,
                    right: sideInset,
                    child: Center(
                      child: Text(
                        footerText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: footerStyle,
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(outerRadius),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.white.withValues(alpha: 0.14),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.07),
                          ],
                          stops: const <double>[0, 0.18, 1],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStrip(
    _StripRender strip, {
    required double pageWidth,
    required double pageHeight,
  }) {
    if (!strip.visible ||
        strip.width <= 0 ||
        pageWidth <= 0 ||
        pageHeight <= 0) {
      return const SizedBox.shrink();
    }

    final bgPositionRatio =
        widget.nPolygons == 1 ? 0.0 : strip.index / (widget.nPolygons - 1);
    final textureOffsetX = (strip.width - pageWidth) * bgPositionRatio;

    final useLiveWidgetFallback = strip.provider == null &&
        strip.rawImage == null &&
        strip.pageData?.widgetBuilder != null;

    final layers = <Widget>[
      if (strip.provider == null &&
          strip.rawImage == null &&
          !useLiveWidgetFallback)
        ColoredBox(color: widget.blankPageColor)
      else
        ClipRect(
          child: Transform.translate(
            offset: Offset(textureOffsetX, 0),
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: pageWidth,
              maxWidth: pageWidth,
              minHeight: pageHeight,
              maxHeight: pageHeight,
              child: SizedBox(
                width: pageWidth,
                height: pageHeight,
                child: _buildImage(
                  provider: strip.provider,
                  pageData: strip.pageData,
                  filterQuality: FilterQuality.none,
                  allowLiveWidget: useLiveWidgetFallback,
                  rawImage: strip.rawImage,
                ),
              ),
            ),
          ),
        ),
    ];

    if (strip.diffuse != null) {
      layers.add(
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                for (final value in strip.diffuse!)
                  Colors.black.withValues(alpha: value),
              ],
              stops: const <double>[0, 0.25, 0.5, 0.75, 1],
            ),
          ),
        ),
      );
    }

    if (strip.specular != null) {
      layers.add(
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                for (final value in strip.specular!)
                  Colors.white.withValues(alpha: value),
              ],
              stops: const <double>[0, 0.25, 0.5, 0.75, 1],
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: 0,
      top: 0,
      width: strip.width,
      height: pageHeight,
      child: IgnorePointer(
        child: Transform(
          alignment: Alignment.topLeft,
          transform: strip.matrix,
          child: Stack(fit: StackFit.expand, children: layers),
        ),
      ),
    );
  }

  Widget _buildFallbackFlipLayer({
    required double pageWidth,
    required double pageHeight,
    required double xMargin,
    required double yMargin,
  }) {
    final direction = _flip.direction;
    final frontPage = _flip.frontPage;
    if (direction == null || frontPage == null) {
      return const SizedBox.shrink();
    }

    final provider = _pageProvider(
      frontPage,
      hiRes: true,
    );
    final rawImage = _pageRawImage(frontPage);
    final pageData = _pageData(frontPage);
    if (provider == null && rawImage == null && pageData?.widgetBuilder == null) {
      return const SizedBox.shrink();
    }

    final progress = _flip.progress.clamp(0.0, 1.0).toDouble();
    final t = Curves.easeInOut.transform(progress);

    double left;
    Alignment anchor;
    if (_displayedPages == 1) {
      left = xMargin;
      final isForward = direction == _forwardDirection;
      if (widget.forwardDirection == FlipbookForwardDirection.left) {
        anchor = isForward ? Alignment.centerLeft : Alignment.centerRight;
      } else {
        anchor = isForward ? Alignment.centerRight : Alignment.centerLeft;
      }
    } else {
      if (direction == _FlipDirection.left) {
        left = xMargin;
        anchor = Alignment.centerRight;
      } else {
        left = _viewWidth / 2;
        anchor = Alignment.centerLeft;
      }
    }

    final scaleX = (1 - t).clamp(0.02, 1.0).toDouble();
    final shade = (0.5 * t).clamp(0.0, 0.5).toDouble();
    final fromLeft = anchor == Alignment.centerLeft;

    return Positioned(
      left: left,
      top: yMargin,
      width: pageWidth,
      height: pageHeight,
      child: IgnorePointer(
        child: Transform(
          alignment: anchor,
          transform: Matrix4.identity()..scaleByDouble(scaleX, 1.0, 1.0, 1.0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildImage(
                provider: provider,
                pageData: pageData,
                filterQuality: FilterQuality.high,
                allowLiveWidget: true,
                rawImage: rawImage,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin:
                        fromLeft ? Alignment.centerLeft : Alignment.centerRight,
                    end:
                        fromLeft ? Alignment.centerRight : Alignment.centerLeft,
                    colors: <Color>[
                      Colors.black.withValues(alpha: shade),
                      Colors.transparent,
                      Colors.black.withValues(alpha: shade * 0.35),
                    ],
                    stops: const <double>[0, 0.65, 1],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _PolygonFrame _buildPolygonFrame({
    required double pageWidth,
    required double pageHeight,
    required double xMargin,
    required double yMargin,
    required double polygonWidth,
  }) {
    final direction = _flip.direction;
    if (direction == null) {
      return _PolygonFrame.empty();
    }

    var progress = _flip.progress;
    var renderDirection = direction;
    if (_displayedPages == 1 &&
        !_singleSpreadNavigationEnabled &&
        direction != _forwardDirection) {
      progress = 1 - progress;
      renderDirection = _forwardDirection;
    }

    final opacity = (_displayedPages == 1 &&
            !_singleSpreadNavigationEnabled &&
            progress > 0.7)
        ? 1 - ((progress - 0.7) / 0.3)
        : 1.0;

    final front = _buildFace(
      face: _Face.front,
      progress: progress,
      direction: renderDirection,
      pageWidth: pageWidth,
      pageHeight: pageHeight,
      xMargin: xMargin,
      yMargin: yMargin,
      polygonWidth: polygonWidth,
    );
    final back = _buildFace(
      face: _Face.back,
      progress: progress,
      direction: renderDirection,
      pageWidth: pageWidth,
      pageHeight: pageHeight,
      xMargin: xMargin,
      yMargin: yMargin,
      polygonWidth: polygonWidth,
    );

    final strips = <_StripRender>[
      for (final strip in front.strips)
        if (strip.visible) strip,
      for (final strip in back.strips)
        if (strip.visible) strip,
    ];
    strips.sort((a, b) {
      final zCompare = a.zIndex.compareTo(b.zIndex);
      if (zCompare != 0) {
        return zCompare;
      }
      return a.id.compareTo(b.id);
    });

    var minX = double.infinity;
    var maxX = -double.infinity;

    if (front.minX.isFinite) {
      minX = math.min(minX, front.minX);
      maxX = math.max(maxX, front.maxX);
    }
    if (back.minX.isFinite) {
      minX = math.min(minX, back.minX);
      maxX = math.max(maxX, back.maxX);
    }

    return _PolygonFrame(
      strips: strips,
      minX: minX,
      maxX: maxX,
      opacity: opacity.clamp(0.0, 1.0).toDouble(),
    );
  }

  _FaceRender _buildFace({
    required _Face face,
    required double progress,
    required _FlipDirection direction,
    required double pageWidth,
    required double pageHeight,
    required double xMargin,
    required double yMargin,
    required double polygonWidth,
  }) {
    final page = face == _Face.front ? _flip.frontPage : _flip.backPage;
    final pageData = page == null ? null : _pageData(page);
    final provider = page == null
        ? null
        : face == _Face.front
            ? (_flip.frontProvider ?? _pageProvider(page))
            : (_flip.backProvider ?? _pageProvider(page));
    final rawImage = page == null ? null : _pageRawImage(page);

    if (page != null &&
        provider == null &&
        rawImage == null &&
        _pageIsWidget(page)) {
      _requestWidgetSnapshots(<int>[page]);
    }

    var pageX = xMargin;
    var originRight = false;

    if (_singleSpreadNavigationEnabled && _displayedPages == 1) {
      final cameraFactor = _singleSpreadCameraFactor();
      final leftPos = xMargin - cameraFactor * pageWidth;
      final rightPos = xMargin + (1 - cameraFactor) * pageWidth;
      final pageOnRight =
          page == null ? face == _Face.back : _isRightSidePage(page);
      pageX = pageOnRight ? rightPos : leftPos;
      originRight = !pageOnRight;
    } else if (_displayedPages == 1) {
      if (_forwardDirection == _FlipDirection.right) {
        if (face == _Face.back) {
          originRight = true;
          pageX = xMargin - pageWidth;
        }
      } else {
        if (direction == _FlipDirection.left) {
          if (face == _Face.back) {
            pageX = pageWidth - xMargin;
          } else {
            originRight = true;
          }
        } else {
          if (face == _Face.front) {
            pageX = pageWidth - xMargin;
          } else {
            originRight = true;
          }
        }
      }
    } else {
      if (direction == _FlipDirection.left) {
        if (face == _Face.back) {
          pageX = _viewWidth / 2;
        } else {
          originRight = true;
        }
      } else {
        if (face == _Face.front) {
          pageX = _viewWidth / 2;
        } else {
          originRight = true;
        }
      }
    }

    final pageMatrix = Matrix4.identity()
      ..setEntry(3, 2, -1 / widget.perspective)
      ..translateByDouble(pageX, yMargin, 0.0, 1.0);

    var pageRotation = 0.0;
    if (progress > 0.5) {
      pageRotation = -(progress - 0.5) * 2 * 180;
    }
    if (direction == _FlipDirection.left) {
      pageRotation = -pageRotation;
    }
    if (face == _Face.back) {
      pageRotation += 180;
    }

    if (pageRotation != 0) {
      if (originRight) {
        pageMatrix.translateByDouble(pageWidth, 0.0, 0.0, 1.0);
      }
      pageMatrix.rotateY(_degToRad(pageRotation));
      if (originRight) {
        pageMatrix.translateByDouble(-pageWidth, 0.0, 0.0, 1.0);
      }
    }

    var theta = progress < 0.5
        ? progress * 2 * math.pi
        : (1 - (progress - 0.5) * 2) * math.pi;
    if (theta == 0) {
      theta = 1e-9;
    }

    final radius = pageWidth / theta;
    var radian = 0.0;
    final dRadian = theta / widget.nPolygons;
    var rotate = dRadian / 2 / math.pi * 180;
    var dRotate = dRadian / math.pi * 180;

    if (originRight) {
      rotate = -theta / math.pi * 180 + dRotate / 2;
    }

    if (face == _Face.back) {
      rotate = -rotate;
      dRotate = -dRotate;
    }

    var minX = double.infinity;
    var maxX = -double.infinity;
    final strips = <_StripRender>[];

    for (var i = 0; i < widget.nPolygons; i++) {
      final matrix = pageMatrix.clone();
      final rad = originRight ? theta - radian : radian;
      var x = math.sin(rad) * radius;
      if (originRight) {
        x = pageWidth - x;
      }
      var z = (1 - math.cos(rad)) * radius;
      if (face == _Face.back) {
        z = -z;
      }

      matrix.translateByDouble(x, 0.0, z, 1.0);
      matrix.rotateY(_degToRad(-rotate));

      final x0 = _transformX(matrix, 0);
      final x1 = _transformX(matrix, polygonWidth);
      minX = math.min(minX, math.min(x0, x1));
      maxX = math.max(maxX, math.max(x0, x1));

      final rot = pageRotation - rotate;
      final lighting = _computeLighting(rot, dRotate);
      // Mimic CSS `backface-visibility: hidden` used by flipbook-vue:
      // each strip is visible only when its front normal faces the camera.
      final normalizedRot = ((rot + 180) % 360) - 180;
      final visible = normalizedRot.abs() <= 90;

      strips.add(
        _StripRender(
          id: '${face.name}$i',
          index: i,
          pageData: pageData,
          provider: provider,
          rawImage: rawImage,
          matrix: matrix,
          width: polygonWidth,
          zIndex: z.abs().round(),
          diffuse: lighting.diffuse,
          specular: lighting.specular,
          visible: visible,
        ),
      );

      radian += dRadian;
      rotate += dRotate;
    }

    return _FaceRender(strips: strips, minX: minX, maxX: maxX);
  }

  _Lighting _computeLighting(double rot, double dRotate) {
    const points = <double>[-0.5, -0.25, 0, 0.25, 0.5];
    List<double>? diffuse;
    List<double>? specular;

    if (widget.ambient < 1) {
      final blackness = 1 - widget.ambient;
      diffuse = <double>[
        for (final d in points)
          ((1 - math.cos(_degToRad(rot - dRotate * d))) * blackness)
              .clamp(0.0, 1.0)
              .toDouble(),
      ];
    }

    if (widget.gloss > 0) {
      const deg = 30.0;
      const powValue = 200;
      specular = <double>[
        for (final d in points)
          (math.max(
                    math
                        .pow(
                          math.cos(_degToRad(rot + deg - dRotate * d)),
                          powValue,
                        )
                        .toDouble(),
                    math
                        .pow(
                          math.cos(_degToRad(rot - deg - dRotate * d)),
                          powValue,
                        )
                        .toDouble(),
                  ) *
                  widget.gloss)
              .clamp(0.0, 1.0)
              .toDouble(),
      ];
    }

    return _Lighting(diffuse: diffuse, specular: specular);
  }

  double _transformX(Matrix4 matrix, double x) {
    final m = matrix.storage;
    return (x * m[0] + m[12]) / (x * m[3] + m[15]);
  }

  double _computeBoundingLeft(double minX, double xMargin) {
    if (_displayedPages == 1) {
      if (_singleSpreadNavigationEnabled) {
        final cameraFactor = _singleSpreadCameraFactor();
        final leftPos = xMargin - cameraFactor * _pageWidth;
        final rightPos = xMargin + (1 - cameraFactor) * _pageWidth;
        final spreadLeft = math.min(leftPos, rightPos);
        if (!minX.isFinite) {
          return spreadLeft;
        }
        return spreadLeft < minX ? spreadLeft : minX;
      }
      return xMargin;
    }
    final x = _hasRenderablePage(_leftPage) ? xMargin : _viewWidth / 2;
    if (!minX.isFinite) {
      return x;
    }
    return x < minX ? x : minX;
  }

  double _computeBoundingRight(double maxX, double xMargin) {
    if (_displayedPages == 1) {
      if (_singleSpreadNavigationEnabled) {
        final cameraFactor = _singleSpreadCameraFactor();
        final leftPos = xMargin - cameraFactor * _pageWidth;
        final rightPos = xMargin + (1 - cameraFactor) * _pageWidth;
        final spreadRight = math.max(leftPos, rightPos) + _pageWidth;
        if (!maxX.isFinite) {
          return spreadRight;
        }
        return spreadRight > maxX ? spreadRight : maxX;
      }
      return _viewWidth - xMargin;
    }
    final x =
        _hasRenderablePage(_rightPage) ? _viewWidth - xMargin : _viewWidth / 2;
    if (!maxX.isFinite) {
      return x;
    }
    return x > maxX ? x : maxX;
  }

  double _degToRad(double deg) => deg / 180 * math.pi;
}

class _FlipState {
  double progress = 0;
  _FlipDirection? direction;
  int? frontPage;
  int? backPage;
  ImageProvider? frontProvider;
  ImageProvider? backProvider;
  bool auto = false;
  double opacity = 1;
}

class _SlideState {
  double progress = 0;
  _FlipDirection? direction;
  int? fromPage;
  int? toPage;
  bool auto = false;
}

enum _Face { front, back }

class _PolygonFrame {
  const _PolygonFrame({
    required this.strips,
    required this.minX,
    required this.maxX,
    required this.opacity,
  });

  const _PolygonFrame.empty()
      : strips = const <_StripRender>[],
        minX = double.infinity,
        maxX = -double.infinity,
        opacity = 1;

  final List<_StripRender> strips;
  final double minX;
  final double maxX;
  final double opacity;
}

class _FaceRender {
  const _FaceRender({
    required this.strips,
    required this.minX,
    required this.maxX,
  });

  final List<_StripRender> strips;
  final double minX;
  final double maxX;
}

class _StripRender {
  const _StripRender({
    required this.id,
    required this.index,
    required this.pageData,
    required this.provider,
    required this.rawImage,
    required this.matrix,
    required this.width,
    required this.zIndex,
    required this.diffuse,
    required this.specular,
    required this.visible,
  });

  final String id;
  final int index;
  final FlipbookPage? pageData;
  final ImageProvider? provider;
  final ui.Image? rawImage;
  final Matrix4 matrix;
  final double width;
  final int zIndex;
  final List<double>? diffuse;
  final List<double>? specular;
  final bool visible;
}

class _Lighting {
  const _Lighting({required this.diffuse, required this.specular});

  final List<double>? diffuse;
  final List<double>? specular;
}
