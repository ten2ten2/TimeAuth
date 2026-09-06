import { BusinessError } from '@kit.BasicServicesKit';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { EmptyState } from '../../components/EmptyState';
import { OtpCard } from '../../components/OtpCard';
import { PageHeader } from '../../components/PageHeader';
import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../design/Tokens';
import { OtpKind } from '../../models/AppModels';
import { isAppSessionUnlocked } from '../../security/AppSession';
import { copySensitiveText } from '../../security/SecureClipboard';
import { emptyOtpDraft, OtpDraft, OtpError, parseOtpAuthUri, validateDraft } from './OtpCore';
import { NativeOtpCrypto } from './OtpCrypto';
import { OtpDeleteDialog } from './OtpDeleteDialog';
import { OtpEditor } from './OtpEditor';
import { otpErrorMessage } from './OtpMessages';
import { getOtpRepository } from './OtpRepository';
import { OtpSession, OtpSnapshot } from './OtpSession';
import { OtpViewItem } from './OtpViewItem';

@Component
export struct AuthenticatorPage {
  @StorageLink('timeauth.sessionUnlocked') @Watch('onSessionChanged') private unlocked: boolean = false;
  @State private items: OtpViewItem[] = [];
  @State private loading: boolean = false;
  @State private loadFailed: boolean = false;
  @State private ready: boolean = false;
  @State private busy: boolean = false;
  @State private scanning: boolean = false;
  @State private hasCodeFailure: boolean = false;
  @State private feedbackVisible: boolean = false;
  @State private feedbackText: ResourceStr = '';
  @State private showEditor: boolean = false;
  @State private editing: boolean = false;
  @State private editorDraft: OtpDraft = emptyOtpDraft();
  @State private editorError: ResourceStr = '';
  @State private deleteMessage: ResourceStr = '';
  private editorId: string = '';
  private deleteId: string = '';
  private deleteDialogOpen: boolean = false;
  private deleteToken: number = 0;
  private session: OtpSession | undefined = undefined;
  private listScroller: ListScroller = new ListScroller();
  private swipedItemId: string = '';
  private active: boolean = false;
  private lifetime: number = 0;
  private revision: number = 0;
  private copyRevision: number = 0;
  private refreshTimer: number = -1;
  private feedbackTimer: number = -1;
  private pendingScanTimer: number = -1;
  private pendingScan: OtpDraft | undefined = undefined;
  private pendingFeedback: ResourceStr = '';
  private lastSecond: number = -1;

  private deleteDialog: CustomDialogController | undefined = undefined;

  aboutToAppear(): void {
    this.active = true;
    if (this.unlocked && isAppSessionUnlocked()) {
      this.loadAccounts();
    }
  }

  aboutToDisappear(): void {
    this.active = false;
    this.lifetime += 1;
    this.suspend();
    this.clearPendingScan();
    this.pendingFeedback = '';
  }

  private onSessionChanged(): void {
    if (!this.active) { return; }
    if (this.unlocked && isAppSessionUnlocked()) {
      this.loadAccounts();
    } else {
      this.suspend();
    }
  }

  private suspend(): void {
    this.revision += 1;
    this.copyRevision += 1;
    this.ready = false;
    this.loading = false;
    this.busy = false;
    this.showEditor = false;
    this.editorDraft.secret = '';
    this.editorDraft = emptyOtpDraft();
    this.editorError = '';
    this.editorId = '';
    this.cancelDelete();
    this.closeSwipeActions();
    if (this.refreshTimer >= 0) { clearInterval(this.refreshTimer); this.refreshTimer = -1; }
    if (this.feedbackTimer >= 0) { clearTimeout(this.feedbackTimer); this.feedbackTimer = -1; }
    this.feedbackVisible = false;
    if (this.session !== undefined) { this.session.close(); this.session = undefined; }
    this.items = [];
  }

