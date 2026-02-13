import {
  AbilityAware,
  AbilityPluginBinding,
  ByteBuffer,
  FlutterPlugin,
  Log,
  MethodCall,
  MethodChannel
} from '@ohos/flutter_ohos';
import { MethodCallHandler, MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import { FlutterPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import { common, UIAbility } from '@kit.AbilityKit';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import fileuri from '@ohos.file.fileuri';

const TAG: string = 'PublicFileSaverPlugin';
const CHANNEL_NAME: string = 'public_file_saver';

/**
 * Convert bytes from Flutter to Uint8Array.
 * Flutter may send bytes as Uint8Array, ArrayBuffer, or Array.
 */
function toUint8Array(data: ESObject): Uint8Array {
  if (data instanceof Uint8Array) {
    return data;
  }
  if (data instanceof ArrayBuffer) {
    return new Uint8Array(data);
  }
  if (Array.isArray(data)) {
    return new Uint8Array(data);
  }
  // Try to handle other buffer types
  if (data && data.buffer instanceof ArrayBuffer) {
    return new Uint8Array(data.buffer);
  }
  throw new Error('Cannot convert data to Uint8Array');
}


export default class PublicFileSaverPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private methodChannel: MethodChannel | null = null;
  private ability: UIAbility | null = null;

  getUniqueClassName(): string {
    return 'PublicFileSaverPlugin';
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.ability = binding.getAbility();
  }

  onDetachedFromAbility(): void {
    this.ability = null;
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.methodChannel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
    this.methodChannel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(): void {
    this.methodChannel?.setMethodCallHandler(null);
    this.methodChannel = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'saveBytes':
        this.saveBytes(call, result);
        break;
      case 'saveBytesWithDialog':
        this.saveBytesWithDialog(call, result);
        break;
      // Legacy methods for backward compatibility
      case 'saveCacheFileToDownloads':
        this.saveCacheFileToDownloads(call, result);
        break;
      case 'saveCacheFileWithDialog':
        this.saveCacheFileWithDialog(call, result);
        break;
      default:
        result.notImplemented();
    }
  }

  /**
   * Save bytes directly to Downloads directory (no dialog).
   * Uses DocumentViewPicker with DOWNLOAD mode to get the Downloads/<bundle>/ directory.
   */
  private async saveBytes(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      if (!this.ability) {
        result.error('NO_ABILITY', 'UIAbility is null (plugin not attached to ability).', null);
        return;
      }

      const ctx = this.ability.context as common.UIAbilityContext;
      const bytesArg = call.argument('bytes') as ByteBuffer;
      const fileName = call.argument('fileName') as string;

      if (!bytesArg || !fileName) {
        result.error('INVALID_ARGUMENTS', 'bytes and fileName are required', null);
        return;
      }

      const bytes = toUint8Array(bytesArg);
      const documentViewPicker = new picker.DocumentViewPicker(ctx);

      const opts = new picker.DocumentSaveOptions();
      // DOWNLOAD mode: Get Download/<bundleName>/ directory URI directly
      opts.pickerMode = picker.DocumentPickerMode.DOWNLOAD;

      const uris: Array<string> = await documentViewPicker.save(opts);
      if (!uris || uris.length === 0) {
        // User cancelled (though DOWNLOAD mode usually doesn't show UI)
        result.success(null);
        return;
      }

      const dirUri: string = uris[0];
      const dstUri: string = `${dirUri}/${fileName}`;
      const dstPath: string = new fileuri.FileUri(dstUri).path;

      // Write bytes to file
      const dstFile = fs.openSync(dstUri, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(dstFile.fd, bytes.buffer);
      fs.closeSync(dstFile);

      const response: Record<string, string | null> = {
        'fileName': fileName,
        'uri': dstUri,
        'path': dstPath
      };
      result.success(response);

    } catch (e) {
      Log.e(TAG, `saveBytes failed: ${JSON.stringify(e)}`);
      result.error('SAVE_FAILED', String(e), null);
    }
  }

  /**
   * Save bytes with system file picker dialog.
   * Uses DocumentViewPicker.save with DocumentSaveOptions to let user choose location.
   */
  private async saveBytesWithDialog(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      if (!this.ability) {
        result.error('NO_ABILITY', 'UIAbility is null (plugin not attached to ability).', null);
        return;
      }

      const ctx = this.ability.context as common.UIAbilityContext;
      const bytesArg = call.argument('bytes') as ByteBuffer;
      const fileName = call.argument('fileName') as string;
      const fileSuffixChoices = call.argument('fileSuffixChoices') as Array<string> | null;

      if (!bytesArg || !fileName) {
        result.error('INVALID_ARGUMENTS', 'bytes and fileName are required', null);
        return;
      }

      const bytes = toUint8Array(bytesArg);
      const documentViewPicker = new picker.DocumentViewPicker(ctx);

      const opts = new picker.DocumentSaveOptions();
      opts.newFileNames = [fileName];

      if (fileSuffixChoices && fileSuffixChoices.length > 0) {
        opts.fileSuffixChoices = fileSuffixChoices.map((x) => String(x));
      }

      const uris: Array<string> = await documentViewPicker.save(opts);
      if (!uris || uris.length === 0) {
        // User cancelled
        result.success(null);
        return;
      }

      const fileUriStr: string = uris[0];
      const dstPath: string = new fileuri.FileUri(fileUriStr).path;
      const savedFileName: string = dstPath.substring(dstPath.lastIndexOf('/') + 1);

      // Write bytes to the selected file
      const dstFile = fs.openSync(fileUriStr, fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(dstFile.fd, bytes.buffer);
      fs.closeSync(dstFile);

      const response: Record<string, string | null> = {
        'fileName': savedFileName,
        'uri': fileUriStr,
        'path': dstPath
      };
      result.success(response);

    } catch (e) {
      Log.e(TAG, `saveBytesWithDialog failed: ${JSON.stringify(e)}`);
      result.error('SAVE_FAILED', String(e), null);
    }
  }

  // ==================== Legacy Methods for Backward Compatibility ====================

  /**
   * Legacy method: Save cache file to Downloads (no dialog).
   * Kept for backward compatibility.
   */
  private async saveCacheFileToDownloads(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      if (!this.ability) {
        result.error('NO_ABILITY', 'UIAbility is null (plugin not attached to ability).', null);
        return;
      }

      const ctx = this.ability.context as common.UIAbilityContext;
      const cachePath = this.normalizeCachePath(ctx, String(call.argument('cachePath')));
      const fileName = String(call.argument('fileName'));

      const documentViewPicker = new picker.DocumentViewPicker(ctx);
      const opts = new picker.DocumentSaveOptions();
      opts.pickerMode = picker.DocumentPickerMode.DOWNLOAD;

      const uris: Array<string> = await documentViewPicker.save(opts);
      if (!uris || uris.length === 0) {
        result.success(null);
        return;
      }

      const dirUri: string = uris[0];
      const dstUri: string = `${dirUri}/${fileName}`;
      const dstPath: string = new fileuri.FileUri(dstUri).path;

      const srcFile = fs.openSync(cachePath, fs.OpenMode.READ_ONLY);
      const dstFile = fs.openSync(dstUri, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.copyFileSync(srcFile.fd, dstFile.fd);
      fs.closeSync(srcFile);
      fs.closeSync(dstFile);

      // Return in new format for consistency
      const response: Record<string, string | null> = {
        'fileName': fileName,
        'uri': dstUri,
        'path': dstPath
      };
      result.success(response);

    } catch (e) {
      Log.e(TAG, `saveCacheFileToDownloads failed: ${JSON.stringify(e)}`);
      result.error('SAVE_FAILED', String(e), null);
    }
  }

  /**
   * Legacy method: Save cache file with dialog.
   * Kept for backward compatibility.
   */
  private async saveCacheFileWithDialog(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      if (!this.ability) {
        result.error('NO_ABILITY', 'UIAbility is null (plugin not attached to ability).', null);
        return;
      }

      const ctx = this.ability.context as common.UIAbilityContext;
      const cachePath = this.normalizeCachePath(ctx, String(call.argument('cachePath')));
      const fileName = String(call.argument('fileName'));

      const documentViewPicker = new picker.DocumentViewPicker(ctx);
      const opts = new picker.DocumentSaveOptions();
      opts.newFileNames = [fileName];

      const suffixObj = call.argument('fileSuffixChoices') as Array<string> | null;
      if (suffixObj && suffixObj.length > 0) {
        opts.fileSuffixChoices = suffixObj.map((x) => String(x));
      }

      const uris: Array<string> = await documentViewPicker.save(opts);
      if (!uris || uris.length === 0) {
        result.success(null);
        return;
      }

      const fileUriStr: string = uris[0];
      const dstPath: string = new fileuri.FileUri(fileUriStr).path;
      const savedFileName: string = dstPath.substring(dstPath.lastIndexOf('/') + 1);

      const srcFile = fs.openSync(cachePath, fs.OpenMode.READ_ONLY);
      const dstFile = fs.openSync(fileUriStr, fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.copyFileSync(srcFile.fd, dstFile.fd);
      fs.closeSync(srcFile);
      fs.closeSync(dstFile);

      const response: Record<string, string | null> = {
        'fileName': savedFileName,
        'uri': fileUriStr,
        'path': dstPath
      };
      result.success(response);

    } catch (e) {
      Log.e(TAG, `saveCacheFileWithDialog failed: ${JSON.stringify(e)}`);
      result.error('SAVE_FAILED', String(e), null);
    }
  }

  /**
   * Normalize cache path from Flutter format to actual file system path.
   */
  private normalizeCachePath(ctx: common.UIAbilityContext, input: string): string {
    if (input.startsWith('internal://cache/')) {
      const name = input.substring('internal://cache/'.length);
      return `${ctx.cacheDir}/${name}`;
    }
    if (input.startsWith('file://')) {
      return new fileuri.FileUri(input).path;
    }
    return input;
  }
}

