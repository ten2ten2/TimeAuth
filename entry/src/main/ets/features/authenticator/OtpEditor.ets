import { AppLayout, AppRadius, AppSpacing, AppTypography } from '../../design/Tokens';
import { OtpKind } from '../../models/AppModels';
import {
  emptyOtpDraft, OtpAlgorithm, OtpDraft, OtpError, OTP_ISSUER_MAX_LENGTH,
  OTP_ACCOUNT_MAX_LENGTH, OTP_SECRET_MAX_LENGTH, steamSharedSecretToBase32, validateDraft
} from './OtpCore';
import { otpErrorMessage } from './OtpMessages';

@Component
export struct OtpEditor {
  @Prop initial: OtpDraft = emptyOtpDraft();
  @Prop editing: boolean = false;
  @Prop saving: boolean = false;
  @Prop errorText: ResourceStr = '';
  onSave: (draft: OtpDraft) => void = () => {};
  onCancel: () => void = () => {};
  @State private issuer: string = '';
  @State private account: string = '';
  @State private secret: string = '';
  @State private kind: OtpKind = OtpKind.TOTP;
  @State private algorithm: OtpAlgorithm = OtpAlgorithm.SHA1;
  @State private digits: number = 6;
  @State private period: string = '30';
  @State private counter: string = '0';
  @State private replaceSecret: boolean = false;
  @State private base64Steam: boolean = false;
  @State private advanced: boolean = false;
  @State private localError: ResourceStr = '';

  aboutToAppear(): void {
    this.issuer = this.initial.issuer;
    this.account = this.initial.account;
    this.kind = this.initial.kind;
    this.algorithm = this.initial.algorithm;
    this.digits = this.initial.digits;
    this.period = `${this.initial.period}`;
    this.counter = `${this.initial.counter ?? 0}`;
    this.replaceSecret = !this.editing;
    this.secret = this.editing ? '' : this.initial.secret;
    this.base64Steam = this.kind === OtpKind.STEAM && this.initial.secret.length === 0;
    this.advanced = this.algorithm !== OtpAlgorithm.SHA1 || this.digits === 8 ||
      (this.kind === OtpKind.TOTP && this.period !== '30');
    this.localError = '';
  }

  aboutToDisappear(): void {
    this.secret = '';
    this.initial = emptyOtpDraft();
  }

  private kindIndex(): number {
    if (this.kind === OtpKind.HOTP) { return 1; }
    return this.kind === OtpKind.STEAM ? 2 : 0;
  }

  private kindLabel(): string {
    if (this.kind === OtpKind.HOTP) { return 'HOTP'; }
    return this.kind === OtpKind.STEAM ? 'Steam Guard' : 'TOTP';
  }

  private chooseKind(index: number): void {
    this.kind = index === 2 ? OtpKind.STEAM : index === 1 ? OtpKind.HOTP : OtpKind.TOTP;
    this.algorithm = OtpAlgorithm.SHA1;
    this.digits = this.kind === OtpKind.STEAM ? 5 : 6;
    this.period = '30';
    this.counter = '0';
    this.secret = '';
    this.base64Steam = this.kind === OtpKind.STEAM;
    this.advanced = false;
    if (this.kind === OtpKind.STEAM && this.issuer.trim().length === 0) {
      this.issuer = 'Steam';
    }
  }

  private parsedCounter(): number {
    if (this.kind !== OtpKind.HOTP) { return 0; }
    if (!/^[0-9]{1,16}$/.test(this.counter)) { return -1; }
    return Number(this.counter);
  }