  private updateItems(snapshots: OtpSnapshot[]): void {
    if (!this.active || !this.unlocked || !isAppSessionUnlocked()) { return; }
    const next: OtpViewItem[] = [];
    let membershipChanged: boolean = snapshots.length !== this.items.length;
    this.hasCodeFailure = false;
    for (let i: number = 0; i < snapshots.length; i++) {
      const snapshot: OtpSnapshot = snapshots[i];
      const previous: OtpViewItem | undefined = this.items.find((item: OtpViewItem) => item.id === snapshot.id);
      if (previous !== undefined) {
        previous.update(snapshot);
        next.push(previous);
      } else {
        next.push(new OtpViewItem(snapshot));
        membershipChanged = true;
      }
      if (this.items[i] === undefined || this.items[i].id !== snapshot.id) { membershipChanged = true; }
      if (snapshot.failed) { this.hasCodeFailure = true; }
    }
    if (membershipChanged) { this.items = next; }
  }

  private async loadAccounts(): Promise<void> {
    if (!this.active || !isAppSessionUnlocked() || this.loading) { return; }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { this.loadFailed = true; return; }
    const revision: number = ++this.revision;
    this.loading = true;
    this.ready = false;
    this.loadFailed = false;
    if (this.session === undefined) {
      this.session = new OtpSession(getOtpRepository(context), new NativeOtpCrypto(), () => Date.now(),
        (items: OtpSnapshot[]) => { this.updateItems(items); });
    }
    try {
      await this.session.open();
      if (!this.active || revision !== this.revision || !isAppSessionUnlocked()) { return; }
      this.loading = false;
      this.ready = true;
      this.startRefresh();
      this.consumePendingScan();
      if (this.pendingFeedback !== '') {
        this.showFeedback(this.pendingFeedback);
        this.pendingFeedback = '';
      }
    } catch {
      if (this.active && revision === this.revision) {
        this.loading = false;
        this.ready = false;
        this.loadFailed = true;
        this.items = [];
      }
    }
  }

  private startRefresh(): void {
    if (this.refreshTimer >= 0) { clearInterval(this.refreshTimer); }
    this.lastSecond = -1;
    this.refreshTimer = setInterval(() => {
      const second: number = Math.floor(Date.now() / 1000);
      if (second === this.lastSecond || !this.ready || !isAppSessionUnlocked() || this.session === undefined) { return; }
      this.lastSecond = second;
      this.session.refresh().catch(() => {
        if (this.ready && isAppSessionUnlocked()) { this.hasCodeFailure = true; }
      });
    }, 250);
  }

  private showFeedback(message: ResourceStr): void {
    if (!this.active) { return; }
    if (!isAppSessionUnlocked()) { this.pendingFeedback = message; return; }
    if (this.feedbackTimer >= 0) { clearTimeout(this.feedbackTimer); }
    this.feedbackText = message;
    this.feedbackVisible = true;
    this.feedbackTimer = setTimeout(() => { this.feedbackVisible = false; this.feedbackTimer = -1; }, 2200);
  }

  private closeSwipeActions(): void {
    try { this.listScroller.closeAllSwipeActions(); } catch {}
    this.swipedItemId = '';
  }

  private async copyItem(id: string): Promise<void> {
    if (!this.ready || this.busy || !isAppSessionUnlocked() || this.session === undefined) { return; }
    if (this.swipedItemId.length > 0) { this.closeSwipeActions(); return; }
    const revision: number = ++this.copyRevision;
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { this.showFeedback($r('app.string.security_copy_failed')); return; }
    try {
      // TOTP/Steam are recalculated at tap time; HOTP copies the current counter without advancing it.
      const code: string = await this.session.freshCode(id);
      if (!this.active || !isAppSessionUnlocked() || revision !== this.copyRevision) { return; }
      const success: boolean = await copySensitiveText(context, code);
      if (this.active && isAppSessionUnlocked() && revision === this.copyRevision) {
        this.showFeedback(success ? $r('app.string.security_copy_success') : $r('app.string.security_copy_failed'));
      }
    } catch {
      if (this.active && isAppSessionUnlocked() && revision === this.copyRevision) {
        this.showFeedback($r('app.string.security_copy_failed'));
      }
    }
  }

