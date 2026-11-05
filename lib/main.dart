// Importación para manejar operaciones asíncronas (como esperar a que cargue el anuncio)
import 'dart:async';

// Importación principal de los componentes de la interfaz de usuario de Flutter
import 'package:flutter/material.dart';
// Importación del SDK de Google Mobile Ads para usar AdMob
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ID de prueba oficial de Google para Banners Adaptables Intercalados.
// Es crucial usar este ID en desarrollo para evitar baneos de cuenta.
const _testAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

// Punto de entrada de la aplicación.
Future<void> main() async {
  // Asegura que el framework de Flutter esté inicializado antes de ejecutar código nativo.
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa el SDK de AdMob antes de arrancar la interfaz gráfica.
  await MobileAds.instance.initialize();
  // Arranca la aplicación mostrando el widget principal.
  runApp(const BannerDemoApp());
}

// Widget raíz de la aplicación. Define la configuración global.
class BannerDemoApp extends StatelessWidget {
  const BannerDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anuncios intercalados',
      // Configuración de los colores y estilo visual (Material Design 3)
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      // Define cuál será la primera pantalla que verá el usuario
      home: const InlineAdaptiveExample(),
    );
  }
}

// Pantalla principal que mostrará la lista (el feed) con el contenido.
class InlineAdaptiveExample extends StatelessWidget {
  const InlineAdaptiveExample({super.key});

  // Configuración del feed: espaciado, frecuencia de anuncios y publicaciones.
  static const _horizontalPadding = 16.0;
  static const _itemsPerAd = 10;
  static const _contentItemCount = 33;

  // Construye una tarjeta de contenido; el índice recibido empieza en cero.
  Widget _buildContentItem(BuildContext context, int index) {
    final number = index + 1;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(child: Text('$number')), // Círculo con el número
        title: Text('Contenido de ejemplo $number'),
        subtitle: const Text(
          'Este elemento representa una publicación dentro del feed.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feed con anuncios')),
      // La lista intercala el contenido y crea un widget independiente por anuncio.
      body: InterleavedFeedList(
        itemCount: _contentItemCount,
        itemsPerAd: _itemsPerAd,
        itemBuilder: _buildContentItem,
        // El índice del anuncio también empieza en cero; se suma uno para mostrarlo.
        adBuilder: (context, index) =>
            _InlineAdaptiveBanner(advertisementNumber: index + 1),
        padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
      ),
    );
  }
}

// Cada anuncio es Stateful porque su carga y tamaño cambian durante su vida.
class _InlineAdaptiveBanner extends StatefulWidget {
  const _InlineAdaptiveBanner({required this.advertisementNumber});

  // Número que se muestra como etiqueta para distinguir cada espacio publicitario.
  final int advertisementNumber;

  @override
  State<_InlineAdaptiveBanner> createState() => _InlineAdaptiveBannerState();
}

// Gestiona la solicitud, presentación y liberación de un banner adaptable.
class _InlineAdaptiveBannerState extends State<_InlineAdaptiveBanner> {
  // Se deja margen a cada lado para que el anuncio quepa dentro de la pantalla.
  static const _horizontalPadding = 16.0;

  BannerAd? _bannerAd; // Anuncio solicitado o cargado.
  AdSize? _adSize; // Tamaño real que informa la plataforma después de cargarlo.
  double? _loadedWidth; // Ancho usado en la solicitud anterior.
  Orientation?
  _loadedOrientation; // Orientación usada en la solicitud anterior.
  String? _adError; // Mensaje que se muestra si la carga falla.
  int _loadGeneration = 0; // Descarta respuestas de solicitudes antiguas.

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El tamaño disponible puede cambiar al rotar el dispositivo o redimensionar.
    final width = MediaQuery.sizeOf(context).width - 2 * _horizontalPadding;
    final orientation = MediaQuery.orientationOf(context);

    // No se solicita un banner con ancho inválido ni se repite una solicitud idéntica.
    if (width <= 0 ||
        (width == _loadedWidth && orientation == _loadedOrientation)) {
      return;
    }

