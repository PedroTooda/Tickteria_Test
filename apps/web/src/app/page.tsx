import Link from 'next/link';

export default function Home() {
  return (
    <main>
      <h1>Tickteira</h1>
      <p>
        <Link href="/support/emails">Suporte: e-mails com falha</Link>
      </p>
    </main>
  );
}
