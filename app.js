(function(){
  const built = new Date().toISOString();
  document.getElementById('built').textContent = built;
  // Simple build/version marker; in CI we will replace __GIT_SHA__ env
  const version = {
    git: '__GIT_SHA__',
    time: built
  };
  document.getElementById('version').textContent = JSON.stringify(version, null, 2);
})();
