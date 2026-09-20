export interface SignatureVerifier {
  /** Valida HMAC-SHA256 sobre o corpo CRU (bytes originais). */
  verify(rawBody: Buffer, signature: string): boolean;
}