  private submit(): void {
    if (this.saving) { return; }
    try {
      let secret: string = this.replaceSecret ? this.secret : this.initial.secret;
      if (this.replaceSecret && this.kind === OtpKind.STEAM && this.base64Steam) {
        secret = steamSharedSecretToBase32(secret);
      }
      const draft: OtpDraft = validateDraft({
        issuer: this.issuer, account: this.account, secret: secret, kind: this.kind,
        algorithm: this.algorithm, digits: this.digits,
        period: this.kind === OtpKind.HOTP ? 30 : /^[0-9]{1,5}$/.test(this.period) ? Number(this.period) : 0,
        counter: this.parsedCounter()
      });
      this.localError = '';
      this.onSave(draft);
    } catch (error) {
      this.localError = otpErrorMessage((error as OtpError).code);
    }
  }

  @Builder
  Label(text: ResourceStr) {
    Text(text)
      .fontSize(AppTypography.label)
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
  }

  @Builder
  AlgorithmAndDigits() {
    this.Label($r('app.string.auth_live_algorithm'))
    Select([{ value: 'SHA1' }, { value: 'SHA256' }, { value: 'SHA512' }])
      .selected(this.algorithm === OtpAlgorithm.SHA512 ? 2 : this.algorithm === OtpAlgorithm.SHA256 ? 1 : 0)
      .value(this.algorithm)
      .onSelect((index: number) => {
        this.algorithm = index === 2 ? OtpAlgorithm.SHA512 : index === 1 ? OtpAlgorithm.SHA256 : OtpAlgorithm.SHA1;
      })
    this.Label($r('app.string.auth_live_digits'))
    Select([{ value: '6' }, { value: '8' }])
      .selected(this.digits === 8 ? 1 : 0)
      .value(`${this.digits}`)
      .onSelect((index: number) => { this.digits = index === 1 ? 8 : 6; })
  }

