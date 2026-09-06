import { OtpKind } from '../../models/AppModels';
import { displayOtp } from './OtpCore';
import { OtpSnapshot } from './OtpSession';

// Stable observed instances keep countdown/counter updates from rebuilding ListItems / closing swipe actions.
@Observed
export class OtpViewItem {
  id: string = '';
  issuer: string = '';
  account: string = '';
  kind: OtpKind = OtpKind.TOTP;
  code: string = '';
  remainingSeconds: number = 30;
  periodSeconds: number = 30;
  counter: number = 0;
  failed: boolean = false;

  constructor(snapshot: OtpSnapshot) {
    this.update(snapshot);
  }

  update(snapshot: OtpSnapshot): void {
    this.id = snapshot.id;
    this.issuer = snapshot.issuer;
    this.account = snapshot.account;
    this.kind = snapshot.kind;
    this.code = displayOtp(snapshot.code);
    this.remainingSeconds = snapshot.remaining;
    this.periodSeconds = snapshot.period;
    this.counter = snapshot.counter;
    this.failed = snapshot.failed;
  }
}
