import 'dart:convert';
import 'recording_session.dart';

/// Generates a standalone, self-contained interactive HTML report for a signal recording session.
String generateRecordingHtml(SignalRecordingSession session) {
  final sessionJson = jsonEncode(session.toJson());
  final filename = RecordingStorage.generateFilename(session.startTime).replaceAll('.json', '.html');
  final startTimeStr = session.startTime.toLocal().toString().split('.').first;
  final durationLabel = session.durationLabel;
  final sampleCount = session.samples.length;

  return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CellTuner · Signal Session Report ($filename)</title>
  <style>
    :root {
      --bg: #f8fafc;
      --surface: #ffffff;
      --surface-subtle: #f1f5f9;
      --border: #e2e8f0;
      --border-subtle: rgba(226, 232, 240, 0.6);
      --text: #0f172a;
      --text-muted: #64748b;
      --primary: #003BFF;
      --lte: #00A83B;
      --nr5g: #003BFF;
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background-color: var(--bg);
      color: var(--text);
      line-height: 1.5;
      padding: 24px;
      -webkit-font-smoothing: antialiased;
    }

    .report-container {
      max-width: 1440px;
      margin: 0 auto;
    }

    /* Report Header */
    .report-header {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 20px 24px;
      margin-bottom: 20px;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.02);
    }

    .header-top {
      display: flex;
      flex-wrap: wrap;
      justify-content: space-between;
      align-items: center;
      gap: 16px;
      margin-bottom: 16px;
      border-bottom: 1px solid var(--border);
      padding-bottom: 16px;
    }

    .brand-title {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .brand-icon {
      width: 40px;
      height: 40px;
      background: rgba(0, 59, 255, 0.08);
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
      color: var(--primary);
    }

    .brand-icon svg {
      width: 22px;
      height: 22px;
    }

    .title-text h1 {
      font-size: 18px;
      font-weight: 800;
      letter-spacing: -0.3px;
    }

    .title-text p {
      font-size: 12px;
      color: var(--text-muted);
      font-family: monospace;
    }

    .meta-badges {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }

    .badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 5px 11px;
      border-radius: 6px;
      font-size: 12px;
      font-weight: 600;
      border: 1px solid var(--border);
      background: var(--surface-subtle);
    }

    /* Controls Bar */
    .controls-bar {
      display: flex;
      flex-wrap: wrap;
      justify-content: space-between;
      align-items: center;
      gap: 12px;
    }

    .control-group {
      display: flex;
      align-items: center;
      gap: 8px;
      flex-wrap: wrap;
    }

    .control-label {
      font-size: 12px;
      font-weight: 600;
      color: var(--text-muted);
      margin-right: 4px;
    }

    .btn-group {
      display: inline-flex;
      border-radius: 6px;
      border: 1px solid var(--border);
      overflow: hidden;
      background: var(--surface);
    }

    .btn-group button {
      border: none;
      background: none;
      padding: 6px 12px;
      font-size: 12px;
      font-weight: 600;
      color: var(--text-muted);
      cursor: pointer;
      transition: all 0.15s ease;
      border-right: 1px solid var(--border);
    }

    .btn-group button:last-child {
      border-right: none;
    }

    .btn-group button.active {
      background: var(--primary);
      color: #ffffff;
    }

    .btn-group button:hover:not(.active) {
      background: var(--surface-subtle);
      color: var(--text);
    }

    .zoom-btn {
      padding: 6px 12px;
      border-radius: 6px;
      border: 1px solid var(--border);
      background: var(--surface);
      font-size: 12px;
      font-weight: 600;
      cursor: pointer;
      color: var(--text);
      display: inline-flex;
      align-items: center;
      gap: 4px;
      transition: all 0.15s ease;
    }

    .zoom-btn:hover {
      background: var(--surface-subtle);
    }

    .zoom-indicator {
      font-size: 12px;
      font-weight: 700;
      color: var(--primary);
      min-width: 44px;
      text-align: center;
    }

    /* Grid of Metric Cards */
    .metrics-grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 16px;
    }

    @media (max-width: 992px) {
      .metrics-grid {
        grid-template-columns: 1fr;
      }
    }

    .metric-card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 10px;
      box-shadow: 0 3px 10px rgba(0, 0, 0, 0.03);
      padding: 16px;
      overflow: hidden;
      position: relative;
    }

    .metric-card-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 12px;
      gap: 8px;
    }

    .metric-card-title {
      font-size: 14px;
      font-weight: 700;
      letter-spacing: -0.2px;
      color: var(--text);
    }

    .metric-card-badges {
      display: flex;
      gap: 6px;
    }

    .series-badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 3px 8px;
      border-radius: 5px;
      font-size: 11px;
      font-weight: 700;
      border: none;
    }

    .series-badge.lte {
      background: #D1FAE5;
      color: var(--lte);
    }

    .series-badge.nr5g {
      background: #E0E7FF;
      color: var(--nr5g);
    }

    .series-dot {
      width: 6px;
      height: 6px;
      border-radius: 50%;
      flex-shrink: 0;
    }

    .series-badge.lte .series-dot { background: var(--lte); }
    .series-badge.nr5g .series-dot { background: var(--nr5g); }

    /* Chart Container & Scroll */
    .chart-scroll-wrapper {
      position: relative;
      width: 100%;
      height: 240px;
      overflow-x: auto;
      overflow-y: hidden;
      border-radius: 6px;
      scrollbar-width: thin;
      scrollbar-color: #cbd5e1 #f8fafc;
    }

    .chart-scroll-wrapper::-webkit-scrollbar {
      height: 6px;
    }

    .chart-scroll-wrapper::-webkit-scrollbar-track {
      background: #f8fafc;
      border-radius: 3px;
    }

    .chart-scroll-wrapper::-webkit-scrollbar-thumb {
      background: #cbd5e1;
      border-radius: 3px;
    }

    .chart-scroll-wrapper::-webkit-scrollbar-thumb:hover {
      background: #94a3b8;
    }

    .chart-canvas-container {
      position: relative;
      height: 240px;
      width: 100%;
      cursor: default;
    }

    .chart-scrub-line {
      position: absolute;
      top: 15px;
      bottom: 25px;
      width: 1px;
      background: #94a3b8;
      pointer-events: none;
      display: none;
      z-index: 50;
    }

    canvas {
      display: block;
      width: 100%;
      height: 100%;
    }

    /* Floating Tooltip */
    .chart-tooltip {
      position: absolute;
      display: none;
      background: #0f172a;
      color: #ffffff;
      padding: 5px 10px;
      border-radius: 6px;
      font-size: 11px;
      line-height: 1.35;
      pointer-events: none;
      z-index: 100;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.25);
      white-space: nowrap;
      top: 8px;
      transform: translateX(-50%);
      border: 1px solid rgba(255, 255, 255, 0.12);
    }

    .tooltip-time {
      font-weight: 700;
      color: #94a3b8;
      font-size: 10px;
      line-height: 1.2;
    }

    .tooltip-cell {
      font-weight: 600;
      color: #f8fafc;
      font-size: 11px;
      margin-top: 1px;
      line-height: 1.2;
    }
  </style>
