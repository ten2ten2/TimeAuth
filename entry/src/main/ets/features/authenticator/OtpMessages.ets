import { OtpErrorCode } from './OtpCore';

export function otpErrorMessage(code: OtpErrorCode): Resource {
  switch (code) {
    case OtpErrorCode.INVALID_SECRET: return $r('app.string.auth_live_invalid_secret_v2');
    case OtpErrorCode.INVALID_LABEL: return $r('app.string.auth_live_invalid_label');
    case OtpErrorCode.INVALID_PARAMETERS: return $r('app.string.auth_live_invalid_parameters_v2');
    case OtpErrorCode.INVALID_URI: return $r('app.string.auth_live_invalid_uri_v2');
    case OtpErrorCode.UNSUPPORTED_IMPORT: return $r('app.string.auth_live_unsupported_import_v2');
    case OtpErrorCode.ISSUER_MISMATCH: return $r('app.string.auth_live_issuer_mismatch');
    case OtpErrorCode.DUPLICATE: return $r('app.string.auth_live_duplicate');
    case OtpErrorCode.CRYPTO: return $r('app.string.auth_live_crypto_error_v2');
    case OtpErrorCode.LOCKED: return $r('app.string.auth_live_unlock_description');
    default: return $r('app.string.auth_live_operation_error');
  }
}
