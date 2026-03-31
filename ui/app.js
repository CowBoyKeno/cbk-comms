const app = document.getElementById('app')
const root = document.documentElement
const body = document.body
const deviceFrame = document.querySelector('.device-frame')
const closeBtn = document.getElementById('closeBtn')
const powerBtn = document.getElementById('powerBtn')
const leaveBtn = document.getElementById('leaveBtn')
const sizeDownBtn = document.getElementById('sizeDownBtn')
const sizeUpBtn = document.getElementById('sizeUpBtn')
const closeOnJoinToggle = document.getElementById('closeOnJoinToggle')
const resetLayoutBtn = document.getElementById('resetLayoutBtn')
const volumeSlider = document.getElementById('volumeSlider')
const volumeValue = document.getElementById('volumeValue')
const activeChannel = document.getElementById('activeChannel')
const activeMeta = document.getElementById('activeMeta')
const selectedTier = document.getElementById('selectedTier')
const departmentHint = document.getElementById('departmentHint')
const departmentTabs = document.getElementById('departmentTabs')
const channelList = document.getElementById('channelList')
const scaleReadout = document.getElementById('scaleReadout')
const shellLabel = document.getElementById('shellLabel')

const resourceName = typeof GetParentResourceName === 'function'
  ? GetParentResourceName()
  : 'cbk-comms'
const isStandalonePreview = window.location.protocol === 'file:' || window.location.search.includes('preview=1')
const layoutStorageKey = `${resourceName}:layout:v11`
const prefsStorageKey = `${resourceName}:prefs`
const layoutBounds = {
  margin: 8,
  maxScale: 2.5
}
const consoleModes = new Set([
  'admin_console',
  'dispatch_console',
  'admin_all',
  'dispatch_primary'
])
const shellConfigs = {
  field: {
    width: 305,
    height: 800,
    minScale: 0.4,
    defaultBias: 0.9
  },
  dispatch: {
    width: 820,
    height: 560,
    minScale: 0.35,
    defaultBias: 0.92
  }
}

let state = {
  radioOn: true,
  volume: 80,
  active: null,
  departments: {},
  uiDefaults: {
    closeOnJoin: false
  }
}

let viewState = {
  selectedDepartment: null,
  transmitActive: false
}

let pendingChannelRequest = null
let prefsHydrated = loadJson(prefsStorageKey) !== null
let layout = loadJson(layoutStorageKey) || defaultLayout()
let prefs = loadJson(prefsStorageKey) || defaultPrefs()

function loadJson(key) {
  try {
    const raw = window.localStorage.getItem(key)
    return raw ? JSON.parse(raw) : null
  } catch {
    return null
  }
}

function saveJson(key, value) {
  try {
    window.localStorage.setItem(key, JSON.stringify(value))
  } catch {
  }
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value))
}

function defaultPrefs() {
  return {
    closeOnJoin: false
  }
}

function getViewportBounds() {
  return {
    width: window.innerWidth || 1280,
    height: window.innerHeight || 720
  }
}

function getShellConfig(shell = app.dataset.shell || resolveShellTheme()) {
  return shellConfigs[shell] || shellConfigs.field
}

function getDefaultScale(shell = resolveShellTheme()) {
  const viewport = getViewportBounds()
  const config = getShellConfig(shell)
  const fitScale = Math.min(
    (viewport.width - (layoutBounds.margin * 2)) / config.width,
    (viewport.height - (layoutBounds.margin * 2)) / config.height,
    layoutBounds.maxScale
  )

  if (!Number.isFinite(fitScale) || fitScale <= 0) {
    return config.minScale
  }

  if (shell === 'field') {
    return clamp(0.87, Math.min(config.minScale, fitScale), fitScale)
  }

  return clamp(Number((fitScale * config.defaultBias).toFixed(2)), Math.min(config.minScale, fitScale), fitScale)
}

function defaultLayout(shell = resolveShellTheme()) {
  return {
    scale: getDefaultScale(shell),
    x: null,
    y: null
  }
}

