import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system.dart';

class DarbCityCarousel extends StatefulWidget {
  const DarbCityCarousel({super.key});

  @override
  State<DarbCityCarousel> createState() => _DarbCityCarouselState();
}

class _DarbCityCarouselState extends State<DarbCityCarousel> {
  static const _cities = <_CitySlide>[
    _CitySlide('aleppo', 'حلب', 'Aleppo', 'Halep'),
    _CitySlide('homs', 'حمص', 'Homs', 'Humus'),
    _CitySlide('hama', 'حماة', 'Hama', 'Hama'),
    _CitySlide('damascus', 'دمشق', 'Damascus', 'Şam'),
    _CitySlide('latakia', 'اللاذقية', 'Latakia', 'Lazkiye'),
  ];

  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted || DarbMotion.reduceMotion(context)) return;
      setState(() => _index = (_index + 1) % _cities.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final city = _cities[_index];
    final language = Localizations.localeOf(context).languageCode;
    final cityName = switch (language) {
      'en' => city.english,
      'tr' => city.turkish,
      _ => city.arabic,
    };
    final duration = DarbMotion.effectiveDuration(
      context,
      const Duration(milliseconds: 1100),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: duration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.expand,
            children: [...previous, if (current != null) current],
          ),
          transitionBuilder: (child, animation) {
            final reduced = DarbMotion.reduceMotion(context);
            return FadeTransition(
              opacity: animation,
              child: reduced
                  ? child
                  : ScaleTransition(
                      scale: Tween<double>(begin: 1.035, end: 1).animate(
                        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                      ),
                      child: child,
                    ),
            );
          },
          child: Image.asset(
            'assets/cities/${city.assetName}.jpg',
            key: ValueKey(city.assetName),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => const SizedBox.expand(),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x24000000), Color(0xC9102B26)],
            ),
          ),
        ),
        PositionedDirectional(
          top: 78,
          end: 18,
          child: AnimatedSwitcher(
            duration: duration,
            child: Container(
              key: ValueKey(city.assetName),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xA6102B26),
                borderRadius: BorderRadius.circular(DarbRadius.pill),
                border: Border.all(color: Colors.white.withValues(alpha: .25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_rounded, color: Color(0xFFC8F169), size: 14),
                  const SizedBox(width: 5),
                  Text(
                    cityName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        PositionedDirectional(
          bottom: 13,
          end: 20,
          child: Row(
            children: List.generate(_cities.length, (index) => AnimatedContainer(
              duration: DarbMotion.fast,
              curve: DarbMotion.enter,
              margin: const EdgeInsetsDirectional.only(start: 4),
              width: index == _index ? 17 : 5,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: index == _index ? .95 : .48),
                borderRadius: BorderRadius.circular(DarbRadius.pill),
              ),
            )),
          ),
        ),
      ],
    );
  }
}

class _CitySlide {
  const _CitySlide(this.assetName, this.arabic, this.english, this.turkish);
  final String assetName;
  final String arabic;
  final String english;
  final String turkish;
}
