import { common } from '@kit.AbilityKit';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { readSecuritySettings } from './SecuritySettingsManager';

const CLEAR_DELAY_MS: number = 30 * 1000;
const systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
let clearTimer: number = -1;
let clearGeneration: number = 0;
let clearDeadline: number = 0;
let expectedChangeCount: number = -1;
let expectedDataSource: string = '';

function logClipboardFailure(operation: string, error: BusinessError): void {
  // Platform errors can contain submitted data. Never serialize their message or payload.
  const code: number = error === undefined || error === null ? -1 : error.code;
  console.error(`[SecureClipboard] ${operation} failed, code=${Number.isFinite(code) ? code : -1}`);
}

export function cancelPendingSensitiveClipboardClear(): void {
  clearGeneration += 1;
  if (clearTimer >= 0) {
    clearTimeout(clearTimer);
    clearTimer = -1;
  }
  clearDeadline = 0;
  expectedChangeCount = -1;
  expectedDataSource = '';
}

function clearIfStillOwnedByTimeAuth(): void {
  if (expectedChangeCount <= 0 || expectedDataSource.length === 0) {
    return;
  }
  try {
    const source: string = systemPasteboard.getDataSource();
    // API 18+: each copy increments this count, including copies of identical text.
    // A data source is only an app name; it cannot distinguish newer same-app values.
    const count: number = systemPasteboard.getChangeCount();
    if (count === 0) {
      return; // Metadata unavailable: keep the deadline for a foreground retry.
    }
    if (source !== expectedDataSource || count !== expectedChangeCount) {
      cancelPendingSensitiveClipboardClear();
      return;
    }
    // API 11+: synchronous clear leaves no asynchronous JavaScript gap after the check.
    // The platform has no atomic compare-and-clear API; clearing remains best effort.
    systemPasteboard.clearDataSync();
    cancelPendingSensitiveClipboardClear();
  } catch (error) {
    logClipboardFailure('clear', error as BusinessError);
    // A background restriction/transient error can be retried when the app returns.
  }
}

function scheduleClipboardClear(): void {
  if (clearTimer >= 0) {
    clearTimeout(clearTimer);
  }
  const generation: number = clearGeneration;
  clearTimer = setTimeout(() => {
    if (generation !== clearGeneration) {
      return;
    }
    clearTimer = -1;
    clearIfStillOwnedByTimeAuth();
  }, Math.max(0, clearDeadline - Date.now()));
}

export function resumeSensitiveClipboardClear(): void {
  if (expectedChangeCount <= 0) {
    return;
  }
  // Background timers can be suspended. Preserve the original deadline on return.
  if (Date.now() >= clearDeadline) {
    clearIfStillOwnedByTimeAuth();
  } else {
    scheduleClipboardClear();
  }
}

export function disposeSensitiveClipboard(): void {
  // onDestroy is best effort too: the OS may terminate a process without this callback.
  clearIfStillOwnedByTimeAuth();
  cancelPendingSensitiveClipboardClear();
}

export async function copySensitiveText(context: common.Context, text: string): Promise<boolean> {
  if (text.length === 0) {
    return false;
  }

  const shouldAutoClear: boolean = readSecuritySettings(context).clearClipboard;
  let beforeCount: number = -1;
  if (shouldAutoClear) {
    try {
      beforeCount = systemPasteboard.getChangeCount();
    } catch (error) {
      logClipboardFailure('read copy revision', error as BusinessError);
    }
  }

  try {
    const pasteData: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    const property: pasteboard.PasteDataProperty = pasteData.getProperty();
    property.shareOption = pasteboard.ShareOption.LOCALDEVICE;
    property.tag = 'timeauth-sensitive';
    pasteData.setProperty(property);
    // API 11+: keep writes serialized without pending Promise continuations/timers.
    systemPasteboard.setDataSync(pasteData);
  } catch (error) {
    logClipboardFailure('copy', error as BusinessError);
    return false; // Preserve an existing cleanup when a new write fails.
  }

  cancelPendingSensitiveClipboardClear();
  if (!shouldAutoClear || beforeCount < 0) {
    return true;
  }

  try {
    const source: string = systemPasteboard.getDataSource();
    const afterCount: number = systemPasteboard.getChangeCount();
    // API 18 (supported by our API 20 minimum): 0 also signals lookup failure.
    // Arm only when exactly our one write occurred between the two observations.
    if (afterCount <= 0 || afterCount !== beforeCount + 1 || source.length === 0) {
      return true;
    }
    expectedDataSource = source;
    expectedChangeCount = afterCount;
    clearDeadline = Date.now() + CLEAR_DELAY_MS;
    scheduleClipboardClear();
  } catch (error) {
    logClipboardFailure('schedule clear', error as BusinessError);
    // The write succeeded even if automatic-cleanup metadata is unavailable.
  }
  return true;
}