function getAxisRange(total, scaledSize) {
  const min = layoutBounds.margin
  const max = total - scaledSize - layoutBounds.margin

  if (max < min) {
    const centered = Math.round((total - scaledSize) / 2)
    return { min: centered, max: centered }
  }

  return { min, max }
}

function normalizeLayout(nextLayout) {
  const shell = app.dataset.shell || resolveShellTheme()
  const config = getShellConfig(shell)
  const viewport = getViewportBounds()
  const maxScale = Math.max(
    0.25,
    Math.min(
      layoutBounds.maxScale,
      (viewport.width - (layoutBounds.margin * 2)) / config.width,
      (viewport.height - (layoutBounds.margin * 2)) / config.height
    )
  )
  const minScale = Math.min(config.minScale, maxScale)
  const fallbackScale = clamp(getDefaultScale(shell), minScale, maxScale)
  const requestedScale = typeof nextLayout.scale === 'number' ? nextLayout.scale : fallbackScale
  const scale = Number(clamp(requestedScale, minScale, maxScale).toFixed(2))
  const scaledWidth = config.width * scale
  const scaledHeight = config.height * scale
  const xRange = getAxisRange(viewport.width, scaledWidth)
  const yRange = getAxisRange(viewport.height, scaledHeight)
  const centeredX = Math.round((viewport.width - scaledWidth) / 2)
  const centeredY = Math.round((viewport.height - scaledHeight) / 2)
  const x = typeof nextLayout.x === 'number'
    ? clamp(Math.round(nextLayout.x), xRange.min, xRange.max)
    : clamp(centeredX, xRange.min, xRange.max)
  const y = typeof nextLayout.y === 'number'
    ? clamp(Math.round(nextLayout.y), yRange.min, yRange.max)
    : clamp(centeredY, yRange.min, yRange.max)

  return { scale, x, y }
}

function saveLayout() {
  saveJson(layoutStorageKey, layout)
}

function savePrefs() {
  saveJson(prefsStorageKey, prefs)
}

function applyLayout() {
  layout = normalizeLayout(layout)
  app.style.transform = `translate(${layout.x}px, ${layout.y}px) scale(${layout.scale})`
  scaleReadout.textContent = `${layout.scale.toFixed(2)}x`
}

function resizeBy(delta) {
  layout = normalizeLayout({
    ...layout,
    scale: layout.scale + delta
  })
  applyLayout()
  saveLayout()
}

function resetLayout() {
  layout = normalizeLayout(defaultLayout())
  applyLayout()
  saveLayout()
}

function ensurePrefsDefaults() {
  if (prefsHydrated) {
    return
  }

  prefs.closeOnJoin = state.uiDefaults?.closeOnJoin === true
  prefsHydrated = true
  savePrefs()
}

