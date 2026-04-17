import { NextResponse } from "next/server";
import { z } from "zod";

import { createSession, setSessionCookie, verifyPassword } from "@/lib/auth";
import { db } from "@/lib/db";
import { jsonError } from "@/lib/http";

const loginSchema = z.object({
  email: z.email().trim().toLowerCase(),
  password: z.string().min(8).max(128),
});

export async function POST(request: Request) {
  const body = await request.json().catch(() => null);
  const parsed = loginSchema.safeParse(body);

  if (!parsed.success) {
    return jsonError("Invalid login payload.", 422);
  }

  const user = await db.user.findUnique({
    where: { email: parsed.data.email },
  });

  if (!user) {
    return jsonError("Invalid email or password.", 401);
  }

  const isValid = await verifyPassword(user.passwordHash, parsed.data.password);

  if (!isValid) {
    return jsonError("Invalid email or password.", 401);
  }

  const session = await createSession(user.id);
  await setSessionCookie(session.token, session.expiresAt);

  return NextResponse.json({
    user: {
      id: user.id,
      email: user.email,
      createdAt: user.createdAt,
    },
  });
}
