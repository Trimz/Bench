import { createHash, randomBytes, timingSafeEqual } from "node:crypto";

import argon2 from "argon2";
import { cookies } from "next/headers";

import { db } from "@/lib/db";
import { getEnv } from "@/lib/env";

const SESSION_COOKIE = "bench_session";
const SESSION_TTL_MS = 1000 * 60 * 60 * 24 * 30;

function hashToken(token: string) {
  return createHash("sha256").update(token).digest("hex");
}

function deriveCookieSignature(token: string, secret: string) {
  return createHash("sha256").update(`${token}:${secret}`).digest("hex");
}

export async function hashPassword(password: string) {
  return argon2.hash(password);
}

export async function verifyPassword(hash: string, password: string) {
  return argon2.verify(hash, password);
}

export async function createSession(userId: string) {
  const token = randomBytes(32).toString("hex");
  const expiresAt = new Date(Date.now() + SESSION_TTL_MS);

  await db.session.create({
    data: {
      userId,
      tokenHash: hashToken(token),
      expiresAt,
    },
  });

  return { token, expiresAt };
}

export async function setSessionCookie(token: string, expiresAt: Date) {
  const { SESSION_SECRET } = getEnv();
  const signature = deriveCookieSignature(token, SESSION_SECRET);
  const cookieStore = await cookies();

  cookieStore.set(SESSION_COOKIE, `${token}.${signature}`, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    expires: expiresAt,
  });
}

export async function clearSessionCookie() {
  const cookieStore = await cookies();
  cookieStore.delete(SESSION_COOKIE);
}

export async function getCurrentUser() {
  const { SESSION_SECRET } = getEnv();
  const cookieStore = await cookies();
  const rawValue = cookieStore.get(SESSION_COOKIE)?.value;

  if (!rawValue) {
    return null;
  }

  const [token, signature] = rawValue.split(".");

  if (!token || !signature) {
    return null;
  }

  const expectedSignature = deriveCookieSignature(token, SESSION_SECRET);
  const actual = Buffer.from(signature);
  const expected = Buffer.from(expectedSignature);

  if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) {
    return null;
  }

  const session = await db.session.findUnique({
    where: {
      tokenHash: hashToken(token),
    },
    include: {
      user: true,
    },
  });

  if (!session || session.expiresAt <= new Date()) {
    return null;
  }

  return session.user;
}
