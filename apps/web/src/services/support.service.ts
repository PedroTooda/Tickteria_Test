import type { EmailDeliveryView } from '../types/email-delivery.type';

const API = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001';

export const supportService = {
  async listFailedEmails(): Promise<EmailDeliveryView[]> {
    const res = await fetch(`${API}/support/emails?status=FAILED`, { cache: 'no-store' });
    if (!res.ok) throw new Error('Falha ao listar e-mails');
    return res.json();
  },
  async resend(id: string): Promise<void> {
    const res = await fetch(`${API}/support/emails/${id}/resend`, { method: 'POST' });
    if (!res.ok) throw new Error('Falha ao reenviar e-mail');
  },
};
