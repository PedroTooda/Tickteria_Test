export interface QrCodeGenerator {
  /** @returns imagem em data URI (PNG) para o conteúdo informado. */
  toDataUri(content: string): Promise<string>;
}
