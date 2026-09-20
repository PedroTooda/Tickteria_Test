'use client';

import { useCallback, useEffect, useState } from 'react';
import { supportService } from '../../../services/support.service';
import type { EmailDeliveryView } from '../../../types/email-delivery.type';

export default function SupportEmailsPage() {
  const [items, setItems] = useState<EmailDeliveryView[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      setItems(await supportService.listFailedEmails());
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erro inesperado');
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  async function resend(id: string) {
    setBusyId(id);
    try {
      await supportService.resend(id);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erro inesperado');
    } finally {
      setBusyId(null);
    }
  }

  return (
    <main>
      <h1>E-mails com falha</h1>
      {error && <p style={{ color: 'crimson' }}>{error}</p>}
      {!error && items.length === 0 && <p>Nenhum envio com falha.</p>}
      {items.length > 0 && (
        <table cellPadding={8} style={{ borderCollapse: 'collapse' }}>
          <thead>
            <tr>
              <th align="left">Pedido</th>
              <th align="left">Destinatário</th>
              <th align="left">Tentativas</th>
              <th align="left">Erro</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {items.map((item) => (
              <tr key={item.id}>
                <td>{item.orderReference}</td>
                <td>{item.recipient}</td>
                <td>{item.attempts}</td>
                <td>{item.lastError}</td>
                <td>
                  <button disabled={busyId === item.id} onClick={() => resend(item.id)}>
                    {busyId === item.id ? 'Reenviando…' : 'Reenviar'}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </main>
  );
}
