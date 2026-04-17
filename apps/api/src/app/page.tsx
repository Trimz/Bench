import Link from "next/link";

export default function Home() {
  return (
    <main className="shell">
      <section className="panel">
        <span className="eyebrow">Bench</span>
        <h1>Bench API is scaffolded.</h1>
        <p>
          This Vercel-ready Next.js app now contains the first auth, health, and project
          endpoints for the macOS client.
        </p>
        <div className="actions">
          <Link href="/api/health">Health endpoint</Link>
          <Link href="/api/auth/me">Auth status</Link>
        </div>
      </section>
    </main>
  );
}
