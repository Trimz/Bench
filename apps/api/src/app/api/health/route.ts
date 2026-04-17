import { NextResponse } from "next/server";

export async function GET() {
  return NextResponse.json({
    ok: true,
    service: "bench-api",
    timestamp: new Date().toISOString(),
  });
}