  private async advanceHOTP(id: string): Promise<void> {
    if (!this.ready || this.busy || !isAppSessionUnlocked() || this.session === undefined) { return; }
    if (this.swipedItemId.length > 0) { this.closeSwipeActions(); return; }
    const item: OtpViewItem | undefined = this.items.find((value: OtpViewItem) => value.id === id);
    if (item === undefined || item.kind !== OtpKind.HOTP) { return; }
    const revision: number = this.revision;
    this.busy = true;
    this.copyRevision += 1;
    try {
      await this.session.advanceHOTP(id);
      if (this.active && revision === this.revision && isAppSessionUnlocked()) {
        this.showFeedback($r('app.string.auth_live_hotp_advanced'));
      }
    } catch (error) {
      if (this.active && revision === this.revision) {
        this.showFeedback(otpErrorMessage((error as OtpError).code));
      }
    } finally {
      if (revision === this.revision) { this.busy = false; }
    }
  }

  private openManual(): void {
    if (!this.ready || this.busy || !isAppSessionUnlocked()) { return; }
    this.openDraft('', emptyOtpDraft());
  }

  private openDraft(id: string, draft: OtpDraft): void {
    this.closeSwipeActions();
    this.editorId = id;
    this.editing = id.length > 0;
    this.editorDraft = draft;
    this.editorError = '';
    this.showEditor = true;
  }

  private openEditor(id: string): void {
    if (!this.ready || this.busy || !isAppSessionUnlocked() || this.session === undefined) { return; }
    try { this.openDraft(id, this.session.draft(id)); }
    catch (error) { this.showFeedback(otpErrorMessage((error as OtpError).code)); }
  }

  private async saveEdit(draft: OtpDraft): Promise<void> {
    if (!this.ready || this.busy || !isAppSessionUnlocked() || this.session === undefined) { return; }
    const revision: number = this.revision;
    this.busy = true;
    this.editorError = '';
    this.copyRevision += 1;
    try {
      await this.session.save(this.editorId, draft);
      if (!this.active || revision !== this.revision || !isAppSessionUnlocked()) { return; }
      this.showEditor = false;
      this.editorDraft.secret = '';
      this.editorDraft = emptyOtpDraft();
      this.showFeedback($r('app.string.auth_live_saved'));
    } catch (error) {
      if (this.active && revision === this.revision) {
        this.editorError = otpErrorMessage((error as OtpError).code);
      }
    } finally {
      if (revision === this.revision) { this.busy = false; }
    }
  }

  private confirmDelete(id: string): void {
    if (!this.ready || this.busy || this.deleteDialogOpen || !isAppSessionUnlocked()) { return; }
    const item: OtpViewItem | undefined = this.items.find((value: OtpViewItem) => value.id === id);
    if (item === undefined) { return; }
    this.closeSwipeActions();
    this.deleteId = id;
    this.deleteMessage = $r('app.string.auth_live_delete_message', item.issuer, item.account);
    this.deleteDialogOpen = true;
    const token: number = ++this.deleteToken;
    const revision: number = this.revision;
    try {
      this.deleteDialog = new CustomDialogController({
        builder: OtpDeleteDialog({ message: this.deleteMessage,
          onCancel: () => { if (token === this.deleteToken) { this.cancelDelete(); } },
          onDelete: () => { this.deleteConfirmed(id, token, revision); } }),
        autoCancel: true,
        cancel: () => {
          if (token !== this.deleteToken) { return; }
          this.deleteToken += 1;
          this.deleteDialogOpen = false;
          this.deleteId = '';
          this.deleteMessage = '';
          this.deleteDialog = undefined;
        }
      });
      this.deleteDialog.open();
    }
    catch { this.cancelDelete(); this.showFeedback($r('app.string.auth_live_operation_error')); }
  }

  private cancelDelete(): void {
    this.deleteToken += 1;
    const dialog: CustomDialogController | undefined = this.deleteDialog;
    this.deleteDialog = undefined;
    this.deleteDialogOpen = false;
    this.deleteId = '';
    this.deleteMessage = '';
    if (dialog !== undefined) { try { dialog.close(); } catch {} }
  }

  private async deleteConfirmed(id: string, token: number, revision: number): Promise<void> {
    if (id !== this.deleteId || token !== this.deleteToken || revision !== this.revision ||
      !this.deleteDialogOpen || !this.ready || this.busy || id.length === 0 ||
      !isAppSessionUnlocked() || this.session === undefined) { return; }
    this.cancelDelete();
    this.busy = true;
    this.copyRevision += 1;
    try {
      await this.session.remove(id);
      if (this.active && revision === this.revision && isAppSessionUnlocked()) {
        this.showFeedback($r('app.string.auth_live_deleted'));
      }
    } catch (error) {
      if (this.active && revision === this.revision) {
        this.showFeedback(otpErrorMessage((error as OtpError).code));
      }
    } finally {
      if (revision === this.revision) { this.busy = false; }
    }
  }

