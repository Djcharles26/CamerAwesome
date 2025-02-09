import 'dart:math';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/src/utils/colors.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

/// Visual indicator of current selected zoom
/// - [allowDigitalZoom] If true, automatic jump between sensors will be disabled and
/// digital zoom will be enabled
class _ZoomIndicator extends StatelessWidget {
  final double zoom;
  final double displayZoom;
  final bool selected;

  final void Function (double) onSelected;


  const _ZoomIndicator({
    required this.zoom,
    required this.displayZoom,
    required this.selected,
    required this.onSelected
  });

  @override
  Widget build(BuildContext context) {
    Widget content = AwesomeBouncingWidget(
      key: ValueKey("zoomIndicator_${zoom}_selected"),
      onTap: () {
        onSelected (zoom);
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacityA(0.2),
        ),
        padding: const EdgeInsets.all(8.0),
        child: Text(
          "${displayZoom.toStringAsFixed(1)}${selected?"X":""}",
          maxLines: 1,
          style: TextStyle(
            color: selected ? Colors.yellowAccent : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );

    // Same width for each dot to keep them in their position
    return SizedBox(
      width: 56,
      child: Center(
        child: content,
      ),
    );
  }
}

class AwesomeZoomSelector extends StatefulWidget {
  final CameraState state;
  final bool allowDigitalZoom;
  final num? maxZoom;

  /// Zoom selector widget
  /// 
  /// Displays current zoom.
  const AwesomeZoomSelector({
    super.key,
    required this.state,
    this.allowDigitalZoom = false,
    this.maxZoom
  });

  @override
  State<AwesomeZoomSelector> createState() => _AwesomeZoomSelectorState();
}

class _AwesomeZoomSelectorState extends State<AwesomeZoomSelector> {
  num minZoom (SensorConfig sensorConfig) => sensorConfig.device.minZoom;
  num maxDeviceZoom (SensorConfig sensorConfig) => widget.allowDigitalZoom
    ? sensorConfig.device.maxDigitalZoom 
    : sensorConfig.device.maxOpticalZoom;
  
  num maxZoom (SensorConfig sensorConfig) => widget.maxZoom == null 
    ? maxDeviceZoom (sensorConfig)
    : min (maxDeviceZoom (sensorConfig), maxZoom (sensorConfig));

  @override
  void initState() {
    super.initState();
  }

  // double normalizeZoom (SensorConfig config, zoom) => 
  //   (zoom - minZoom (config)) / (maxZoom(config) - minZoom(config));

  /// Show 2 dots for zooming: min, 1.0X and max zoom. The closer one shows
  /// text, the other ones a dot.
  Widget _layout ({
    required double zoom, 
    required SensorConfig sensorConfig
  }) {
    return StreamBuilder<SensorType>(
      stream: sensorConfig.sensorType$,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _ZoomIndicator(
            zoom: zoom, 
            displayZoom: zoom,
            selected: true, 
            onSelected: (_){}
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: widget.state.cameraContext.sensorTypeDevices.sorted(
            (a,b) => a.sensorType.order.compareTo(b.sensorType.order)
          ).where (
            (sensor) => sensor.sensorType != SensorType.trueDepth
          ).map<Widget>(
            (sensorTypeDevice) {
              bool sensorSelected = sensorTypeDevice.sensorType == snapshot.requireData;
              return _ZoomIndicator(
                zoom: sensorSelected 
                  ? zoom 
                  : sensorTypeDevice.minZoom.toDouble(), 
                displayZoom: sensorSelected 
                  ? (
                    (maxZoom(sensorConfig) - minZoom(sensorConfig)) * zoom + 
                    minZoom(sensorConfig)
                  )
                  : sensorTypeDevice.minZoom.toDouble(),
                selected: sensorSelected, 
                onSelected: (_) async {
                  /// Each time a selector is tapped, its value will be resetted
                  /// to zero.
                  /// 
                  /// If a sensor is tapped and is not selected yet, then the 
                  /// selector will be changed
                  if (sensorSelected) {
                    sensorConfig.setZoom(0);
                    sensorConfig.resetGestures ();
                  } else {
                    await sensorConfig.setZoom(0);
                    SensorConfig next = await widget.state.setSensorType(
                      0, 
                      sensorTypeDevice.sensorType, 
                      sensorTypeDevice.uid
                    );

                    next.resetGestures ();
                  }
                }
              );
            }
          ).toList()
          // [
          //   _ZoomIndicator(
          //     zoom: zoom,
          //     selected: zoom <= minZoom,
          //     onSelected: (zoom) => sensorConfig.setZoom(normalizeZoom(zoom))
          //   ),
          //   const SizedBox(height: 16),
          //   _ZoomIndicator(
          //     zoom: zoom,
          //     selected: zoom == maxZoom,
          //     onSelected: (zoom) => sensorConfig.setZoom(normalizeZoom(zoom)),
          //   ),
          // ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SensorConfig>(
      stream: widget.state.sensorConfig$,
      builder: (context, sensorConfigSnapshot) {
        if (sensorConfigSnapshot.data == null) {
          return const SizedBox.shrink();
        } else {
          return StreamBuilder<double>(
            stream: sensorConfigSnapshot.requireData.zoom$,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return _layout (
                  zoom: snapshot.requireData,
                  sensorConfig: widget.state.sensorConfig
                );
              } else {
                return const SizedBox.shrink();
              }
            },
          );
        }
      },
    );
  }
}