function nui(action, payload = {}) {
  return fetch(`https://${resourceName}/${action}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload)
  }).catch(() => {})
}

function getDepartmentEntries() {
  return Object.values(state.departments || {}).sort((left, right) => {
    if (left.authorized !== right.authorized) {
      return left.authorized ? -1 : 1
    }

    return String(left.label || left.key).localeCompare(String(right.label || right.key))
  })
}

function sortChannels(channels) {
  return Object.values(channels || {}).sort((left, right) => {
    return Number(left.voiceChannelId || 0) - Number(right.voiceChannelId || 0)
  })
}

function isConsoleShell() {
  return (app.dataset.shell || resolveShellTheme()) === 'dispatch'
}

function getConsoleRole(targetState = state, departments = Object.values(targetState.departments || {})) {
  if (targetState.active?.consoleRole === 'admin') {
    return 'admin'
  }

  if (targetState.active?.consoleRole === 'dispatch') {
    return 'dispatch'
  }

  if (departments.some((department) => department.key === 'admin' && department.authorized && department.accessMode === 'direct')) {
    return 'admin'
  }

  if (departments.some((department) => department.key === 'dispatch' && department.authorized && department.accessMode === 'direct')) {
    return 'dispatch'
  }

  return null
}

function getConsoleRoleLabel(departments, targetState = state) {
  const role = getConsoleRole(targetState, departments)
  if (role === 'admin') {
    return 'ADMIN'
  }

  if (role === 'dispatch') {
    return 'DISPATCH'
  }

  return 'CONSOLE'
}

function hasConsoleSession(targetState = state, departments = Object.values(targetState.departments || {})) {
  return getConsoleRole(targetState, departments) !== null || consoleModes.has(targetState.active?.mode)
}

function getConsoleChannelEntries(departments) {
  const entries = []

  for (const department of departments) {
    for (const channel of sortChannels(department.channels)) {
      if (!channel.canJoin) {
        continue
      }

      entries.push({ department, channel })
    }
  }

  entries.sort((left, right) => {
    return Number(left.channel.voiceChannelId || 0) - Number(right.channel.voiceChannelId || 0)
  })

  return entries
}

function resolveShellTheme() {
  const departments = Object.values(state.departments || {})
  if (hasConsoleSession(state, departments)) {
    return 'dispatch'
  }

  const activeDepartment = state.active ? state.departments?.[state.active.department] : null
  const hasDirectFieldAccess = departments.some((department) => (
    department.authorized &&
    department.key !== 'admin' &&
    department.key !== 'dispatch' &&
    department.tierLabel !== 'Admin Override' &&
    department.tierLabel !== 'Dispatch Primary'
  ))
  const activeIsField = activeDepartment && activeDepartment.key !== 'admin' && activeDepartment.key !== 'dispatch'

  if (hasDirectFieldAccess || activeIsField) {
    return 'field'
  }

  return 'field'
}

function getCompactTierLabel(label) {
  const normalized = String(label || '').toLowerCase()

  if (normalized.includes('admin')) return 'ADMIN'
  if (normalized.includes('dispatch')) return 'DISPATCH'
  if (normalized.includes('command')) return 'COMMAND'
  if (normalized.includes('supervisor')) return 'SUPERVISOR'
  if (normalized.includes('override')) return 'OVERRIDE'
  if (normalized.includes('primary')) return 'PRIMARY'
  if (normalized.includes('unauthorized')) return 'NO ACCESS'

  return String(label || 'Authorized').toUpperCase()
}

function compactDepartmentLabel(label) {
  const value = String(label || '').trim()
  const normalized = value.toLowerCase()

  if (normalized === 'police') return 'PD'
  if (normalized === 'ems') return 'EMS'
  if (normalized === 'fire') return 'FIRE'
  if (normalized === 'tow') return 'TOW'
  if (normalized === 'admin') return 'ADMIN'
  if (normalized === 'dispatch') return 'DSP'
  if (value.length <= 10) return value.toUpperCase()

  return value.slice(0, 10).toUpperCase()
}

function hexToRgba(color, alpha) {
  const value = String(color || '').trim()

  if (!value.startsWith('#')) {
    return `rgba(107, 214, 255, ${alpha})`
  }

  let hex = value.slice(1)
  if (hex.length === 3) {
    hex = hex.split('').map((part) => part + part).join('')
  }

  if (hex.length !== 6) {
    return `rgba(107, 214, 255, ${alpha})`
  }

  const intValue = Number.parseInt(hex, 16)
  const red = (intValue >> 16) & 255
  const green = (intValue >> 8) & 255
  const blue = intValue & 255
  return `rgba(${red}, ${green}, ${blue}, ${alpha})`
}

function isActiveChannel(departmentKey, channelKey) {
  return Boolean(
    state.active &&
    state.active.department === departmentKey &&
    state.active.channel === channelKey
  )
}

function hasPatchedChannel(targetState, departmentKey, channelKey) {
  return Boolean(
    (targetState?.active?.listenChannels || []).some((channelRef) => (
      channelRef.department === departmentKey &&
      channelRef.channel === channelKey
    ))
  )
}

function getActiveChannelRecord() {
  if (!state.active) {
    return null
  }

  const department = state.departments?.[state.active.department]
  const channel = department?.channels?.[state.active.channel]

  if (!department || !channel) {
    return null
  }

  return { department, channel }
}

function ensureSelectedDepartment() {
  const departments = getDepartmentEntries()

  if (!departments.length) {
    viewState.selectedDepartment = null
    return null
  }

  if (viewState.selectedDepartment) {
    const existing = departments.find((department) => department.key === viewState.selectedDepartment)
    if (existing) {
      return existing
    }
  }

  if (state.active?.department) {
    const activeDepartment = departments.find((department) => department.key === state.active.department)
    if (activeDepartment) {
      viewState.selectedDepartment = activeDepartment.key
      return activeDepartment
    }
  }

  viewState.selectedDepartment = departments[0].key
  return departments[0]
}

function setTone(element, tone) {
  if (!element) {
    return
  }

  element.dataset.tone = tone
}

function renderTabs(departments, selectedDepartment) {
  departmentTabs.innerHTML = ''
  departmentTabs.classList.toggle('hidden', isConsoleShell())

  if (isConsoleShell() || !departments.length) {
    return
  }

  for (const department of departments) {
    const button = document.createElement('button')
    const active = selectedDepartment && department.key === selectedDepartment.key
    button.type = 'button'
    button.className = `department-tab${active ? ' active' : ''}`
    button.textContent = compactDepartmentLabel(department.label)
    button.setAttribute('role', 'tab')
    button.setAttribute('aria-selected', active ? 'true' : 'false')
    button.style.borderColor = hexToRgba(department.color, active ? 0.44 : 0.18)
    button.style.color = department.authorized ? '#f2fbff' : '#8ca4b2'

    button.addEventListener('click', () => {
      viewState.selectedDepartment = department.key
      render()
    })

    departmentTabs.appendChild(button)
  }
}

function renderConsoleChannels(departments) {
  channelList.innerHTML = ''

  const entries = getConsoleChannelEntries(departments)
  if (!entries.length) {
    channelList.innerHTML = '<div class="empty-state">No accessible channels.</div>'
    return
  }

  for (const entry of entries) {
    const department = entry.department
    const channel = entry.channel
    const card = document.createElement('article')
    const active = hasPatchedChannel(state, department.key, channel.key)
    const statusTone = channel.locked ? 'warn' : 'good'
    const stateClass = channel.locked ? 'state-locked' : 'state-open'
    const lockable = department.tier >= 4 && channel.lockable

    card.className = `channel-card${active ? ' is-active' : ''}${channel.locked ? ' is-locked' : ''}`
    card.innerHTML = `
      <div class="channel-topline">
        <div class="channel-name">${channel.label}</div>
        <div class="channel-state" data-tone="${statusTone}">
          <span class="state-dot ${stateClass}"></span>${channel.locked ? 'Locked' : 'Open'}
        </div>
      </div>
      <div class="channel-meta-row">
        <div class="channel-meta">${department.label} | ${channel.memberCount} linked | VC ${channel.voiceChannelId}</div>
        <div class="channel-buttons">
          ${lockable ? `<button class="channel-button${channel.locked ? ' locked' : ''}" data-action="lock" data-department="${department.key}" data-channel="${channel.key}" data-locked="${channel.locked ? '1' : '0'}">${channel.locked ? 'Unlock' : 'Lock'}</button>` : ''}
          <button class="channel-button primary${active ? ' active' : ''}" data-action="patch" data-department="${department.key}" data-channel="${channel.key}" data-active="${active ? '1' : '0'}">${active ? 'Patched' : 'Patch'}</button>
        </div>
      </div>
    `

    channelList.appendChild(card)
  }

  channelList.querySelectorAll('[data-action="patch"]').forEach((button) => {
    button.addEventListener('click', () => {
      const active = button.dataset.active === '1'
      pendingChannelRequest = {
        department: button.dataset.department,
        channel: button.dataset.channel,
        type: 'patch',
        expectedPatched: !active
      }

      nui('togglePatch', {
        department: button.dataset.department,
        channel: button.dataset.channel
      })
    })
  })

  channelList.querySelectorAll('[data-action="lock"]').forEach((button) => {
    button.addEventListener('click', () => {
      nui('toggleLock', {
        department: button.dataset.department,
        channel: button.dataset.channel,
        locked: button.dataset.locked !== '1'
      })
    })
  })
}

function renderChannels(selectedDepartment, departments) {
  if (isConsoleShell()) {
    renderConsoleChannels(departments)
    return
  }

  channelList.innerHTML = ''

  if (!selectedDepartment) {
    channelList.innerHTML = '<div class="empty-state">No departments available.</div>'
    return
  }

  const channels = sortChannels(selectedDepartment.channels)
  if (!channels.length) {
    channelList.innerHTML = '<div class="empty-state">No channels configured.</div>'
    return
  }

  for (const channel of channels) {
    const card = document.createElement('article')
    const active = isActiveChannel(selectedDepartment.key, channel.key)
    const statusTone = channel.canJoin ? (channel.locked ? 'warn' : 'good') : 'danger'
    const stateClass = channel.canJoin ? (channel.locked ? 'state-locked' : 'state-open') : 'state-offline'
    const lockable = selectedDepartment.tier >= 4 && channel.lockable
    const joinLabel = active ? 'Connected' : 'Join'
    const stateLabel = channel.canJoin ? (channel.locked ? 'Locked' : 'Open') : 'Restricted'
    const purposeLabel = channel.lockable ? 'Secure channel' : 'Operations channel'

    card.className = `channel-card${active ? ' is-active' : ''}${channel.locked ? ' is-locked' : ''}`
    card.innerHTML = `
      <div class="channel-topline">
        <div class="channel-name">${channel.label}</div>
        <div class="channel-state" data-tone="${statusTone}">
          <span class="state-dot ${stateClass}"></span>${stateLabel}
        </div>
      </div>
      <div class="channel-meta-row">
        <div class="channel-meta">${channel.memberCount} linked | VC ${channel.voiceChannelId}<br>${purposeLabel}</div>
        <div class="channel-buttons">
          ${lockable ? `<button class="channel-button${channel.locked ? ' locked' : ''}" data-action="lock" data-department="${selectedDepartment.key}" data-channel="${channel.key}" data-locked="${channel.locked ? '1' : '0'}">${channel.locked ? 'Unlock' : 'Lock'}</button>` : ''}
          <button class="channel-button primary" data-action="join" data-department="${selectedDepartment.key}" data-channel="${channel.key}" ${channel.canJoin ? '' : 'disabled'}>${joinLabel}</button>
        </div>
      </div>
    `

    channelList.appendChild(card)
  }

  channelList.querySelectorAll('[data-action="join"]').forEach((button) => {
    button.addEventListener('click', () => {
      pendingChannelRequest = {
        department: button.dataset.department,
        channel: button.dataset.channel,
        type: 'join'
      }

      nui('join', {
        department: button.dataset.department,
        channel: button.dataset.channel
      })
    })
  })

  channelList.querySelectorAll('[data-action="lock"]').forEach((button) => {
    button.addEventListener('click', () => {
      nui('toggleLock', {
        department: button.dataset.department,
        channel: button.dataset.channel,
        locked: button.dataset.locked !== '1'
      })
    })
  })
}

function renderSummary(departments, selectedDepartment, activeRecord) {
  const powerValue = powerBtn.querySelector('.hud-value')
  powerValue.textContent = state.radioOn ? 'ON' : 'OFF'
  powerValue.style.color = state.radioOn ? 'var(--screen-green)' : 'var(--screen-red)'
  powerBtn.dataset.active = state.radioOn ? '1' : '0'

  volumeSlider.value = Number(state.volume || 0)
  volumeValue.textContent = String(state.volume || 0)

  if (activeRecord) {
    if (isConsoleShell() && hasConsoleSession(state, departments) && (state.active?.listenChannels || []).length > 0) {
      activeChannel.textContent = state.active.scopeLabel || `${getConsoleRoleLabel(departments)} Patch`
      activeMeta.textContent = `${(state.active.listenChannels || []).length} patched | Focus ${state.active.focusLabel || `${activeRecord.department.label} / ${activeRecord.channel.label}`}`
    } else {
      activeChannel.textContent = `${activeRecord.department.label} / ${activeRecord.channel.label}`
      activeMeta.textContent = `${activeRecord.channel.memberCount} linked | Voice ${activeRecord.channel.voiceChannelId}`
    }
  } else {
    activeChannel.textContent = isConsoleShell() ? 'Console offline' : 'Not connected'
    activeMeta.textContent = isConsoleShell() ? 'Patch into a channel to start monitoring' : 'Waiting for assignment'
  }

  if (isConsoleShell()) {
    const consoleChannels = getConsoleChannelEntries(departments)
    selectedTier.textContent = getConsoleRoleLabel(departments)
    setTone(selectedTier, consoleChannels.length > 0 ? 'good' : 'danger')
    departmentHint.textContent = consoleChannels.length > 0 ? `${consoleChannels.length} channels visible` : 'No accessible channels'
  } else if (selectedDepartment) {
    selectedTier.textContent = getCompactTierLabel(selectedDepartment.tierLabel)
    setTone(selectedTier, selectedDepartment.authorized ? 'good' : 'danger')
    departmentHint.textContent = selectedDepartment.memberLabel || `${sortChannels(selectedDepartment.channels).length} channels ready`
  } else {
    selectedTier.textContent = 'No Access'
    setTone(selectedTier, 'danger')
    departmentHint.textContent = 'Select a department'
  }

  closeOnJoinToggle.checked = prefs.closeOnJoin === true

  const shell = app.dataset.shell
  shellLabel.textContent = shell === 'dispatch' ? 'COMMS CONSOLE' : 'FIELD HANDSET'
}

function render() {
  ensurePrefsDefaults()
  app.dataset.shell = resolveShellTheme()
  applyLayout()

  const departments = getDepartmentEntries()
  const selectedDepartment = ensureSelectedDepartment()
  const activeRecord = getActiveChannelRecord()

  renderSummary(departments, selectedDepartment, activeRecord)
  renderTabs(departments, selectedDepartment)
  renderChannels(selectedDepartment, departments)
}

function setVisible(visible) {
  root.classList.toggle('nui-hidden', !visible)
  app.classList.toggle('hidden', !visible)
}

function createPreviewState() {
  return {
    radioOn: true,
    volume: 80,
    active: {
      department: 'police',
      channel: 'primary'
    },
    uiDefaults: {
      closeOnJoin: false
    },
    departments: {
      police: {
        key: 'police',
        label: 'Police',
        color: '#2f72b6',
        authorized: true,
        accessMode: 'direct',
        tier: 4,
        tierLabel: 'Command',
        memberLabel: '2A11 Command',
        channels: {
          primary: {
            key: 'primary',
            label: 'PD-PRIMARY',
            voiceChannelId: 41011,
            memberCount: 3,
            locked: false,
            lockable: false,
            canJoin: true
          },
          alpha: {
            key: 'alpha',
            label: 'PD-ALPHA',
            voiceChannelId: 41012,
            memberCount: 0,
            locked: true,
            lockable: true,
            canJoin: true
          },
          bravo: {
            key: 'bravo',
            label: 'PD-BRAVO',
            voiceChannelId: 41013,
            memberCount: 1,
            locked: false,
            lockable: true,
            canJoin: true
          }
        }
      },
      ems: {
        key: 'ems',
        label: 'EMS',
        color: '#d03f4f',
        authorized: true,
        accessMode: 'direct',
        tier: 2,
        tierLabel: 'Field',
        memberLabel: 'Medic 4',
        channels: {
          primary: {
            key: 'primary',
            label: 'EMS-PRIMARY',
            voiceChannelId: 42011,
            memberCount: 2,
            locked: false,
            lockable: false,
            canJoin: true
          },
          bravo: {
            key: 'bravo',
            label: 'EMS-BRAVO',
            voiceChannelId: 42012,
            memberCount: 0,
            locked: true,
            lockable: true,
            canJoin: true
          }
        }
      }
    }
  }
}

function bootStandalonePreview() {
  root.classList.add('preview-mode')
  body.classList.add('preview-mode')
  state = createPreviewState()
  setVisible(true)
  render()
}

if (isStandalonePreview) {
  bootStandalonePreview()
} else {
  app.dataset.shell = resolveShellTheme()
  applyLayout()
  setVisible(false)
}

window.addEventListener('message', (event) => {
  const data = event.data || {}

  if (data.action === 'visibility') {
    setVisible(data.payload?.visible === true)
  }

  if (data.action === 'state') {
    state = data.payload || state
    render()

    if (pendingChannelRequest) {
      let requestSucceeded = false

      if (pendingChannelRequest.type === 'patch') {
        const patched = hasPatchedChannel(state, pendingChannelRequest.department, pendingChannelRequest.channel)
        requestSucceeded = pendingChannelRequest.expectedPatched ? patched : !patched
      } else {
        requestSucceeded = Boolean(
          state.active &&
          state.active.department === pendingChannelRequest.department &&
          state.active.channel === pendingChannelRequest.channel
        )
      }

      const shouldClose = pendingChannelRequest.type === 'patch'
        ? pendingChannelRequest.expectedPatched === true
        : true

      pendingChannelRequest = null

      if (requestSucceeded && shouldClose && prefs.closeOnJoin === true) {
        nui('close')
      }
    }
  }

  if (data.action === 'transmit') {
    viewState.transmitActive = data.payload?.active === true
  }
})

closeBtn.addEventListener('click', () => nui('close'))
leaveBtn.addEventListener('click', () => nui('leave'))
sizeDownBtn.addEventListener('click', () => resizeBy(-0.08))
sizeUpBtn.addEventListener('click', () => resizeBy(0.08))
resetLayoutBtn.addEventListener('click', resetLayout)

closeOnJoinToggle.addEventListener('change', () => {
  prefs.closeOnJoin = closeOnJoinToggle.checked === true
  prefsHydrated = true
  savePrefs()
})

powerBtn.addEventListener('click', () => {
  nui('togglePower', {
    enabled: !state.radioOn
  })
})

volumeSlider.addEventListener('input', () => {
  volumeValue.textContent = volumeSlider.value
})

volumeSlider.addEventListener('change', () => {
  nui('setVolume', {
    volume: Number(volumeSlider.value)
  })
})

document.addEventListener('keyup', (event) => {
  if (event.key === 'Escape') {
    nui('close')
  }
})

document.addEventListener('contextmenu', (event) => {
  event.preventDefault()
  nui('releaseFocus')
})

deviceFrame.addEventListener('mousedown', (event) => {
  if (event.button !== 0) {
    return
  }

  const interactiveTarget = event.target.closest('button, input, label')
  const inHeader = event.target.closest('.screen-header')
  const outsideScreen = !event.target.closest('.device-screen')

  if (interactiveTarget || (!inHeader && !outsideScreen)) {
    return
  }

  const offsetX = event.clientX - layout.x
  const offsetY = event.clientY - layout.y

  const onMove = (moveEvent) => {
    layout = normalizeLayout({
      ...layout,
      x: moveEvent.clientX - offsetX,
      y: moveEvent.clientY - offsetY
    })
    applyLayout()
  }

  const onUp = () => {
    window.removeEventListener('mousemove', onMove)
    window.removeEventListener('mouseup', onUp)
    saveLayout()
  }

  event.preventDefault()
  window.addEventListener('mousemove', onMove)
  window.addEventListener('mouseup', onUp)
})

window.addEventListener('resize', () => {
  applyLayout()
})
