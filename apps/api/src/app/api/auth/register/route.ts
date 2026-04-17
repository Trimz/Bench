import { NextResponse } from "next/server";
import { z } from "zod";

import { createSession, hashPassword, setSessionCookie } from "@/lib/auth";
import { db } from "@/lib/db";
import { jsonError } from "@/lib/http";

const registerSchema = z.object({
  email: z.email().trim().toLowerCase(),
  password: z.string().min(8).max(128),
});

export async function POST(request: Request) {
  const body = await request.json().catch(() => null);
  const parsed = registerSchema.safeParse(body);

  if (!parsed.success) {
    return jsonError("Invalid registration payload.", 422);
  }

  const existingUser = await db.user.findUnique({
    where: { email: parsed.data.email },
    select: { id: true },
  });

  if (existingUser) {
    return jsonError("An account with that email already exists.", 409);
  }

  const user = await db.user.create({
    data: {
      email: parsed.data.email,
      passwordHash: await hashPassword(parsed.data.password),
    },
    select: {
      id: true,
      email: true,
      createdAt: true,
    },
  });

  const session = await createSession(user.id);
  await setSessionCookie(session.token, session.expiresAt);

  return NextResponse.json({
    user,
  });
}