  build() {
    Column({ space: AppSpacing.md }) {
      Row({ space: AppSpacing.xs }) {
        Button($r('app.string.auth_cancel'))
          .height(AppLayout.minimumTouchTarget)
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.brand'))
          .enabled(!this.saving)
          .onClick(() => { this.onCancel(); })
        Text(this.editing ? $r('app.string.auth_edit_title') : $r('app.string.auth_live_add_title'))
          .fontSize(AppTypography.section)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
        Button(this.saving ? $r('app.string.auth_live_saving') : $r('app.string.auth_save'))
          .height(AppLayout.minimumTouchTarget)
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.brand'))
          .enabled(!this.saving)
          .onClick(() => { this.submit(); })
      }
      .width('100%')

      Scroll() {
        Column({ space: AppSpacing.sm }) {
          this.Label($r('app.string.auth_issuer_label'))
          TextInput({ text: this.issuer, placeholder: $r('app.string.auth_issuer_label') })
            .maxLength(OTP_ISSUER_MAX_LENGTH)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.surface_secondary'))
            .accessibilityText($r('app.string.auth_issuer_label'))
            .onChange((value: string) => { this.issuer = value; })
          this.Label($r('app.string.auth_account_label'))
          TextInput({ text: this.account, placeholder: $r('app.string.auth_account_label') })
            .maxLength(OTP_ACCOUNT_MAX_LENGTH)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.surface_secondary'))
            .accessibilityText($r('app.string.auth_account_label'))
            .onChange((value: string) => { this.account = value; })
          this.Label($r('app.string.auth_type_label'))
          Select([{ value: 'TOTP' }, { value: 'HOTP' }, { value: 'Steam Guard' }])
            .selected(this.kindIndex())
            .value(this.kindLabel())
            .enabled(!this.editing)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.surface_secondary'))
            .onSelect((index: number) => { this.chooseKind(index); })

          if (this.editing) {
            Row() {
              Text($r('app.string.auth_live_replace_secret'))
                .fontSize(AppTypography.body)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.replaceSecret })
                .selectedColor($r('app.color.brand'))
                .onChange((value: boolean) => {
                  this.replaceSecret = value;
                  this.secret = '';
                })
            }
            .width('100%')
            .height(AppLayout.minimumTouchTarget)
          }
          if (this.replaceSecret) {
            if (this.kind === OtpKind.STEAM) {
              this.Label($r('app.string.auth_live_secret_format'))
              Select([{ value: 'Base32' }, { value: 'shared_secret (Base64)' }])
                .selected(this.base64Steam ? 1 : 0)
                .value(this.base64Steam ? 'shared_secret (Base64)' : 'Base32')
                .onSelect((index: number) => { this.base64Steam = index === 1; this.secret = ''; })
            }
            this.Label(this.base64Steam && this.kind === OtpKind.STEAM ?
              $r('app.string.auth_live_steam_secret') : $r('app.string.auth_live_secret'))
            TextInput({ text: this.secret, placeholder: this.base64Steam && this.kind === OtpKind.STEAM ?
              $r('app.string.auth_live_steam_secret') : $r('app.string.auth_live_secret') })
              .type(InputType.Password)
              .enableAutoFill(false)
              .copyOption(CopyOptions.None)
              .maxLength(OTP_SECRET_MAX_LENGTH)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor($r('app.color.surface_secondary'))
              .accessibilityText($r('app.string.auth_live_secret'))
              .onChange((value: string) => { this.secret = value; })
          } else {
            Text($r('app.string.auth_live_secret_unchanged'))
              .fontSize(AppTypography.label)
              .fontColor($r('app.color.text_secondary'))
          }

          if (this.kind === OtpKind.STEAM) {
            Text($r('app.string.auth_live_steam_notice'))
              .fontSize(AppTypography.label)
              .fontColor($r('app.color.text_secondary'))
              .lineHeight(22)
          } else {
            if (this.kind === OtpKind.HOTP) {
              this.Label($r('app.string.auth_live_hotp_counter'))
              TextInput({ text: this.counter })
                .type(InputType.Number)
                .maxLength(16)
                .fontColor($r('app.color.text_primary'))
                .backgroundColor($r('app.color.surface_secondary'))
                .accessibilityText($r('app.string.auth_live_hotp_counter'))
                .onChange((value: string) => { this.counter = value; })
              Text($r('app.string.auth_live_hotp_counter_notice'))
                .fontSize(AppTypography.caption)
                .fontColor($r('app.color.warning'))
                .lineHeight(20)
            }
            Button($r('app.string.auth_live_advanced'))
              .backgroundColor(Color.Transparent)
              .fontColor($r('app.color.brand'))
              .height(AppLayout.minimumTouchTarget)
              .onClick(() => { this.advanced = !this.advanced; })
            if (this.advanced) {
              this.AlgorithmAndDigits()
              if (this.kind === OtpKind.TOTP) {
                this.Label($r('app.string.auth_live_period'))
                TextInput({ text: this.period })
                  .type(InputType.Number)
                  .maxLength(5)
                  .fontColor($r('app.color.text_primary'))
                  .backgroundColor($r('app.color.surface_secondary'))
                  .accessibilityText($r('app.string.auth_live_period'))
                  .onChange((value: string) => { this.period = value; })
                Text($r('app.string.auth_live_parameters_notice'))
                  .fontSize(AppTypography.caption)
                  .fontColor($r('app.color.text_secondary'))
                  .lineHeight(20)
              } else {
                Text($r('app.string.auth_live_hotp_parameters_notice'))
                  .fontSize(AppTypography.caption)
                  .fontColor($r('app.color.text_secondary'))
                  .lineHeight(20)
              }
            }
          }
          if (this.localError !== '' || this.errorText !== '') {
            Text(this.localError !== '' ? this.localError : this.errorText)
              .fontSize(AppTypography.label)
              .fontColor($r('app.color.danger'))
              .width('100%')
          }
          Text($r('app.string.auth_live_backup_warning'))
            .fontSize(AppTypography.label)
            .fontColor($r('app.color.warning'))
            .lineHeight(22)
            .width('100%')
        }
        .enabled(!this.saving)
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ bottom: AppSpacing.xxl })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding(AppSpacing.lg)
    .backgroundColor($r('app.color.surface'))
  }
}
