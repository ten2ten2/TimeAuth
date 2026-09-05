import { common } from '@kit.AbilityKit';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { readSecuritySettings } from './SecuritySettingsManager';

const CLEAR_DELAY_MS: number = 30 * 1000;
const systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
let clearTimer: number = -1;
let updateListener: (() => void) | undefined = undefined;
let suppressNextUpdate: boolean = false;
let expectedDataSource: string = '';

function stopMonitoring(): void {
  if (updateListener !== undefined) {
    try {
      systemPasteboard.off('update', updateListener);
    } catch (error) {
      console.error(`Failed to stop TimeAuth pasteboard listener: ${JSON.stringify(error)}`);
    }
    updateListener = undefined;
  }
  suppressNextUpdate = false;
}

export function cancelPendingSensitiveClipboardClear(): void {
  if (clearTimer >= 0) {
    clearTimeout(clearTimer);
    clearTimer = -1;
  }
  stopMonitoring();
  expectedDataSource = '';
}

function clearIfStillOwnedByTimeAuth(): void {
  let shouldClear: boolean = false;
  try {
    const currentDataSource: string = systemPasteboard.getDataSource();
    shouldClear = expectedDataSource.length > 0 && currentDataSource === expectedDataSource;
  } catch (error) {
    console.error(`Failed to verify TimeAuth pasteboard data source: ${JSON.stringify(error)}`);
  }

  stopMonitoring();
  clearTimer = -1;
  expectedDataSource = '';

  if (!shouldClear) {
    return;
  }

  systemPasteboard.clearData().catch((error: BusinessError) => {
    console.error(`Failed to clear TimeAuth sensitive clipboard data: ${JSON.stringify(error)}`);
  });
}

export async function copySensitiveText(context: common.Context, text: string): Promise<boolean> {
  if (text.length === 0) {
    return false;
  }

  cancelPendingSensitiveClipboardClear();

  const pasteData: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
  const property: pasteboard.PasteDataProperty = pasteData.getProperty();
  property.shareOption = pasteboard.ShareOption.LOCALDEVICE;
  property.tag = 'timeauth-sensitive';
  pasteData.setProperty(property);

  suppressNextUpdate = true;
  updateListener = (): void => {
    if (suppressNextUpdate) {
      suppressNextUpdate = false;
      return;
    }
    // Another copy replaced the TimeAuth value. Never clear the user's newer clipboard content.
    cancelPendingSensitiveClipboardClear();
  };

  try {
    systemPasteboard.on('update', updateListener);
    await systemPasteboard.setData(pasteData);
    expectedDataSource = systemPasteboard.getDataSource();
  } catch (error) {
    cancelPendingSensitiveClipboardClear();
    console.error(`Failed to copy TimeAuth sensitive data: ${JSON.stringify(error)}`);
    return false;
  }

  if (!readSecuritySettings(context).clearClipboard) {
    cancelPendingSensitiveClipboardClear();
    return true;
  }

  clearTimer = setTimeout(() => {
    clearIfStillOwnedByTimeAuth();
  }, CLEAR_DELAY_MS);

  return true;
}
