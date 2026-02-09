import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

typedef FlipbookPageCallback = void Function(int page);
typedef FlipbookZoomCallback = void Function(double zoom);

enum FlipbookForwardDirection { right, left }

enum FlipbookWheelMode { scroll, zoom }

enum _FlipDirection { left, right }

class FlipbookPage {
  const FlipbookPage({
    required this.image,
    this.hiResImage,
    this.headerText,
    this.footerText,
    this.headerAlignment = Alignment.topCenter,
  });

  final ImageProvider image;
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
    this.clickToZoom = true,
    this.dragToFlip = true,
    this.dragToScroll = true,
    this.wheel = FlipbookWheelMode.scroll,
    this.paperColor = Colors.white,
    this.mushafChrome = false,
    this.mushafTopInsetRatio = 0.075,
    this.mushafBottomInsetRatio = 0.085,
    this.mushafSideInsetRatio = 0.045,
    this.mushafHeaderStyle,
    this.mushafFooterStyle,
    this.mushafHeaderFooterColor = const Color(0xFF6D4C1E),
    this.mushafBorderColor = const Color(0xFFC8A86F),
    this.mushafInnerBorderColor = const Color(0xFFEAD3A5),
    this.mushafShadowStrength = 0.22,
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
        assert(mushafTopInsetRatio >= 0 && mushafTopInsetRatio <= 0.3),
        assert(mushafBottomInsetRatio >= 0 && mushafBottomInsetRatio <= 0.3),
        assert(mushafSideInsetRatio >= 0 && mushafSideInsetRatio <= 0.2),
        assert(mushafShadowStrength >= 0 && mushafShadowStrength <= 1);

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

  final bool clickToZoom;
  final bool dragToFlip;
  final bool dragToScroll;
  final FlipbookWheelMode wheel;

  final Color paperColor;
  final bool mushafChrome;
  final double mushafTopInsetRatio;
  final double mushafBottomInsetRatio;
  final double mushafSideInsetRatio;
  final TextStyle? mushafHeaderStyle;
  final TextStyle? mushafFooterStyle;
  final Color mushafHeaderFooterColor;
  final Color mushafBorderColor;
  final Color mushafInnerBorderColor;
  final double mushafShadowStrength;
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
  static const String _buildTag = 'flipbook_local_2026_02_09_r12';
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

  bool get _canGoForward =>
      _flip.direction == null &&
      _currentPage < widget.pages.length - _displayedPages;

  bool get _canGoBack =>
      _flip.direction == null &&
      _currentPage >= _displayedPages &&
      !(_displayedPages == 1 && _pageProvider(_firstPage - 1) == null);

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

  bool get _showLeftPage => _pageProvider(_leftPage) != null;
  bool get _showRightPage =>
      _pageProvider(_rightPage) != null && _displayedPages == 2;

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

  void _updateLayoutForSize(Size size) {
    if (size == _viewSize) {
      return;
    }
    _viewSize = size;
    final displayedPages =
        size.width > size.height && !widget.singlePage ? 2 : 1;
    if (displayedPages != _displayedPages) {
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
        _pageProvider(0) == null) {
      _currentPage++;
    }
  }

  FlipbookPage? _pageData(int page) {
    if (page < 0 || page >= widget.pages.length) {
      return null;
    }
    return widget.pages[page];
  }

