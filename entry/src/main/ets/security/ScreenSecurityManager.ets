import { common } from '@kit.AbilityKit';
import { FrameCallback, UIContext, window } from '@kit.ArkUI';
import { readSecuritySettings } from './SecuritySettingsManager';

export enum ScreenSecurityPage {
  ONBOARDING = 'ONBOARDING',
  ABOUT = 'ABOUT',
  SETTINGS = 'SETTINGS',
  UNLOCK = 'UNLOCK',
  AUTHENTICATOR = 'AUTHENTICATOR',
  VAULT = 'VAULT',
  GENERATOR = 'GENERATOR'
}

// These AppStorage values are transient UI signals, not a second preference store.
const COVER_KEY: string = 'timeauth.screenCovered';
const ERROR_KEY: string = 'timeauth.screenProtectionFailed';
let mainWindow: window.Window | undefined = undefined;
let uiContext: UIContext | undefined = undefined;
let currentPage: ScreenSecurityPage = ScreenSecurityPage.UNLOCK;
let resumed: boolean = false;
let focused: boolean = false;
let foreground: boolean = true;
let contentReady: boolean = false;
let pageFramePending: boolean = true;
let hideTaskPreview: boolean = true;
let appliedPrivacy: boolean | undefined = undefined;
let applying: boolean = false;
let failed: boolean = false;
let frameFailed: boolean = false;
let setupFailed: boolean = false;
let windowGeneration: number = 0;
let pageRevision: number = 0;

function pageAllowsCapture(): boolean {
  return currentPage === ScreenSecurityPage.ONBOARDING ||
    currentPage === ScreenSecurityPage.SETTINGS || currentPage === ScreenSecurityPage.ABOUT;
}

function isInteractive(): boolean {
  return resumed && focused && foreground;
}

function desiredPrivacy(): boolean {
  // Keep native privacy enabled while a capture-allowed destination is replacing a
  // sensitive page. The privacy flag itself is not visually intrusive, so this can
  // wait for the destination frame without covering normal foreground navigation.
  return setupFailed || !contentReady || !pageAllowsCapture() ||
    (pageAllowsCapture() && pageFramePending) ||
    (hideTaskPreview && !isInteractive());
}

function shouldCoverContent(): boolean {
  if (setupFailed || !contentReady) {
    return true;
  }

  // The opaque cover is for inactive/task-switching states. Do not show it during
  // ordinary foreground tab/page changes; native privacy mode can change silently.
  if (!isInteractive()) {
    return !pageAllowsCapture() || hideTaskPreview;
  }

  // If native protection actually fails on a sensitive foreground page, fail closed.
  return !pageAllowsCapture() && failed;
}

function publishState(reason: string): void {
  const covered: boolean = shouldCoverContent();
  const update: () => void = (): void => {
    AppStorage.setOrCreate<boolean>(ERROR_KEY, failed || frameFailed || setupFailed);
    AppStorage.setOrCreate<boolean>(COVER_KEY, covered);
  };
  if (uiContext !== undefined) {
    uiContext.runScopedTask(update);
  } else {
    update();
  }
  // Diagnostics contain only policy state, never clipboard values, passwords or OTPs.
  console.info(`[ScreenSecurity] ${reason} page=${currentPage} resumed=${resumed} focused=${focused}` +
    ` foreground=${foreground} hidePreview=${hideTaskPreview} cover=${covered} private=${appliedPrivacy} failed=${failed || frameFailed || setupFailed}`);
}

async function applyLatestPrivacy(): Promise<void> {
  const targetWindow: window.Window | undefined = mainWindow;
  if (targetWindow === undefined || applying) {
    return;
  }
  const target: boolean = desiredPrivacy();
  if (appliedPrivacy === target && !failed) {
    return;
  }
  const generation: number = windowGeneration;
  applying = true;
  publishState('request');
  try {
    await targetWindow.setWindowPrivacyMode(target);
    if (generation !== windowGeneration) {
      return;
    }
    const actual: boolean = targetWindow.getWindowProperties().isPrivacyMode;
    if (actual !== target) {
      throw new Error('Window privacy acknowledgement did not match the requested state');
    }
    appliedPrivacy = actual;
    failed = false;
  } catch (error) {
    if (generation !== windowGeneration) {
      return;
    }
    appliedPrivacy = undefined;
    failed = true;
    console.error(`[ScreenSecurity] request private=${target} failed: ${JSON.stringify(error)} ` +
      (error as Error).message);
  } finally {
    if (generation === windowGeneration) {
      applying = false;
      publishState('ack');
      // Coalesce changes while the previous request was in flight. Never let an old
      // foreground "false" request finish after the final background "true" request.
      if (desiredPrivacy() !== target) {
        applyLatestPrivacy();
      }
    }
  }
}

