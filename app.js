const modal = document.getElementById('checkinModal');
const startButton = document.getElementById('startCheckin');
const closeButton = document.getElementById('closeModal');
const modalAction = document.getElementById('modalAction');
const statusLine = document.getElementById('scanStatus');
const introLine = document.getElementById('modalIntro');
const progressBar = document.getElementById('scanProgress');
const toast = document.getElementById('toast');
let cameraStream;
let isScanning = false;

const now = new Date();
document.getElementById('todayDate').textContent = now.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' }).toUpperCase();
const timeOfDay = now.getHours();
const greeting = timeOfDay < 12 ? 'Good morning' : timeOfDay < 18 ? 'Good afternoon' : 'Good evening';
document.getElementById('greeting').innerHTML = `${greeting}, Anish<span>.</span>`;

function setModal(open) {
  modal.classList.toggle('open', open);
  modal.setAttribute('aria-hidden', String(!open));
  document.body.style.overflow = open ? 'hidden' : '';
  if (!open) stopCamera();
}

async function requestCamera() {
  if (!navigator.mediaDevices?.getUserMedia) return false;
  try {
    cameraStream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' }, audio: false });
    const preview = document.getElementById('cameraPreview');
    preview.srcObject = cameraStream;
    return true;
  } catch (error) {
    console.info('Camera permission was not granted; continuing with the guided demo scan.');
    return false;
  }
}

function stopCamera() {
  cameraStream?.getTracks().forEach(track => track.stop());
  cameraStream = undefined;
}

function showToast(message) {
  toast.textContent = message;
  toast.classList.add('show');
  window.setTimeout(() => toast.classList.remove('show'), 3000);
}

function updateMeasurements() {
  document.getElementById('heartRate').textContent = '66';
  document.getElementById('oxygen').textContent = '98';
  document.getElementById('bloodPressure').textContent = '117/75';
  statusLine.textContent = 'Check-in complete · signals look steady';
  introLine.textContent = 'Your pulse pattern looks calm and consistent. Here’s your refreshed wellness snapshot.';
  modalAction.innerHTML = 'Done <span class="arrow">✓</span>';
  modalAction.dataset.complete = 'true';
  showToast('Your check-in is complete ✦');
}

async function runScan() {
  if (isScanning) return;
  if (modalAction.dataset.complete === 'true') {
    setModal(false);
    modalAction.dataset.complete = 'false';
    modalAction.innerHTML = 'Begin scan <span class="arrow">→</span>';
    statusLine.textContent = 'Ready when you are';
    introLine.textContent = 'Cover the rear camera and flash on your iPhone. We’ll look for subtle pulse changes.';
    progressBar.style.width = '0%';
    return;
  }
  isScanning = true;
  modalAction.disabled = true;
  modalAction.style.opacity = '.65';
  statusLine.textContent = 'Finding your pulse…';
  const hasCamera = await requestCamera();
  if (hasCamera) introLine.textContent = 'Camera connected. Keep your finger still while we take a short reading.';
  const duration = 4800;
  const started = Date.now();
  const tick = () => {
    const progress = Math.min((Date.now() - started) / duration, 1);
    progressBar.style.width = `${Math.round(progress * 100)}%`;
    if (progress < 1) {
      window.requestAnimationFrame(tick);
    } else {
      isScanning = false;
      modalAction.disabled = false;
      modalAction.style.opacity = '1';
      updateMeasurements();
      stopCamera();
    }
  };
  window.requestAnimationFrame(tick);
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