  private clearPendingScan(): void {
    if (this.pendingScan !== undefined) { this.pendingScan.secret = ''; this.pendingScan = undefined; }
    if (this.pendingScanTimer >= 0) { clearTimeout(this.pendingScanTimer); this.pendingScanTimer = -1; }
  }

  private consumePendingScan(): void {
    if (!this.ready || !isAppSessionUnlocked() || this.pendingScan === undefined) { return; }
    const draft: OtpDraft = validateDraft(this.pendingScan);
    this.clearPendingScan();
    this.openDraft('', draft); // Explicit review + Save. A scan never silently persists a credential.
  }

  private async scanQr(): Promise<void> {
    if (!this.ready || this.busy || this.scanning || !isAppSessionUnlocked()) { return; }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { this.showFeedback($r('app.string.auth_live_scan_failed')); return; }
    this.closeSwipeActions();
    this.clearPendingScan();
    this.scanning = true;
    const lifetime: number = this.lifetime;
    try {
      const result: scanBarcode.ScanResult = await scanBarcode.startScanForResult(context, {
        scanTypes: [scanCore.ScanType.QR_CODE], enableMultiMode: false, enableAlbum: true
      });
      if (!this.active || lifetime !== this.lifetime) { return; }
      this.pendingScan = parseOtpAuthUri(result.originalValue);
      // Native scanner may background this ability. Review is deferred until the app session is available again.
      this.pendingScanTimer = setTimeout(() => { this.clearPendingScan(); }, 120000);
      this.consumePendingScan();
    } catch (error) {
      if (this.active && lifetime === this.lifetime && (error as BusinessError).code !== 1000500002) {
        const code = (error as OtpError).code;
        this.showFeedback(typeof code === 'string' ? otpErrorMessage(code) : $r('app.string.auth_live_scan_failed'));
      }
    } finally {
      if (this.active && lifetime === this.lifetime) { this.scanning = false; }
    }
  }

  @Builder
  AddMenu() {
    Menu() {
      MenuItem({ startIcon: $r('app.media.menu_scan_qr'), content: $r('app.string.auth_scan_qr') })
        .onClick(() => { this.scanQr(); })
      MenuItem({ startIcon: $r('app.media.menu_manual_entry'), content: $r('app.string.auth_manual_entry') })
        .onClick(() => { this.openManual(); })
    }
  }

