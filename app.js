const modal = document.getElementById('checkinModal');
const startButton = document.getElementById('startCheckin');
const closeButton = document.getElementById('closeModal');
const modalAction = document.getElementById('modalAction');
const statusLine = document.getElementById('scanStatus');
const introLine = document.getElementById('modalIntro');
const progressBar = document.getElementById('scanProgress');
const toast = document.getElementById('toast');
const preview = document.getElementById('cameraPreview');
const canvas = document.getElementById('ppgCanvas');
const canvasContext = canvas.getContext('2d', { willReadFrequently: true });

let cameraStream;
let cameraTrack;
let isScanning = false;
let scanFrameId;
let scanStartedAt;
let lastSampleAt = 0;
let samples = [];

const now = new Date();
document.getElementById('todayDate').textContent = now.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' }).toUpperCase();
const timeOfDay = now.getHours();
const greeting = timeOfDay < 12 ? 'Good morning' : timeOfDay < 18 ? 'Good afternoon' : 'Good evening';
document.getElementById('greeting').innerHTML = `${greeting}, Anish<span>.</span>`;

function setModal(open) {
  modal.classList.toggle('open', open);
  modal.setAttribute('aria-hidden', String(!open));
  document.body.style.overflow = open ? 'hidden' : '';
  if (!open) {
    cancelScan();
    resetScanUi();
  }
}

async function requestCamera() {
  if (!navigator.mediaDevices?.getUserMedia) {
    throw new Error('This browser cannot access the camera.');
  }

  cameraStream = await navigator.mediaDevices.getUserMedia({
    audio: false,
    video: {
      facingMode: { ideal: 'environment' },
      width: { ideal: 640 },
      height: { ideal: 480 },
      frameRate: { ideal: 30 }
    }
  });

  cameraTrack = cameraStream.getVideoTracks()[0];
  preview.srcObject = cameraStream;
  await preview.play();

  // Some browsers expose the rear-camera torch. It improves the signal, but is optional.
  const capabilities = cameraTrack.getCapabilities?.();
  if (capabilities?.torch) {
    try { await cameraTrack.applyConstraints({ advanced: [{ torch: true }] }); } catch (error) { /* torch is optional */ }
  }
}

function stopCamera() {
  const capabilities = cameraTrack?.getCapabilities?.();
  if (capabilities?.torch) {
    cameraTrack.applyConstraints({ advanced: [{ torch: false }] }).catch(() => {});
  }
  cameraStream?.getTracks().forEach(track => track.stop());
  cameraStream = undefined;
  cameraTrack = undefined;
  preview.srcObject = null;
}

function showToast(message) {
  toast.textContent = message;
  toast.classList.add('show');
  window.setTimeout(() => toast.classList.remove('show'), 3000);
}

function resetScanUi() {
  modalAction.disabled = false;
  modalAction.style.opacity = '1';
  modalAction.dataset.complete = 'false';
  modalAction.innerHTML = 'Begin scan <span class="arrow">→</span>';
  statusLine.textContent = 'Ready when you are';
  introLine.textContent = 'Cover the rear camera and flash on your iPhone. Keep your finger still while Vita measures your pulse.';
  progressBar.style.width = '0%';
}

function cancelScan() {
  isScanning = false;
  if (scanFrameId) window.cancelAnimationFrame(scanFrameId);
  scanFrameId = undefined;
  stopCamera();
  if (modalAction.dataset.complete !== 'true') resetScanUi();
}

// Camera PPG: average the red/green light signal under the fingertip, then
// find the strongest repeating period in the normal resting-heart-rate range.
function captureSample(timestamp) {
  if (timestamp - lastSampleAt < 50 || preview.readyState < 2) return;
  lastSampleAt = timestamp;
  canvasContext.drawImage(preview, 0, 0, canvas.width, canvas.height);
  const pixels = canvasContext.getImageData(0, 0, canvas.width, canvas.height).data;
  let red = 0;
  let green = 0;
  let count = 0;
  for (let index = 0; index < pixels.length; index += 4) {
    red += pixels[index];
    green += pixels[index + 1];
    count += 1;
  }
  // The red/green ratio is more stable than raw brightness when exposure shifts.
  samples.push({ time: timestamp, value: red / Math.max(green, 1) });
}

function detrend(values, windowSize) {
  return values.map((value, index) => {
    const start = Math.max(0, index - windowSize);
    const end = Math.min(values.length, index + windowSize + 1);
    let total = 0;
    for (let cursor = start; cursor < end; cursor += 1) total += values[cursor];
    return value - total / (end - start);
  });
}

function correlationAtLag(values, lag) {
  const length = values.length - lag;
  let leftMean = 0;
  let rightMean = 0;
  for (let index = 0; index < length; index += 1) {
    leftMean += values[index];
    rightMean += values[index + lag];
  }
  leftMean /= length;
  rightMean /= length;
  let numerator = 0;
  let leftPower = 0;
  let rightPower = 0;
  for (let index = 0; index < length; index += 1) {
    const left = values[index] - leftMean;
    const right = values[index + lag] - rightMean;
    numerator += left * right;
    leftPower += left * left;
    rightPower += right * right;
  }
  return numerator / Math.sqrt(Math.max(leftPower * rightPower, Number.EPSILON));
}