</head>
<body>

  <div class="report-container">
    <!-- Header -->
    <header class="report-header">
      <div class="header-top">
        <div class="brand-title">
          <div class="brand-icon">
            <svg fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M22 12h-4l-3 9L9 3l-3 9H2" />
            </svg>
          </div>
          <div class="title-text">
            <h1>CellTuner · Signal Session Report</h1>
            <p>$filename</p>
          </div>
        </div>

        <div class="meta-badges">
          <div class="badge">
            <svg width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
            $durationLabel ($sampleCount samples)
          </div>
          <div class="badge">
            <svg width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
            $startTimeStr
          </div>
        </div>
      </div>

      <!-- Controls -->
      <div class="controls-bar">
        <div class="control-group">
          <span class="control-label">Tech Mode:</span>
          <div class="btn-group" id="techModeGroup">
            <button class="active" data-mode="both">Both (4G & 5G)</button>
            <button data-mode="4g">4G LTE Only</button>
            <button data-mode="5g">5G NR Only</button>
          </div>
        </div>

        <div class="control-group">
          <span class="control-label">Cell ID:</span>
          <div class="btn-group" id="cellIdGroup">
            <button class="active" data-split="true">Split eNB/Sector</button>
            <button data-split="false">Raw Cell ID</button>
          </div>
        </div>

        <div class="control-group">
          <span class="control-label">Zoom & Pan:</span>
          <button class="zoom-btn" id="zoomOutBtn" title="Zoom Out (Ctrl+Minus or Scroll Down)">-</button>
          <span class="zoom-indicator" id="zoomLevelText">1.0x</span>
          <button class="zoom-btn" id="zoomInBtn" title="Zoom In (Ctrl+Plus or Scroll Up)">+</button>
          <button class="zoom-btn" id="zoomResetBtn" title="Reset Zoom">Reset</button>
        </div>
      </div>
    </header>

    <!-- Metrics Cards Grid -->
    <main class="metrics-grid">
      <!-- RSSI -->
      <div class="metric-card" id="card-RSSI">
        <div class="metric-card-header">
          <div class="metric-card-title">RSSI (Received Signal Strength)</div>
          <div class="metric-card-badges">
            <div class="series-badge lte" id="badge-RSSI-lte"><span class="series-dot"></span><span>4G: N/A</span></div>
            <div class="series-badge nr5g" id="badge-RSSI-nr5g"><span class="series-dot"></span><span>5G: N/A</span></div>
          </div>
        </div>
        <div class="chart-scroll-wrapper" id="scroll-RSSI">
          <div class="chart-canvas-container" id="container-RSSI">
            <canvas id="canvas-RSSI"></canvas>
            <div class="chart-scrub-line" id="scrub-RSSI"></div>
            <div class="chart-tooltip" id="tooltip-RSSI"></div>
          </div>
        </div>
      </div>

      <!-- RSRP -->
      <div class="metric-card" id="card-RSRP">
        <div class="metric-card-header">
          <div class="metric-card-title">RSRP (Reference Signal Received Power)</div>
          <div class="metric-card-badges">
            <div class="series-badge lte" id="badge-RSRP-lte"><span class="series-dot"></span><span>4G: N/A</span></div>
            <div class="series-badge nr5g" id="badge-RSRP-nr5g"><span class="series-dot"></span><span>5G: N/A</span></div>
          </div>
        </div>
        <div class="chart-scroll-wrapper" id="scroll-RSRP">
          <div class="chart-canvas-container" id="container-RSRP">
            <canvas id="canvas-RSRP"></canvas>
            <div class="chart-scrub-line" id="scrub-RSRP"></div>
            <div class="chart-tooltip" id="tooltip-RSRP"></div>
          </div>
        </div>
      </div>

      <!-- RSRQ -->
      <div class="metric-card" id="card-RSRQ">
        <div class="metric-card-header">
          <div class="metric-card-title">RSRQ (Reference Signal Received Quality)</div>
          <div class="metric-card-badges">
            <div class="series-badge lte" id="badge-RSRQ-lte"><span class="series-dot"></span><span>4G: N/A</span></div>
            <div class="series-badge nr5g" id="badge-RSRQ-nr5g"><span class="series-dot"></span><span>5G: N/A</span></div>
          </div>
        </div>
        <div class="chart-scroll-wrapper" id="scroll-RSRQ">
          <div class="chart-canvas-container" id="container-RSRQ">
            <canvas id="canvas-RSRQ"></canvas>
            <div class="chart-scrub-line" id="scrub-RSRQ"></div>
            <div class="chart-tooltip" id="tooltip-RSRQ"></div>
          </div>
        </div>
      </div>

      <!-- SINR -->
      <div class="metric-card" id="card-SINR">
        <div class="metric-card-header">
          <div class="metric-card-title">SINR (Signal to Interference & Noise)</div>
          <div class="metric-card-badges">
            <div class="series-badge lte" id="badge-SINR-lte"><span class="series-dot"></span><span>4G: N/A</span></div>
            <div class="series-badge nr5g" id="badge-SINR-nr5g"><span class="series-dot"></span><span>5G: N/A</span></div>
          </div>
        </div>
        <div class="chart-scroll-wrapper" id="scroll-SINR">
          <div class="chart-canvas-container" id="container-SINR">
            <canvas id="canvas-SINR"></canvas>
            <div class="chart-scrub-line" id="scrub-SINR"></div>
            <div class="chart-tooltip" id="tooltip-SINR"></div>
          </div>
        </div>
      </div>
    </main>
  </div>

  <script>
    const sessionData = $sessionJson;

    const METRIC_CONFIGS = [
      { key: 'RSSI', title: 'RSSI (Received Signal Strength)', unit: 'dBm', defaultMin: -110, defaultMax: -40 },
      { key: 'RSRP', title: 'RSRP (Reference Signal Received Power)', unit: 'dBm', defaultMin: -125, defaultMax: -65 },
      { key: 'RSRQ', title: 'RSRQ (Reference Signal Received Quality)', unit: 'dB', defaultMin: -20, defaultMax: -3 },
      { key: 'SINR', title: 'SINR (Signal to Interference & Noise)', unit: 'dB', defaultMin: -10, defaultMax: 30 }
    ];

    let currentTechMode = 'both'; // 'both', '4g', '5g'
    let currentSplitCellId = true;
    let currentZoom = 1.0;
    const MIN_ZOOM = 1.0;
    const MAX_ZOOM = 10.0;
    const ZOOM_STEP = 0.5;

    const samples = sessionData.samples || [];
    const handoffs = sessionData.handoffs || [];
    const totalDurationSeconds = Math.max(sessionData.session.actualDurationSeconds || sessionData.session.targetDurationSeconds || 60, 1);

    function formatCellIdString(val, is5g) {
      if (!val || val === '-' || val === 'N/A') return val || '-';
      const num = parseInt(val, 10);
      if (isNaN(num)) return val;
      if (!is5g) {
        const enb = Math.floor(num / 256);
        const sector = num % 256;
        return enb + '-' + sector;
      } else {
        const gnb = Math.floor(num / 16384);
        const sector = num % 16384;
        return gnb + '-' + sector;
      }
    }

    function getFormattedCellId(sample, split) {
      if (!sample) return 'N/A';
      let lteVal = sample.cellIdLte || '-';
      let nr5gVal = sample.cellIdNr5g || '-';

      if (split) {
        if (lteVal !== '-') lteVal = formatCellIdString(lteVal, false);
        if (nr5gVal !== '-') nr5gVal = formatCellIdString(nr5gVal, true);
      }

      if (currentTechMode === '4g') {
        return lteVal !== '-' ? lteVal : 'N/A';
      } else if (currentTechMode === '5g') {
        return nr5gVal !== '-' ? nr5gVal : 'N/A';
      }

      if (lteVal !== '-' && nr5gVal !== '-' && lteVal !== nr5gVal) {
        return lteVal + ' / ' + nr5gVal;
      } else if (lteVal !== '-') {
        return lteVal;
      } else if (nr5gVal !== '-') {
        return nr5gVal;
      }
      return 'N/A';
    }

    function formatTimeLabel(seconds) {
      if (seconds <= 0) return '0s';
      const rounded = Math.round(seconds);
      if (rounded < 60) return rounded + 's';
      const m = Math.floor(rounded / 60);
      const s = rounded % 60;
      if (s === 0) return m + 'm';
      return m + 'm ' + s + 's';
    }

    function calculateDynamicYRange(metricKey, defaultMin, defaultMax) {
      const show4g = currentTechMode === 'both' || currentTechMode === '4g';
      const show5g = currentTechMode === 'both' || currentTechMode === '5g';

      const vals = [];
      const lteProp = metricKey.toLowerCase() + 'Lte';
      const nr5gProp = metricKey.toLowerCase() + 'Nr5g';

      for (const s of samples) {
        if (show4g && s[lteProp] != null) vals.push(s[lteProp]);
        if (show5g && s[nr5gProp] != null) vals.push(s[nr5gProp]);
      }

      if (vals.length === 0) {
        return { minY: defaultMin, maxY: defaultMax };
      }

      let min = Math.min(...vals);
      let max = Math.max(...vals);

      if (min === max) {
        return { minY: min - 2, maxY: max + 2 };
      }

      const padding = (max - min) * 0.15;
      return {
        minY: Math.floor(min - padding),
        maxY: Math.ceil(max + padding)
      };
    }

    function drawChart(config) {
      const { key, unit, defaultMin, defaultMax } = config;
      const canvas = document.getElementById('canvas-' + key);
      const container = document.getElementById('container-' + key);
      const scrollWrapper = document.getElementById('scroll-' + key);
      const tooltip = document.getElementById('tooltip-' + key);

      const dpr = window.devicePixelRatio || 1;
      const rect = container.getBoundingClientRect();
      const cssWidth = Math.max(rect.width, 300);
      const cssHeight = 240;

      canvas.width = Math.round(cssWidth * dpr);
      canvas.height = Math.round(cssHeight * dpr);

      const ctx = canvas.getContext('2d');
      ctx.scale(dpr, dpr);

      const chartLeft = 45;
      const chartRight = cssWidth - 15;
      const chartTop = 15;
      const chartBottom = cssHeight - 25;
      const chartWidth = chartRight - chartLeft;
      const chartHeight = chartBottom - chartTop;

      ctx.clearRect(0, 0, cssWidth, cssHeight);

      const { minY, maxY } = calculateDynamicYRange(key, defaultMin, defaultMax);
      const effectiveSpan = maxY - minY <= 0 ? 1 : maxY - minY;

      // Draw horizontal grid lines & Y labels
      const numYDivisions = 3;
      ctx.strokeStyle = 'rgba(203, 213, 225, 0.4)';
      ctx.lineWidth = 1;
      ctx.fillStyle = '#64748b';
      ctx.font = '10px -apple-system, sans-serif';
      ctx.textAlign = 'right';
      ctx.textBaseline = 'middle';

      for (let i = 0; i <= numYDivisions; i++) {
        const yRatio = i / numYDivisions;
        const y = chartBottom - (yRatio * chartHeight);
        ctx.beginPath();
        ctx.moveTo(chartLeft, y);
        ctx.lineTo(chartRight, y);
        ctx.stroke();

        const val = minY + (yRatio * effectiveSpan);
        const labelText = effectiveSpan < 4 ? val.toFixed(1) : Math.round(val).toString();
        ctx.fillText(labelText, chartLeft - 6, y);
      }

      // Draw vertical grid lines & X labels
      const numXDivisions = Math.max(4, Math.round(4 * currentZoom));
      ctx.textAlign = 'center';
      ctx.textBaseline = 'top';

      for (let i = 0; i <= numXDivisions; i++) {
        const xRatio = i / numXDivisions;
        const x = chartLeft + (xRatio * chartWidth);
        ctx.beginPath();
        ctx.moveTo(x, chartTop);
        ctx.lineTo(x, chartBottom);
        ctx.stroke();

        const elapsedSec = xRatio * totalDurationSeconds;
        ctx.fillText(formatTimeLabel(elapsedSec), x, chartBottom + 6);
      }

      const show4g = currentTechMode === 'both' || currentTechMode === '4g';
      const show5g = currentTechMode === 'both' || currentTechMode === '5g';

      function drawSeries(propName, color, fillColor) {
        const points = [];
        for (const s of samples) {
          const val = s[propName];
          if (val == null) continue;
          const x = chartLeft + (s.elapsedSeconds / totalDurationSeconds) * chartWidth;
          const yRatio = (val - minY) / effectiveSpan;
          const y = chartBottom - (yRatio * chartHeight);
          points.push({ x: Math.max(chartLeft, Math.min(chartRight, x)), y: Math.max(chartTop, Math.min(chartBottom, y)), val });
        }

        if (points.length === 0) return;

        if (points.length === 1) {
          points.unshift({ x: chartLeft, y: points[0].y, val: points[0].val });
        }

        // Fill Path
        ctx.beginPath();
        ctx.moveTo(points[0].x, chartBottom);
        ctx.lineTo(points[0].x, points[0].y);

        for (let i = 0; i < points.length - 1; i++) {
          const p0 = points[i];
          const p1 = points[i + 1];
          const cpX = (p0.x + p1.x) / 2;
          ctx.bezierCurveTo(cpX, p0.y, cpX, p1.y, p1.x, p1.y);
        }
        ctx.lineTo(points[points.length - 1].x, chartBottom);
        ctx.closePath();

        const gradient = ctx.createLinearGradient(0, chartTop, 0, chartBottom);
        gradient.addColorStop(0, fillColor);
        gradient.addColorStop(1, 'rgba(255, 255, 255, 0)');
        ctx.fillStyle = gradient;
        ctx.fill();

        // Stroke Path
        ctx.beginPath();
        ctx.moveTo(points[0].x, points[0].y);
        for (let i = 0; i < points.length - 1; i++) {
          const p0 = points[i];
          const p1 = points[i + 1];
          const cpX = (p0.x + p1.x) / 2;
          ctx.bezierCurveTo(cpX, p0.y, cpX, p1.y, p1.x, p1.y);
        }
        ctx.strokeStyle = color;
        ctx.lineWidth = 2.5;
        ctx.stroke();

        // End Dot
        const lastP = points[points.length - 1];
        ctx.beginPath();
        ctx.arc(lastP.x, lastP.y, 4.5, 0, Math.PI * 2);
        ctx.fillStyle = color;
        ctx.fill();
        ctx.beginPath();
        ctx.arc(lastP.x, lastP.y, 2.0, 0, Math.PI * 2);
        ctx.fillStyle = '#ffffff';
        ctx.fill();
      }

      if (show4g) drawSeries(key.toLowerCase() + 'Lte', '#00A83B', 'rgba(0, 168, 59, 0.18)');
      if (show5g) drawSeries(key.toLowerCase() + 'Nr5g', '#003BFF', 'rgba(0, 59, 255, 0.18)');

      // Draw Handoff lines
      for (const h of handoffs) {
        if (h.elapsedSeconds > totalDurationSeconds) continue;
        const x = chartLeft + (h.elapsedSeconds / totalDurationSeconds) * chartWidth;
        if (x < chartLeft || x > chartRight) continue;

        ctx.save();
        ctx.setLineDash([3, 3]);
        ctx.strokeStyle = '#111827';
        ctx.lineWidth = 1.2;
        ctx.beginPath();
        ctx.moveTo(x, chartTop);
        ctx.lineTo(x, chartBottom);
        ctx.stroke();
        ctx.restore();
      }

      // Update card header badges with latest values
      const latest = samples.length > 0 ? samples[samples.length - 1] : null;
      updateHeaderBadge(key, latest);
    }

    function updateHeaderBadge(metricKey, sample) {
      const lteBadge = document.getElementById('badge-' + metricKey + '-lte');
      const nrBadge = document.getElementById('badge-' + metricKey + '-nr5g');
      const lteVal = sample ? sample[metricKey.toLowerCase() + 'Lte'] : null;
      const nrVal = sample ? sample[metricKey.toLowerCase() + 'Nr5g'] : null;
      const cfg = METRIC_CONFIGS.find(c => c.key === metricKey);

      lteBadge.style.display = (currentTechMode === 'both' || currentTechMode === '4g') ? 'inline-flex' : 'none';
      nrBadge.style.display = (currentTechMode === 'both' || currentTechMode === '5g') ? 'inline-flex' : 'none';

      const lteText = lteVal != null ? Math.round(lteVal) + cfg.unit : 'N/A';
      const nrText = nrVal != null ? Math.round(nrVal) + cfg.unit : 'N/A';
      lteBadge.querySelector('span:last-child').textContent = '4G: ' + lteText;
      nrBadge.querySelector('span:last-child').textContent = '5G: ' + nrText;
    }

    function renderAllCharts() {
      // Adjust canvas container width based on current zoom
      METRIC_CONFIGS.forEach(cfg => {
        const container = document.getElementById('container-' + cfg.key);
        if (currentZoom > 1.0) {
          container.style.width = (currentZoom * 100) + '%';
        } else {
          container.style.width = '100%';
        }
      });

      METRIC_CONFIGS.forEach(cfg => drawChart(cfg));
    }

    // Attach interactive hover & wheel zoom
    METRIC_CONFIGS.forEach(cfg => {
      const { key, unit } = cfg;
      const container = document.getElementById('container-' + key);
      const scrollWrapper = document.getElementById('scroll-' + key);
      const tooltip = document.getElementById('tooltip-' + key);
      const scrubLine = document.getElementById('scrub-' + key);

      container.addEventListener('mousemove', (e) => {
        const rect = container.getBoundingClientRect();
        const mouseX = e.clientX - rect.left;
        const chartLeft = 45;
        const chartRight = rect.width - 15;
        const chartWidth = chartRight - chartLeft;

        if (mouseX < chartLeft || mouseX > chartRight || samples.length === 0) {
          tooltip.style.display = 'none';
          if (scrubLine) scrubLine.style.display = 'none';
          return;
        }

        if (scrubLine) {
          scrubLine.style.display = 'block';
          scrubLine.style.left = mouseX + 'px';
        }

        const elapsedAtMouse = ((mouseX - chartLeft) / chartWidth) * totalDurationSeconds;

        // Closest sample
        let closest = samples[0];
        let minDiff = Math.abs(closest.elapsedSeconds - elapsedAtMouse);
        for (let i = 1; i < samples.length; i++) {
          const diff = Math.abs(samples[i].elapsedSeconds - elapsedAtMouse);
          if (diff < minDiff) {
            minDiff = diff;
            closest = samples[i];
          }
        }

        const time = new Date(closest.timestamp).toLocaleTimeString();
        const cellId = getFormattedCellId(closest, currentSplitCellId);

        tooltip.innerHTML = '<div class="tooltip-time">' + time + '</div><div class="tooltip-cell">Cell ID: ' + cellId + '</div>';
        tooltip.style.display = 'block';

        const tooltipWidth = tooltip.offsetWidth || 110;
        const halfW = tooltipWidth / 2;
        const clampedLeft = Math.max(chartLeft + halfW, Math.min(chartRight - halfW, mouseX));
        tooltip.style.left = clampedLeft + 'px';
        tooltip.style.top = '8px';

        // Update header badge dynamically on scrub
        updateHeaderBadge(key, closest);
      });

      container.addEventListener('mouseleave', () => {
        tooltip.style.display = 'none';
        if (scrubLine) scrubLine.style.display = 'none';
        const latest = samples.length > 0 ? samples[samples.length - 1] : null;
        updateHeaderBadge(key, latest);
      });

      // Mouse wheel zoom
      scrollWrapper.addEventListener('wheel', (e) => {
        if (e.ctrlKey || e.altKey || Math.abs(e.deltaY) > 0) {
          e.preventDefault();
          if (e.deltaY < 0) {
            setZoom(currentZoom + ZOOM_STEP);
          } else {
            setZoom(currentZoom - ZOOM_STEP);
          }
        }
      }, { passive: false });

      // Synchronize horizontal scrolling across all charts
      scrollWrapper.addEventListener('scroll', () => {
        const left = scrollWrapper.scrollLeft;
        METRIC_CONFIGS.forEach(c => {
          if (c.key !== key) {
            const other = document.getElementById('scroll-' + c.key);
            if (other && Math.abs(other.scrollLeft - left) > 1) {
              other.scrollLeft = left;
            }
          }
        });
      });
    });

    function setZoom(newZoom) {
      currentZoom = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, Math.round(newZoom * 10) / 10));
      document.getElementById('zoomLevelText').textContent = currentZoom.toFixed(1) + 'x';
      renderAllCharts();
    }

    // Zoom buttons
    document.getElementById('zoomInBtn').addEventListener('click', () => setZoom(currentZoom + ZOOM_STEP));
    document.getElementById('zoomOutBtn').addEventListener('click', () => setZoom(currentZoom - ZOOM_STEP));
    document.getElementById('zoomResetBtn').addEventListener('click', () => setZoom(1.0));

    // Tech Mode Buttons
    document.querySelectorAll('#techModeGroup button').forEach(btn => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('#techModeGroup button').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        currentTechMode = btn.dataset.mode;
        renderAllCharts();
      });
    });

    // Cell ID Format Buttons
    document.querySelectorAll('#cellIdGroup button').forEach(btn => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('#cellIdGroup button').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        currentSplitCellId = btn.dataset.split === 'true';
      });
    });

    // Window resize handler
    window.addEventListener('resize', () => {
      renderAllCharts();
    });

    // Initial render
    renderAllCharts();
  </script>
</body>
</html>''';
}