    _loadedWidth = width;
    _loadedOrientation = orientation;
    // La carga es asíncrona; no hace falta bloquear la actualización de la pantalla.
    unawaited(_loadAd(width));
  }

  Future<void> _loadAd(double width) async {
    // Cada carga recibe un número para ignorar resultados si cambia la orientación.
    final generation = ++_loadGeneration;
    final previousAd = _bannerAd;
    _bannerAd = null;
    _adSize = null;
    _adError = null;

    // Libera el anuncio anterior antes de pedir uno con el nuevo tamaño.
    await previousAd?.dispose();
    if (!mounted || generation != _loadGeneration) return;

    // Calcula un tamaño adaptable al ancho disponible y crea una solicitud de prueba.
    final size = AdSize.getCurrentOrientationInlineAdaptiveBannerAdSize(
      width.truncate(),
    );
    final ad = BannerAd(
      adUnitId: _testAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        // Al cargar, consulta el tamaño definitivo y actualiza la interfaz.
        onAdLoaded: (Ad loadedAd) async {
          final bannerAd = loadedAd as BannerAd;
          final platformSize = await bannerAd.getPlatformAdSize();

          // Si esta pantalla ya se cerró o empezó otra carga, libera este resultado.
          if (!mounted || generation != _loadGeneration) {
            unawaited(bannerAd.dispose());
            return;
          }

          if (platformSize == null) {
            debugPrint('No se pudo obtener el tamaño del banner cargado.');
            setState(() {
              _bannerAd = null;
              _adError = 'No se pudo mostrar el anuncio.';
            });
            unawaited(bannerAd.dispose());
            return;
          }

          setState(() {
            _bannerAd = bannerAd;
            _adSize = platformSize;
            _adError = null;
          });
        },
        // Informa el fallo en consola, muestra un mensaje y libera el anuncio fallido.
        onAdFailedToLoad: (Ad failedAd, LoadAdError error) {
          debugPrint('Error al cargar el banner: $error');
          if (mounted && generation == _loadGeneration) {
            setState(() {
              _bannerAd = null;
              _adSize = null;
              _adError = 'No se pudo cargar el anuncio.';
            });
          }
          unawaited(failedAd.dispose());
        },
      ),
    );

    // Guarda la instancia para poder liberarla si cambia la orientación o se cierra.
    _bannerAd = ad;
    try {
      await ad.load();
    } on Exception catch (error, stackTrace) {
      // Captura errores inesperados al iniciar la solicitud y deja registro de ellos.
      debugPrint('Error inesperado al solicitar el banner: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _bannerAd = null;
          _adError = 'No se pudo cargar el anuncio.';
        });
      }
      unawaited(ad.dispose());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Copias locales para comprobar que tanto el anuncio como su tamaño están listos.
    final ad = _bannerAd;
    final size = _adSize;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(
            'PUBLICIDAD ${widget.advertisementNumber}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          // Muestra el anuncio cargado; mientras tanto, muestra carga o el error.
          if (ad != null && size != null)
            SizedBox(
              width: size.width.toDouble(),
              height: size.height.toDouble(),
              child: AdWidget(ad: ad),
            )
          else
            SizedBox(
              height: 90,
              child: Center(
                child: _adError == null
                    ? const CircularProgressIndicator()
                    : Text(
                        _adError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Invalida callbacks pendientes y libera recursos del SDK de anuncios.
    _loadGeneration++;
    unawaited(_bannerAd?.dispose());
    super.dispose();
  }
}

// Construye una lista eficiente e intercala anuncios entre bloques de contenido.
class InterleavedFeedList extends StatelessWidget {
  const InterleavedFeedList({
    required this.itemCount,
    required this.itemsPerAd,
    required this.itemBuilder,
    required this.adBuilder,
    this.padding,
    super.key,
  }) : assert(itemsPerAd > 0);

  final int itemCount;
  final int itemsPerAd;
  final IndexedWidgetBuilder itemBuilder;
  final Widget Function(BuildContext, int) adBuilder;
  final EdgeInsetsGeometry? padding;

  // Por ejemplo, 33 elementos cada 10 generan 3 anuncios (tras 10, 20 y 30).
  int get _adCount => itemCount <= 0 ? 0 : (itemCount - 1) ~/ itemsPerAd;

  @override
  Widget build(BuildContext context) {
    // Cada bloque contiene N elementos y, salvo el último, una fila de anuncio.
    final itemsPerGroup = itemsPerAd + 1;
    final totalCount = itemCount + _adCount;

    return ListView.builder(
      padding: padding,
      itemCount: totalCount,
      itemBuilder: (context, index) {
        // En el índice N de cada bloque se construye el anuncio correspondiente.
        if (index % itemsPerGroup == itemsPerAd) {
          return adBuilder(context, index ~/ itemsPerGroup);
        }

        // Resta los anuncios anteriores para recuperar el índice original del contenido.
        final adsBefore = index ~/ itemsPerGroup;
        return itemBuilder(context, index - adsBefore);
      },
    );
  }
}