function reconcile(reason: string): void {
  publishState(reason);
  applyLatestPrivacy();
}

class PageRenderedCallback extends FrameCallback {
  private generation: number;
  private revision: number;

  constructor(generation: number, revision: number) {
    super();
    this.generation = generation;
    this.revision = revision;
  }

  onIdle(timeLeftInNano: number): void {
    if (this.generation !== windowGeneration || this.revision !== pageRevision) {
      return;
    }
    pageFramePending = false;
    frameFailed = false;
    reconcile('page-rendered');
  }
}

function waitForPageFrame(): void {
  if (uiContext === undefined) {
    return;
  }
  try {
    uiContext.postFrameCallback(new PageRenderedCallback(windowGeneration, pageRevision));
  } catch (error) {
    // Keep native privacy enabled if the replacement frame cannot be observed.
    frameFailed = true;
    publishState('frame-error');
    console.error(`[ScreenSecurity] failed to observe rendered page: ${JSON.stringify(error)}`);
  }
}

export function attachScreenSecurity(context: common.Context, targetWindow: window.Window): void {
  windowGeneration += 1;
  pageRevision += 1;
  mainWindow = targetWindow;
  uiContext = undefined;
  currentPage = ScreenSecurityPage.UNLOCK;
  resumed = false;
  focused = false;
  foreground = true;
  contentReady = false;
  pageFramePending = true;
  appliedPrivacy = undefined;
  applying = false;
  failed = false;
  frameFailed = false;
  setupFailed = false;
  hideTaskPreview = readSecuritySettings(context).hideTaskPreview;
  try {
    focused = targetWindow.isFocused();
  } catch (error) {
    console.error(`[ScreenSecurity] failed to read focus: ${JSON.stringify(error)}`);
  }
  reconcile('attach');
}

export function markScreenContentReady(context: common.Context, targetUI: UIContext): void {
  uiContext = targetUI;
  contentReady = true;
  hideTaskPreview = readSecuritySettings(context).hideTaskPreview;
  if (mainWindow !== undefined) {
    try {
      focused = mainWindow.isFocused();
    } catch (error) {
      console.error(`[ScreenSecurity] failed to refresh focus: ${JSON.stringify(error)}`);
    }
  }
  waitForPageFrame();
  reconcile('content-ready');
}

export function detachScreenSecurity(): void {
  windowGeneration += 1;
  pageRevision += 1;
  mainWindow = undefined;
  uiContext = undefined;
  contentReady = false;
  applying = false;
  appliedPrivacy = undefined;
  // Never turn privacy off on a disappearing/destroyed window.
  AppStorage.setOrCreate<boolean>(COVER_KEY, true);
}

export function setCurrentScreen(context: common.Context, page: ScreenSecurityPage): void {
  if (currentPage !== page) {
    currentPage = page;
    pageRevision += 1;
    pageFramePending = true;
    if (mainWindow !== undefined) {
      waitForPageFrame();
    }
  }
  if (mainWindow !== undefined) {
    refreshScreenSecurity(context);
  }
}

export function handleWindowStageLifecycle(event: window.WindowStageLifecycleEventType): void {
  resumed = event === window.WindowStageLifecycleEventType.RESUMED;
  reconcile(`stage:${event}`);
}

export function handleWindowEvent(event: window.WindowEventType): void {
  if (event === window.WindowEventType.WINDOW_ACTIVE) {
    focused = true;
  } else if (event === window.WindowEventType.WINDOW_INACTIVE) {
    focused = false;
  } else if (event === window.WindowEventType.WINDOW_HIDDEN) {
    focused = false;
    resumed = false;
  } else {
    return;
  }
  reconcile(`window:${event}`);
}

export function setScreenAbilityForeground(value: boolean): void {
  foreground = value;
  reconcile(value ? 'ability-foreground' : 'ability-background');
}

export function refreshScreenSecurity(context: common.Context): void {
  hideTaskPreview = readSecuritySettings(context).hideTaskPreview;
  if (mainWindow === undefined) {
    return; // Component Preview has no attached native window; never claim native protection there.
  }
  if (pageFramePending && contentReady) {
    waitForPageFrame();
  }
  reconcile('refresh');
}

export function reportScreenSecuritySetupFailure(): void {
  setupFailed = true;
  reconcile('setup-error');
}
