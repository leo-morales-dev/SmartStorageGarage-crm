// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MonitoreoChartsView extends StatelessWidget {
  MonitoreoChartsView({super.key}) {
    _registerViewFactory();
  }

  static const String _viewType = 'monitoreo-charts-view';
  static bool _registered = false;

  void _registerViewFactory() {
    if (_registered || !kIsWeb) return;

    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final wrapper = html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.boxSizing = 'border-box'
        ..style.padding = '0';

      final containerId = 'monitoreo-container-$viewId';
      final distId = 'dist-chart-$viewId';
      final tempId = 'temp-chart-$viewId';
      final humId = 'hum-chart-$viewId';

      // Main content with canvases
      final content = html.DivElement()
        ..id = containerId
        ..setInnerHtml('''
          <style>
            :root {
              --card-bg: #ffffff;
              --card-border: rgba(0, 0, 0, 0.06);
              --text-main: #0f172a;
              --text-subtle: rgba(15, 23, 42, 0.72);
              --divider: rgba(15, 23, 42, 0.08);
            }

            @media (prefers-color-scheme: dark) {
              :root {
                --card-bg: rgba(255, 255, 255, 0.04);
                --card-border: rgba(255, 255, 255, 0.08);
                --text-main: #e2e8f0;
                --text-subtle: rgba(226, 232, 240, 0.72);
                --divider: rgba(226, 232, 240, 0.08);
              }
            }

            .page {
              font-family: 'Inter', system-ui, -apple-system, BlinkMacSystemFont,
                'Segoe UI', sans-serif;
              color: var(--text-main);
            }

            .page h1 {
              margin: 0 0 4px;
              font-size: 22px;
              font-weight: 700;
            }

            .page p {
              margin: 0 0 16px;
              color: var(--text-subtle);
              font-size: 14px;
            }

            .chart-grid {
              display: grid;
              grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
              gap: 16px;
            }

            .chart-card {
              background: var(--card-bg);
              border: 1px solid var(--card-border);
              border-radius: 16px;
              padding: 16px;
              box-sizing: border-box;
              box-shadow: 0 10px 30px rgba(0, 0, 0, 0.04);
            }

            .chart-card h2 {
              margin: 0 0 12px;
              font-size: 16px;
              font-weight: 600;
              color: var(--text-main);
            }

            canvas {
              width: 100% !important;
              height: 240px !important;
            }

            .status {
              margin-top: 10px;
              color: var(--text-subtle);
              font-size: 12px;
              border-top: 1px solid var(--divider);
              padding-top: 8px;
            }
          </style>
          <div class="page">
            <h1>Monitoreo en Tiempo Real</h1>
            <p>Datos enviados desde los sensores físicos (ESP32).</p>

            <div class="chart-grid">
              <section class="chart-card">
                <h2>Distancia (cm)</h2>
                <canvas id="$distId"></canvas>
              </section>

              <section class="chart-card">
                <h2>Temperatura (°C)</h2>
                <canvas id="$tempId"></canvas>
              </section>

              <section class="chart-card">
                <h2>Humedad (%)</h2>
                <canvas id="$humId"></canvas>
              </section>
            </div>

            <div class="status" id="status-$distId"></div>
          </div>
        ''',
            validator: html.NodeValidatorBuilder.common()
              ..allowElement('section')
              ..allowElement('canvas', attributes: ['id'])
              ..allowElement('style')
              ..allowElement('h1')
              ..allowElement('h2')
              ..allowElement('p'));

      wrapper.children.add(content);

      _attachScripts(distId: distId, tempId: tempId, humId: humId);

      return wrapper;
    });

    _registered = true;
  }

  void _attachScripts({
    required String distId,
    required String tempId,
    required String humId,
  }) {
    void runCharts() {
      final initScript = html.ScriptElement()
        ..text = '''
          (function() {
            if (typeof db === 'undefined') {
              console.warn('Firebase database instance (db) no encontrada.');
              const statusEl = document.getElementById('status-$distId');
              if (statusEl) {
                statusEl.textContent = 'No se encontró la instancia de Firebase. Verifica la configuración en web/index.html';
              }
              return;
            }

            const ref = db.ref("sensores");
            const labels = [];

            const dist1Data = [];
            const dist2Data = [];
            const temp1Data = [];
            const temp2Data = [];
            const hum1Data = [];
            const hum2Data = [];

            const statusEl = document.getElementById('status-$distId');
            if (statusEl) statusEl.textContent = 'Conectado a Firebase. Esperando lecturas...';

            const trimData = (arr) => {
              const maxPoints = 24;
              if (arr.length > maxPoints) {
                arr.splice(0, arr.length - maxPoints);
              }
            };

            const distChart = new Chart(document.getElementById('$distId'), {
              type: 'line',
              data: {
                labels,
                datasets: [
                  { label: "Bodega 1", data: dist1Data, borderColor: "green" },
                  { label: "Bodega 2", data: dist2Data, borderColor: "red" }
                ]
              }
            });

            const tempChart = new Chart(document.getElementById('$tempId'), {
              type: 'line',
              data: {
                labels,
                datasets: [
                  { label: "Bodega 1", data: temp1Data, borderColor: "orange" },
                  { label: "Bodega 2", data: temp2Data, borderColor: "yellow" }
                ]
              }
            });

            const humChart = new Chart(document.getElementById('$humId'), {
              type: 'line',
              data: {
                labels,
                datasets: [
                  { label: "Bodega 1", data: hum1Data, borderColor: "blue" },
                  { label: "Bodega 2", data: hum2Data, borderColor: "cyan" }
                ]
              }
            });

            ref.on("value", snap => {
              const data = snap.val();
              if (!data) return;

              const now = new Date().toLocaleTimeString();
              labels.push(now);

              trimData(labels);

              dist1Data.push(data.bodega1?.dist ?? 0);
              temp1Data.push(data.bodega1?.temp ?? 0);
              hum1Data.push(data.bodega1?.hum ?? 0);

              dist2Data.push(data.bodega2?.dist ?? 0);
              temp2Data.push(data.bodega2?.temp ?? 0);
              hum2Data.push(data.bodega2?.hum ?? 0);

              trimData(dist1Data);
              trimData(temp1Data);
              trimData(hum1Data);
              trimData(dist2Data);
              trimData(temp2Data);
              trimData(hum2Data);

              distChart.update();
              tempChart.update();
              humChart.update();

              if (statusEl) {
                statusEl.textContent = `Última actualización: ${now}`;
              }
            });
          })();
        ''';

      html.document.body?.append(initScript);
    }

    if ((html.window as dynamic).Chart != null) {
      runCharts();
      return;
    }

    final chartScript = html.ScriptElement()
      ..src = 'https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js'
      ..crossOrigin = 'anonymous'
      ..defer = true;

    chartScript.onError.listen((_) {
      html.window.console
          .warn('No fue posible cargar Chart.js para la vista de monitoreo.');
    });

    chartScript.onLoad.listen((_) => runCharts());
    html.document.head?.append(chartScript);
  }

  @override
  Widget build(BuildContext context) {
    return const HtmlElementView(viewType: _viewType);
  }
}
