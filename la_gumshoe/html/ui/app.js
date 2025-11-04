// minimal app.js - safe handlers for La Gumshoe test UI
(() => {
  const root = document.getElementById('app')
  const closeBtn = document.getElementById('close')
  const recordBtn = document.getElementById('record')
  const markBtn = document.getElementById('mark')
  const collectBtn = document.getElementById('collect')
  const victimName = document.getElementById('victimName')
  const victimType = document.getElementById('victimType')
  const estTOD = document.getElementById('estTOD')
  const causeField = document.getElementById('cause')
  const criticalField = document.getElementById('critical')
  const cluesList = document.getElementById('clues')

  function post(endpoint, payload = {}) {
    fetch(`https://${GetParentResourceName()}/${endpoint}`, { method: 'POST', body: JSON.stringify(payload) }).catch(()=>{})
  }

  function toArray(v){ if(!v) return []; if(Array.isArray(v)) return v; if(typeof v === 'string') return [v]; return [] }

  window.addEventListener('message', (ev) => {
    const m = ev.data
    if(!m) return
    if(m.action === 'open') {
      const d = m.data || {}
      victimName.innerText = d.victim || 'Unknown'
      victimType.innerText = (d.victim_type || 'npc').toUpperCase()
      estTOD.innerText = d.estimated_tod || '—'
      causeField.innerText = (d.cause || 'unknown').toUpperCase()
      criticalField.innerText = (d.critical_area || 'unknown').toUpperCase()
      let clues = []
      if(d.scene && d.scene.clues) clues = toArray(d.scene.clues)
      else if(d.scene_data && d.scene_data.clues) clues = toArray(d.scene_data.clues)
      if(!clues.length) clues = ['No obvious clues']
      cluesList.innerHTML = ''
      clues.forEach(x => { const li = document.createElement('li'); li.innerText = x; cluesList.appendChild(li) })
      root.classList.remove('hidden')
    } else if(m.action === 'close') {
      root.classList.add('hidden')
    }
  })

  closeBtn.addEventListener('click', ()=>{ post('close',{}); root.classList.add('hidden') })
  recordBtn.addEventListener('click', ()=>{ 
    const payload = {
      victim_type: victimType.innerText || 'npc',
      victim_identifier: victimName.innerText || null,
      estimated_tod: estTOD.innerText || null,
      cause: causeField.innerText || 'unknown',
      critical_area: criticalField.innerText || 'unknown',
      scene_data: { clues: Array.from(cluesList.children).map(li=>li.innerText) }
    }
    post('saveInvestigation', payload)
  })
  markBtn.addEventListener('click', ()=>post('markEvidence', {}))
  collectBtn.addEventListener('click', ()=>post('collectSample', {}))

  window.addEventListener('keydown', (ev) => {
    if(ev.key === 'Escape') { post('close',{}); root.classList.add('hidden') }
  })

  console.info('la_gumshoe NUI test loaded')
})()
