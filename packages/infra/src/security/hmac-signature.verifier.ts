import { createHmac, timingSafeEqual } from 'node:crypto';
import { SignatureVerifier } from '@tickteira/core';

export class HmacSignatureVerifier implements SignatureVerifier {
  constructor(private readonly secret: string) {}

  verify(rawBody: Buffer, signature: string): boolean {
    const expected = createHmac('sha256', this.secret).update(rawBody).digest();
    const received = Buffer.from(signature, 'hex');
    return received.length === expected.length && timingSafeEqual(received, expected);
  }
}