  ImageProvider? _pageProvider(int page, {bool hiRes = false}) {
    final pageData = _pageData(page);
    if (pageData == null) {
      return null;
    }
    if (hiRes && _zoom > 1 && !_zooming && pageData.hiResImage != null) {
      return pageData.hiResImage;
    }
    return pageData.image;
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

  void _preloadImages([bool hiRes = false]) {
    if (!mounted) {
      return;
    }
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
  }

  Future<void> _precache(ImageProvider provider) async {
    try {
      await precacheImage(provider, context);
    } catch (_) {
      // Ignore preload errors to keep page rendering non-blocking.
    }
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
    int? frontPage;
    int? backPage;

    if (direction != _forwardDirection) {
      if (_displayedPages == 1) {
        frontPage = _currentPage - 1;
        backPage = null;
      } else {
        frontPage = _firstPage;
        backPage = _currentPage - _displayedPages + 1;
      }
    } else {
      if (_displayedPages == 1) {
        frontPage = _currentPage;
        backPage = null;
      } else {
        frontPage = _secondPage;
        backPage = _currentPage + _displayedPages;
      }
    }

    _flipProgressController.stop();
    _flipProgressController.value = 0;
    setState(() {
      _flip.direction = direction;
      _flip.progress = 0;
      _flip.frontPage = frontPage;
      _flip.backPage = backPage;
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

  void _completeFlip(_FlipDirection direction) {
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
      _flip.opacity = 1;
      _flip.auto = false;
      _flipProgressController.value = 0;
    });
    _emitFlipEnd(direction);
    _preloadImages();
  }

  void _cancelFlip() {
    setState(() {
      _firstPage = _currentPage;
      _secondPage = _currentPage + 1;
      _flip.direction = null;
      _flip.progress = 0;
      _flip.frontPage = null;
      _flip.backPage = null;
      _flip.opacity = 1;
      _flip.auto = false;
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
    if (!mounted || _flip.direction == null) {
      return;
    }
    final value = _flipProgressController.value.clamp(0.0, 1.0);
    if ((value - _flip.progress).abs() < 1e-6) {
      return;
    }
    setState(() {
      _flip.progress = value;
    });
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

    if (!didFlip && widget.clickToZoom) {
      final local = Offset(
        details.localPosition.dx + _lastBoundingLeft,
        details.localPosition.dy + _lastYMargin,
      );
      _zoomAt(local);
    }
  }

  void _onPanStart(DragStartDetails details) {
    final local = Offset(
      details.localPosition.dx + _lastBoundingLeft,
      details.localPosition.dy + _lastYMargin,
    );
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

  void _onPanUpdate(DragUpdateDetails details) {
    final start = _touchStart;
    if (start == null) {
      return;
    }
    _dragDx += details.delta.dx;
    _dragDy += details.delta.dy;

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
    if (_flip.direction == null && y.abs() > x.abs()) {
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
      }
    } else {
      if (_flip.direction == null && _canFlipRight && x <= -widget.swipeMin) {
        _flipStart(_FlipDirection.right, false);
      }
      if (_flip.direction == _FlipDirection.right) {
        final progress = (-x / _pageWidth).clamp(0.0, 1.0).toDouble();
        _flipProgressController.value = progress;
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _endSwipeGesture(details.velocity.pixelsPerSecond.dx);
  }

  void _onPanCancel() {
    _endSwipeGesture(0);
  }

  void _endSwipeGesture(double velocityX) {
    if (_touchStart == null) {
      return;
    }

    if (widget.clickToZoom &&
        _maxMove < widget.swipeMin &&
        _lastTouch != null) {
      _zoomAt(_lastTouch!);
    }

    if (_flip.direction != null && !_flip.auto) {
      const velocityThreshold = 700.0;
      final forwardFling = _flip.direction == _FlipDirection.left
          ? velocityX > velocityThreshold
          : velocityX < -velocityThreshold;
      if (_flip.progress >= 0.5 || forwardFling) {
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

        final polygonFrame = _buildPolygonFrame(
          pageWidth: pageWidth,
          pageHeight: pageHeight,
          xMargin: xMargin,
          yMargin: yMargin,
          polygonWidth: polygonWidth,
        );

        final boundingLeft = _computeBoundingLeft(polygonFrame.minX, xMargin);
        final boundingRight = _computeBoundingRight(polygonFrame.maxX, xMargin);
        final centerTarget = widget.centering
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
          if (_showLeftPage)
            _buildFixedPage(
              pageIndex: _leftPage,
              left: xMargin,
              top: yMargin,
              width: pageWidth,
              height: pageHeight,
            ),
          if (_showRightPage)
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
          Positioned(
            left: boundingLeft,
            top: yMargin,
            width: math.max(0, boundingRight - boundingLeft),
            height: pageHeight,
            child: MouseRegion(
              cursor: _cursor,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: _onTapUp,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                onPanCancel: _onPanCancel,
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
          child: ClipRect(
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

  Widget _buildFixedPage({
    required int pageIndex,
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    final pageData = _pageData(pageIndex);
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: _buildImage(
        provider: _pageProvider(pageIndex, hiRes: true),
        pageData: pageData,
        filterQuality: FilterQuality.high,
      ),
    );
  }

  Widget _buildImage({
    required ImageProvider? provider,
    required FlipbookPage? pageData,
    required FilterQuality filterQuality,
  }) {
    final imageLayer = provider == null
        ? ColoredBox(color: widget.blankPageColor)
        : Image(
            image: provider,
            fit: BoxFit.fill,
            filterQuality: filterQuality,
            errorBuilder: (context, error, stackTrace) {
              return ColoredBox(color: widget.blankPageColor);
            },
          );

    if (!widget.mushafChrome) {
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

          final sideInset = (width * widget.mushafSideInsetRatio).clamp(
            8.0,
            40.0,
          );
          final topInset = (height * widget.mushafTopInsetRatio).clamp(
            12.0,
            64.0,
          );
          final bottomInset = (height * widget.mushafBottomInsetRatio).clamp(
            12.0,
            72.0,
          );
          final outerRadius = (width * 0.018).clamp(6.0, 16.0);
          final innerRadius = (width * 0.008).clamp(2.0, 8.0);

          final headerStyle = widget.mushafHeaderStyle ??
              TextStyle(
                color: widget.mushafHeaderFooterColor,
                fontSize: (width * 0.028).clamp(10.0, 18.0),
                fontWeight: FontWeight.w600,
                height: 1.1,
              );
          final footerStyle = widget.mushafFooterStyle ??
              TextStyle(
                color: widget.mushafHeaderFooterColor,
                fontSize: (width * 0.03).clamp(10.0, 18.0),
                fontWeight: FontWeight.w700,
              );

          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(outerRadius),
              border: Border.all(color: widget.mushafBorderColor, width: 1.2),
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
                    alpha: widget.mushafShadowStrength * 0.55,
                  ),
                  blurRadius: 9,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: widget.mushafShadowStrength * 0.25,
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
                          color: widget.mushafInnerBorderColor.withValues(
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

    final layers = <Widget>[
      if (strip.provider == null)
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
      child: Transform(
        alignment: Alignment.topLeft,
        transform: strip.matrix,
        child: Stack(fit: StackFit.expand, children: layers),
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

    final provider = _pageProvider(frontPage, hiRes: true);
    final pageData = _pageData(frontPage);
    if (provider == null) {
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
    if (_displayedPages == 1 && direction != _forwardDirection) {
      progress = 1 - progress;
      renderDirection = _forwardDirection;
    }

    final opacity = (_displayedPages == 1 && progress > 0.7)
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
    final provider = page == null ? null : _pageProvider(page);

    var pageX = xMargin;
    var originRight = false;

    if (_displayedPages == 1) {
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
      return xMargin;
    }
    final x = _pageProvider(_leftPage) != null ? xMargin : _viewWidth / 2;
    if (!minX.isFinite) {
      return x;
    }
    return x < minX ? x : minX;
  }

  double _computeBoundingRight(double maxX, double xMargin) {
    if (_displayedPages == 1) {
      return _viewWidth - xMargin;
    }
    final x = _pageProvider(_rightPage) != null
        ? _viewWidth - xMargin
        : _viewWidth / 2;
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
  bool auto = false;
  double opacity = 1;
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
