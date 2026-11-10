// Utility: promisified delay using async/await pattern (replaces setTimeout callback)
function delay(ms) {
  return new Promise(function (resolve) {
    setTimeout(resolve, ms);
  });
}

(async function () {
  function resetToDefaults() {
    topbar.config({
      autoRun: true,
      barThickness: 3,
      barColors: {
        '.75': 'rgba(255, 255, 60, .9)',
        '.75': 'rgba(255, 212, 0, .9)',
        '1.0': 'rgba(211, 84,  0, .9)'
      },
      shadowBlur: 10,
      shadowColor: 'rgba(0,   0,   0,   .6)',
      className: 'topbar'
    });
  }

  resetToDefaults();
  topbar.show();

  // Replaced nested setTimeout callback with async/await for clarity and maintainability
  await delay(1500);
  $('#container').fadeIn('slow');
  topbar.hide();
})();