function estimatePulse() {
  if (samples.length < 100) return null;
  const sampleRate = (samples.length - 1) / ((samples[samples.length - 1].time - samples[0].time) / 1000);
  const values = samples.map(sample => sample.value);
  const normalized = detrend(values, Math.max(8, Math.round(sampleRate * 0.8)));
  const signalEnergy = Math.sqrt(normalized.reduce((total, value) => total + value * value, 0) / normalized.length);
  if (signalEnergy < 0.0003) return null;
  let bestLag = 0;
  let bestCorrelation = -1;
  const minLag = Math.max(2, Math.floor(sampleRate * 60 / 180));
  const maxLag = Math.ceil(sampleRate * 60 / 42);
  for (let lag = minLag; lag <= maxLag && lag < normalized.length / 2; lag += 1) {
    const correlation = correlationAtLag(normalized, lag);
    if (correlation > bestCorrelation) {
      bestCorrelation = correlation;
      bestLag = lag;
    }
  }
  if (!bestLag || bestCorrelation < 0.18) return null;
  const bpm = Math.round(60 * sampleRate / bestLag);
  if (bpm < 42 || bpm > 180) return null;
  return { bpm, confidence: Math.round(Math.min(0.99, Math.max(0.35, bestCorrelation))) };
}

function updateMeasurements(result) {
  document.getElementById('heartRate').textContent = String(result.bpm);
  document.querySelector('.signal-heart .trend').textContent = `${result.confidence >= 0.65 ? 'stable' : 'estimate'}`;
  statusLine.textContent = `Pulse detected · ${result.bpm} bpm`;
  introLine.textContent = 'Your camera captured a repeating pulse signal. Keep checking at similar times to build a personal trend.';
  modalAction.innerHTML = 'Done <span class="arrow">✓</span>';
  modalAction.dataset.complete = 'true';
  showToast(`Pulse captured · ${result.bpm} bpm`);
}

function finishScan() {
  const result = estimatePulse();
  isScanning = false;
  if (scanFrameId) window.cancelAnimationFrame(scanFrameId);
  scanFrameId = undefined;
  stopCamera();
  modalAction.disabled = false;
  modalAction.style.opacity = '1';
  if (result) {
    updateMeasurements(result);
  } else {
    statusLine.textContent = 'Signal too weak to read';
    introLine.textContent = 'No stable pulse pattern came through. Try again with the flash covered and your finger completely still.';
    modalAction.innerHTML = 'Try again <span class="arrow">↻</span>';
    modalAction.dataset.complete = 'false';
  }
}

function collectPulse(timestamp) {
  if (!isScanning) return;
  captureSample(timestamp);
  const elapsed = timestamp - scanStartedAt;
  progressBar.style.width = `${Math.min(100, Math.round(elapsed / 12000 * 100))}%`;
  if (elapsed < 12000) {
    const seconds = Math.floor(elapsed / 1000);
    statusLine.textContent = seconds < 3 ? 'Warming up the signal…' : seconds < 9 ? 'Reading your pulse…' : 'Checking signal quality…';
    scanFrameId = window.requestAnimationFrame(collectPulse);
  } else {
    finishScan();
  }
}

async function runScan() {
  if (isScanning) return;
  if (modalAction.dataset.complete === 'true') {
    setModal(false);
    resetScanUi();
    return;
  }

  isScanning = true;
  samples = [];
  lastSampleAt = 0;
  scanStartedAt = performance.now();
  modalAction.disabled = true;
  modalAction.style.opacity = '.65';
  statusLine.textContent = 'Opening the rear camera…';

  try {
    await requestCamera();
    introLine.textContent = 'Camera connected. Keep your finger still while Vita measures your pulse.';
    scanStartedAt = performance.now();
    scanFrameId = window.requestAnimationFrame(collectPulse);
  } catch (error) {
    isScanning = false;
    stopCamera();
    modalAction.disabled = false;
    modalAction.style.opacity = '1';
    statusLine.textContent = 'Camera access is required';
    introLine.textContent = 'Open this app over HTTPS, allow Safari to use the camera, then try again.';
    showToast('Camera access was not available');
  }
}

startButton.addEventListener('click', () => setModal(true));
closeButton.addEventListener('click', () => setModal(false));
modalAction.addEventListener('click', runScan);
modal.addEventListener('click', event => { if (event.target === modal) setModal(false); });
document.addEventListener('keydown', event => { if (event.key === 'Escape') setModal(false); });

document.getElementById('seeInsights').addEventListener('click', () => {
  document.querySelector('.recommendations-section').scrollIntoView({ behavior: 'smooth', block: 'start' });
});

document.querySelectorAll('.nav-item').forEach(item => {
  item.addEventListener('click', () => {
    document.querySelectorAll('.nav-item').forEach(nav => nav.classList.remove('active'));
    item.classList.add('active');
    if (item.dataset.tab === 'insights') {
      document.querySelector('.signals-section').scrollIntoView({ behavior: 'smooth', block: 'start' });
      showToast('Insights are ready above ↑');
    }
    if (item.dataset.tab === 'profile') showToast('Profile settings coming soon');
    if (item.dataset.tab === 'home') window.scrollTo({ top: 0, behavior: 'smooth' });
  });
});