  @Builder
  SwipeActions(item: OtpViewItem) {
    Row({ space: AppSpacing.xs }) {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Image($r('app.media.action_edit'))
          .width(24).height(24).objectFit(ImageFit.Contain)
          .fillColor($r('app.color.brand')).draggable(false).accessibilityLevel('no')
      }
      .width(68).height('100%').padding(0)
      .backgroundColor($r('app.color.brand_soft')).borderRadius(AppRadius.medium)
      .accessibilityText($r('app.string.auth_edit_accessibility', item.issuer, item.account))
      .enabled(!this.busy)
      .onClick(() => { this.openEditor(item.id); })
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Image($r('app.media.action_delete'))
          .width(24).height(24).objectFit(ImageFit.Contain)
          .fillColor(Color.White).draggable(false).accessibilityLevel('no')
      }
      .width(68).height('100%').padding(0)
      .backgroundColor($r('app.color.danger')).borderRadius(AppRadius.medium)
      .accessibilityText($r('app.string.auth_delete_accessibility', item.issuer, item.account))
      .enabled(!this.busy)
      .onClick(() => { this.confirmDelete(item.id); })
    }
    .height('100%').width(152).padding({ left: AppSpacing.xs })
  }

  @Builder
  EditorSheet() {
    OtpEditor({
      initial: this.editorDraft, editing: this.editing, saving: this.busy, errorText: this.editorError,
      onSave: (draft: OtpDraft) => { this.saveEdit(draft); },
      onCancel: () => { this.showEditor = false; }
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: AppSpacing.md }) {
        Row({ space: AppSpacing.md }) {
          PageHeader({ title: $r('app.string.auth_title'), subtitle: $r('app.string.auth_live_subtitle') })
            .layoutWeight(1)
          Button('+')
            .type(ButtonType.Circle)
            .width(AppLayout.minimumTouchTarget).height(AppLayout.minimumTouchTarget)
            .fontSize(28).fontColor(Color.White).backgroundColor($r('app.color.brand'))
            .enabled(this.ready && !this.busy && !this.scanning)
            .accessibilityText($r('app.string.auth_add_code'))
            .bindMenu(this.AddMenu, { placement: Placement.BottomRight })
        }
        .width('100%').alignItems(VerticalAlign.Top)

        Text($r('app.string.auth_card_hint'))
          .fontSize(AppTypography.caption).fontColor($r('app.color.text_secondary')).width('100%')

        if (this.loading) {
          Column({ space: AppSpacing.md }) {
            LoadingProgress().width(40).height(40).color($r('app.color.brand'))
            Text($r('app.string.auth_live_loading')).fontColor($r('app.color.text_secondary'))
          }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.loadFailed) {
          Column({ space: AppSpacing.md }) {
            Text($r('app.string.auth_live_load_error'))
              .fontSize(AppTypography.body).fontColor($r('app.color.danger')).lineHeight(24)
            Button($r('app.string.auth_live_retry')).onClick(() => { this.loadAccounts(); })
          }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.items.length === 0) {
          Column({ space: AppSpacing.md }) {
            EmptyState({ symbol: '+', title: $r('app.string.auth_live_empty_title'),
              message: $r('app.string.auth_live_empty_message') })
            Text($r('app.string.auth_live_backup_warning'))
              .fontSize(AppTypography.label).fontColor($r('app.color.warning')).lineHeight(22)
          }
          .width('100%').layoutWeight(1)
        } else {
          if (this.hasCodeFailure) {
            Text($r('app.string.auth_live_crypto_error'))
              .fontSize(AppTypography.label).fontColor($r('app.color.danger')).width('100%')
          }
          List({ space: AppSpacing.sm, scroller: this.listScroller }) {
            ForEach(this.items, (item: OtpViewItem) => {
              ListItem() {
                OtpCard({
                  item: item,
                  onCopy: () => { this.copyItem(item.id); },
                  onAdvance: () => { this.advanceHOTP(item.id); }
                })
              }
              .swipeAction({
                end: { builder: () => { this.SwipeActions(item); }, actionAreaDistance: 0 },
                edgeEffect: SwipeEdgeEffect.None,
                onOffsetChange: (offset: number) => {
                  if (Math.abs(offset) > 1) { this.swipedItemId = item.id; }
                  else if (this.swipedItemId === item.id) { this.swipedItemId = ''; }
                }
              })
            }, (item: OtpViewItem) => item.id)
          }
          .width('100%').layoutWeight(1).scrollBar(BarState.Auto)
        }
      }
      .width('100%').height('100%').constraintSize({ maxWidth: AppLayout.pageMaxWidth })
      .padding({ left: AppLayout.compactPadding, right: AppLayout.compactPadding,
        top: AppSpacing.xl, bottom: AppSpacing.lg })

      if (this.feedbackVisible) {
        Text(this.feedbackText)
          .fontSize(AppTypography.label).fontColor(Color.White)
          .padding({ left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.sm, bottom: AppSpacing.sm })
          .backgroundColor('#CC17191D').borderRadius(AppRadius.pill).margin({ bottom: AppSpacing.lg })
          .hitTestBehavior(HitTestMode.None).transition(TransitionEffect.OPACITY)
      }
    }
    .width('100%').height('100%').backgroundColor($r('app.color.background'))
    .bindSheet($$this.showEditor, this.EditorSheet(), {
      height: SheetSize.LARGE, showClose: false, dragBar: false, backgroundColor: $r('app.color.surface'),
      onDisappear: () => {
        if (this.showEditor) { return; }
        this.editorDraft.secret = '';
        this.editorDraft = emptyOtpDraft();
        this.editorError = '';
        this.editorId = '';
      }
    })
  }
}
